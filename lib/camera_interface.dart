// lib/camera_interface.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Camera interface that prefers MJPEG via Image.network, and falls back to polling /snap
class CameraInterface extends StatefulWidget {
const CameraInterface({super.key});

@override
_CameraInterfaceState createState() => _CameraInterfaceState();
}

class _CameraInterfaceState extends State<CameraInterface> {
String _espIp = '192.168.1.100'; // change this to your ESP IP or edit in UI
bool _streaming = false;
bool _usingPolling = false;
String _status = 'idle';

Uint8List? _lastSnapshot;
Timer? _pollTimer;
bool _loadingSnap = false;
Duration _pollInterval = const Duration(milliseconds: 700);

String get _mjpegUrl => 'http://$_espIp/stream';
String get _snapUrl => 'http://$_espIp/snap';

@override
void dispose() {
_stopPolling();
super.dispose();
}

void _start() {
setState(() {
_streaming = true;
_usingPolling = false;
_status = 'Starting (attempting MJPEG)...';
});

// if MJPEG fails, Image.network's errorBuilder will call _onMjpegError which starts polling.
}

void _stop() {
_stopPolling();
setState(() {
_streaming = false;
_usingPolling = false;
_status = 'Stopped';
_lastSnapshot = null;
});
}

void _startPolling() {
_stopPolling();
setState(() {
_usingPolling = true;
_status = 'Polling snapshots...';
});
_pollTimer = Timer.periodic(_pollInterval, (_) => _fetchSnapshot());
// fetch first immediately
_fetchSnapshot();
}

void _stopPolling() {
_pollTimer?.cancel();
_pollTimer = null;
setState(() {
_usingPolling = false;
});
}

Future<void> _fetchSnapshot() async {
if (_loadingSnap) return;
setState(() => _loadingSnap = true);
try {
final uri = Uri.parse(_snapUrl);
final resp = await http.get(uri).timeout(const Duration(seconds: 2));
if (resp.statusCode == 200) {
setState(() {
_lastSnapshot = resp.bodyBytes;
_status = 'Snapshot updated';
});
} else {
setState(() {
_status = 'Snap failed: ${resp.statusCode}';
});
}
} catch (e) {
setState(() {
_status = 'Snap error';
});
} finally {
setState(() => _loadingSnap = false);
}
}

/// Manual snapshot
Future<void> _snapNow() async {
await _fetchSnapshot();
if (_lastSnapshot != null && mounted) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Snapshot captured')));
} else if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Snapshot failed')));
}
}

/// Called when Image.network (MJPEG) fails — switch to polling fallback
void _onMjpegError(Object? err) {
if (!mounted) return;
setState(() {
_status = 'MJPEG failed — falling back to polling';
_usingPolling = true;
_streaming = false;
});
// small delay so UI updates first
Future.delayed(const Duration(milliseconds: 200), () => _startPolling());
}

Widget _buildControls() {
return Padding(
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
child: Row(
children: [
Expanded(
child: TextField(
decoration: const InputDecoration(labelText: 'ESP IP (e.g. 192.168.1.100)', border: OutlineInputBorder(), isDense: true),
controller: TextEditingController(text: _espIp),
onChanged: (v) => _espIp = v.trim(),
onSubmitted: (v) => _espIp = v.trim(),
),
),
const SizedBox(width: 8),
ElevatedButton(
onPressed: _streaming || _usingPolling ? _stop : _start,
style: ElevatedButton.styleFrom(backgroundColor: (_streaming || _usingPolling) ? Colors.red : Colors.green),
child: Text((_streaming || _usingPolling) ? 'Stop' : 'Start'),
),
const SizedBox(width: 8),
OutlinedButton.icon(onPressed: _snapNow, icon: const Icon(Icons.camera_alt), label: const Text('Snap')),
const SizedBox(width: 8),
IconButton(
tooltip: 'Force polling',
onPressed: () {
_startPolling();
},
icon: const Icon(Icons.sync_problem),
),
],
),
);
}

Widget _buildViewer(double width, double height) {
// Priority:
// - If streaming true and not usingPolling => show Image.network pointed at /stream
// - Else if lastSnapshot exists => show snapshot
// - Else if usingPolling => show loader while fetching
// - else show placeholder
if ((_streaming || !_usingPolling) && _streaming) {
// show Image.network which will request the MJPEG stream; errorBuilder switches to polling
return Container(
width: width,
height: height,
decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
child: Image.network(
_mjpegUrl,
fit: BoxFit.contain,
gaplessPlayback: true,
errorBuilder: (context, error, stack) {
// error in MJPEG stream — fallback to polling
WidgetsBinding.instance.addPostFrameCallback((_) => _onMjpegError(error));
return Center(child: Text('MJPEG stream error — switching to snapshot', style: TextStyle(color: Colors.grey.shade700)));
},
),
);
}

if (_lastSnapshot != null) {
return Container(
width: width,
height: height,
decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
child: Image.memory(_lastSnapshot!, fit: BoxFit.contain, gaplessPlayback: true),
);
}

if (_usingPolling) {
return Container(
width: width,
height: height,
decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
child: const Center(child: CircularProgressIndicator()),
);
}

return Container(
width: width,
height: height,
decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8), color: Colors.grey.shade100),
child: const Center(child: Text('No stream. Enter IP and press Start')),
);
}

@override
Widget build(BuildContext context) {
final media = MediaQuery.of(context);
final viewerWidth = media.size.width - 48;
final viewerHeight = media.size.height * 0.62;

return Scaffold(
appBar: AppBar(
title: const Text('Camera Interface'),
actions: [Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Center(child: Text(_status)))],
),
body: Column(
children: [
_buildControls(),
const SizedBox(height: 8),
Expanded(
child: Center(
child: SizedBox(width: viewerWidth, height: viewerHeight, child: _buildViewer(viewerWidth, viewerHeight)),
),
),
Padding(
padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
child: Row(
mainAxisAlignment: MainAxisAlignment.spaceBetween,
children: [
Text('MJPEG: ${_streaming && !_usingPolling ? 'on' : 'off'}'),
Text('Polling: ${_usingPolling ? 'on' : 'off'}'),
ElevatedButton.icon(
onPressed: () {
if (_streaming || _usingPolling) {
_stop();
} else {
_start();
}
},
icon: Icon((_streaming || _usingPolling) ? Icons.stop : Icons.play_arrow),
label: Text((_streaming || _usingPolling) ? 'Stop' : 'Start'),
),
],
),
),
const SizedBox(height: 12),
],
),
);
}
}