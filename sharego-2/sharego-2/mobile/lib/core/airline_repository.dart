import 'dart:convert';

import 'package:flutter/services.dart';

class Airline {
  const Airline({
    required this.iata,
    required this.name,
    required this.country,
  });

  final String iata;
  final String name;
  final String country;

  String get displayLabel => '$iata - $name';

  factory Airline.fromJson(Map<String, dynamic> json) => Airline(
        iata: json['iata'] as String,
        name: json['name'] as String,
        country: json['country'] as String,
      );

  @override
  String toString() => displayLabel;
}

class AirlineRepository {
  List<Airline> _airlines = [];
  final Map<String, Airline> _byIata = {};

  bool get isLoaded => _airlines.isNotEmpty;

  Future<void> load() async {
    if (_airlines.isNotEmpty) return;
    final raw = await rootBundle.loadString('assets/airlines.json');
    final list = jsonDecode(raw) as List;
    _airlines = list
        .map((e) => Airline.fromJson(e as Map<String, dynamic>))
        .toList();
    for (final a in _airlines) {
      _byIata[a.iata] = a;
    }
  }

  Airline? byIata(String code) => _byIata[code.toUpperCase()];

  List<Airline> search(String query, {int limit = 15}) {
    if (query.isEmpty) return _airlines.take(limit).toList();
    final q = query.toLowerCase();

    final exact = <Airline>[];
    final prefix = <Airline>[];
    final contains = <Airline>[];

    for (final a in _airlines) {
      final iataLower = a.iata.toLowerCase();
      final nameLower = a.name.toLowerCase();
      final countryLower = a.country.toLowerCase();

      if (iataLower == q) {
        exact.add(a);
      } else if (iataLower.startsWith(q) || nameLower.startsWith(q)) {
        prefix.add(a);
      } else if (nameLower.contains(q) ||
          countryLower.contains(q) ||
          iataLower.contains(q)) {
        contains.add(a);
      }
    }

    return [...exact, ...prefix, ...contains].take(limit).toList();
  }
}
