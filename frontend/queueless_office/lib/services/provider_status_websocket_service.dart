import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class ProviderStatusWebSocketService {
  WebSocket? _socket;
  Timer? _reconnectTimer;
  bool _disposed = false;
  final Function(Map<String, dynamic> data) onStatusChange;

  ProviderStatusWebSocketService({required this.onStatusChange});

  void connect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();

    final host = kIsWeb ? 'localhost:8083' : '10.0.2.2:8083';
    final url = 'ws://$host/ws/provider-status';

    WebSocket.connect(url).then((ws) {
      if (_disposed) {
        ws.close();
        return;
      }
      _socket = ws;
      debugPrint('[WS-Office] Connected to provider status WebSocket');

      ws.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            onStatusChange(json);
          } catch (e) {
            debugPrint('[WS-Office] Error parsing message: $e');
          }
        },
        onError: (err) {
          debugPrint('[WS-Office] WebSocket error: $err');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('[WS-Office] WebSocket closed');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    }).catchError((e) {
      debugPrint('[WS-Office] Connection error: $e');
      _scheduleReconnect();
    });
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!_disposed) {
        connect();
      }
    });
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    try {
      _socket?.close();
    } catch (_) {}
    _socket = null;
  }
}
