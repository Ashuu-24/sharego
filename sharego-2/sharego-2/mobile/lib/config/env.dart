import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  final String apiBaseUrlDev;
  final String apiBaseUrlStage;
  final String apiBaseUrlProd;
  final String appEnv;

  /// Picks stage/prod URLs when `APP_ENV` is set accordingly; defaults to dev.
  String get apiBaseUrl {
    switch (appEnv) {
      case 'prod':
      case 'production':
        return apiBaseUrlProd;
      case 'stage':
      case 'staging':
        return apiBaseUrlStage;
      default:
        return apiBaseUrlDev;
    }
  }

  final bool enableLogging;
  final bool enableOfflineQueue;
  final bool enableAiChat;
  final String defaultCurrency;
  final String defaultTimezone;

  EnvConfig._({
    required this.apiBaseUrlDev,
    required this.apiBaseUrlStage,
    required this.apiBaseUrlProd,
    required this.appEnv,
    required this.enableLogging,
    required this.enableOfflineQueue,
    required this.enableAiChat,
    required this.defaultCurrency,
    required this.defaultTimezone,
  });

  factory EnvConfig.load() {
    final devUrl = dotenv.get('API_BASE_URL_DEV', fallback: 'http://localhost:8000');
    final stageUrl = dotenv.get('API_BASE_URL_STAGE', fallback: devUrl);
    final prodUrl = dotenv.get('API_BASE_URL_PROD', fallback: devUrl);
    final appEnv = dotenv.get('APP_ENV', fallback: 'dev').toLowerCase().trim();

    return EnvConfig._(
      apiBaseUrlDev: devUrl,
      apiBaseUrlStage: stageUrl,
      apiBaseUrlProd: prodUrl,
      appEnv: appEnv,
      enableLogging: dotenv.get('ENABLE_LOGGING', fallback: 'true') == 'true',
      enableOfflineQueue: dotenv.get('ENABLE_OFFLINE_QUEUE', fallback: 'true') == 'true',
      enableAiChat: dotenv.get('ENABLE_AI_CHAT', fallback: 'true') == 'true',
      defaultCurrency: dotenv.get('DEFAULT_CURRENCY', fallback: 'PKR'),
      defaultTimezone: dotenv.get('DEFAULT_TIMEZONE', fallback: 'Asia/Karachi'),
    );
  }
}
