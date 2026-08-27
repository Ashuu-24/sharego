import 'package:dio/dio.dart';

class AiChatMsg {
  AiChatMsg({required this.isUser, required this.text, this.source, this.data});

  final bool isUser;
  final String text;
  final String? source;
  final Map<String, dynamic>? data;
}

class AiService {
  AiService(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> chat(
    String message, {
    List<Map<String, String>>? history,
  }) async {
    final response = await _dio.post('/ai/chat', data: {
      'message': message,
      if (history != null && history.isNotEmpty) 'history': history,
    });
    return response.data as Map<String, dynamic>;
  }
}
