/*
 * Rescue Radar - ESP32 Sensor Data Uploader
 * 
 * This code reads sensor data and sends it to the Railway-hosted backend
 * 
 * Required Libraries:
 * - WiFi.h (built-in)
 * - HTTPClient.h (built-in)
 * - ArduinoJson (install via Library Manager)
 * 
 * Hardware Connections (example):
 * - Ultrasonic Sensor: Trig -> GPIO 5, Echo -> GPIO 18
 * - Servo Motor (for angle): Signal -> GPIO 19
 * - DHT22 (temp/humidity): Data -> GPIO 4
 * - MQ-2 Gas Sensor: A0 -> GPIO 34
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// ==================== CONFIGURATION ====================
// WiFi Credentials
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

// Backend Configuration
const char* backendUrl = "https://web-production-87279.up.railway.app";
const char* apiKey = "rescue-radar-dev";  // Change to your WRITE_API_KEY
const char* endpoint = "/api/v1/readings";

// Sensor Pins
#define TRIG_PIN 5      // Ultrasonic sensor trigger
#define ECHO_PIN 18     // Ultrasonic sensor echo
#define SERVO_PIN 19    // Servo motor for angle measurement
#define DHT_PIN 4       // DHT22 temperature/humidity sensor
#define GAS_PIN 34      // MQ-2 gas sensor analog pin

// Timing Configuration
const unsigned long SEND_INTERVAL = 5000;  // Send data every 5 seconds
const unsigned long SENSOR_READ_INTERVAL = 1000;  // Read sensors every 1 second

// ==================== GLOBAL VARIABLES ====================
unsigned long lastSendTime = 0;
unsigned long lastSensorReadTime = 0;
String victimId = "esp32-001";  // Unique ID for this ESP32 device

// Sensor values
struct SensorData {
  bool detected = false;
  float rangeCm = 0.0;
  float angleDeg = 0.0;
  float temperatureC = 0.0;
  float humidityPct = 0.0;
  float gasPpm = 0.0;
};

SensorData currentData;

// ==================== SETUP ====================
void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n=== Rescue Radar ESP32 ===");
  
  // Initialize sensor pins
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(GAS_PIN, INPUT);
  
  // Initialize WiFi
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  
  Serial.print("Connecting to WiFi");
  int wifiTimeout = 0;
  while (WiFi.status() != WL_CONNECTED && wifiTimeout < 30) {
    delay(500);
    Serial.print(".");
    wifiTimeout++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi Connected!");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\nWiFi Connection Failed!");
    Serial.println("Please check your credentials");
  }
  
  // Generate unique victim ID based on MAC address
  uint8_t mac[6];
  WiFi.macAddress(mac);
  char macStr[18];
  snprintf(macStr, sizeof(macStr), "%02X%02X%02X", mac[3], mac[4], mac[5]);
  victimId = "esp32-" + String(macStr);
  
  Serial.print("Device ID: ");
  Serial.println(victimId);
  
  delay(2000);
}

// ==================== MAIN LOOP ====================
void loop() {
  // Check WiFi connection
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi disconnected. Reconnecting...");
    WiFi.reconnect();
    delay(5000);
    return;
  }
  
  // Read sensors periodically
  unsigned long currentMillis = millis();
  if (currentMillis - lastSensorReadTime >= SENSOR_READ_INTERVAL) {
    readSensors();
    lastSensorReadTime = currentMillis;
  }
  
  // Send data to backend periodically
  if (currentMillis - lastSendTime >= SEND_INTERVAL) {
    sendDataToBackend();
    lastSendTime = currentMillis;
  }
  
  delay(100);
}

// ==================== SENSOR READING FUNCTIONS ====================

void readSensors() {
  // Read ultrasonic sensor (range detection)
  float range = readUltrasonicSensor();
  currentData.rangeCm = range;
  currentData.detected = (range > 0 && range < 1000);  // Detect if object within 10m
  
  // Read angle (from servo position or IMU)
  currentData.angleDeg = readAngle();
  
  // Read temperature and humidity (DHT22)
  readDHT22(&currentData.temperatureC, &currentData.humidityPct);
  
  // Read gas sensor
  currentData.gasPpm = readGasSensor();
  
  // Print sensor values
  Serial.println("\n--- Sensor Readings ---");
  Serial.printf("Detected: %s\n", currentData.detected ? "YES" : "NO");
  Serial.printf("Range: %.1f cm\n", currentData.rangeCm);
  Serial.printf("Angle: %.1f deg\n", currentData.angleDeg);
  Serial.printf("Temperature: %.1f C\n", currentData.temperatureC);
  Serial.printf("Humidity: %.1f %%\n", currentData.humidityPct);
  Serial.printf("Gas: %.0f ppm\n", currentData.gasPpm);
}

float readUltrasonicSensor() {
  // Send trigger pulse
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  
  // Read echo pulse duration
  long duration = pulseIn(ECHO_PIN, HIGH, 30000);  // 30ms timeout
  
  if (duration == 0) {
    return 0.0;  // No echo received
  }
  
  // Calculate distance (speed of sound = 343 m/s = 0.0343 cm/μs)
  float distance = (duration * 0.0343) / 2.0;
  
  // Filter out invalid readings (too close or too far)
  if (distance < 2.0 || distance > 1000.0) {
    return 0.0;
  }
  
  return distance;
}

float readAngle() {
  // Option 1: Read from servo position (if using servo to rotate sensor)
  // int servoPos = analogRead(SERVO_PIN);
  // return map(servoPos, 0, 4095, 0, 360);
  
  // Option 2: Use IMU (MPU6050) - implement if you have one
  // return readIMUAngle();
  
  // Option 3: Fixed angle or sweep pattern
  // For now, return a simulated angle based on time
  static float angle = 0.0;
  angle += 2.0;  // Increment by 2 degrees each read
  if (angle >= 360.0) angle = 0.0;
  return angle;
}

void readDHT22(float* temp, float* humidity) {
  // DHT22 reading code (requires DHT library)
  // Install: Sketch -> Include Library -> Manage Libraries -> Search "DHT sensor library"
  
  // Uncomment and configure if you have DHT22:
  /*
  #include <DHT.h>
  #define DHT_TYPE DHT22
  DHT dht(DHT_PIN, DHT_TYPE);
  
  *temp = dht.readTemperature();
  *humidity = dht.readHumidity();
  
  if (isnan(*temp) || isnan(*humidity)) {
    *temp = 0.0;
    *humidity = 0.0;
  }
  */
  
  // Simulated values for testing (remove when using real sensor)
  *temp = 25.0 + (random(0, 50) / 10.0);  // 25-30°C
  *humidity = 50.0 + (random(0, 30));     // 50-80%
}

float readGasSensor() {
  // Read MQ-2 gas sensor (analog)
  int sensorValue = analogRead(GAS_PIN);
  
  // Convert to PPM (calibration required - this is approximate)
  // Formula depends on your specific sensor model
  float voltage = (sensorValue / 4095.0) * 3.3;  // ESP32 ADC is 12-bit
  float ppm = voltage * 100.0;  // Rough conversion (calibrate for your sensor)
  
  return ppm;
}

// ==================== NETWORK FUNCTIONS ====================

void sendDataToBackend() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi not connected. Skipping upload.");
    return;
  }
  
  HTTPClient http;
  String url = String(backendUrl) + String(endpoint);
  
  Serial.println("\n--- Sending Data to Backend ---");
  Serial.print("URL: ");
  Serial.println(url);
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("x-api-key", apiKey);
  
  // Create JSON payload
  DynamicJsonDocument doc(1024);
  doc["victim_id"] = victimId;
  doc["detected"] = currentData.detected;
  
  if (currentData.rangeCm > 0) {
    doc["range_cm"] = currentData.rangeCm;
    doc["distance_cm"] = currentData.rangeCm;  // Legacy field
  }
  
  if (currentData.angleDeg >= 0) {
    doc["angle_deg"] = currentData.angleDeg;
  }
  
  if (currentData.temperatureC > 0) {
    doc["temperature"] = currentData.temperatureC;
  }
  
  if (currentData.humidityPct > 0) {
    doc["humidity"] = currentData.humidityPct;
  }
  
  if (currentData.gasPpm > 0) {
    doc["gas"] = currentData.gasPpm;
  }
  
  String jsonPayload;
  serializeJson(doc, jsonPayload);
  
  Serial.print("Payload: ");
  Serial.println(jsonPayload);
  
  // Send POST request
  int httpResponseCode = http.POST(jsonPayload);
  
  if (httpResponseCode > 0) {
    Serial.print("HTTP Response code: ");
    Serial.println(httpResponseCode);
    
    if (httpResponseCode == 200) {
      String response = http.getString();
      Serial.print("Response: ");
      Serial.println(response);
      Serial.println("✓ Data sent successfully!");
    } else {
      Serial.print("✗ Error response: ");
      Serial.println(httpResponseCode);
      String response = http.getString();
      Serial.println(response);
    }
  } else {
    Serial.print("✗ HTTP Error: ");
    Serial.println(httpResponseCode);
    Serial.println("Connection failed!");
  }
  
  http.end();
}

// ==================== HELPER FUNCTIONS ====================

void printWiFiStatus() {
  Serial.println("\n--- WiFi Status ---");
  Serial.print("SSID: ");
  Serial.println(WiFi.SSID());
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());
  Serial.print("Signal Strength (RSSI): ");
  Serial.print(WiFi.RSSI());
  Serial.println(" dBm");
  Serial.print("MAC Address: ");
  Serial.println(WiFi.macAddress());
}
