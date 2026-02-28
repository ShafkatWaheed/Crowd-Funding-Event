import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';

class ChatSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  String? _token;
  int _backoff = 1;
  bool _disposed = false;

  /// Track which bids are currently joined so we can re-join on reconnect.
  final Set<int> _joinedBids = {};

  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _controller.stream;
  bool get isConnected => _channel != null;

  void connect(String firebaseToken) {
    _token = firebaseToken;
    _disposed = false;
    _doConnect();
  }

  void _doConnect() {
    if (_disposed || _token == null) return;

    try {
      final base = ApiConfig.baseUrl
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://');
      final url = '$base${ApiConfig.apiPrefix}/chat/ws/chat';
      _channel = WebSocketChannel.connect(Uri.parse(url));

      // Authenticate via first message (keeps token out of URL / browser logs).
      _send({'type': 'auth', 'token': _token});

      _subscription = _channel!.stream.listen(
        (data) {
          _backoff = 1;
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            if (json['type'] == 'ping') {
              _send({'type': 'pong'});
              return;
            }
            _controller.add(json);
          } catch (e) {
            debugPrint('WS parse error: $e');
          }
        },
        onError: (e) {
          debugPrint('WS error: $e');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('WS closed');
          _scheduleReconnect();
        },
        cancelOnError: false,
      );

      // Re-join any bids that were active before a reconnect.
      for (final bidId in _joinedBids) {
        _send({'type': 'join', 'bid_id': bidId});
      }

      debugPrint('WS connected (rejoining ${_joinedBids.length} bids)');
    } catch (e) {
      debugPrint('WS connect failed: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _cleanup();
    if (_disposed) return;
    final delay = Duration(seconds: min(_backoff, 30));
    _backoff *= 2;
    debugPrint('WS reconnecting in ${delay.inSeconds}s');
    _reconnectTimer = Timer(delay, _doConnect);
  }

  void _send(Map<String, dynamic> data) {
    try {
      _channel?.sink.add(jsonEncode(data));
    } catch (e) {
      debugPrint('WS send error: $e');
    }
  }

  void join(int bidId) {
    _joinedBids.add(bidId);
    _send({'type': 'join', 'bid_id': bidId});
  }

  void leave(int bidId) {
    _joinedBids.remove(bidId);
    _send({'type': 'leave', 'bid_id': bidId});
  }

  void sendMessage(int bidId, String body, String clientId) {
    _send({
      'type': 'send',
      'bid_id': bidId,
      'body': body,
      'client_id': clientId,
    });
  }

  void ack(int bidId, String messageId) {
    _send({'type': 'ack', 'bid_id': bidId, 'message_id': messageId});
  }

  void markRead(int bidId, String messageId) {
    _send({'type': 'read', 'bid_id': bidId, 'message_id': messageId});
  }

  void sendTyping(int bidId, bool isTyping) {
    _send({'type': 'typing', 'bid_id': bidId, 'is_typing': isTyping});
  }

  void _cleanup() {
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (e) { debugPrint(e.toString()); }
    _channel = null;
  }

  void disconnect() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _joinedBids.clear();
    _cleanup();
  }

  void dispose() {
    disconnect();
    _controller.close();
  }
}
