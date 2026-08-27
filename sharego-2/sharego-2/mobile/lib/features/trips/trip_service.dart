import 'package:dio/dio.dart';

class TripService {
  TripService(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> createTrip({
    required String originAirport,
    required String destinationAirport,
    required DateTime flightDate,
    required double capacityKg,
    required int? feePkr,
    String? flightNumber,
    String? airline,
  }) async {
    final response = await _dio.post(
      '/trips',
      data: {
        'origin_airport': originAirport,
        'dest_airport': destinationAirport,
        'date': flightDate.toIso8601String(),
        'capacity_kg': capacityKg,
        if (feePkr != null) 'fee_pkr': feePkr,
        if (flightNumber != null && flightNumber.isNotEmpty)
          'flight_number': flightNumber,
        if (airline != null && airline.isNotEmpty) 'airline': airline,
      },
    );
    return (response.data as Map).cast<String, dynamic>();
  }

  /// Fetch all trips. If [mine] is true, returns all of the current user's
  /// trips (including pending/rejected). Otherwise returns only approved trips.
  Future<List<Map<String, dynamic>>> listTrips({bool mine = false}) async {
    final response = await _dio.get('/trips', queryParameters: {
      if (mine) 'mine': true,
    });
    final list = response.data as List;
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  /// Search trips with optional filters (for booking search).
  Future<List<Map<String, dynamic>>> searchTrips({
    String? origin,
    String? dest,
    DateTime? dateFrom,
    DateTime? dateTo,
    double? minCapacity,
  }) async {
    final params = <String, dynamic>{};
    if (origin != null) params['origin'] = origin;
    if (dest != null) params['dest'] = dest;
    if (dateFrom != null) params['date_from'] = dateFrom.toIso8601String();
    if (dateTo != null) params['date_to'] = dateTo.toIso8601String();
    if (minCapacity != null) params['min_capacity'] = minCapacity;
    final response = await _dio.get('/trips', queryParameters: params);
    final list = response.data as List;
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  /// Fetch a single trip by ID.
  Future<Map<String, dynamic>> getTrip(int tripId) async {
    final response = await _dio.get('/trips/$tripId');
    return (response.data as Map).cast<String, dynamic>();
  }

  /// Get real-time flight status for a trip.
  Future<Map<String, dynamic>> getFlightStatus(int tripId) async {
    final response = await _dio.get('/trips/$tripId/flight-status');
    return (response.data as Map).cast<String, dynamic>();
  }
}
