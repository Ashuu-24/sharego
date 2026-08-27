import 'dart:typed_data';

import 'package:dio/dio.dart';

class ProfileService {
  ProfileService(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get('/users/me');
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> updateMe({
    String? name,
    String? phone,
    String? city,
    String? country,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (phone != null) data['phone'] = phone;
    if (city != null) data['city'] = city;
    if (country != null) data['country'] = country;

    final response = await _dio.patch('/users/me', data: data);
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> submitKyc({
    required String docType,
    required String docUrl,
    String? selfieUrl,
    String? passportUrl,
  }) async {
    final response = await _dio.post('/kyc/submit', data: {
      'doc_type': docType,
      'doc_url': docUrl,
      if (selfieUrl != null) 'selfie_url': selfieUrl,
      if (passportUrl != null) 'passport_url': passportUrl,
    });
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> getKycStatus() async {
    final response = await _dio.get('/kyc/status');
    return (response.data as Map).cast<String, dynamic>();
  }

  /// Upload a file to `/media/upload`. Uses bytes so it works on **web** and mobile
  /// (avoid `dart:io` / `File.path` which throws `Unsupported operation: _Namespace` on web).
  Future<Map<String, dynamic>> uploadMediaBytes(Uint8List bytes, String filename) async {
    final safeName = filename.trim().isEmpty ? 'upload.jpg' : filename.trim();
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: safeName),
      });

      final response = await _dio.post(
        '/media/upload',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      return (response.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw Exception(e.response?.data ?? e.message);
    }
  }

  Future<Map<String, dynamic>> submitReview({
    required String targetType,
    required int targetId,
    required int revieweeId,
    required int rating,
    String? comment,
  }) async {
    final response = await _dio.post('/reviews', data: {
      'target_type': targetType,
      'target_id': targetId,
      'reviewee_id': revieweeId,
      'rating': rating,
      if (comment != null) 'comment': comment,
    });
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> getReviews({int? revieweeId}) async {
    final response = await _dio.get('/reviews', queryParameters: {
      if (revieweeId != null) 'reviewee_id': revieweeId,
    });
    final list = response.data as List;
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }
}
