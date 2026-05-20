# Polarna

Platform logistik rantai dingin (cold chain) terdesentralisasi yang menghubungkan UMKM dengan Mitra pemilik gudang berpendingin, dilengkapi monitoring suhu real-time berbasis IoT.

## Fitur Utama

| Role | Fitur |
|------|-------|
| **UMKM** | Cari gudang, booking, QR check-in/out, pantau suhu real-time |
| **Mitra** | Daftarkan gudang, kelola kapasitas, scan QR, laporan pendapatan |
| **Admin** | Verifikasi gudang, manajemen pengguna, statistik platform |

## Tech Stack

- **Frontend**: Flutter 3.x (Dart), Riverpod 2.x, GoRouter
- **Backend**: Firebase (Auth, Firestore, Storage, Cloud Functions, FCM)
- **IoT**: ESP32 + DHT11, HTTP POST ke Cloud Functions
- **Architecture**: Clean Architecture (feature-first)
- **Testing**: 282+ tests (unit, property-based via Glados, integration)

## Arsitektur

```
lib/
├── core/              # Theme, router, constants, utils, widgets
├── features/
│   ├── auth/          # Login, register, profile, email verification
│   ├── warehouse/     # Search, register, edit, detail, map picker
│   ├── booking/       # Form, payment, QR check-in/out, history
│   ├── telemetry/     # Real-time monitoring, chart, CSV export
│   ├── notification/  # Breach detection, incident logs
│   ├── dashboard_mitra/  # Revenue, transactions, warehouse health
│   └── admin/         # Dashboard, user management, verification
```

## Alur Sistem

```
UMKM bayar → status "paid" → QR Check-In (Mitra scan) → status "active"
→ Monitoring suhu real-time → QR Check-Out (Mitra scan) → status "completed"
```

## IoT Architecture

```
ESP32 + DHT11 → HTTP POST (setiap 7 detik) → Cloud Function (receiveTelemetry)
→ Firestore (telemetry) → Firestore Trigger (onTelemetryWrite)
→ Cek threshold → FCM Push Notification (jika breach)
```

## Revenue Model

Platform menggunakan commission-based model:
- UMKM bayar 100% total booking
- Platform (Polarna) mengambil 10% komisi
- Mitra menerima 90% dari total booking

## Setup & Run

### Prerequisites
- Flutter SDK 3.x
- Firebase CLI
- Node.js 20+ (untuk Cloud Functions)
- Android Studio / VS Code

### Langkah

```bash
# 1. Clone repo
git clone https://github.com/f4rma/Polarna.git
cd Polarna

# 2. Install dependencies
flutter pub get

# 3. Setup Firebase (buat project di Firebase Console)
flutterfire configure --project=YOUR_PROJECT_ID

# 4. Deploy Cloud Functions
cd functions
npm install
cd ..
firebase deploy --only functions

# 5. Deploy Firestore indexes & rules
firebase deploy --only firestore

# 6. Run app
flutter run
```

### ESP32 Firmware

Upload firmware di `sketch_may14a/` ke ESP32 dengan Arduino IDE. Ganti:
- `serverUrl` → URL Cloud Function `receiveTelemetry`
- `warehouseId` → Document ID gudang dari Firestore

## Security

- Email verification wajib sebelum login
- Account lockout (5x gagal → 15 menit terkunci)
- Firestore Security Rules per-role
- Firebase Storage rules (max 5MB/foto)
- QR Code verification untuk serah-terima barang
- Admin verification untuk gudang baru

## Testing

```bash
# Run semua tests
flutter test

# Run dengan coverage
flutter test --coverage
```

## License

© 2026 Raditya Putra. All rights reserved.

Proyek ini merupakan karya tugas akhir mata kuliah Mobile Development Lanjutan. Tidak diperkenankan untuk direproduksi, didistribusikan, atau digunakan tanpa izin tertulis dari pemilik.
