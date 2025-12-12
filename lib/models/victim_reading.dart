// lib/models/victim_reading.dart
class VictimReading {
  final int? id;
  final String victimId;

  // Radar-specific fields your UI expects
  final bool detected;
  final double? rangeCm; // primary distance value from radar
  final double? angleDeg;

  // Backwards-compatible fields (some payloads still use distance_cm)
  final double? distanceCm;

  // Other optional sensors (kept for compatibility)
  final double? temperatureC;
  final double? humidityPct;
  final double? gasPpm;
  final double? latitude;
  final double? longitude;

  final DateTime timestamp;

  VictimReading({
    this.id,
    required this.victimId,
    required this.detected,
    this.rangeCm,
    this.angleDeg,
    this.distanceCm,
    this.temperatureC,
    this.humidityPct,
    this.gasPpm,
    this.latitude,
    this.longitude,
    required this.timestamp,
  });

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    return double.tryParse(s);
  }

  static bool _toBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    final s = v.toString().trim().toLowerCase();
    return (s == '1' || s == 'true' || s == 'yes' || s == 'on');
  }

  factory VictimReading.fromJson(Map<String, dynamic> js) {
    // Support multiple key names used by various backends
    String vid = js['victim_id'] ??
        js['victimId'] ??
        js['id']?.toString() ??
        'vic-${DateTime.now().millisecondsSinceEpoch}';

    // Range may be under range_cm, range, distance_cm, distance
    final dynamic rawRange = js['range_cm'] ??
        js['range'] ??
        js['distance_cm'] ??
        js['distance'];

    final dynamic rawAngle = js['angle_deg'] ?? js['angle'];

    final dynamic rawDetected = js['detected'] ??
        js['has_person'] ??
        js['presence'] ??
        js['found'];

    final timestampRaw = js['timestamp'] ?? js['time'] ?? js['ts'];

    DateTime ts;
    if (timestampRaw == null) {
      ts = DateTime.now();
    } else {
      try {
        ts = DateTime.parse(timestampRaw.toString());
      } catch (_) {
        // Try numeric epoch (seconds or milliseconds)
        final epoch = int.tryParse(timestampRaw.toString());
        if (epoch != null) {
          ts = epoch > 9999999999 ? DateTime.fromMillisecondsSinceEpoch(epoch) : DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
        } else {
          ts = DateTime.now();
        }
      }
    }

    return VictimReading(
      id: js['id'] is int ? js['id'] as int : (int.tryParse(js['id']?.toString() ?? '') ?? null),
      victimId: vid.toString(),
      detected: _toBool(rawDetected),
      rangeCm: _toDouble(rawRange),
      angleDeg: _toDouble(rawAngle),
      distanceCm: _toDouble(js['distance_cm'] ?? js['distance']),
      temperatureC: _toDouble(js['temperature'] ?? js['temperature_c']),
      humidityPct: _toDouble(js['humidity'] ?? js['humidity_pct']),
      gasPpm: _toDouble(js['gas'] ?? js['gas_ppm']),
      latitude: _toDouble(js['latitude']),
      longitude: _toDouble(js['longitude']),
      timestamp: ts,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'victim_id': victimId,
    'detected': detected,
    'range_cm': rangeCm,
    'angle_deg': angleDeg,
    'distance_cm': distanceCm,
    'temperature': temperatureC,
    'humidity': humidityPct,
    'gas': gasPpm,
    'latitude': latitude,
    'longitude': longitude,
    'timestamp': timestamp.toUtc().toIso8601String(),
  };
}