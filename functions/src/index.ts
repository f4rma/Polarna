import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// =============================================================================
// 1. receiveTelemetry — HTTP endpoint untuk menerima data dari ESP32 IoT Node
// =============================================================================

interface TelemetryPayload {
  id_gudang: string;
  timestamp: string;
  suhu: number;
  kelembapan: number;
}

export const receiveTelemetry = functions.https.onRequest(async (req, res) => {
  // Hanya terima POST
  if (req.method !== "POST") {
    res.status(405).json({error: "Method not allowed"});
    return;
  }

  const body = req.body as Partial<TelemetryPayload>;
  const errors: string[] = [];

  // Validasi field wajib
  if (!body.id_gudang || typeof body.id_gudang !== "string" ||
      body.id_gudang.trim() === "") {
    errors.push("id_gudang");
  }
  if (!body.timestamp || typeof body.timestamp !== "string") {
    errors.push("timestamp");
  } else {
    const parsed = new Date(body.timestamp);
    if (isNaN(parsed.getTime())) errors.push("timestamp");
  }
  if (body.suhu === undefined || typeof body.suhu !== "number" ||
      body.suhu < -50 || body.suhu > 100) {
    errors.push("suhu");
  }
  if (body.kelembapan === undefined || typeof body.kelembapan !== "number" ||
      body.kelembapan < 0 || body.kelembapan > 100) {
    errors.push("kelembapan");
  }

  if (errors.length > 0) {
    res.status(400).json({
      error: "Payload tidak valid",
      invalidFields: errors,
    });
    return;
  }

  // Simpan ke Firestore
  const telemetryData = {
    warehouseId: body.id_gudang,
    timestamp: admin.firestore.Timestamp.fromDate(new Date(body.timestamp!)),
    temperature: body.suhu,
    humidity: body.kelembapan,
    receivedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  try {
    await db.collection("telemetry").add(telemetryData);
    res.status(200).json({status: "ok"});
  } catch (err) {
    functions.logger.error("Gagal menyimpan telemetri:", err);
    res.status(500).json({error: "Internal server error"});
  }
});

// =============================================================================
// 2. onTelemetryWrite — Firestore trigger: cek threshold & kirim notifikasi
// =============================================================================

export const onTelemetryWrite = functions.firestore
  .document("telemetry/{telemetryId}")
  .onCreate(async (snap) => {
    const data = snap.data();
    const warehouseId = data.warehouseId as string;
    const temperature = data.temperature as number;

    // Ambil data gudang untuk threshold
    const warehouseDoc = await db.collection("warehouses")
      .doc(warehouseId).get();

    if (!warehouseDoc.exists) {
      functions.logger.warn(`Gudang ${warehouseId} tidak ditemukan`);
      return;
    }

    const warehouse = warehouseDoc.data()!;
    const threshold = warehouse.temperatureThreshold as number;
    const warehouseName = warehouse.name as string;

    // Cek pelanggaran: suhu > threshold
    if (temperature <= threshold) {
      return; // Normal — tidak perlu notifikasi
    }

    // === PELANGGARAN TERDETEKSI ===
    functions.logger.info(
      `Pelanggaran suhu di ${warehouseName}: ${temperature}°C > ${threshold}°C`
    );

    // Cari semua UMKM dengan booking aktif di gudang ini
    const activeBookings = await db.collection("bookings")
      .where("warehouseId", "==", warehouseId)
      .where("status", "==", "active")
      .get();

    const affectedUmkmIds = activeBookings.docs.map(
      (doc) => doc.data().umkmId as string
    );

    // Kumpulkan FCM tokens: Mitra pemilik + UMKM aktif
    const recipientIds = [warehouse.mitraId, ...affectedUmkmIds];
    const tokens: string[] = [];

    for (const uid of recipientIds) {
      const userDoc = await db.collection("users").doc(uid).get();
      if (userDoc.exists) {
        const fcmToken = userDoc.data()?.fcmToken;
        if (fcmToken) tokens.push(fcmToken);
      }
    }

    // Kirim push notification
    const notificationsSent: string[] = [];
    const notificationsFailed: string[] = [];

    if (tokens.length > 0) {
      const message: admin.messaging.MulticastMessage = {
        tokens,
        notification: {
          title: "⚠️ Peringatan Suhu!",
          body: `${warehouseName}: ${temperature.toFixed(1)}°C melebihi batas ${threshold.toFixed(1)}°C`,
        },
        data: {
          type: "violation",
          warehouseId: warehouseId,
          temperature: temperature.toString(),
          threshold: threshold.toString(),
        },
      };

      try {
        const response = await messaging.sendEachForMulticast(message);
        response.responses.forEach((resp, idx) => {
          if (resp.success) {
            notificationsSent.push(recipientIds[idx]);
          } else {
            notificationsFailed.push(recipientIds[idx]);
          }
        });
      } catch (err) {
        functions.logger.error("Gagal mengirim notifikasi:", err);
        notificationsFailed.push(...recipientIds);
      }
    }

    // Catat ke incident_logs
    const severity = (temperature - threshold) > 5 ? "critical" : "warning";

    await db.collection("incident_logs").add({
      warehouseId,
      warehouseName,
      temperature,
      threshold,
      severity,
      eventType: "violation",
      affectedUmkmIds,
      notificationsSent,
      notificationsFailed,
      timestamp: data.timestamp,
      resolvedAt: null,
    });
  });

// =============================================================================
// 3. onTelemetryRecovery — Deteksi pemulihan suhu (5 menit berturut normal)
// =============================================================================

export const checkRecovery = functions.pubsub
  .schedule("every 5 minutes")
  .onRun(async () => {
    // Cari incident_logs yang belum resolved
    const unresolvedIncidents = await db.collection("incident_logs")
      .where("resolvedAt", "==", null)
      .where("eventType", "==", "violation")
      .get();

    for (const incidentDoc of unresolvedIncidents.docs) {
      const incident = incidentDoc.data();
      const warehouseId = incident.warehouseId as string;
      const threshold = incident.threshold as number;

      // Ambil 5 menit terakhir data telemetri
      const fiveMinAgo = new Date(Date.now() - 5 * 60 * 1000);
      const recentData = await db.collection("telemetry")
        .where("warehouseId", "==", warehouseId)
        .where("timestamp", ">=", admin.firestore.Timestamp.fromDate(fiveMinAgo))
        .orderBy("timestamp", "desc")
        .get();

      if (recentData.empty) continue;

      // Cek apakah SEMUA reading dalam 5 menit terakhir <= threshold
      const allNormal = recentData.docs.every(
        (doc) => (doc.data().temperature as number) <= threshold
      );

      if (!allNormal) continue;

      // === PEMULIHAN TERDETEKSI ===
      const latestTemp = recentData.docs[0].data().temperature as number;

      // Update incident sebagai resolved
      await incidentDoc.ref.update({
        resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Ambil warehouse untuk mitra ID
      const warehouseDoc = await db.collection("warehouses")
        .doc(warehouseId).get();
      const mitraId = warehouseDoc.data()?.mitraId;
      const warehouseName = incident.warehouseName;

      // Kirim notifikasi pemulihan ke Mitra + semua UMKM yang terdampak
      const allRecipients = mitraId
        ? [mitraId, ...incident.affectedUmkmIds]
        : incident.affectedUmkmIds;

      const tokens: string[] = [];
      for (const uid of allRecipients) {
        const userDoc = await db.collection("users").doc(uid).get();
        if (userDoc.exists) {
          const fcmToken = userDoc.data()?.fcmToken;
          if (fcmToken) tokens.push(fcmToken);
        }
      }

      if (tokens.length > 0) {
        await messaging.sendEachForMulticast({
          tokens,
          notification: {
            title: "✅ Suhu Kembali Normal",
            body: `${warehouseName}: ${latestTemp.toFixed(1)}°C — suhu telah stabil`,
          },
          data: {
            type: "recovery",
            warehouseId,
            temperature: latestTemp.toString(),
          },
        });
      }

      // Catat recovery di incident_logs
      await db.collection("incident_logs").add({
        warehouseId,
        warehouseName,
        temperature: latestTemp,
        threshold,
        severity: "info",
        eventType: "recovery",
        affectedUmkmIds: incident.affectedUmkmIds,
        notificationsSent: allRecipients,
        notificationsFailed: [],
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      functions.logger.info(
        `Pemulihan suhu di ${warehouseName}: ${latestTemp}°C`
      );
    }
  });
