// lib/live_graph_interface.dart - SIMPLE Distance vs Time Graph
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class LiveGraphInterface extends StatefulWidget {
  const LiveGraphInterface({super.key});

  @override
  State<LiveGraphInterface> createState() => _LiveGraphInterfaceState();
}

class _LiveGraphInterfaceState extends State<LiveGraphInterface> {
  final int windowSeconds = 60;
  final double maxDepth = 10.0;

  List<_Sample> distanceHistory = [];
  double currentDistance = 4.2;
  String status = 'Stable';

  @override
  void initState() {
    super.initState();
    _generateSampleData();
  }

  void _generateSampleData() {
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final Random rnd = Random(42); // Fixed seed for demo

    // Generate 60 seconds of earthquake aftershock data
    for (int i = 0; i < 30; i++) {
      final t = now - (windowSeconds - i * 2);
      double distance = 4.2;

      // Simulate aftershocks and rubble shifts
      if (i == 8) distance += 1.2;  // Aftershock #1 - falls deeper
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
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final displaySamples = distanceHistory.where((s) => s.t >= now - windowSeconds).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Distance vs Time'),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _generateSampleData,
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
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text('Current: ${currentDistance.toStringAsFixed(1)}m',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  Text(status, style: TextStyle(color: Colors.white70, fontSize: 16)),
                  Text('60 second monitoring window', style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Graph (90% screen)
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.indigoAccent, width: 2),
                ),
                padding: const EdgeInsets.all(20),
                child: CustomPaint(
                  painter: SimpleDistanceTimePainter(displaySamples, windowSeconds),
                ),
              ),
            ),

            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('← Older        Time → NOW',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                Text('↑ Distance (meters)',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
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

    // Background
    final bgPaint = Paint()..color = Colors.black87;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)), bgPaint);

    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final windowStart = now - windowSeconds;

    // Simple grid
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 1;

    // Depth grid lines (0-10m)
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

    // Labels
    const labels = ['0m', '2m', '4m', '6m', '8m', '10m'];
    for (int i = 0; i < labels.length; i++) {
      tp.text = TextSpan(text: labels[i], style: const TextStyle(color: Colors.white60, fontSize: 12));
      tp.layout();
      final y = topPadding + plotHeight - (i / 5.0) * plotHeight - tp.height / 2;
      tp.paint(canvas, Offset(8, y));
    }

    // Time labels
    for (int i = 0; i <= 5; i++) {
      final sec = (windowSeconds * i / 5).round();
      tp.text = TextSpan(text: '$sec s', style: const TextStyle(color: Colors.white60, fontSize: 12));
      tp.layout();
      final x = leftPadding + (i / 5.0) * plotWidth - tp.width / 2;
      tp.paint(canvas, Offset(x, size.height - 35));
    }

    if (samples.isEmpty) return;

    // Draw line
    final path = Path();
    bool first = true;

    for (final sample in samples) {
      if (sample.t < windowStart) continue;

      final xNorm = ((sample.t - windowStart) / windowSeconds).clamp(0.0, 1.0);
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
      final xNorm = ((last.t - windowStart) / windowSeconds).clamp(0.0, 1.0);
      final x = leftPadding + xNorm * plotWidth;
      final yNorm = (last.distance / 10.0).clamp(0.0, 1.0);
      final y = topPadding + plotHeight - (yNorm * plotHeight);

      final dotPaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(x, y), 6, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
