import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class CameraInterface extends StatefulWidget {
  @override
  _CameraInterfaceState createState() => _CameraInterfaceState();
}

class _CameraInterfaceState extends State<CameraInterface> {
  Uint8List? _cameraImage;
  bool isConnected = false;
  bool isRecording = false;
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  String esp32Url = "ws://192.168.1.100:81/"; // Replace with your ESP32 IP
  String esp32HttpUrl = "http://192.168.1.100:81/stream"; // For MJPEG stream

  @override
  void initState() {
    super.initState();
    _connectToESP32();
  }

  void _connectToESP32() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(esp32Url));
      _channel!.stream.listen(
            (data) {
          setState(() {
            isConnected = true;
            _cameraImage = data as Uint8List;
          });
        },
        onError: (error) {
          print("WebSocket error: $error");
          _attemptReconnect();
        },
        onDone: () {
          print("WebSocket disconnected");
          _attemptReconnect();
        },
      );
    } catch (e) {
      print("Connection failed: $e");
      _attemptReconnect();
    }
  }

  void _attemptReconnect() {
    setState(() => isConnected = false);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: 3), () {
      _connectToESP32();
    });
  }

  Future<void> _toggleRecording() async {
    // Send recording command to ESP32
    try {
      await http.get(Uri.parse("${esp32HttpUrl}/record?start=${!isRecording}"));
      setState(() => isRecording = !isRecording);
    } catch (e) {
      print("Recording command failed: $e");
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _reconnectTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ESP32 Camera feed viewport
          Center(
            child: Container(
              width: 800,
              height: 600,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade800, width: 4),
                color: Colors.grey[900],
              ),
              child: Stack(
                children: [
                  // Live image from ESP32
                  if (_cameraImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _cameraImage!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    )
                  else
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 64, color: Colors.white54),
                          SizedBox(height: 16),
                          Text(
                            isConnected ? "Waiting for stream..." : "Connecting to ESP32...",
                            style: TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),

                  // Grid pattern overlay
                  CustomPaint(
                    size: Size(800, 600),
                    painter: _GridPatternPainter(),
                  ),

                  // Center crosshair
                  Center(
                    child: Icon(Icons.add, color: Colors.white54, size: 40),
                  ),

                  // Corner overlays
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Row(
                      children: [
                        Icon(
                          Icons.fiber_manual_record,
                          color: isRecording ? Colors.red : Colors.grey,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          "ESP32 CAM 01",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: StreamBuilder(
                      stream: Stream.periodic(Duration(seconds: 1)),
                      builder: (context, snapshot) => Text(
                        "${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Text(
                      "1280x720 @ 15fps",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isConnected ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isConnected ? "CONNECTED" : "DISCONNECTED",
                        style: TextStyle(
                          color: isConnected ? Colors.greenAccent : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Top control bar - ESP32 optimized
          Positioned(
            top: 8,
            left: 820,
            right: 10,
            height: 40,
            child: Row(
              children: [
                DropdownButton<String>(
                  value: "ESP32-CAM",
                  items: ["ESP32-CAM", "ESP32-CAM 2", "Mobile Cam"].map((cam) {
                    return DropdownMenuItem(value: cam, child: Text(cam));
                  }).toList(),
                  onChanged: (value) {
                    // Switch ESP32 camera modules
                  },
                ),
                SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _toggleRecording,
                  icon: Icon(Icons.videocam),
                  label: Text(isRecording ? "Stop Record" : "Start Record"),
                  style: ElevatedButton.styleFrom(backgroundColor: isRecording ? Colors.red : Colors.green),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => _connectToESP32(),
                  child: Text("Reconnect"),
                ),
              ],
            ),
          ),

          // Right ESP32 control panel
          Positioned(
            top: 60,
            right: 10,
            width: 260,
            bottom: 150,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
              ),
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.settings, color: Colors.cyanAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "ESP32 Controls",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Stream Quality
                  Text("Stream Quality", style: TextStyle(color: Colors.white)),
                  DropdownButton<int>(
                    isExpanded: true,
                    value: 1,
                    items: [1, 2, 3].map((quality) {
                      return DropdownMenuItem(value: quality, child: Text("Quality $quality"));
                    }).toList(),
                    onChanged: (value) {
                      // Send quality command to ESP32
                    },
                  ),

                  SizedBox(height: 12),
                  _buildToggle("Night Vision", false, (val) {}),
                  _buildToggle("Motion Detection", false, (val) {}),
                  _buildToggle("High FPS", false, (val) {}),

                  Spacer(),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text("ESP32 Settings"),
                          content: Text("IP: $esp32Url\nStatus: ${isConnected ? 'Connected' : 'Disconnected'}"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: Text("OK")),
                          ],
                        ),
                      ),
                      icon: Icon(Icons.settings),
                      label: Text("Advanced"),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom thumbnail gallery (recorded clips)
          Positioned(
            bottom: 10,
            left: 10,
            right: 10,
            height: 100,
            child: Container(
              color: Colors.black54,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (int i = 0; i < 4; i++)
                    Container(
                      width: 120,
                      margin: EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(8),
                        border: isRecording && i == 0
                            ? Border.all(color: Colors.red, width: 2)
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.videocam, color: Colors.white60, size: 32),
                          Text("Clip ${i + 1}", style: TextStyle(color: Colors.white60)),
                        ],
                      ),
                    ),
                  Container(
                    width: 120,
                    margin: EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.cyanAccent),
                    ),
                    child: Icon(Icons.add, color: Colors.cyanAccent, size: 40),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(String label, bool value, Function(bool) onChanged) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white)),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// Keep the grid painter
class _GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.1)
      ..strokeWidth = 1;

    final cellSize = 40.0;
    for (double x = 0; x <= size.width; x += cellSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += cellSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
