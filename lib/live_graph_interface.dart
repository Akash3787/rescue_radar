// lib/live_graph_interface.dart - SIMPLE Distance vs Time Graph
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import 'main.dart'; // for ThemeController
import 'services/api_service.dart';

class LiveGraphInterface extends StatefulWidget {
  final String? victimId; // Optional: if provided, show graph for specific victim
  
  const LiveGraphInterface({super.key, this.victimId});

  @override
  State<LiveGraphInterface> createState() => _LiveGraphInterfaceState();
}

class _LiveGraphInterfaceState extends State<LiveGraphInterface> {
  final int windowSeconds = 300; // 5 minutes window for victim-specific data
  final double maxDepth = 10.0;

  List<_Sample> distanceHistory = [];
  double currentDistance = 0.0;
  String status = 'Loading...';
  bool _isLoading = false;
  String? _error;
  Timer? _autoRefreshTimer;
  late ApiService _apiService;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService.forHosted();
    if (widget.victimId != null) {
      _loadVictimData();
      _startAutoRefresh();
    } else {
      _generateSampleData();
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  String _calculateDistanceChange() {
    if (distanceHistory.length < 2) return 'N/A';
    final first = distanceHistory.first.distance;
    final last = distanceHistory.last.distance;
    final change = last - first;
    final changePercent = first > 0 ? (change / first * 100).abs() : 0.0;
    
    if (change.abs() < 0.01) {
      return 'Stable (${change.abs().toStringAsFixed(3)}m)';
    } else if (change > 0) {
      return '↑ Deeper by ${change.toStringAsFixed(2)}m (${changePercent.toStringAsFixed(1)}%)';
    } else {
      return '↓ Closer by ${change.abs().toStringAsFixed(2)}m (${changePercent.toStringAsFixed(1)}%)';
    }
  }

  Color _getChangeColor() {
    if (distanceHistory.length < 2) return Colors.grey;
    final first = distanceHistory.first.distance;
    final last = distanceHistory.last.distance;
    final change = last - first;
    
    if (change.abs() < 0.01) {
      return Colors.green;
    } else if (change > 0) {
      return Colors.red; // Getting deeper (worse)
    } else {
      return Colors.green; // Getting closer (better)
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (widget.victimId != null) {
        _loadVictimData();
      }
    });
  }

  Future<void> _loadVictimData() async {
    if (_isLoading || widget.victimId == null) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final readings = await _apiService.fetchReadingsForVictim(widget.victimId!);
      
      if (readings.isEmpty) {
        setState(() {
          _isLoading = false;
          status = 'No data available for ${widget.victimId}';
          distanceHistory = [];
        });
        return;
      }

      // Convert readings to samples
      distanceHistory = readings.map((r) {
        final timestampSeconds = r.timestamp.millisecondsSinceEpoch / 1000.0;
        // Convert cm to meters
        final distanceMeters = r.distanceCm / 100.0;
        return _Sample(timestampSeconds, distanceMeters.clamp(0.0, maxDepth));
      }).toList();

      // Sort by timestamp
      distanceHistory.sort((a, b) => a.t.compareTo(b.t));

      if (distanceHistory.isNotEmpty) {
        currentDistance = distanceHistory.last.distance;
        final latestReading = readings.last;
        final timeAgo = DateTime.now().difference(latestReading.timestamp);
        if (timeAgo.inSeconds < 60) {
          status = 'Active - ${timeAgo.inSeconds}s ago';
        } else if (timeAgo.inMinutes < 60) {
          status = 'Active - ${timeAgo.inMinutes}m ago';
        } else {
          status = 'Last seen ${timeAgo.inHours}h ago';
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
        status = 'Error loading data';
      });
    }
  }

  void _generateSampleData() {
    distanceHistory.clear();

    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final Random rnd = Random(42); // Fixed seed for demo

    // Generate 60 seconds of earthquake aftershock data
    for (int i = 0; i < 30; i++) {
      final t = now - (60 - i * 2);
      double distance = 4.2;

      // Simulate aftershocks and rubble shifts
      if (i == 8) distance += 1.2; // Aftershock #1 - falls deeper
      if (i == 15) distance -= 0.8; // Rubble shift - closer
      if (i == 22) distance += 0.6; // Aftershock #2 - deeper again

      distance += (rnd.nextDouble() - 0.5) * 0.3; // Breathing noise
      distanceHistory.add(_Sample(t, distance.clamp(0.5, maxDepth)));
    }

    currentDistance = distanceHistory.last.distance;
    status = 'Monitoring complete';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final baseTextColor = isDarkMode ? Colors.white : Colors.black87;
    final secondaryTextColor = isDarkMode ? Colors.white70 : Colors.black54;
    final hintTextColor = isDarkMode ? Colors.white54 : Colors.black45;

    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final displaySamples = widget.victimId != null
      ? distanceHistory // Show all readings for victim-specific view
      : distanceHistory.where((s) => s.t >= now - 60).toList(); // 60s window for demo mode

    return Scaffold(
      // Use theme background so light mode is softer
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.victimId != null 
            ? 'Victim: ${widget.victimId} - Distance vs Time'
            : 'Distance vs Time',
          style: TextStyle(color: baseTextColor),
        ),
        backgroundColor: isDarkMode
            ? const Color(0xFF151922)
            : Theme.of(context).colorScheme.inversePrimary,
        foregroundColor: baseTextColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: baseTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Theme toggle (same as dashboard)
          Switch(
            value: ThemeController.of(context)?.isDark ?? false,
            onChanged: (value) {
              ThemeController.of(context)?.onToggle(value);
            },
          ),
          IconButton(
            icon: _isLoading 
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(baseTextColor),
                  ),
                )
              : Icon(Icons.refresh, color: baseTextColor),
            onPressed: widget.victimId != null ? _loadVictimData : _generateSampleData,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Simple Status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.grey[900]
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Current: ${currentDistance.toStringAsFixed(2)}m (${(currentDistance * 100).toStringAsFixed(1)} cm)',
                    style: TextStyle(
                      color: baseTextColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    status,
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    widget.victimId != null
                      ? '${distanceHistory.length} readings | ${windowSeconds ~/ 60} minute window'
                      : '60 second monitoring window',
                    style: TextStyle(color: hintTextColor),
                  ),
                  if (widget.victimId != null && distanceHistory.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Distance change: ${_calculateDistanceChange()}',
                        style: TextStyle(
                          color: _getChangeColor(),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Graph
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.grey[900]
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.indigoAccent.withOpacity(0.8), width: 2),
                ),
                padding: const EdgeInsets.all(20),
                child: CustomPaint(
                  painter: SimpleDistanceTimePainter(
                    displaySamples,
                    widget.victimId != null ? 300 : 60,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Error: $_error',
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.victimId != null
                    ? '← Older        Time → Latest'
                    : '← Older        Time → NOW',
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '↑ Distance (meters)',
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Sample {
  final double t;
  final double distance;
  _Sample(this.t, this.distance);
}

class SimpleDistanceTimePainter extends CustomPainter {
  final List<_Sample> samples;
  final int windowSeconds;

  SimpleDistanceTimePainter(this.samples, this.windowSeconds);

  @override
  void paint(Canvas canvas, Size size) {
    final leftPadding = 50.0;
    final rightPadding = 50.0;
    final topPadding = 30.0;
    final bottomPadding = 50.0;
    final plotWidth = size.width - leftPadding - rightPadding;
    final plotHeight = size.height - topPadding - bottomPadding;

    // Background of plot area (keep dark for contrast with neon line)
    final bgPaint = Paint()..color = Colors.black87;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(16),
      ),
      bgPaint,
    );

    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final windowStart = samples.isNotEmpty && samples.first.t < now - windowSeconds
      ? samples.first.t
      : now - windowSeconds;
    final actualWindow = samples.isNotEmpty 
      ? (samples.last.t - windowStart).clamp(1.0, windowSeconds.toDouble())
      : windowSeconds.toDouble();

    // Grid
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 1;

    // Depth grid lines (0–10 m)
    for (int i = 0; i <= 5; i++) {
      final y = topPadding + (i / 5.0) * plotHeight;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );
    }

    // Time grid
    for (int i = 0; i <= 5; i++) {
      final x = leftPadding + (i / 5.0) * plotWidth;
      canvas.drawLine(
        Offset(x, topPadding),
        Offset(x, size.height - bottomPadding),
        gridPaint,
      );
    }

    final tp = TextPainter(textDirection: TextDirection.ltr);

    // Y labels
    const labels = ['0m', '2m', '4m', '6m', '8m', '10m'];
    for (int i = 0; i < labels.length; i++) {
      tp.text = const TextSpan(
        text: '',
      );
      tp.text = TextSpan(
        text: labels[i],
        style: const TextStyle(color: Colors.white60, fontSize: 12),
      );
      tp.layout();
      final y = topPadding +
          plotHeight -
          (i / 5.0) * plotHeight -
          tp.height / 2;
      tp.paint(canvas, Offset(8, y));
    }

    // Time labels
    for (int i = 0; i <= 5; i++) {
      final sec = (actualWindow * i / 5).round();
      final timeText = actualWindow > 60 
        ? '${(sec / 60).toStringAsFixed(1)}m'
        : '$sec s';
      tp.text = TextSpan(
        text: timeText,
        style: const TextStyle(color: Colors.white60, fontSize: 12),
      );
      tp.layout();
      final x = leftPadding + (i / 5.0) * plotWidth - tp.width / 2;
      tp.paint(canvas, Offset(x, size.height - 35));
    }

    if (samples.isEmpty) return;

    // Distance line
    final path = Path();
    bool first = true;

    for (final sample in samples) {
      if (sample.t < windowStart) continue;

      final xNorm =
      ((sample.t - windowStart) / actualWindow).clamp(0.0, 1.0);
      final x = leftPadding + xNorm * plotWidth;

      final yNorm = (sample.distance / 10.0).clamp(0.0, 1.0);
      final y = topPadding + plotHeight - (yNorm * plotHeight);

      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }

    // Line with glow
    final glowPaint = Paint()
      ..color = Colors.indigoAccent.withOpacity(0.5)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(path, glowPaint);

    final linePaint = Paint()
      ..color = Colors.indigoAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    // Current point
    if (samples.isNotEmpty) {
      final last = samples.last;
      final xNorm =
      ((last.t - windowStart) / actualWindow).clamp(0.0, 1.0);
      final x = leftPadding + xNorm * plotWidth;
      final yNorm = (last.distance / 10.0).clamp(0.0, 1.0);
      final y = topPadding + plotHeight - (yNorm * plotHeight);

      final dotPaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(x, y), 6, dotPaint);
      
      // Draw a pulsing ring for latest point
      final pulsePaint = Paint()
        ..color = Colors.indigoAccent.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(x, y), 10, pulsePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

