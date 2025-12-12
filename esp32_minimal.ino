/*
 * Rescue Radar - ESP32 Minimal Version
 * Sends: range_cm, detected, angle_deg to Railway backend
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// ==================== CONFIGURATION ====================
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";
const char* backendUrl = "https://web-production-87279.up.railway.app";
const char* apiKey = "rescue-radar-dev";  // Change to your WRITE_API_KEY

// Sensor Pins
#define TRIG_PIN 5      // Ultrasonic trigger
#define ECHO_PIN 18     // Ultrasonic echo
#define ANGLE_PIN 34    // Analog pin for angle (or use servo/IMU)

// Timing
const unsigned long SEND_INTERVAL = 5000;  // Send every 5 seconds

// Variables
unsigned long lastSendTime = 0;
String victimId = "esp32-001";

// Detection state tracking
float lastRange = 0.0;
unsigned long stableStartTime = 0;
const unsigned long STABLE_THRESHOLD = 10000;  // 10 seconds of stable readings = rest state
const float VARIATION_THRESHOLD = 5.0;  // 5cm variation = movement detected
bool isRestState = false;

// ==================== SETUP ====================
void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n=== Rescue Radar ESP32 ===");
  
  // Initialize pins
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(ANGLE_PIN, INPUT);
  
  // Connect WiFi
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  
  Serial.println("\nWiFi Connected!");
  Serial.print("IP: ");
  Serial.println(WiFi.localIP());
  
  // Generate unique device ID from MAC address
  uint8_t mac[6];
  WiFi.macAddress(mac);
  char macStr[18];
  snprintf(macStr, sizeof(macStr), "%02X%02X%02X", mac[3], mac[4], mac[5]);
  victimId = "esp32-" + String(macStr);
  
  Serial.print("Device ID: ");
  Serial.println(victimId);
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
  
  // Send data periodically
  if (millis() - lastSendTime >= SEND_INTERVAL) {
    // Read sensors
    float range = readRange();
    float angle = readAngle();
    
    // Determine detection status based on movement/variation
    bool detected = determineDetectionStatus(range);
    
    // Print readings
    Serial.println("\n--- Sensor Readings ---");
    Serial.printf("Range: %.1f cm\n", range);
    Serial.printf("Status: %s\n", detected ? "PERSON DETECTED" : (isRestState ? "REST STATE" : "NO PERSON"));
    Serial.printf("Angle: %.1f deg\n", angle);
    if (isRestState) {
      Serial.printf("Stable for: %lu ms\n", millis() - stableStartTime);
    }
    
    // Send to backend
    sendToBackend(range, detected, angle);
    
    lastSendTime = millis();
  }
  
  delay(100);
}

// ==================== SENSOR FUNCTIONS ====================

float readRange() {
  // Send trigger pulse
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  
  // Read echo pulse
  long duration = pulseIn(ECHO_PIN, HIGH, 30000);  // 30ms timeout
  
  if (duration == 0) {
    return 0.0;  // No echo
  }
  
  // Calculate distance (speed of sound = 0.0343 cm/μs)
  float distance = (duration * 0.0343) / 2.0;
  
  // Filter invalid readings
  if (distance < 2.0 || distance > 1000.0) {
    return 0.0;
  }
  
  return distance;
}

float readAngle() {
  // Option 1: Read from analog pin (potentiometer or analog sensor)
  int analogValue = analogRead(ANGLE_PIN);
  float angle = map(analogValue, 0, 4095, 0, 360);  // ESP32 ADC is 12-bit
  return angle;
  
  // Option 2: Use servo position (if you have servo)
  // int servoPos = readServoPosition();
  // return map(servoPos, 0, 180, 0, 360);
  
  // Option 3: Simulated angle (for testing)
  // static float angle = 0.0;
  // angle += 5.0;
  // if (angle >= 360.0) angle = 0.0;
  // return angle;
}

bool determineDetectionStatus(float currentRange) {
  // No valid reading = not detected
  if (currentRange <= 0 || currentRange > 1000) {
    lastRange = 0.0;
    stableStartTime = 0;
    isRestState = false;
    return false;
  }
  
  // Check if reading has changed significantly (movement detected)
  float variation = abs(currentRange - lastRange);
  
  if (variation > VARIATION_THRESHOLD) {
    // Significant change = movement detected = person detected
    lastRange = currentRange;
    stableStartTime = millis();
    isRestState = false;
    return true;
  }
  
  // Reading is stable (similar to last reading)
  if (lastRange == 0.0) {
    // First valid reading - start tracking
    lastRange = currentRange;
    stableStartTime = millis();
    isRestState = false;
    return true;  // Assume detected on first reading
  }
  
  // Check how long readings have been stable
  unsigned long stableDuration = millis() - stableStartTime;
  
  if (stableDuration >= STABLE_THRESHOLD) {
    // Been stable for threshold time = rest state = not detected
    isRestState = true;
    return false;
  } else {
    // Still within threshold, but stable = might be person but stationary
    // You can change this to return true if you want to detect stationary people
    isRestState = false;
    return true;  // Still consider detected if within threshold
  }
}

// ==================== NETWORK FUNCTION ====================

void sendToBackend(float range, bool detected, float angle) {
  HTTPClient http;
  String url = String(backendUrl) + "/api/v1/readings";
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("x-api-key", apiKey);
  
  // Create JSON payload
  DynamicJsonDocument doc(512);
  doc["victim_id"] = victimId;
  doc["detected"] = detected;
  
  if (range > 0) {
    doc["range_cm"] = range;
  }
  
  if (angle >= 0) {
    doc["angle_deg"] = angle;
  }
  
  String jsonPayload;
  serializeJson(doc, jsonPayload);
  
  Serial.println("\n--- Sending to Backend ---");
  Serial.print("URL: ");
  Serial.println(url);
  Serial.print("Payload: ");
  Serial.println(jsonPayload);
  
  // Send POST request
  int httpCode = http.POST(jsonPayload);
  
  if (httpCode == 200) {
    Serial.println("✓ Success! Data sent to backend.");
    String response = http.getString();
    Serial.print("Response: ");
    Serial.println(response);
  } else {
    Serial.printf("✗ Error: HTTP %d\n", httpCode);
    String response = http.getString();
    Serial.println(response);
  }
  
  http.end();
}
