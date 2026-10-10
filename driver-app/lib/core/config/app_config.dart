class AppConfig {
  static const String baseUrl = 'http://10.0.2.2:8080/api/v1';

  // The STOMP broker sits on the raw WebSocket endpoint, not the SockJS one, so
  // the scheme has to be ws:// for the Dart client to connect at all.
  static const String wsUrl = 'ws://10.0.2.2:8080/api/v1/ws';

  static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
  static const int connectTimeout = 30;
  static const int receiveTimeout = 30;
}
