/// Core data model for astrological chart data.
///
/// This is the common denominator across all chart file formats.
/// Every format reader produces a [ChartData], and every writer consumes one.
class ChartData {
  String name;
  DateTime dateTime; // Local time
  GeoLocation birthLocation;
  double utcOffsetHours; // Hours east of UTC (e.g. IST = 5.5, EST = -5.0)
  double dstOffsetHours;

  // Optional fields — not all formats carry these
  Gender? gender;
  String? notes;
  String? roddenRating;
  GeoLocation? currentLocation;
  double? currentUtcOffsetHours;
  List<PlanetPosition>? planets;
  Map<String, dynamic> extra; // Format-specific overflow

  ChartData({
    required this.name,
    required this.dateTime,
    required this.birthLocation,
    this.utcOffsetHours = 0.0,
    this.dstOffsetHours = 0.0,
    this.gender,
    this.notes,
    this.roddenRating,
    this.currentLocation,
    this.currentUtcOffsetHours,
    this.planets,
    Map<String, dynamic>? extra,
  }) : extra = extra ?? {};

  /// Julian-style UTC datetime.
  DateTime get utcDateTime => dateTime.subtract(
    Duration(minutes: ((utcOffsetHours + dstOffsetHours) * 60).round()),
  );

  /// Decimal hours of the local time (e.g. 14:30 → 14.5).
  double get decimalHours =>
      dateTime.hour + dateTime.minute / 60.0 + dateTime.second / 3600.0;

  @override
  String toString() =>
      'ChartData($name, ${dateTime.toIso8601String()}, $birthLocation)';

  Map<String, dynamic> toJson() => {
    'name': name,
    'date': '${dateTime.year}-${_p2(dateTime.month)}-${_p2(dateTime.day)}',
    'time':
        '${_p2(dateTime.hour)}:${_p2(dateTime.minute)}:${_p2(dateTime.second)}',
    'utc_offset': utcOffsetHours,
    'dst_offset': dstOffsetHours,
    'location': birthLocation.toJson(),
    if (gender != null) 'gender': gender!.name,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
    if (roddenRating != null) 'rodden_rating': roddenRating,
    if (currentLocation != null) 'current_location': currentLocation!.toJson(),
    if (currentUtcOffsetHours != null)
      'current_utc_offset': currentUtcOffsetHours,
    if (planets != null) 'planets': planets!.map((p) => p.toJson()).toList(),
    if (extra.isNotEmpty) 'extra': extra,
  };

  factory ChartData.fromJson(Map<String, dynamic> json) {
    final dateParts = (json['date'] as String).split('-');
    final timeParts = (json['time'] as String).split(':');
    return ChartData(
      name: json['name'] as String,
      dateTime: DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
        timeParts.length > 2 ? int.parse(timeParts[2]) : 0,
      ),
      birthLocation: GeoLocation.fromJson(json['location']),
      utcOffsetHours: (json['utc_offset'] as num?)?.toDouble() ?? 0.0,
      dstOffsetHours: (json['dst_offset'] as num?)?.toDouble() ?? 0.0,
      gender: json['gender'] != null
          ? _parseGender(json['gender'] as String)
          : null,
      notes: json['notes'] as String?,
      roddenRating: json['rodden_rating'] as String?,
      currentLocation: json['current_location'] != null
          ? GeoLocation.fromJson(json['current_location'])
          : null,
      currentUtcOffsetHours: (json['current_utc_offset'] as num?)?.toDouble(),
      planets: json['planets'] != null
          ? (json['planets'] as List)
                .map((p) => PlanetPosition.fromJson(p))
                .toList()
          : null,
      extra: json['extra'] != null
          ? Map<String, dynamic>.from(json['extra'])
          : {},
    );
  }
}

String _p2(int n) => n.toString().padLeft(2, '0');

Gender? _parseGender(String value) {
  for (final g in Gender.values) {
    if (g.name == value) return g;
  }
  return null;
}

enum Gender { male, female, unknown }

class GeoLocation {
  String city;
  String country;
  double latitude; // Positive = north
  double longitude; // Positive = east

  GeoLocation({
    this.city = '',
    this.country = '',
    required this.latitude,
    required this.longitude,
  });

  @override
  String toString() {
    final ns = latitude >= 0 ? 'N' : 'S';
    final ew = longitude >= 0 ? 'E' : 'W';
    return '$city, $country '
        '(${latitude.abs().toStringAsFixed(2)}$ns, '
        '${longitude.abs().toStringAsFixed(2)}$ew)';
  }

  Map<String, dynamic> toJson() => {
    'city': city,
    'country': country,
    'latitude': latitude,
    'longitude': longitude,
  };

  factory GeoLocation.fromJson(Map<String, dynamic> json) => GeoLocation(
    city: json['city'] as String? ?? '',
    country: json['country'] as String? ?? '',
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
  );
}

class PlanetPosition {
  String name;
  double longitude; // Ecliptic longitude 0–360
  bool retrograde;

  PlanetPosition({
    required this.name,
    required this.longitude,
    this.retrograde = false,
  });

  @override
  String toString() {
    final sign = _signs[(longitude ~/ 30) % 12];
    final deg = longitude % 30;
    return '$name: ${deg.toStringAsFixed(2)}° $sign${retrograde ? ' R' : ''}';
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'longitude': longitude,
    if (retrograde) 'retrograde': true,
  };

  factory PlanetPosition.fromJson(Map<String, dynamic> json) => PlanetPosition(
    name: json['name'] as String,
    longitude: (json['longitude'] as num).toDouble(),
    retrograde: json['retrograde'] as bool? ?? false,
  );

  static const _signs = [
    'Aries',
    'Taurus',
    'Gemini',
    'Cancer',
    'Leo',
    'Virgo',
    'Libra',
    'Scorpio',
    'Sagittarius',
    'Capricorn',
    'Aquarius',
    'Pisces',
  ];
}
