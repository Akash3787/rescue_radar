/*
 * Rescue Radar - ESP32 Simple Version (Minimal Sensors)
 * 
 * Simplified version with only ultrasonic sensor (range detection)
 * Perfect for quick testing and deployment
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// ==================== CONFIGURATION ====================
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";
const char* backendUrl = "https://web-production-87279.up.railway.app";
const char* apiKey = "rescue-radar-dev";  // Your WRITE_API_KEY

// Sensor Pins
#define TRIG_PIN 5
#define ECHO_PIN 18

// Timing
const unsigned long SEND_INTERVAL = 5000;  // 5 seconds

// Variables
unsigned long lastSendTime = 0;
String victimId = "esp32-001";

// ==================== SETUP ====================
void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n=== Rescue Radar ESP32 (Simple) ===");
  
  // Initialize pins
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  
  // Connect WiFi
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  
  Serial.print("Connecting");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  
  Serial.println("\nWiFi Connected!");
  Serial.print("IP: ");
  Serial.println(WiFi.localIP());
  
  // Generate device ID from MAC
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
  if (WiFi.status() != WL_CONNECTED) {
    WiFi.reconnect();
    delay(5000);
    return;
  }
  
  if (millis() - lastSendTime >= SEND_INTERVAL) {
    float range = readUltrasonic();
    bool detected = (range > 0 && range < 1000);
    
    Serial.printf("\nRange: %.1f cm | Detected: %s\n", range, detected ? "YES" : "NO");
    
    sendToBackend(range, detected);
    lastSendTime = millis();
  }
  
  delay(100);
}

// ==================== FUNCTIONS ====================

float readUltrasonic() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  
  long duration = pulseIn(ECHO_PIN, HIGH, 30000);
  
  if (duration == 0) return 0.0;
  
  float distance = (duration * 0.0343) / 2.0;
  
  if (distance < 2.0 || distance > 1000.0) return 0.0;
  
  return distance;
}

void sendToBackend(float range, bool detected) {
  HTTPClient http;
  String url = String(backendUrl) + "/api/v1/readings";
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("x-api-key", apiKey);
  
  DynamicJsonDocument doc(512);
  doc["victim_id"] = victimId;
  doc["detected"] = detected;
  
  if (range > 0) {
    doc["range_cm"] = range;
    doc["distance_cm"] = range;  // Legacy compatibility
  }
  
  // Optional: Add angle if you have servo/IMU
  // doc["angle_deg"] = 45.0;
  
  String jsonPayload;
  serializeJson(doc, jsonPayload);
  
  Serial.print("Sending: ");
  Serial.println(jsonPayload);
  
  int code = http.POST(jsonPayload);
  
  if (code == 200) {
    Serial.println("✓ Success!");
    String response = http.getString();
    Serial.println(response);
  } else {
    Serial.printf("✗ Error: %d\n", code);
    Serial.println(http.getString());
  }
  
  http.end();
}
