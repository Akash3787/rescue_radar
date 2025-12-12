# ESP32 Setup Guide for Rescue Radar

## Hardware Requirements

### Required Components:
- ESP32 Development Board (ESP32-WROOM-32 or similar)
- Ultrasonic Sensor (HC-SR04) - for range detection
- Optional Sensors:
  - DHT22 - Temperature & Humidity
  - MQ-2 Gas Sensor - Gas detection
  - Servo Motor - For angle measurement
  - MPU6050 IMU - For precise angle measurement

### Pin Connections:

| Component | ESP32 Pin | Notes |
|-----------|-----------|-------|
| Ultrasonic Trigger | GPIO 5 | Digital output |
| Ultrasonic Echo | GPIO 18 | Digital input |
| Servo Motor | GPIO 19 | PWM output (optional) |
| DHT22 Data | GPIO 4 | Digital input (optional) |
| MQ-2 Sensor | GPIO 34 | Analog input (optional) |

## Software Setup

### 1. Install Arduino IDE
- Download from: https://www.arduino.cc/en/software
- Install ESP32 Board Support:
  - File → Preferences → Additional Board Manager URLs
  - Add: `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
  - Tools → Board → Boards Manager → Search "ESP32" → Install

### 2. Install Required Libraries
Open Arduino IDE → Sketch → Include Library → Manage Libraries:

- **ArduinoJson** by Benoit Blanchon (version 6.x or 7.x)
  - Search "ArduinoJson" and install

- **DHT sensor library** by Adafruit (if using DHT22)
  - Search "DHT sensor library" and install
  - Also install "Adafruit Unified Sensor" dependency

### 3. Configure the Code

Edit `esp32_rescue_radar.ino`:

```cpp
// Update these values:
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";
const char* apiKey = "rescue-radar-dev";  // Your WRITE_API_KEY from Railway
```

### 4. Upload Code

1. Connect ESP32 via USB
2. Select Board: Tools → Board → ESP32 Arduino → Your ESP32 Board
3. Select Port: Tools → Port → COMx (Windows) or /dev/ttyUSBx (Linux/Mac)
4. Click Upload button

## Testing

### Serial Monitor
1. Open Serial Monitor (Tools → Serial Monitor)
2. Set baud rate to 115200
3. You should see:
   - WiFi connection status
   - Device ID (based on MAC address)
   - Sensor readings every second
   - HTTP POST requests every 5 seconds

### Expected Output:
```
=== Rescue Radar ESP32 ===
Connecting to WiFi...
WiFi Connected!
IP Address: 192.168.1.100
Device ID: esp32-A1B2C3

--- Sensor Readings ---
Detected: YES
Range: 245.3 cm
Angle: 45.0 deg
Temperature: 26.5 C
Humidity: 65.0 %
Gas: 120 ppm

--- Sending Data to Backend ---
URL: https://web-production-87279.up.railway.app/api/v1/readings
Payload: {"victim_id":"esp32-A1B2C3","detected":true,"range_cm":245.3,...}
HTTP Response code: 200
✓ Data sent successfully!
```

## Customization

### Change Send Interval
```cpp
const unsigned long SEND_INTERVAL = 5000;  // Change to desired milliseconds
```

### Add GPS Module
If you want to include GPS coordinates:

```cpp
#include <TinyGPS++.h>
#include <HardwareSerial.h>

HardwareSerial SerialGPS(1);
TinyGPS++ gps;

void setup() {
  SerialGPS.begin(9600, SERIAL_8N1, 16, 17);  // RX=16, TX=17
}

void readGPS(float* lat, float* lon) {
  while (SerialGPS.available() > 0) {
    if (gps.encode(SerialGPS.read())) {
      if (gps.location.isValid()) {
        *lat = gps.location.lat();
        *lon = gps.location.lng();
      }
    }
  }
}

// Add to JSON payload:
if (latitude > 0 && longitude > 0) {
  doc["latitude"] = latitude;
  doc["longitude"] = longitude;
}
```

### Multiple Sensors
To use multiple ESP32 devices:

1. Each device will auto-generate unique ID from MAC address
2. Or manually set: `victimId = "esp32-sensor-01";`
3. All devices can send to the same backend simultaneously

## Troubleshooting

### WiFi Connection Fails
- Check SSID and password
- Ensure 2.4GHz WiFi (ESP32 doesn't support 5GHz)
- Check signal strength

### HTTP Request Fails
- Verify backend URL is correct
- Check API key matches Railway `WRITE_API_KEY`
- Check Serial Monitor for error messages
- Test backend with curl:
  ```bash
  curl -X POST https://web-production-87279.up.railway.app/api/v1/readings \
    -H "Content-Type: application/json" \
    -H "x-api-key: rescue-radar-dev" \
    -d '{"victim_id":"test","detected":true,"range_cm":100}'
  ```

### Sensor Readings Incorrect
- Calibrate ultrasonic sensor (check datasheet)
- Verify pin connections
- Check sensor power supply (5V for HC-SR04)
- Use voltage divider if sensor is 5V and ESP32 is 3.3V

### Compilation Errors
- Ensure all libraries are installed
- Check Arduino IDE version (1.8.x or 2.x)
- Verify ESP32 board support is installed

## Power Consumption

For battery-powered operation:
- Use deep sleep mode between readings
- Reduce send interval
- Disable unnecessary sensors
- Use ESP32's built-in power management

Example deep sleep code:
```cpp
// After sending data:
esp_sleep_enable_timer_wakeup(SEND_INTERVAL * 1000);  // microseconds
esp_deep_sleep_start();
```

## Security Notes

- **Never commit WiFi credentials** to version control
- Use environment variables or separate config file
- Consider using WiFiManager library for easy setup
- Use HTTPS (already configured in code)
- Rotate API keys periodically

## Next Steps

1. Test with one ESP32 device
2. Verify data appears in your Flutter app
3. Deploy multiple devices as needed
4. Monitor backend logs for errors
5. Adjust sensor calibration as needed
