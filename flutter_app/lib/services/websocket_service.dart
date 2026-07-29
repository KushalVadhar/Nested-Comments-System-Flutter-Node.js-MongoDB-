import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/api_constants.dart';

enum WsConnectionStatus { connected, connecting, disconnected, reconnecting }

class WsEvent {
  final String type;
  final dynamic data;
  final String timestamp;

  WsEvent({required this.type, required this.data, required this.timestamp});

  factory WsEvent.fromJson(Map<String, dynamic> json) {
    return WsEvent(
      type: json['type'] ?? '',
      data: json['data'],
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
    );
  }
}

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;

  final _eventController = StreamController<WsEvent>.broadcast();
  final _statusController = StreamController<WsConnectionStatus>.broadcast();

  WsConnectionStatus _status = WsConnectionStatus.disconnected;
  WsConnectionStatus get status => _status;

  Stream<WsEvent> get eventStream => _eventController.stream;
  Stream<WsConnectionStatus> get statusStream => _statusController.stream;

  bool _isDisposed = false;
  int _reconnectAttempts = 0;

  String get _wsUrl {
    try {
      if (Platform.isAndroid) {
        return ApiConstants.wsUrl;
      }
    } catch (e) {
      // Desktop or Web
    }
    return ApiConstants.wsUrlLocal;
  }

  void connect() {
    if (_isDisposed) return;
    if (_status == WsConnectionStatus.connected ||
        _status == WsConnectionStatus.connecting) return;

    _updateStatus(WsConnectionStatus.connecting);

    try {
      final uri = Uri.parse(_wsUrl);
      _channel = WebSocketChannel.connect(uri);

      // Handle uncaught errors on _channel.ready (web_socket_channel 3.x) to avoid unhandled Future rejection logs
      _channel!.ready.catchError((error) {
        // Handled via stream listener onError
      });

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      _reconnectAttempts = 0;
      _startHeartbeat();
    } catch (e) {
      _handleDisconnect();
    }
  }

  void _onMessage(dynamic message) {
    try {
      final json = jsonDecode(message.toString());
      final event = WsEvent.fromJson(json);

      if (event.type == 'CONNECTED') {
        _updateStatus(WsConnectionStatus.connected);
      } else {
        _eventController.add(event);
      }
    } catch (e) {
      // Ignore unparseable frames
    }
  }

  void _onError(error) {
    _handleDisconnect();
  }

  void _onDone() {
    _handleDisconnect();
  }

  void _handleDisconnect() {
    _stopHeartbeat();
    _subscription?.cancel();
    _subscription = null;
    _channel = null;

    if (_isDisposed) return;

    _updateStatus(WsConnectionStatus.reconnecting);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();

    // Exponential backoff capped at 10 seconds
    final delaySeconds =
        (_reconnectAttempts < 5) ? (1 << _reconnectAttempts) : 10;
    _reconnectAttempts++;

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_isDisposed && _status != WsConnectionStatus.connected) {
        connect();
      }
    });
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_status == WsConnectionStatus.connected && _channel != null) {
        _channel!.sink.add(jsonEncode({'type': 'PING'}));
      }
    });
  }

  void _stopHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  void _updateStatus(WsConnectionStatus newStatus) {
    _status = newStatus;
    _statusController.add(_status);
  }

  void disconnect() {
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _updateStatus(WsConnectionStatus.disconnected);
  }

  void dispose() {
    _isDisposed = true;
    disconnect();
    _eventController.close();
    _statusController.close();
  }
}
