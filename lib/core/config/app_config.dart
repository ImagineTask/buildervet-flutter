class AppConfig {
  AppConfig._();

  /// Set to false when real backend is ready
  static const bool useMockData = true;

  /// API base URL (used when useMockData is false)
  static const String apiBaseUrl = 'https://api.renovation-app.com/v1';

  /// App info
  static const String appName = 'BuilderVet';
  static const String appVersion = '0.1.0';
}
