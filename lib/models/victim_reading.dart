// lib/models/victim_reading.dart
class VictimReading {
  final int id;
  final String victimId;
  final double distanceCm;
  final double? latitude;
  final double? longitude;
  final DateTime timestamp;

  VictimReading({
    required this.id,
    required this.victimId,
    required this.distanceCm,
    this.latitude,
    this.longitude,
    required this.timestamp,
  });

  /// Robust ISO timestamp parser:
  /// - accepts: "2025-11-28T17:49:43Z"
  /// - accepts: "2025-11-28T17:49:43+00:00"
  /// - accepts: "2025-11-28T17:49:43+00:00Z" (we will normalize it)
  static DateTime _parseTimestamp(String? s) {
    if (s == null || s.isEmpty) {
      // fallback to now if missing (or throw if you prefer)
      return DateTime.now().toUtc();
    }

    var str = s.trim();

    // Normalise common broken form: "+00:00Z" -> "Z"
    // e.g. "2025-11-28T17:49:43+00:00Z" -> "2025-11-28T17:49:43Z"
    if (str.endsWith('Z') && str.contains('+')) {
      // remove the trailing Z if there is an explicit +hh:mm part
      // convert "+00:00Z" -> "Z" by removing the "+00:00"
      final lastPlus = str.lastIndexOf('+');
      if (lastPlus != -1) {
        final maybeOffset = str.substring(lastPlus);
        // if looks like +HH:MM or +HHMM or +HH, strip it
        if (RegExp(r'^\+[0-9]{2}(:?[0-9]{2})?Z$').hasMatch(maybeOffset)) {
          // remove the offset and keep single Z
          str = str.substring(0, lastPlus) + 'Z';
        } else {
          // fallback: strip trailing Z only
          str = str.replaceFirst(RegExp(r'Z$'), '');
        }
      }
    }

    // If string ends with 'Z' it's UTC — DateTime.parse can handle it.
    // If it contains a timezone like +05:30 DateTime.parse can handle it.
    try {
      return DateTime.parse(str).toUtc();
    } catch (_) {
      // as last resort try some manual transformations:
      // remove trailing 'Z' and parse as naive then treat as UTC
      final cleaned = str.replaceFirst(RegExp(r'Z$'), '');
      try {
        return DateTime.parse(cleaned).toUtc();
      } catch (e) {
        // ultimate fallback: return now (but log in dev)
        // You may prefer to throw instead.
        return DateTime.now().toUtc();
      }
    }
  }

  factory VictimReading.fromJson(Map<String, dynamic> json) {
    final ts = json['timestamp'];
    // timestamp may be already DateTime (if decoded differently)
    DateTime parsedTs;
    if (ts is DateTime) {
      parsedTs = ts.toUtc();
    } else {
      parsedTs = _parseTimestamp(ts?.toString());
    }

    return VictimReading(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      victimId: json['victim_id'] ?? json['victimId'] ?? 'unknown',
      distanceCm: (json['distance_cm'] is num) ? (json['distance_cm'] as num).toDouble() : double.parse(json['distance_cm'].toString()),
      latitude: json['latitude'] == null ? null : (json['latitude'] as num).toDouble(),
      longitude: json['longitude'] == null ? null : (json['longitude'] as num).toDouble(),
      timestamp: parsedTs,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'victim_id': victimId,
    'distance_cm': distanceCm,
    'latitude': latitude,
    'longitude': longitude,
    // keep ISO UTC with 'Z' suffix
    'timestamp': timestamp.toUtc().toIso8601String().replaceFirst(RegExp(r'\+00:00$'), 'Z'),
  };

  /// convenience string for clipboard / debug
  String toJsonString() => toJson().toString();
}