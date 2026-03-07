class AppConfig {
  AppConfig._();

  /// Set to false when real backend is ready
  static const bool useMockData = true;

  /// API base URL
  static const String apiBaseUrl =
      'https://imaginetask-engine-v1-268920641222.europe-west2.run.app/api/v1';

  /// App info
  static const String appName = 'BuilderVet';
  static const String appVersion = '0.1.0';
}
