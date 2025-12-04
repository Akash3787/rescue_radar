// lib/camera_interface.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/api_service.dart';

/// Camera interface for endoscopy camera connected to Railway backend
class CameraInterface extends StatefulWidget {
  const CameraInterface({super.key});

  @override
  _CameraInterfaceState createState() => _CameraInterfaceState();
}

class _CameraInterfaceState extends State<CameraInterface> {
  static const String _backendBase = 'https://web-production-87279.up.railway.app';
  bool _streaming = false;
  bool _usingPolling = false;
  String _status = 'idle';
  bool _cameraAvailable = false;

  Uint8List? _lastSnapshot;
  Timer? _pollTimer;
  bool _loadingSnap = false;
  bool _reportingVictim = false;
  Duration _pollInterval = const Duration(milliseconds: 200); // Faster polling for smoother feed
  late ApiService _apiService;

  String get _mjpegUrl => '$_backendBase/stream';
  String get _snapUrl => '$_backendBase/snap';

  @override
  void initState() {
    super.initState();
    _apiService = ApiService.forHosted();
    _checkCameraStatus();
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  Future<void> _checkCameraStatus() async {
    try {
      final uri = Uri.parse('$_backendBase/api/camera/status');
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        setState(() {
          _cameraAvailable = data['live'] == true || data['available'] == true;
          _status = _cameraAvailable ? 'Camera ready' : 'Camera not available';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Cannot check camera status';
        _cameraAvailable = false;
      });
    }
  }

  void _start() {
    setState(() {
      _streaming = true;
      _usingPolling = false;
      _status = 'Starting endoscopy feed...';
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
      _status = 'Polling endoscopy feed...';
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
      final resp = await http.get(uri).timeout(const Duration(seconds: 3));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        setState(() {
          _lastSnapshot = resp.bodyBytes;
          _status = 'Live feed active';
        });
      } else {
        setState(() {
          _status = 'Feed error: ${resp.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Connection error';
      });
    } finally {
      setState(() => _loadingSnap = false);
    }
  }

  /// Manual snapshot
  Future<void> _snapNow() async {
    await _fetchSnapshot();
    if (_lastSnapshot != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📸 Snapshot captured')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Snapshot failed')),
      );
    }
  }

  /// Report victim detection from camera
  Future<void> _reportVictimDetection() async {
    // Show dialog to get distance
    final distanceController = TextEditingController();
    final victimIdController = TextEditingController(
      text: 'cam-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Victim Detection'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: victimIdController,
                decoration: const InputDecoration(
                  labelText: 'Victim ID',
                  hintText: 'Auto-generated',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: distanceController,
                decoration: const InputDecoration(
                  labelText: 'Distance (cm)',
                  hintText: 'e.g., 250',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              const Text(
                'GPS location will be captured automatically',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (distanceController.text.isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final distanceText = distanceController.text.trim();
    if (distanceText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Please enter distance')),
      );
      return;
    }

    final distance = double.tryParse(distanceText);
    if (distance == null || distance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Invalid distance value')),
      );
      return;
    }

    setState(() => _reportingVictim = true);

    try {
      // Get GPS location
      double? latitude;
      double? longitude;

      try {
        // Request location permission
        final locationPermission = await Permission.location.request();
        if (locationPermission.isGranted) {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          latitude = position.latitude;
          longitude = position.longitude;
        }
      } catch (e) {
        // GPS failed, but continue without it
        developer.log('GPS error: $e');
      }

      // Send to backend
      final response = await _apiService.postReading({
        'victim_id': victimIdController.text.trim(),
        'distance_cm': distance,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      });

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Victim reported: ${victimIdController.text}\n'
                'Distance: ${distance.toStringAsFixed(1)} cm'
                '${latitude != null && longitude != null ? '\nGPS: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}' : '\n⚠️ No GPS'}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      developer.log('❌ Report victim error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to report victim: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _reportingVictim = false);
      }
    }
  }

  /// Called when Image.network (MJPEG) fails — switch to polling fallback
  void _onMjpegError(Object? err) {
    if (!mounted) return;
    setState(() {
      _status = 'MJPEG stream unavailable — using snapshot polling';
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
            child: Card(
              color: _cameraAvailable ? Colors.green.shade50 : Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Icon(
                      _cameraAvailable ? Icons.videocam : Icons.videocam_off,
                      color: _cameraAvailable ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _cameraAvailable ? 'Endoscopy Camera: Ready' : 'Endoscopy Camera: Not Available',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _cameraAvailable ? Colors.green.shade700 : Colors.orange.shade700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _checkCameraStatus,
                      tooltip: 'Check camera status',
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _streaming || _usingPolling ? _stop : _start,
            style: ElevatedButton.styleFrom(
              backgroundColor: (_streaming || _usingPolling) ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
            ),
            icon: Icon((_streaming || _usingPolling) ? Icons.stop : Icons.play_arrow),
            label: Text((_streaming || _usingPolling) ? 'Stop' : 'Start'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _snapNow,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Snap'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _reportingVictim ? null : _reportVictimDetection,
            icon: _reportingVictim 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.person_add),
            label: const Text('Report Victim'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Force snapshot polling mode',
            onPressed: () {
              _startPolling();
            },
            icon: const Icon(Icons.sync),
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
    if (_streaming && !_usingPolling) {
      // show Image.network which will request the MJPEG stream; errorBuilder switches to polling
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300, width: 2),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            _mjpegUrl,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('Loading endoscopy feed...', style: TextStyle(color: Colors.grey.shade700)),
                  ],
                ),
              );
            },
            errorBuilder: (context, error, stack) {
              // error in MJPEG stream — fallback to polling
              WidgetsBinding.instance.addPostFrameCallback((_) => _onMjpegError(error));
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.orange),
                    const SizedBox(height: 16),
                    Text(
                      'MJPEG stream unavailable\nSwitching to snapshot mode...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }

    if (_lastSnapshot != null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300, width: 2),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            _lastSnapshot!,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
        ),
      );
    }

    if (_usingPolling) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Fetching endoscopy feed...', style: TextStyle(color: Colors.grey.shade700)),
            ],
          ),
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 2),
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade100,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No feed active',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Press Start to begin endoscopy feed',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final viewerWidth = media.size.width - 48;
    final viewerHeight = media.size.height * 0.65;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Endoscopy Camera Feed'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                _status,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildControls(),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: SizedBox(
                width: viewerWidth,
                height: viewerHeight,
                child: _buildViewer(viewerWidth, viewerHeight),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatusChip('MJPEG Stream', _streaming && !_usingPolling),
                _buildStatusChip('Snapshot Polling', _usingPolling),
                _buildStatusChip('Active', _streaming || _usingPolling),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? Colors.green.shade100 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? Colors.green : Colors.grey,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: active ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? Colors.green.shade700 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}