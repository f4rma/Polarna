# IoT Firmware — ESP32 + DHT11

Firmware untuk node IoT yang mengirim data suhu dan kelembapan ke Cloud Function Polarna.

## Hardware

- ESP32 DevKit V1
- DHT11 (sensor suhu & kelembapan)
- Resistor 10kΩ (pull-up, antara DATA dan VCC — jika sensor telanjang)

## Wiring

| DHT11 Pin | ESP32 Pin |
|-----------|-----------|
| VCC       | 3.3V      |
| DATA      | GPIO 4    |
| GND       | GND       |

## Setup

1. Buka `esp32_dht11_firmware.ino` di Arduino IDE
2. Install libraries: `DHT sensor library`, `ArduinoJson`, `Adafruit Unified Sensor`
3. Pilih board: ESP32 Dev Module
4. Ganti placeholder:
   - `YOUR_WIFI_SSID` → nama WiFi
   - `YOUR_WIFI_PASSWORD` → password WiFi
   - `YOUR_PROJECT` → Firebase project ID
   - `YOUR_WAREHOUSE_ID` → Document ID gudang dari Firestore
5. Upload ke ESP32
6. Buka Serial Monitor (115200 baud)

## Output yang Diharapkan

```
WiFi connected
IP: 192.168.x.x
NTP synced
POST → 200 | {"id_gudang":"xxx","timestamp":"2026-05-20T10:00:00Z","suhu":28.5,"kelembapan":65}
```

## Protokol

HTTP POST (HTTPS) ke Firebase Cloud Function `receiveTelemetry`. Interval: 7 detik.
