import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ChatRealtimeClient {
  ChatRealtimeClient({
    required this.apiBaseUrl,
    required this.getToken,
  });

  final String apiBaseUrl;
  final Future<String?> Function() getToken;

  final ValueNotifier<bool> connected = ValueNotifier(false);
  final _messages = StreamController<Map<String, dynamic>>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _ping;
  Timer? _reconnect;
  String? _token;
  int _attempts = 0;
  bool _disposed = false;

  Stream<Map<String, dynamic>> get messages => _messages.stream;

  Future<void> ensureConnected() async {
    if (_disposed) return;
    final token = await getToken();
    if (token == null || token.isEmpty) {
      await disconnect();
      return;
    }
    if (connected.value && _channel != null && _token == token) return;
    await _open(token);
  }

  Future<void> disconnect() async {
    _reconnect?.cancel();
    _reconnect = null;
    await _closeSocket();
  }

  Future<void> _open(String token) async {
    await _closeSocket();
    _token = token;
    try {
      final uri = _wsUri(apiBaseUrl, token);
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _sub = channel.stream.listen(
        _onData,
        onError: (_) => _onDropped(),
        onDone: _onDropped,
        cancelOnError: true,
      );
      _attempts = 0;
      connected.value = true;
      _ping?.cancel();
      _ping = Timer.periodic(const Duration(seconds: 25), (_) {
        _sendJson({'type': 'ping'});
      });
    } catch (_) {
      connected.value = false;
      _scheduleReconnect();
    }
  }

  void _onData(dynamic event) {
    Map<String, dynamic>? data;
    if (event is Map) {
      data = Map<String, dynamic>.from(event);
    } else if (event is String) {
      try {
        final decoded = jsonDecode(event);
        if (decoded is Map) data = Map<String, dynamic>.from(decoded);
      } catch (_) {
        return;
      }
    }
    if (data == null) return;
    final type = data['type']?.toString();
    if (type == 'pong' || type == 'ready') return;
    if (type == 'message') {
      final payload = data['payload'];
      if (payload is Map) {
        _messages.add(Map<String, dynamic>.from(payload));
      }
    }
  }

  void _onDropped() {
    connected.value = false;
    _ping?.cancel();
    _ping = null;
    _channel = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnect?.cancel();
    _attempts += 1;
    final wait = Duration(seconds: (_attempts > 5 ? 15 : _attempts * 2).clamp(2, 15));
    _reconnect = Timer(wait, () {
      ensureConnected();
    });
  }

  void _sendJson(Map<String, dynamic> body) {
    final channel = _channel;
    if (channel == null || !connected.value) return;
    try {
      channel.sink.add(jsonEncode(body));
    } catch (_) {}
  }

  Future<void> _closeSocket() async {
    _ping?.cancel();
    _ping = null;
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    connected.value = false;
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnect?.cancel();
    await _closeSocket();
    await _messages.close();
    connected.dispose();
  }

  static Uri _wsUri(String apiBaseUrl, String token) {
    final base = Uri.parse(apiBaseUrl);
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '/ws/chat',
      queryParameters: {'token': token},
    );
  }
}
