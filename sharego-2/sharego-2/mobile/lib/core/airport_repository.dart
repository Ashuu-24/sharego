import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

class Airport {
  const Airport({
    required this.iata,
    required this.name,
    required this.city,
    required this.country,
    this.lat = 0.0,
    this.lng = 0.0,
  });

  final String iata;
  final String name;
  final String city;
  final String country;
  final double lat;
  final double lng;

  String get displayLabel => '$iata - $city, $country';

  factory Airport.fromJson(Map<String, dynamic> json) => Airport(
        iata: json['iata'] as String,
        name: json['name'] as String,
        city: json['city'] as String,
        country: json['country'] as String,
        lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
        lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      );

  @override
  String toString() => displayLabel;
}

double _toRad(double deg) => deg * pi / 180;

double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadius = 6371.0;
  final dLat = _toRad(lat2 - lat1);
  final dLng = _toRad(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadius * c;
}

class AirportRepository {
  List<Airport> _airports = [];
  final Map<String, Airport> _byIata = {};

  bool get isLoaded => _airports.isNotEmpty;

  Future<void> load() async {
    if (_airports.isNotEmpty) return;
    final raw = await rootBundle.loadString('assets/airports.json');
    final list = jsonDecode(raw) as List;
    _airports = list
        .map((e) => Airport.fromJson(e as Map<String, dynamic>))
        .toList();
    for (final a in _airports) {
      _byIata[a.iata] = a;
    }
  }

  Airport? byIata(String code) => _byIata[code.toUpperCase()];

  /// Returns the nearest airport to the given coordinates, or null if none have valid coords.
  Airport? nearestTo(double lat, double lng) {
    Airport? best;
    double bestDist = double.infinity;
    for (final a in _airports) {
      if (a.lat == 0.0 && a.lng == 0.0) continue;
      final d = _haversineKm(lat, lng, a.lat, a.lng);
      if (d < bestDist) {
        bestDist = d;
        best = a;
      }
    }
    return best;
  }

  List<Airport> search(String query, {int limit = 15}) {
    if (query.isEmpty) return _airports.take(limit).toList();
    final q = query.toLowerCase();

    final exact = <Airport>[];
    final prefix = <Airport>[];
    final contains = <Airport>[];

    for (final a in _airports) {
      final iataLower = a.iata.toLowerCase();
      final cityLower = a.city.toLowerCase();
      final nameLower = a.name.toLowerCase();
      final countryLower = a.country.toLowerCase();

      if (iataLower == q) {
        exact.add(a);
      } else if (iataLower.startsWith(q) || cityLower.startsWith(q)) {
        prefix.add(a);
      } else if (cityLower.contains(q) ||
          nameLower.contains(q) ||
          countryLower.contains(q) ||
          iataLower.contains(q)) {
        contains.add(a);
      }
    }

    return [...exact, ...prefix, ...contains].take(limit).toList();
  }
}
