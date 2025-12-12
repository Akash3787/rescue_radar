// lib/live_graph_interface.dart - REAL-TIME SCROLLING Distance vs Time Graph (CM)
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
  // Real-time scrolling parameters
  final int displayWindowSeconds = 60; // Show last 60 seconds on screen
  final double maxDepth = 1000.0; // 10m = 1000cm

  List<_Sample> distanceHistory = [];
  double currentDistance = 0.0;
  String status = 'Waiting for data...';
  bool _isLoading = false;
  String? _error;
  Timer? _autoRefreshTimer;
  Timer? _simulationTimer; // For demo/real-time simulation
  late ApiService _apiService;
  late DateTime _sessionStartTime; // When user opened this page

  @override
  void initState() {
    super.initState();
    _apiService = ApiService.forHosted();
    _sessionStartTime = DateTime.now();

    if (widget.victimId != null) {
      _loadVictimData();
    } else {
      // Demo mode: start with sample data and simulate live updates
      _generateInitialSampleData();
      _startLiveSimulation();
    }
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _simulationTimer?.cancel();
    super.dispose();
  }

  // Start continuous data updates (for real sensor data)
  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      if (widget.victimId != null) {
        _loadVictimData();
      } else {
        _loadMostRecentVictimData();
      }
    });
  }

  // Simulate live data for demo mode (like a real sensor streaming)
  void _startLiveSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) {
        _addSimulatedData();
      }
    });
  }

  void _addSimulatedData() {
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final Random rnd = Random();

    // Simulate realistic sensor data with some variation (in cm)
    double distance = currentDistance;

    // Random walk (small changes)
    distance += (rnd.nextDouble() - 0.5) * 15.0;

    // Occasional larger movements (heartbeat pulses or rubble shifts)
    if (rnd.nextDouble() < 0.1) {
      distance += (rnd.nextDouble() - 0.5) * 40.0;
    }

    distance = distance.clamp(50.0, maxDepth);

    setState(() {
      distanceHistory.add(_Sample(now, distance));
      currentDistance = distance;

      // Trim history to visible window
      final cutoff = now - displayWindowSeconds;
      distanceHistory =
          distanceHistory.where((s) => s.t >= cutoff).toList(growable: true);

      // Update status with elapsed time
      final elapsed = DateTime.now().difference(_sessionStartTime);
      if (elapsed.inSeconds < 60) {
        status = '🔴 LIVE - ${elapsed.inSeconds}s elapsed';
      } else {
        status =
        '🔴 LIVE - ${elapsed.inMinutes}m ${elapsed.inSeconds % 60}s elapsed';
      }
    });
  }

  void _generateInitialSampleData() {
    distanceHistory.clear();
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final Random rnd = Random(42);

    // Generate initial 10 seconds of data (in cm)
    for (int i = 0; i < 20; i++) {
      final t = now - (10 - i * 0.5);
      double distance = 420.0 + (rnd.nextDouble() - 0.5) * 30.0;
      distanceHistory.add(_Sample(t, distance.clamp(50.0, maxDepth)));
    }

    currentDistance = distanceHistory.last.distance;
    status = '🔴 LIVE - Demo Mode';
  }

  String _calculateDistanceChange() {
    if (distanceHistory.length < 2) return 'N/A';
    final first = distanceHistory.first.distance;
    final last = distanceHistory.last.distance;
    final change = last - first;
    final changePercent = first > 0 ? (change / first * 100).abs() : 0.0;

    if (change.abs() < 1.0) {
      return 'Stable (${change.abs().toStringAsFixed(1)}cm)';
    } else if (change > 0) {
      return '↓ Deeper by ${change.toStringAsFixed(0)}cm (${changePercent.toStringAsFixed(1)}%)';
    } else {
      return '↑ Closer by ${change.abs().toStringAsFixed(0)}cm (${changePercent.toStringAsFixed(1)}%)';
    }
  }

  Color _getChangeColor() {
    if (distanceHistory.length < 2) return Colors.grey;
    final first = distanceHistory.first.distance;
    final last = distanceHistory.last.distance;
    final change = last - first;

    if (change.abs() < 1.0) {
      return Colors.green;
    } else if (change > 0) {
      return Colors.red; // Getting deeper (worse)
    } else {
      return Colors.green; // Getting closer (better)
    }
  }

  /// NEW: Poll backend for the *latest* reading (any victim),
  /// append it as a live sample, and keep only the last N seconds.
  Future<void> _loadMostRecentVictimData() async {
    try {
      final readings = await _apiService.fetchAllReadings();
      if (readings.isEmpty) {
        if (!mounted) return;
        setState(() {
          status = 'Waiting for data...';
          // Keep existing history from simulation if any
        });
        return;
      }

      // Assume API returns newest first, but be safe and sort
      readings.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final latest = readings.last;

      final nowSeconds = DateTime.now().millisecondsSinceEpoch / 1000.0;
      // Use rangeCm (preferred) or distanceCm (fallback), default to 0 if both null
      final distanceValue = latest.rangeCm ?? latest.distanceCm ?? 0.0;
      final distanceCm = distanceValue.clamp(0.0, maxDepth);

      if (!mounted) return;
      setState(() {
        distanceHistory.add(_Sample(nowSeconds, distanceCm));
        currentDistance = distanceCm;

        // Keep only samples inside the visible window
        final cutoff = nowSeconds - displayWindowSeconds;
        distanceHistory =
            distanceHistory.where((s) => s.t >= cutoff).toList(growable: true);

        final elapsed = DateTime.now().difference(_sessionStartTime);
        if (elapsed.inSeconds < 60) {
          status = '🔴 LIVE - ${elapsed.inSeconds}s elapsed';
        } else {
          status =
          '🔴 LIVE - ${elapsed.inMinutes}m ${elapsed.inSeconds % 60}s elapsed';
        }
      });
    } catch (e) {
      if (!mounted) return;
      // Don't spam status, just record error
      setState(() {
        _error = e.toString();
      });
    }
  }

  Future<void> _loadVictimData() async {
    if (_isLoading || widget.victimId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch all readings and filter by victim ID
      final allReadings = await _apiService.fetchAllReadings(page: 1, perPage: 500);
      final readings = allReadings
          .where((r) => r.victimId == widget.victimId)
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (readings.isEmpty) {
        setState(() {
          _isLoading = false;
          status = 'No data for ${widget.victimId}';
          distanceHistory = [];
        });
        return;
      }

      // Convert readings to samples (distance already in cm from API)
      distanceHistory = readings.map((r) {
        final timestampSeconds = r.timestamp.millisecondsSinceEpoch / 1000.0;
        // Use rangeCm (preferred) or distanceCm (fallback), default to 0 if both null
        final distanceValue = r.rangeCm ?? r.distanceCm ?? 0.0;
        final distanceCm = distanceValue.clamp(0.0, maxDepth);
        return _Sample(timestampSeconds, distanceCm);
      }).toList();

      // Sort by timestamp
      distanceHistory.sort((a, b) => a.t.compareTo(b.t));

      // Trim to visible time window
      final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
      final cutoff = now - displayWindowSeconds;
      distanceHistory =
          distanceHistory.where((s) => s.t >= cutoff).toList(growable: true);

      if (distanceHistory.isNotEmpty) {
        currentDistance = distanceHistory.last.distance;
        final elapsed = DateTime.now().difference(_sessionStartTime);
        if (elapsed.inSeconds < 60) {
          status =
          '🔴 LIVE - ${elapsed.inSeconds}s | ${distanceHistory.length} readings';
        } else {
          status =
          '🔴 LIVE - ${elapsed.inMinutes}m | ${distanceHistory.length} readings';
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

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final baseTextColor = isDarkMode ? Colors.white : Colors.black87;
    final secondaryTextColor = isDarkMode ? Colors.white70 : Colors.black54;
    final hintTextColor = isDarkMode ? Colors.white54 : Colors.black45;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.victimId != null
              ? 'Live: ${widget.victimId} - Distance vs Time'
              : 'Live Distance vs Time',
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
            onPressed: widget.victimId != null ? _loadVictimData : null,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Status Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.grey[900]
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withAlpha(100),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Distance: ${currentDistance.toStringAsFixed(0)}cm',
                    style: TextStyle(
                      color: baseTextColor,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    status,
                    style: TextStyle(
                      color: Colors.red[400],
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Data points: ${distanceHistory.length} | Window: ${displayWindowSeconds}s',
                    style: TextStyle(color: hintTextColor, fontSize: 12),
                  ),
                  if (distanceHistory.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Change: ${_calculateDistanceChange()}',
                        style: TextStyle(
                          color: _getChangeColor(),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Real-time Graph
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.grey[900]
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.indigoAccent.withOpacity(0.8),
                    width: 2,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: CustomPaint(
                  painter: RealtimeGraphPainter(
                    distanceHistory,
                    displayWindowSeconds,
                    maxDepth,
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

            // Axis Labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '← Older data     Current time →',
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '↑ Distance (cm)',
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 13,
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
  final double t; // timestamp in seconds since epoch
  final double distance; // distance in cm
  _Sample(this.t, this.distance);
}

class RealtimeGraphPainter extends CustomPainter {
  final List<_Sample> samples;
  final int displayWindowSeconds;
  final double maxDepth;

  RealtimeGraphPainter(this.samples, this.displayWindowSeconds, this.maxDepth);

  @override
  void paint(Canvas canvas, Size size) {
    final leftPadding = 50.0;
    final rightPadding = 30.0;
    final topPadding = 30.0;
    final bottomPadding = 50.0;
    final plotWidth = size.width - leftPadding - rightPadding;
    final plotHeight = size.height - topPadding - bottomPadding;

    // Background of plot area
    final bgPaint = Paint()..color = Colors.black87;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(16),
      ),
      bgPaint,
    );

    if (samples.isEmpty) {
      _drawEmptyGraph(canvas, size, leftPadding, topPadding, plotWidth,
          plotHeight, rightPadding, bottomPadding);
      return;
    }

    // Get current time and calculate display window
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final windowStart = now - displayWindowSeconds; // Start of visible window

    // Grid lines
    _drawGrid(canvas, leftPadding, topPadding, plotWidth, plotHeight, size,
        displayWindowSeconds);

    // Y-axis labels (distance in cm)
    _drawYAxisLabels(canvas, leftPadding, topPadding, plotHeight);

    // X-axis labels (time)
    _drawXAxisLabels(
        canvas, leftPadding, topPadding, plotWidth, size, displayWindowSeconds);

    // Draw distance line
    _drawDistanceLine(canvas, samples, leftPadding, topPadding, plotWidth,
        plotHeight, windowStart, now);

    // Draw current point indicator
    if (samples.isNotEmpty) {
      final lastSample = samples.last;
      final xNorm =
      ((lastSample.t - windowStart) / displayWindowSeconds).clamp(0.0, 1.0);
      final x = leftPadding + xNorm * plotWidth;

      final yNorm = (lastSample.distance / maxDepth).clamp(0.0, 1.0);
      final y = topPadding + plotHeight - (yNorm * plotHeight);

      // Pulsing current point
      final dotPaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(x, y), 7, dotPaint);

      final pulsePaint = Paint()
        ..color = Colors.indigoAccent.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(x, y), 12, pulsePaint);
    }
  }

  void _drawEmptyGraph(
      Canvas canvas,
      Size size,
      double leftPadding,
      double topPadding,
      double plotWidth,
      double plotHeight,
      double rightPadding,
      double bottomPadding) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    tp.text = const TextSpan(
      text: 'Waiting for data...',
      style: TextStyle(color: Colors.white54, fontSize: 16),
    );
    tp.layout();
    tp.paint(
      canvas,
      Offset(
        (size.width - tp.width) / 2,
        (size.height - tp.height) / 2,
      ),
    );
  }

  void _drawGrid(
      Canvas canvas,
      double leftPadding,
      double topPadding,
      double plotWidth,
      double plotHeight,
      Size size,
      int windowSeconds) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 1;

    // Horizontal grid lines (distance in cm)
    for (int i = 0; i <= 5; i++) {
      final y = topPadding + (i / 5.0) * plotHeight;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - 30, y),
        gridPaint,
      );
    }

    // Vertical grid lines (time)
    for (int i = 0; i <= 5; i++) {
      final x = leftPadding + (i / 5.0) * plotWidth;
      canvas.drawLine(
        Offset(x, topPadding),
        Offset(x, size.height - 50),
        gridPaint,
      );
    }
  }

  void _drawYAxisLabels(
      Canvas canvas, double leftPadding, double topPadding, double plotHeight) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    const labels = ['0cm', '200cm', '400cm', '600cm', '800cm', '1000cm'];

    for (int i = 0; i < labels.length; i++) {
      tp.text = TextSpan(
        text: labels[i],
        style: const TextStyle(color: Colors.white60, fontSize: 12),
      );
      tp.layout();

      final y =
          topPadding + plotHeight - (i / 5.0) * plotHeight - tp.height / 2;
      tp.paint(canvas, Offset(8, y));
    }
  }

  void _drawXAxisLabels(Canvas canvas, double leftPadding, double topPadding,
      double plotWidth, Size size, int windowSeconds) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    final now = DateTime.now();

    // Show time labels (5 divisions)
    for (int i = 0; i <= 5; i++) {
      final secondsAgo = (windowSeconds * (5 - i) / 5).round();
      final timePoint = now.subtract(Duration(seconds: secondsAgo));

      final timeText =
          '${timePoint.hour.toString().padLeft(2, '0')}:${timePoint.minute.toString().padLeft(2, '0')}:${timePoint.second.toString().padLeft(2, '0')}';

      tp.text = TextSpan(
        text: timeText,
        style: const TextStyle(color: Colors.white60, fontSize: 11),
      );
      tp.layout();

      final x = leftPadding + (i / 5.0) * plotWidth - tp.width / 2;
      tp.paint(canvas, Offset(x, size.height - 35));
    }
  }

  void _drawDistanceLine(
      Canvas canvas,
      List<_Sample> samples,
      double leftPadding,
      double topPadding,
      double plotWidth,
      double plotHeight,
      double windowStart,
      double now) {
    final path = Path();
    bool first = true;

    // Only draw samples within the display window
    for (final sample in samples) {
      // Skip samples outside the window
      if (sample.t < windowStart) continue;

      // Calculate normalized position in the window
      final xNorm =
      ((sample.t - windowStart) / displayWindowSeconds).clamp(0.0, 1.0);
      final x = leftPadding + xNorm * plotWidth;

      final yNorm = (sample.distance / maxDepth).clamp(0.0, 1.0);
      final y = topPadding + plotHeight - (yNorm * plotHeight);

      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }

    if (first) return; // No data to draw

    // Draw glow effect
    final glowPaint = Paint()
      ..color = Colors.indigoAccent.withOpacity(0.5)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path, glowPaint);

    // Draw main line
    final linePaint = Paint()
      ..color = Colors.indigoAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}