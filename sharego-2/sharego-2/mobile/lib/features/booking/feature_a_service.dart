import 'package:dio/dio.dart';

Map<String, dynamic> parseMatchingSuggestResponse(dynamic data) {
  if (data is Map<String, dynamic>) {
    return data;
  }
  if (data is Map) {
    return data.cast<String, dynamic>();
  }
  throw const FormatException('Unexpected /matching/suggest response format');
}

class FeatureAService {
  FeatureAService(this._dio);

  final Dio _dio;

  // ── Requests ──────────────────────────────────────────

  Future<Map<String, dynamic>> createRequest({
    required String productName,
    required String? specsJson,
    required double targetPrice,
    required String destCity,
    required double weightKg,
    required DateTime windowStart,
    required DateTime windowEnd,
    String? declarationPath,
  }) async {
    final response = await _dio.post(
      '/requests',
      data: {
        'product_name': productName,
        if (specsJson != null && specsJson.isNotEmpty) 'specs_json': specsJson,
        'target_price': targetPrice,
        'dest_city': destCity,
        'weight_kg': weightKg,
        'window_start': windowStart.toIso8601String(),
        'window_end': windowEnd.toIso8601String(),
        if (declarationPath != null && declarationPath.isNotEmpty)
          'declaration_path': declarationPath,
      },
    );
    return (response.data as Map).cast<String, dynamic>();
  }

  // ── Bookings ──────────────────────────────────────────

  Future<Map<String, dynamic>> createBooking({
    required int tripId,
    required int requestId,
    required double amount,
    required String currency,
  }) async {
    final response = await _dio.post(
      '/bookings',
      data: {
        'trip_id': tripId,
        'request_id': requestId,
        'amount': amount,
        'currency': currency,
      },
    );
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> listBookings() async {
    final response = await _dio.get('/bookings');
    final list = response.data as List;
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> getBooking(int bookingId) async {
    final response = await _dio.get('/bookings/$bookingId');
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> listBookingsForTrip(int tripId) async {
    final response = await _dio.get('/bookings', queryParameters: {
      'trip_id': tripId,
    });
    final list = response.data as List;
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> acceptBooking(int bookingId) async {
    final response = await _dio.post('/bookings/$bookingId/accept');
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> declineBooking(int bookingId) async {
    final response = await _dio.post('/bookings/$bookingId/decline');
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> cancelBooking(int bookingId) async {
    final response = await _dio.post('/bookings/$bookingId/cancel');
    return (response.data as Map).cast<String, dynamic>();
  }

  // ── Booking updates (traveler status) ────────────────

  Future<List<Map<String, dynamic>>> listBookingUpdates(int bookingId) async {
    final response = await _dio.get('/bookings/$bookingId/updates');
    final list = response.data as List;
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> postBookingUpdate(
    int bookingId, {
    required String updateType,
    String? note,
  }) async {
    final response = await _dio.post('/bookings/$bookingId/updates', data: {
      'update_type': updateType,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return (response.data as Map).cast<String, dynamic>();
  }

  // ── Handover verification ─────────────────────────────

  Future<Map<String, dynamic>> verifyPickup({
    required int bookingId,
    required String otp,
    required double gpsLat,
    required double gpsLng,
    required List<String> photoPaths,
    String? sealId,
  }) async {
    final response = await _dio.post(
      '/bookings/$bookingId/pickup/verify',
      data: {
        'otp': otp,
        'gps_lat': gpsLat,
        'gps_lng': gpsLng,
        'photo_paths': photoPaths,
        if (sealId != null) 'seal_id': sealId,
      },
    );
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> verifyDelivery({
    required int bookingId,
    required String otp,
    required double gpsLat,
    required double gpsLng,
    required List<String> photoPaths,
    String? sealId,
  }) async {
    final response = await _dio.post(
      '/bookings/$bookingId/delivery/verify',
      data: {
        'otp': otp,
        'gps_lat': gpsLat,
        'gps_lng': gpsLng,
        'photo_paths': photoPaths,
        if (sealId != null) 'seal_id': sealId,
      },
    );
    return (response.data as Map).cast<String, dynamic>();
  }

  // ── Matching ──────────────────────────────────────────

  Future<Map<String, dynamic>> suggestMatches({
    int? tripId,
    int? requestId,
  }) async {
    final response = await _dio.get('/matching/suggest', queryParameters: {
      if (tripId != null) 'tripId': tripId,
      if (requestId != null) 'requestId': requestId,
    });
    return parseMatchingSuggestResponse(response.data);
  }
}
