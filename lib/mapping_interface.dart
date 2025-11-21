import 'package:flutter/material.dart';
import 'dart:math';

class DetectedPoint {
  final double angle;     // in radians
  final double distance;  // 0 to 1 (normalized)
  DetectedPoint(this.angle, this.distance);
}

class MappingInterface extends StatefulWidget {
  @override
  _MappingInterfaceState createState() => _MappingInterfaceState();
}

class _MappingInterfaceState extends State<MappingInterface>
    with SingleTickerProviderStateMixin {

  AnimationController? _controller;

  // Example detected humans (later this will come from ESP32)
  List<DetectedPoint> detected = [
    DetectedPoint(pi / 3, 0.6),     // 60° at 60% radius
    DetectedPoint(5 * pi / 4, 0.4), // 225°
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1A1D23),
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            double size =
                min(constraints.maxWidth, constraints.maxHeight) * 0.95;

            return CustomPaint(
              size: Size(size, size),
              painter: RadarPainter(_controller!, detected),
            );
          },
        ),
      ),
    );
  }
}

class RadarPainter extends CustomPainter {
  final Animation<double> animation;
  final List<DetectedPoint> detected;

  RadarPainter(this.animation, this.detected) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // ---- Draw concentric circles ----
    final circlePaint = Paint()
      ..color = Colors.grey.shade700
      ..style = PaintingStyle.stroke;

    for (int i = 1; i <= 5; i++) {
      canvas.drawCircle(center, i * size.width / 10, circlePaint);
    }

    // ---- Crosshair ----
    final linePaint = Paint()
      ..color = Colors.grey.shade700
      ..strokeWidth = 1;

    canvas.drawLine(center.translate(-size.width / 2, 0),
        center.translate(size.width / 2, 0), linePaint);

    canvas.drawLine(center.translate(0, -size.height / 2),
        center.translate(0, size.height / 2), linePaint);

    // ---- Sweeping line ----
    final sweepPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.green.withOpacity(0.9),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: size.width / 2),
      )
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12);

    final angle = animation.value * 2 * pi;
    final endX = center.dx + (size.width / 2) * cos(angle);
    final endY = center.dy + (size.height / 2) * sin(angle);
    canvas.drawLine(center, Offset(endX, endY), sweepPaint);

    // ---- Draw detected humans as blinking pulse ----
    drawPulseDetections(canvas, size, center);
  }

  void drawPulseDetections(Canvas canvas, Size size, Offset center) {
    for (var d in detected) {

      final dx = center.dx + cos(d.angle) * (d.distance * size.width / 2);
      final dy = center.dy + sin(d.angle) * (d.distance * size.height / 2);
      Offset point = Offset(dx, dy);

      final pulseSize = 8 + sin(animation.value * 2 * pi) * 5;

      final pulsePaint = Paint()
        ..color = Colors.green.withOpacity(0.8)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(point, pulseSize, pulsePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}