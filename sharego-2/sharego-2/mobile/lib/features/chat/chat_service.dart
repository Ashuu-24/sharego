import 'package:dio/dio.dart';

class ChatService {
  ChatService(this._dio);

  final Dio _dio;

  /// Fetch all conversation threads for the current user.
  Future<List<Map<String, dynamic>>> listThreads() async {
    final response = await _dio.get('/messages/threads');
    final list = response.data as List;
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  /// Fetch messages with a specific peer.
  Future<List<Map<String, dynamic>>> listMessages(int peerId) async {
    final response = await _dio.get('/messages', queryParameters: {'peer_id': peerId});
    final list = response.data as List;
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  /// Send a message to a peer.
  Future<Map<String, dynamic>> sendMessage({
    required int receiverId,
    required String content,
    int? bookingId,
    int? listingId,
  }) async {
    final response = await _dio.post('/messages', data: {
      'receiver_id': receiverId,
      'content': content,
      if (bookingId != null) 'booking_id': bookingId,
      if (listingId != null) 'listing_id': listingId,
    });
    return (response.data as Map).cast<String, dynamic>();
  }
}
