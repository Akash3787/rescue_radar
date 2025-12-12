# ESP32 Quick Start - Range, Detected, Angle Only

## Hardware Setup

### Required Components:
- ESP32 Development Board
- HC-SR04 Ultrasonic Sensor (for range)
- Optional: Potentiometer or analog sensor (for angle)

### Pin Connections:

| Component | ESP32 Pin | Description |
|-----------|-----------|-------------|
| Ultrasonic Trigger | GPIO 5 | Digital output |
| Ultrasonic Echo | GPIO 18 | Digital input |
| Angle Sensor | GPIO 34 | Analog input (optional) |

## Software Setup

### 1. Install Arduino IDE
- Download: https://www.arduino.cc/en/software

### 2. Add ESP32 Board Support
1. File → Preferences
2. Add to "Additional Board Manager URLs":
   ```
   https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
   ```
3. Tools → Board → Boards Manager
4. Search "ESP32" → Install

### 3. Install ArduinoJson Library
1. Sketch → Include Library → Manage Libraries
2. Search "ArduinoJson" by Benoit Blanchon
3. Install version 6.x or 7.x

### 4. Configure Code
Open `esp32_minimal.ino` and update:

```cpp
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";
const char* apiKey = "rescue-radar-dev";  // Your Railway WRITE_API_KEY
```

### 5. Upload
1. Connect ESP32 via USB
2. Tools → Board → Select your ESP32 board
3. Tools → Port → Select COM port
4. Click Upload

## Testing

### Serial Monitor
1. Tools → Serial Monitor
2. Set baud rate: 115200
3. You should see:

```
=== Rescue Radar ESP32 ===
Connecting to WiFi...
WiFi Connected!
IP: 192.168.1.100
Device ID: esp32-A1B2C3

--- Sensor Readings ---
Range: 245.3 cm
Detected: YES
Angle: 45.0 deg

--- Sending to Backend ---
URL: https://web-production-87279.up.railway.app/api/v1/readings
Payload: {"victim_id":"esp32-A1B2C3","detected":true,"range_cm":245.3,"angle_deg":45.0}
✓ Success! Data sent to backend.
```

## Angle Measurement Options

### Option 1: Analog Potentiometer
- Connect potentiometer middle pin to GPIO 34
- Connect outer pins to 3.3V and GND
- Code already configured for this

### Option 2: Servo Motor Position
If using servo to rotate sensor:
```cpp
float readAngle() {
  // Read servo position (0-180 degrees)
  int servoPos = readServoPosition();  // Implement your servo reading
  return servoPos;  // or convert to 0-360 range
}
```

### Option 3: Fixed/Sweep Pattern
For testing without angle sensor:
```cpp
float readAngle() {
  static float angle = 0.0;
  angle += 5.0;  // Increment by 5 degrees each read
  if (angle >= 360.0) angle = 0.0;
  return angle;
}
```

## Data Sent to Backend

The code sends this JSON format:
```json
{
  "victim_id": "esp32-A1B2C3",
  "detected": true,
  "range_cm": 245.3,
  "angle_deg": 45.0
}
```

This matches your backend's expected format exactly.

## Troubleshooting

### WiFi Won't Connect
- Check SSID and password
- Ensure 2.4GHz WiFi (ESP32 doesn't support 5GHz)
- Check signal strength

### HTTP Error 401
- Verify `apiKey` matches your Railway `WRITE_API_KEY`
- Check Railway environment variables

### HTTP Error 400
- Check JSON payload format
- Ensure range_cm is a valid number
- Ensure detected is boolean (true/false)

### No Sensor Readings
- Check ultrasonic sensor connections
- Verify sensor power (5V for HC-SR04)
- Use voltage divider if needed (ESP32 is 3.3V logic)

### Compilation Errors
- Ensure ArduinoJson library is installed
- Check ESP32 board support is installed
- Verify Arduino IDE version compatibility

## Customization

### Change Send Interval
```cpp
const unsigned long SEND_INTERVAL = 5000;  // Change to milliseconds
```

### Change Detection Range
```cpp
bool detected = (range > 0 && range < 1000);  // Adjust max range (cm)
```

### Multiple Devices
Each ESP32 auto-generates unique ID from MAC address.
No configuration needed - just upload same code to multiple devices.

## Next Steps

1. Test with one device
2. Verify data appears in Flutter app
3. Deploy additional devices as needed
4. Monitor backend for incoming data
