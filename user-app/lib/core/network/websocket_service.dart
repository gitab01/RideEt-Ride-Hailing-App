import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../config/app_config.dart';

typedef MessageCallback = void Function(Map<String, dynamic> message);

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  StompClient? _client;
  final _storage = const FlutterSecureStorage();
  final Map<String, StompUnsubscribe> _subscriptions = {};

  Future<void> connect({
    required String userId,
    required MessageCallback onRideUpdate,
  }) async {
    final token = await _storage.read(key: 'access_token');

    _client = StompClient(
      config: StompConfig.sockJS(
        url: AppConfig.wsUrl,
        onConnect: (frame) => _onConnect(frame, userId, onRideUpdate),
        onDisconnect: (_) => print('WebSocket disconnected'),
        onWebSocketError: (error) => print('WebSocket error: $error'),
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
        reconnectDelay: const Duration(seconds: 5),
      ),
    );

    _client!.activate();
  }

  void _onConnect(StompFrame frame, String userId, MessageCallback onRideUpdate) {
    // Subscribe to personal ride updates
    final sub = _client!.subscribe(
      destination: '/user/$userId/queue/ride-updates',
      callback: (frame) {
        if (frame.body != null) {
          // Parse and forward the message
          onRideUpdate({'raw': frame.body});
        }
      },
    );
    _subscriptions['ride-updates'] = sub;
  }

  void subscribeToDriverLocation(String driverId, MessageCallback onLocation) {
    final sub = _client!.subscribe(
      destination: '/topic/driver-location/$driverId',
      callback: (frame) {
        if (frame.body != null) {
          onLocation({'raw': frame.body});
        }
      },
    );
    _subscriptions['driver-location'] = sub;
  }

  void unsubscribeFromDriverLocation() {
    _subscriptions['driver-location']?.call();
    _subscriptions.remove('driver-location');
  }

  void disconnect() {
    _client?.deactivate();
    _subscriptions.clear();
  }

  bool get isConnected => _client?.connected ?? false;
}
