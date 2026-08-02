/// App-wide configuration.
class AppConfig {
  AppConfig._();

  /// Local port the app's WebSocket server listens on. The Tor hidden service
  /// forwards onion:80 -> 127.0.0.1:8080 (see the tor_hidden_service plugin).
  static const int hostPort = 8080;

  /// Tor's SOCKS proxy port exposed by the tor_hidden_service plugin.
  static const int socksPort = 9050;

  /// Public port of the hidden service.
  static const int onionPort = 80;

  /// How often the room host re-registers its namecode to stay live.
  static const Duration directoryRefreshInterval = Duration(minutes: 2);

  static const Duration torStartTimeout = Duration(seconds: 320);
  static const Duration connectTimeout = Duration(seconds: 90);
}
