class AppConfig {
  // 10.0.2.2 is the host machine's loopback as seen from the Android emulator.
  static const String baseUrl = 'http://10.0.2.2:8080/api/v1';

  // Raw WebSocket, not SockJS: dart:io can put the Authorization header on the
  // handshake, which is how the backend authenticates the STOMP session.
  static const String wsUrl = 'ws://10.0.2.2:8080/api/v1/ws';
  static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
  static const String stripePublishableKey = 'pk_test_your_stripe_publishable_key';

  // Connection timeouts
  static const int connectTimeout = 30; // seconds
  static const int receiveTimeout = 30;
}
