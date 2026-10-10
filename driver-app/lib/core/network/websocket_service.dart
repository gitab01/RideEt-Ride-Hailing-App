import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../config/app_config.dart';

/// One server push on the driver's private queue: a new offer, a withdrawn offer,
/// or the passenger cancelling a ride already accepted.
class DriverPush {
  final String eventType;
  final int? rideId;
  final Map<String, dynamic> data;

  const DriverPush({required this.eventType, this.rideId, required this.data});

  factory DriverPush.fromFrame(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      return DriverPush(eventType: 'UNKNOWN', data: {'raw': decoded});
    }
    return DriverPush(
      eventType: decoded['eventType'] as String? ?? 'UNKNOWN',
      rideId: (decoded['rideId'] as num?)?.toInt(),
      data: (decoded['data'] as Map<String, dynamic>?) ?? const {},
    );
  }
}

/// App-wide STOMP session for the driver.
///
/// Offers arrive on `/user/queue/ride-requests`, addressed to the authenticated user, and
/// positions leave on `/app/location.update`, which the backend attributes to the socket
/// principal — so a driver never has to name themselves in a request body.
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  StompClient? _client;
  final _storage = const FlutterSecureStorage();
  final _pushes = StreamController<DriverPush>.broadcast();

  Stream<DriverPush> get pushes => _pushes.stream;
  bool get isConnected => _client?.connected ?? false;

  Future<void> connect() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) return;
    if (_client != null) return;

    _client = StompClient(
      config: StompConfig(
        url: AppConfig.wsUrl,
        onConnect: (_) => _subscribeOffers(),
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

  void _subscribeOffers() {
    _client!.subscribe(
      destination: '/user/queue/ride-requests',
      callback: (frame) {
        final body = frame.body;
        if (body != null) _emit(body);
      },
    );
  }

  /// Fire-and-forget: a dropped ping only costs one map refresh, not a failed trip.
  void sendLocation({
    required double latitude,
    required double longitude,
    double? heading,
    double? speedKmh,
  }) {
    if (!isConnected) return;
    _client?.send(
      destination: '/app/location.update',
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        if (heading != null) 'heading': heading,
        if (speedKmh != null) 'speed': speedKmh,
      }),
    );
  }

  void _emit(String body) {
    try {
      _pushes.add(DriverPush.fromFrame(body));
    } on FormatException {
      _log('Ignored non-JSON frame');
    }
  }

  void disconnect() {
    _client?.deactivate();
    _client = null;
  }

  void _log(String message) {
    // ignore: avoid_print
    print('[ws] $message');
  }
}
