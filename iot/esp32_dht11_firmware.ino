#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <DHT.h>
#include <ArduinoJson.h>
#include <time.h>

#define DHTPIN 4
#define DHTTYPE DHT11

const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";
const char* serverUrl = "https://us-central1-YOUR_PROJECT.cloudfunctions.net/receiveTelemetry";
const char* warehouseId = "YOUR_WAREHOUSE_ID";

DHT dht(DHTPIN, DHTTYPE);
WiFiClientSecure client;

void setup() {
  Serial.begin(115200);
  dht.begin();

  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected");
  Serial.print("IP: ");
  Serial.println(WiFi.localIP());

  // Skip SSL verification (aman untuk demo akademis)
  client.setInsecure();

  // Sinkronisasi waktu via NTP
  configTime(7 * 3600, 0, "pool.ntp.org", "time.nist.gov");
  while (time(nullptr) < 100000) {
    delay(100);
  }
  Serial.println("NTP synced");
}

String getISO8601Timestamp() {
  time_t now = time(nullptr);
  struct tm* t = gmtime(&now);
  char buf[25];
  strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%SZ", t);
  return String(buf);
}

void loop() {
  float temp = dht.readTemperature();
  float hum = dht.readHumidity();

  if (!isnan(temp) && !isnan(hum)) {
    HTTPClient http;
    http.begin(client, serverUrl);
    http.addHeader("Content-Type", "application/json");

    StaticJsonDocument<256> doc;
    doc["id_gudang"] = warehouseId;
    doc["timestamp"] = getISO8601Timestamp();
    doc["suhu"] = temp;
    doc["kelembapan"] = hum;

    String body;
    serializeJson(doc, body);

    int httpCode = http.POST(body);
    Serial.printf("POST → %d | %s\n", httpCode, body.c_str());

    if (httpCode <= 0) {
      Serial.printf("Error: %s\n", http.errorToString(httpCode).c_str());
    }

    http.end();
  } else {
    Serial.println("Sensor read failed");
  }

  delay(7000);
}
