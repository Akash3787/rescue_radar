import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';

import 'models/victim_reading.dart';
import 'services/api_service.dart';
import 'live_graph_interface.dart';
import 'victim_map_screen.dart';

class MappingInterface extends StatefulWidget {
  const MappingInterface({super.key});

  @override
  _MappingInterfaceState createState() => _MappingInterfaceState();
}

class _MappingInterfaceState extends State<MappingInterface> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late ApiService _apiService;
  
  List<DetectionPoint> humanPoints = [];
  List<DetectionPoint> noisePoints = [];
  List<DetectionPoint> debrisPoints = [];
  
  List<VictimReading> _victimReadings = [];
  bool _isLoading = false;
  DateTime? _lastUpdate;
  Timer? _autoRefreshTimer;

  bool autoRefresh = true;
  bool showGrid = true;
  bool soundAlert = false;
  final TextEditingController clearPointsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _apiService = ApiService.forHosted();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30), // 2 RPM sweep => 30s per rotation
    )..repeat();
    _loadVictimData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _controller.dispose();
    clearPointsController.dispose();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    if (autoRefresh) {
      _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _loadVictimData();
      });
    }
  }

  Future<void> _loadVictimData() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
  });

    try {
      final readings = await _apiService.fetchAllReadings();
      _convertReadingsToDetectionPoints(readings);
      setState(() {
        _victimReadings = readings;
        _lastUpdate = DateTime.now();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading data: $e")),
        );
      }
    }
  }

  void _convertReadingsToDetectionPoints(List<VictimReading> readings) {
    // Separate victims with GPS and without GPS
    final victimsWithGPS = readings.where((r) => r.latitude != null && r.longitude != null).toList();
    final victimsWithoutGPS = readings.where((r) => r.latitude == null || r.longitude == null).toList();

    // Convert victims with GPS to detection points
    humanPoints = [];
    for (int i = 0; i < victimsWithGPS.length; i++) {
      final victim = victimsWithGPS[i];
      // Use distanceCm to determine radar distance (normalize: max 1000cm = 1.0)
      final normalizedDistance = (victim.distanceCm / 1000.0).clamp(0.1, 1.0);
      // Distribute angles evenly around the circle, or use a hash of victim ID
      final angle = (i * 2 * pi / (victimsWithGPS.isNotEmpty ? victimsWithGPS.length : 1)) + 
                    (victim.victimId.hashCode % 100) / 100.0;
      humanPoints.add(DetectionPoint(
        angle: angle,
        distance: normalizedDistance,
        label: victim.victimId.length > 4 ? victim.victimId.substring(0, 4) : victim.victimId,
        color: const Color(0xFFE53935),
        victimReading: victim, // Store reference to open in maps
      ));
    }

    // Convert victims without GPS (treat as noise/debris for now)
    noisePoints = [];
    debrisPoints = [];
    
    // You can add logic here to categorize based on distance or other factors
    for (int i = 0; i < victimsWithoutGPS.length; i++) {
      final victim = victimsWithoutGPS[i];
      final normalizedDistance = (victim.distanceCm / 1000.0).clamp(0.1, 1.0);
      final angle = (i * 2 * pi / (victimsWithoutGPS.isNotEmpty ? victimsWithoutGPS.length : 1)) + 
                    (victim.victimId.hashCode % 100) / 100.0;
      
      // Categorize based on distance (closer = debris, farther = noise)
      if (victim.distanceCm < 200) {
        debrisPoints.add(DetectionPoint(
          angle: angle,
          distance: normalizedDistance,
          label: victim.victimId.length > 4 ? victim.victimId.substring(0, 4) : victim.victimId,
          color: const Color(0xFF616161),
        ));
      } else {
        noisePoints.add(DetectionPoint(
          angle: angle,
          distance: normalizedDistance,
          label: victim.victimId.length > 4 ? victim.victimId.substring(0, 4) : victim.victimId,
          color: const Color(0xFFFF9100),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const darkBackgroundColor = Color(0xFF1A1D23);
    const tealCyanLight = Color(0xFF26D9C8);
    const activeGreen = Color(0xFF00C853);

    return Scaffold(
      backgroundColor: darkBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.teal[800],
        title: const Text("Rubble Radar Rescue System"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // Goes back to previous screen
          },
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 1050;
          final radarSize = isNarrow
              ? constraints.maxWidth * 0.85
              : 650.0;
          final sideWidth = isNarrow
              ? constraints.maxWidth
              : (constraints.maxWidth * 0.26).clamp(220.0, 320.0);

          Widget infoPanel = Container(
            width: sideWidth,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: darkBackgroundColor,
              border: isNarrow
                  ? const Border(bottom: BorderSide(color: Colors.white24, width: 1))
                  : const Border(right: BorderSide(color: Colors.white24, width: 1)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.circle, color: Color(0xFF00C853), size: 16),
                          SizedBox(width: 8),
                          Text(
                            "Active Scan",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _infoText("Range: 10 meters"),
                      _infoText("Sweep Rate: 2 RPM"),
                      _infoText("Detected Targets: ${humanPoints.length + noisePoints.length + debrisPoints.length}"),
                      _infoText("Humans: ${humanPoints.length}"),
                      _infoText("With GPS: ${_victimReadings.where((r) => r.latitude != null && r.longitude != null).length}"),
                      _infoText(_lastUpdate != null
                          ? "Last Update: ${_formatTimeAgo(_lastUpdate!)}"
                          : "Last Update: Never"),
                    ],
                  ),
                ),
              ],
            ),
          );

          Widget radarPanel = Center(
            child: SizedBox(
              width: radarSize,
              height: radarSize,
              child: GestureDetector(
                onTapDown: (details) {
                  _handleRadarTap(details.localPosition, Size(radarSize, radarSize));
                },
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: RadarPainter(
                        sweepAngle: _controller.value * 2 * pi,
                        humanDetections: humanPoints,
                        noiseDetections: noisePoints,
                        debrisDetections: debrisPoints,
                        showGrid: showGrid,
                      ),
                    );
                  },
                ),
              ),
            ),
          );

          Widget controlPanel = Container(
            width: sideWidth,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: darkBackgroundColor,
              border: isNarrow
                  ? const Border(top: BorderSide(color: Colors.white24, width: 1))
                  : const Border(left: BorderSide(color: Colors.white24, width: 1)),
            ),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : () => _loadVictimData(),
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.refresh, color: Colors.white),
                        label: const Text(
                          "Refresh Map",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tealCyanLight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          elevation: 4,
                          shadowColor: Colors.black45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      "Clear Points",
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: clearPointsController,
                      cursorColor: Colors.white,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        fillColor: Colors.grey[900],
                        filled: true,
                        hintText: "Enter points to clear",
                        hintStyle: const TextStyle(color: Colors.white54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _buildSwitch("Auto Refresh", autoRefresh, activeGreen, (v) {
                      setState(() => autoRefresh = v);
                      _startAutoRefresh();
                    }),
                    _buildSwitch("Show Grid", showGrid, activeGreen, (v) {
                      setState(() => showGrid = v);
                    }),
                    _buildSwitch(
                      "Sound Alert", soundAlert, Colors.grey, (v) => setState(() => soundAlert = v),
                      inactiveTrackColor: const Color(0xFFFF9100),
                    ),
                  ],
                ),
              ),
            ),
          );

          final legendBar = Container(
            height: 56,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A1D23), Color(0xFF252932)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border(top: BorderSide(color: Colors.white24)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _legendCircle(const Color(0xFFE53935), "Human Detected"),
                const SizedBox(width: 16),
                _legendCircle(const Color(0xFFFF9100), "Noise Signal"),
                const SizedBox(width: 16),
                _legendCircle(const Color(0xFF616161), "Object/Debris"),
                const Spacer(),
                Row(
                  children: [
                    Container(
                      width: 100,
                      height: 12,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00C853), Color(0xFF26D9C8)],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Radar Sweep",
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                )
              ],
            ),
          );

          if (isNarrow) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  infoPanel,
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: radarPanel,
                  ),
                  controlPanel,
                  legendBar,
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    infoPanel,
                    Expanded(child: radarPanel),
                    controlPanel,
                  ],
                ),
              ),
              legendBar,
            ],
          );
        },
      ),
    );
  }

  Widget _infoText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
    );
  }

  Widget _buildSwitch(String label, bool value, Color activeColor, ValueChanged<bool> onChanged,
      {Color? inactiveTrackColor}) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
      value: value,
      activeColor: activeColor,
      inactiveTrackColor: inactiveTrackColor,
      onChanged: onChanged,
    );
  }

  Widget _legendCircle(Color color, String label) {
    return Row(
      children: [
        Container(width: 16, height: 16, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ],
    );
  }

  String _formatTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${difference.inHours}h ago';
    }
  }

  void _handleRadarTap(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Calculate distance and angle from center
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    
    // Find closest detection point
    DetectionPoint? closestPoint;
    double minDistance = double.infinity;
    
    for (var point in [...humanPoints, ...noisePoints, ...debrisPoints]) {
      final pointDx = cos(point.angle) * point.distance * radius;
      final pointDy = sin(point.angle) * point.distance * radius;
      final pointDistance = sqrt((dx - pointDx) * (dx - pointDx) + (dy - pointDy) * (dy - pointDy));
      
      if (pointDistance < minDistance && pointDistance < 30) { // 30 pixel threshold
        minDistance = pointDistance;
        closestPoint = point;
      }
    }
    
    if (closestPoint != null && closestPoint.victimReading != null) {
      _showVictimInfo(closestPoint.victimReading!);
    }
  }

  Future<void> _showVictimInfo(VictimReading victim) async {
    if (victim.latitude == null || victim.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No GPS coordinates available for this victim"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Victim: ${victim.victimId}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Distance: ${victim.distanceCm.toStringAsFixed(1)} cm"),
            Text("Latitude: ${victim.latitude!.toStringAsFixed(6)}"),
            Text("Longitude: ${victim.longitude!.toStringAsFixed(6)}"),
            Text("Time: ${victim.timestamp.toString()}"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          if (victim.latitude != null && victim.longitude != null)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VictimMapScreen(victim: victim),
                  ),
                );
              },
              icon: const Icon(Icons.map),
              label: const Text("Maps"),
            ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LiveGraphInterface(victimId: victim.victimId),
                ),
              );
            },
            icon: const Icon(Icons.show_chart),
            label: const Text("Live Graph"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

}

class DetectionPoint {
  final double angle; // radians
  final double distance; // 0-1 normalized
  final String label;
  final Color color;
  final VictimReading? victimReading; // Optional reference to victim data

  DetectionPoint({
    required this.angle,
    required this.distance,
    required this.label,
    required this.color,
    this.victimReading,
  });
}

class RadarPainter extends CustomPainter {
  final double sweepAngle;
  final bool showGrid;
  final List<DetectionPoint> humanDetections;
  final List<DetectionPoint> noiseDetections;
  final List<DetectionPoint> debrisDetections;
  final Paint _circlePaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1;
  final Paint _gridLinePaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.lightBlue.withOpacity(0.3);

  RadarPainter({
    required this.sweepAngle,
    required this.showGrid,
    required this.humanDetections,
    required this.noiseDetections,
    required this.debrisDetections,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background fill
    final bgPaint = Paint()..color = const Color(0xFF1A1D23);
    canvas.drawRect(Offset.zero & size, bgPaint);

    if (showGrid) {
      _drawGrid(canvas, center, radius);
    }

    _drawCrosshairs(canvas, size, center);

    _drawCardinalLabels(canvas, center, radius);

    _drawSweepSector(canvas, center, radius);

    _drawDetections(canvas, center, radius, humanDetections, true);
    _drawDetections(canvas, center, radius, noiseDetections, false);
    _drawDetections(canvas, center, radius, debrisDetections, false);
  }

  void _drawGrid(Canvas canvas, Offset center, double radius) {
    _circlePaint.color = Colors.lightBlue.withOpacity(0.3);

    // Draw 10 circles for 1m through 10m
    for (int i = 1; i <= 10; i++) {
      canvas.drawCircle(center, radius * i / 10, _circlePaint);
    }

    // Draw radial lines every 30 degrees (optional)
    for (int i = 0; i < 12; i++) {
      double angle = i * pi / 6;
      final end = Offset(center.dx + radius * cos(angle), center.dy + radius * sin(angle));
      canvas.drawLine(center, end, _gridLinePaint);
    }

    // Draw distance labels outside the circles for each meter
    final textStyle = TextStyle(color: Colors.lightBlue.withOpacity(0.5), fontSize: 12);
    final tp = TextPainter(textAlign: TextAlign.center, textDirection: TextDirection.ltr);

    for (int i = 1; i <= 10; i++) {
      tp.text = TextSpan(text: '${i}m', style: textStyle);
      tp.layout();
      // Draw label centered horizontally, just below the circle boundary near bottom center.
      tp.paint(canvas, Offset(center.dx + radius * i / 10 - tp.width / 2, center.dy + 4));
    }
  }


  void _drawCrosshairs(Canvas canvas, Size size, Offset center) {
    final crosshairPaint = Paint()
      ..color = Colors.lightBlue.withOpacity(0.6)
      ..strokeWidth = 1;

    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), crosshairPaint);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), crosshairPaint);
  }

  void _drawCardinalLabels(Canvas canvas, Offset center, double radius) {
    final textStyle = TextStyle(
      color: Colors.lightBlue.withOpacity(0.8),
      fontSize: 16,
      fontWeight: FontWeight.bold,
    );
    final tp = TextPainter(textAlign: TextAlign.center, textDirection: TextDirection.ltr);

    final Map<String, Offset> directions = {
      'N': Offset(center.dx, center.dy - radius + 12),
      'S': Offset(center.dx, center.dy + radius - 24),
      'E': Offset(center.dx + radius - 24, center.dy),
      'W': Offset(center.dx - radius + 12, center.dy),
    };

    for (var entry in directions.entries) {
      tp.text = TextSpan(text: entry.key, style: textStyle);
      tp.layout();
      Offset textPos = entry.value - Offset(tp.width / 2, tp.height / 2);
      tp.paint(canvas, textPos);
    }
  }

  void _drawSweepSector(Canvas canvas, Offset center, double radius) {
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          const Color(0xFF26D9C8).withOpacity(0.6),
          const Color(0xFF26D9C8).withOpacity(0.0),
        ],
        startAngle: sweepAngle - 0.2,
        endAngle: sweepAngle,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    Path sector = Path();
    sector.moveTo(center.dx, center.dy);
    sector.arcTo(Rect.fromCircle(center: center, radius: radius), sweepAngle - 0.2, 0.2, false);
    sector.close();

    canvas.drawPath(sector, sweepPaint);
  }

  void _drawDetections(Canvas canvas, Offset center, double radius, List<DetectionPoint> points, bool pulse) {
    final currentTime = DateTime.now().millisecondsSinceEpoch / 1000;
    for (var pt in points) {
      final pos = Offset(center.dx + cos(pt.angle) * pt.distance * radius,
          center.dy + sin(pt.angle) * pt.distance * radius);

      final pointPaint = Paint()..color = pt.color;
      canvas.drawCircle(pos, 12, pointPaint);

      final outlinePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(pos, 12, outlinePaint);

      if (pulse) {
        final pulseRadius = 16 + 6 * sin(currentTime * 2 * pi);
        final pulsePaint = Paint()
          ..color = pt.color.withOpacity(0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, pulseRadius, pulsePaint);
      }

      // Show GPS indicator if victim has coordinates
      if (pt.victimReading != null && pt.victimReading!.latitude != null) {
        final gpsPaint = Paint()
          ..color = Colors.green
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos + const Offset(8, -8), 4, gpsPaint);
      }

      final textPainter = TextPainter(
          text: TextSpan(
            text: pt.label,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, pos + const Offset(16, -10));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}