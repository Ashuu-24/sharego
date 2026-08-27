import 'package:dio/dio.dart';

class MarketplaceService {
  MarketplaceService(this._dio);

  final Dio _dio;

  // ── Categories ───────────────────────────────────────

  Future<List<String>> listCategories() async {
    final response = await _dio.get('/market/categories');
    final list = response.data as List;
    return list.map((e) => e.toString()).toList();
  }

  // ── Listings ──────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listListings({
    String? query,
    String? category,
    double? minPrice,
    double? maxPrice,
    String? status,
    double? latitude,
    double? longitude,
    double? radiusKm,
  }) async {
    final response = await _dio.get('/market/listings', queryParameters: {
      if (query != null && query.isNotEmpty) 'query': query,
      if (category != null && category != 'All') 'category': category,
      if (minPrice != null) 'min_price': minPrice,
      if (maxPrice != null) 'max_price': maxPrice,
      'status': status ?? 'active',
      if (latitude != null && longitude != null)
        'near': '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)},${(radiusKm ?? 50).toStringAsFixed(0)}',
    });
    final list = response.data as List;
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> getListing(int listingId) async {
    final response = await _dio.get('/market/listings/$listingId');
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> createListing({
    required String title,
    required String description,
    required double askPrice,
    List<String> photosPaths = const [],
    String? category,
    String? condition,
    String? locationText,
    double? latitude,
    double? longitude,
    String currency = 'PKR',
    String? contactPref,
  }) async {
    final response = await _dio.post('/market/listings', data: {
      'title': title,
      'description': description,
      'ask_price': askPrice,
      'photos_paths': photosPaths,
      if (category != null) 'category': category,
      if (condition != null) 'condition': condition,
      if (locationText != null) 'location_text': locationText,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'currency': currency,
      if (contactPref != null) 'contact_pref': contactPref,
    });
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> listMyListings() async {
    final response = await _dio.get('/market/listings/mine');
    final list = response.data as List;
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> updateListing(
    int listingId, {
    String? title,
    String? description,
    double? askPrice,
    List<String>? photosPaths,
    String? category,
    String? condition,
    String? locationText,
    double? latitude,
    double? longitude,
    String? currency,
    String? contactPref,
    String? status,
  }) async {
    final response = await _dio.patch('/market/listings/$listingId', data: {
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (askPrice != null) 'ask_price': askPrice,
      if (photosPaths != null) 'photos_paths': photosPaths,
      if (category != null) 'category': category,
      if (condition != null) 'condition': condition,
      if (locationText != null) 'location_text': locationText,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (currency != null) 'currency': currency,
      if (contactPref != null) 'contact_pref': contactPref,
      if (status != null) 'status': status,
    });
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> removeListing(int listingId) async {
    return updateListing(listingId, status: 'removed');
  }

  Future<Map<String, dynamic>> markSold(int listingId, {int? offerId, String? note}) async {
    final response = await _dio.post('/market/listings/$listingId/mark_sold', data: {
      if (offerId != null) 'offer_id': offerId,
      if (note != null) 'note': note,
    });
    return (response.data as Map).cast<String, dynamic>();
  }

  // ── Offers ────────────────────────────────────────────

  Future<Map<String, dynamic>> sendOffer({
    required int listingId,
    required double amount,
    String? message,
    String currency = 'PKR',
  }) async {
    final response = await _dio.post('/market/listings/$listingId/offer', data: {
      'amount': amount,
      'currency': currency,
      if (message != null) 'message': message,
    });
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> listOffers(int listingId) async {
    final response = await _dio.get('/market/listings/$listingId/offers');
    final list = response.data as List;
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> counterOffer(int offerId, {double? amount, String? message}) async {
    final response = await _dio.post('/market/offers/$offerId/counter', data: {
      if (amount != null) 'amount': amount,
      if (message != null) 'message': message,
    });
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> acceptOffer(int offerId) async {
    final response = await _dio.post('/market/offers/$offerId/accept');
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> declineOffer(int offerId) async {
    final response = await _dio.post('/market/offers/$offerId/decline');
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> withdrawOffer(int offerId) async {
    final response = await _dio.post('/market/offers/$offerId/withdraw');
    return (response.data as Map).cast<String, dynamic>();
  }

  // ── Meetups ───────────────────────────────────────────

  Future<Map<String, dynamic>> createMeetup({
    required int listingId,
    required String placeText,
    required DateTime scheduledTs,
  }) async {
    final response = await _dio.post('/market/meetups', data: {
      'listing_id': listingId,
      'place_text': placeText,
      'scheduled_ts': scheduledTs.toIso8601String(),
    });
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> confirmMeetup(int meetupId, String otp) async {
    final response = await _dio.post('/market/meetups/$meetupId/confirm', data: {
      'otp': otp,
    });
    return (response.data as Map).cast<String, dynamic>();
  }
}
