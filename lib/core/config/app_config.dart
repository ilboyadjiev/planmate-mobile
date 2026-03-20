class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: "https://planmate.org",
  );

  static const String apiBaseUrl = "$baseUrl/api";

  static const Duration connectionTimeout = Duration(seconds: 15);
}