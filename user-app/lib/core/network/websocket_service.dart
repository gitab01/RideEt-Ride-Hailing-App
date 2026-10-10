import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../config/app_config.dart';

/// One server push: either a ride lifecycle event on the private queue or a
/// driver position on that driver's public topic.
class RideUpdate {
  final String eventType;
  final int? rideId;
  final Map<String, dynamic> data;

  const RideUpdate({required this.eventType, this.rideId, required this.data});

  /// Lifecycle frames arrive as `{eventType, rideId, data}`. Location frames are a
  /// flat payload, so the whole body is the data and the frame type is implied.
  factory RideUpdate.fromFrame(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      return RideUpdate(eventType: 'UNKNOWN', data: {'raw': decoded});
    }
    if (decoded['eventType'] == null) {
      return RideUpdate(eventType: 'LOCATION', rideId: (decoded['rideId'] as num?)?.toInt(), data: decoded);
    }
    return RideUpdate(
      eventType: decoded['eventType'] as String,
      rideId: (decoded['rideId'] as num?)?.toInt(),
      data: (decoded['data'] as Map<String, dynamic>?) ?? const {},
    );
  }

  double? get latitude => (data['latitude'] as num?)?.toDouble();
  double? get longitude => (data['longitude'] as num?)?.toDouble();
}

/// App-wide STOMP session. The backend addresses pushes by authenticated user, so one
/// connection per login is enough for every screen.
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  StompClient? _client;
  final _storage = const FlutterSecureStorage();
  final _updates = StreamController<RideUpdate>.broadcast();
  StompUnsubscribe? _locationSubscription;
  String? _subscribedDriver;

  Stream<RideUpdate> get updates => _updates.stream;
  bool get isConnected => _client?.connected ?? false;

  Future<void> connect() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) return;
    if (_client != null) return;

    _client = StompClient(
      config: StompConfig(
        url: AppConfig.wsUrl,
        onConnect: (_) => _subscribeRideUpdates(),
        onWebSocketError: (error) => _log('WebSocket error: $error'),
        // The backend authenticates the CONNECT frame; dart:io can put this header on
        // the handshake, SockJS polling cannot.
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
        reconnectDelay: const Duration(seconds: 5),
      ),
    );

    _client!.activate();
  }

  void _subscribeRideUpdates() {
    // Spring maps /user/queue/... to the queue of the authenticated principal.
    _client!.subscribe(
      destination: '/user/queue/ride-updates',
      callback: (frame) {
        final body = frame.body;
        if (body != null) _emit(body);
      },
    );
  }

  void subscribeToDriverLocation(String driverUserId) {
    if (_subscribedDriver == driverUserId) return;
    unsubscribeFromDriverLocation();
    _subscribedDriver = driverUserId;
    _locationSubscription = _client?.subscribe(
      destination: '/topic/driver-location/$driverUserId',
      callback: (frame) {
        final body = frame.body;
        if (body != null) _emit(body);
      },
    );
  }

  void unsubscribeFromDriverLocation() {
    _locationSubscription?.call();
    _locationSubscription = null;
    _subscribedDriver = null;
  }

  void _emit(String body) {
    try {
      _updates.add(RideUpdate.fromFrame(body));
    } on FormatException {
      _log('Ignored non-JSON frame');
    }
  }

  void disconnect() {
    unsubscribeFromDriverLocation();
    _client?.deactivate();
    _client = null;
  }

  void _log(String message) {
    // ignore: avoid_print
    print('[ws] $message');
  }
}
