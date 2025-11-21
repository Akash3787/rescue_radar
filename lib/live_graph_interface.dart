// lib/live_graph_interface.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

/// Live heartbeat graph for one selected life.
/// - Clean, sharp waveform
/// - No time-window controls, no speed slider, no pause/play
/// - Fixed window (12s) showing live samples (right = now)
/// - Top status bar: BPM | Condition | Classification
/// - Prev / Next buttons to switch between detected lives (each life has its own simulated BPM)
class LiveGraphInterface extends StatefulWidget {
  const LiveGraphInterface({super.key});

  @override
  State<LiveGraphInterface> createState() => _LiveGraphInterfaceState();
}

class _DetectedLife {
  final String id;
  double baseBpm;
  _DetectedLife(this.id, this.baseBpm);
}

class _LiveGraphInterfaceState extends State<LiveGraphInterface> {
  // fixed time window in seconds
  final int windowSeconds = 12;

  // samples (timestampSeconds, amplitude)
  final List<_Sample> samples = [];

  // simulation timer
  Timer? sampleTimer;

  // detected lives (demo). In real app, replace with actual detected IDs and initial BPM guesses.
  final List<_DetectedLife> detectedLives = [
    _DetectedLife('Life-1', 78),
    _DetectedLife('Life-2', 64),
    _DetectedLife('Life-3', 130), // example animal-like BPM
  ];
  int selectedIndex = 0;

  // simulation state per selected life
  double simulatedPhase = 0.0;
  double displayedBpm = 0.0;
  String classification = 'Unknown';
  String conditionLabel = 'Unknown';
  Color conditionColor = Colors.grey;

  final Random _rnd = Random();

  @override
  void initState() {
    super.initState();
    // start high-resolution sampling (~40ms)
    sampleTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
      // simulate a sample for current life
      final amp = _simulateSample(now, detectedLives[selectedIndex].baseBpm);
      samples.add(_Sample(now, amp));
      // trim old samples beyond window
      final cutoff = now - windowSeconds - 0.5;
      while (samples.isNotEmpty && samples.first.t < cutoff) samples.removeAt(0);

      // update BPM & status every ~1 second (approx)
      if (samples.length > (1000 / 40)) {
        _computeBpmAndStatus();
      }

      setState(() {});
    });
  }

  @override
  void dispose() {
    sampleTimer?.cancel();
    super.dispose();
  }

  // Simulate one amplitude sample for heartbeat-like waveform for a given base BPM
  double _simulateSample(double nowSec, double baseBpm) {
    // add some slow drift and tiny random jitter
    final bpm = baseBpm + sin(nowSec / 15.0) * 0.8 + (_rnd.nextDouble() - 0.5) * 0.6;
    final freq = bpm / 60.0;
    // step phase
    simulatedPhase += 2 * pi * freq * 0.04; // step relative to sample interval (~40ms)
    // construct a sharper beat: main peak + harmonics + noise
    final s = sin(simulatedPhase);
    final peak = pow(s.abs(), 5) * (s.isNegative ? -1 : 1); // sharper peak
    final harmonic = 0.18 * sin(2 * simulatedPhase);
    final noise = (_rnd.nextDouble() - 0.5) * 0.05;
    final amp = (0.85 * peak + harmonic + noise).toDouble();
    return amp.clamp(-1.0, 1.0);
  }

  // Simple peak detection -> BPM estimation and classification/condition
  void _computeBpmAndStatus() {
    if (samples.length < 8) return;
    final amps = samples.map((s) => s.a).toList();
    final times = samples.map((s) => s.t).toList();

    // adaptive threshold slightly above mean
    final mean = amps.reduce((a, b) => a + b) / amps.length;
    final threshold = mean + 0.14;

    final peaks = <double>[];
    // naive peak detection
    for (int i = 1; i < amps.length - 1; i++) {
      if (amps[i] > amps[i - 1] && amps[i] > amps[i + 1] && amps[i] > threshold) {
        peaks.add(times[i]);
        i += 4; // skip a few samples to avoid double counting
      }
    }

    double bpm;
    if (peaks.length >= 2) {
      final intervals = <double>[];
      for (int i = 1; i < peaks.length; i++) intervals.add(peaks[i] - peaks[i - 1]);
      final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
      bpm = 60.0 / avgInterval;
    } else {
      // fallback to base BPM if peak detection insufficient
      bpm = detectedLives[selectedIndex].baseBpm;
    }

    displayedBpm = bpm;

    // classification heuristic
    if (displayedBpm >= 120) {
      classification = 'Likely Animal';
    } else if (displayedBpm >= 40 && displayedBpm < 120) {
      classification = 'Likely Human';
    } else {
      classification = 'Unknown';
    }

    // condition thresholds
    if (displayedBpm < 50) {
      conditionLabel = 'Weak';
      conditionColor = Colors.orangeAccent;
    } else if (displayedBpm <= 100) {
      conditionLabel = 'Normal';
      conditionColor = Colors.green;
    } else {
      conditionLabel = 'Critical';
      conditionColor = Colors.redAccent;
    }
  }

  // Switch life -> reset samples and use that life base BPM
  void _selectLife(int idx) {
    if (idx < 0 || idx >= detectedLives.length) return;
    setState(() {
      selectedIndex = idx;
      samples.clear();
      displayedBpm = detectedLives[selectedIndex].baseBpm;
      classification = 'Unknown';
      conditionLabel = 'Unknown';
      conditionColor = Colors.grey;
      simulatedPhase = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final displaySamples = samples.where((s) => s.t >= now - windowSeconds).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Live Heartbeat — Single Life View'),
        backgroundColor: Colors.teal[800],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Top status bar (BPM | Condition | Classification)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade800),
              ),
              child: Row(
                children: [
                  Text('Selected: ', style: _s(14, Colors.white70)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.blueGrey.shade700, borderRadius: BorderRadius.circular(20)),
                    child: Text(detectedLives[selectedIndex].id, style: _s(14, Colors.white)),
                  ),
                  const SizedBox(width: 14),
                  Text('BPM: ', style: _s(14, Colors.white70)),
                  Text(displayedBpm.toStringAsFixed(1), style: _s(20, Colors.white, weight: FontWeight.bold)),
                  const SizedBox(width: 20),
                  Text('Condition: ', style: _s(14, Colors.white70)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: conditionColor, borderRadius: BorderRadius.circular(20)),
                    child: Text(conditionLabel, style: _s(14, Colors.black)),
                  ),
                  const SizedBox(width: 20),
                  Text('Classification: ', style: _s(14, Colors.white70)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.blueGrey.shade700, borderRadius: BorderRadius.circular(20)),
                    child: Text(classification, style: _s(14, Colors.white)),
                  ),
                  const Spacer(),
                  // Prev / Next life buttons
                  IconButton(
                    onPressed: () => _selectLife((selectedIndex - 1 + detectedLives.length) % detectedLives.length),
                    icon: const Icon(Icons.chevron_left),
                    color: Colors.white,
                  ),
                  IconButton(
                    onPressed: () => _selectLife((selectedIndex + 1) % detectedLives.length),
                    icon: const Icon(Icons.chevron_right),
                    color: Colors.white,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Graph area (sharp, clear waveform)
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                padding: const EdgeInsets.all(8),
                child: CustomPaint(
                  painter: _RollingWavePainter(displaySamples, windowSeconds),
                  child: Center(
                    child: displaySamples.isEmpty
                        ? const Text('Waiting for data...', style: TextStyle(color: Colors.white54))
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),
            // Legend / axis hints
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('X-axis: seconds (right = now)', style: _s(12, Colors.white70)),
                Text('Amplitude (normalized)', style: _s(12, Colors.white70)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _s(double sz, Color c, {FontWeight weight = FontWeight.normal}) =>
      TextStyle(fontSize: sz, color: c, fontWeight: weight);
}

/// Simple sample
class _Sample {
  final double t; // epoch seconds
  final double a; // amplitude (-1..1)
  _Sample(this.t, this.a);
}

/// Painter draws a clean, sharp rolling waveform with seconds labels and amplitude ticks
class _RollingWavePainter extends CustomPainter {
  final List<_Sample> samples; // samples within window
  final int windowSeconds;

  _RollingWavePainter(this.samples, this.windowSeconds);

  @override
  void paint(Canvas canvas, Size size) {
    // background
    final bg = Paint()..color = Colors.black;
    canvas.drawRect(Offset.zero & size, bg);

    // paddings
    final leftPad = 50.0;
    final rightPad = 8.0;
    final topPad = 12.0;
    final bottomPad = 26.0;
    final w = size.width - leftPad - rightPad;
    final h = size.height - topPad - bottomPad;
    final origin = Offset(leftPad, topPad);

    // draw subtle grid
    final gridPaint = Paint()..color = Colors.grey.withOpacity(0.12);
    for (int i = 0; i <= 4; i++) {
      final y = origin.dy + (i / 4) * h;
      canvas.drawLine(Offset(origin.dx, y), Offset(origin.dx + w, y), gridPaint);
    }

    // vertical ticks: 6 ticks across window
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final ticks = 6;
    final secPerTick = (windowSeconds / (ticks - 1));
    final tp = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < ticks; i++) {
      final x = origin.dx + (i / (ticks - 1)) * w;
      canvas.drawLine(Offset(x, origin.dy), Offset(x, origin.dy + h), gridPaint);
      // label seconds relative to now (negative = seconds ago). Show seconds from left (older) to right (0s)
      final tickSec = (now - (windowSeconds - i * secPerTick)).toStringAsFixed(0);
      tp.text = TextSpan(text: '${tickSec}s', style: const TextStyle(color: Colors.white54, fontSize: 11));
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, origin.dy + h + 4));
    }

    // If no samples: show note
    if (samples.isEmpty) {
      final note = TextPainter(text: const TextSpan(text: 'No samples', style: TextStyle(color: Colors.white38)), textDirection: TextDirection.ltr);
      note.layout();
      note.paint(canvas, Offset(size.width / 2 - note.width / 2, size.height / 2 - note.height / 2));
      return;
    }

    // Build waveform path
    final path = Path();
    final fillPath = Path();

    final minA = -1.0;
    final maxA = 1.0;

    final t0 = now - windowSeconds;

    for (int i = 0; i < samples.length; i++) {
      final s = samples[i];
      final px = origin.dx + ((s.t - t0) / windowSeconds) * w;
      final normA = ((s.a - minA) / (maxA - minA)).clamp(0.0, 1.0);
      final py = origin.dy + h - normA * h;
      if (i == 0) {
        path.moveTo(px, py);
        fillPath.moveTo(px, py);
      } else {
        path.lineTo(px, py);
        fillPath.lineTo(px, py);
      }
    }

    // close fill path
    fillPath.lineTo(origin.dx + w, origin.dy + h);
    fillPath.lineTo(origin.dx, origin.dy + h);
    fillPath.close();

    // Fill under wave with subtle gradient
    final fillPaint = Paint()
      ..shader = LinearGradient(colors: [Colors.teal.withOpacity(0.20), Colors.transparent]).createShader(Rect.fromLTWH(origin.dx, origin.dy, w, h))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Wave stroke: sharp and clear (no blur)
    final stroke = Paint()
      ..color = Colors.tealAccent
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    canvas.drawPath(path, stroke);

    // Left axis amplitude labels (-1.0 .. 1.0)
    final labelTp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i <= 4; i++) {
      final val = (1.0 - i * 0.5).toStringAsFixed(1);
      labelTp.text = TextSpan(text: val, style: const TextStyle(color: Colors.white38, fontSize: 11));
      labelTp.layout();
      final y = origin.dy + (i / 4) * h - labelTp.height / 2;
      labelTp.paint(canvas, Offset(6, y));
    }

    // Now timestamp (right top)
    labelTp.text = TextSpan(text: 'Now: ${DateTime.now().toLocal().toIso8601String().substring(11, 19)}', style: const TextStyle(color: Colors.white60, fontSize: 12));
    labelTp.layout();
    labelTp.paint(canvas, Offset(origin.dx + w - labelTp.width, origin.dy - 18));
  }

  @override
  bool shouldRepaint(covariant _RollingWavePainter oldDelegate) => true;
}