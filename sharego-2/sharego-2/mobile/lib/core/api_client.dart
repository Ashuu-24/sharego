import 'package:dio/dio.dart';
import 'package:dio/browser.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../config/env.dart';
import 'auth_interceptor.dart';
import 'auth_storage.dart';

Dio buildDio(EnvConfig config, AuthStorage storage) {
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      // Web (XHR) does not support Dart-level timeouts — set only on native
      connectTimeout: kIsWeb ? null : const Duration(seconds: 10),
      receiveTimeout: kIsWeb ? null : const Duration(seconds: 10),
      sendTimeout:    kIsWeb ? null : const Duration(seconds: 10),
      responseType: ResponseType.json,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  // On web, swap the default HttpClientAdapter with the browser-native one
  // so that credentials / CORS work correctly with XHR.
  if (kIsWeb) {
    dio.httpClientAdapter = BrowserHttpClientAdapter(withCredentials: false);
  }

  dio.interceptors.add(AuthInterceptor(() => storage.loadToken()));

  // Retry only on native — on web XHR retries can multiply CORS pre-flights
  // and mask the real error, making debugging harder.
  if (!kIsWeb) {
    dio.interceptors.add(
      RetryInterceptor(
        dio: dio,
        retries: 3,
        retryDelays: const [
          Duration(milliseconds: 400),
          Duration(milliseconds: 800),
          Duration(milliseconds: 1600),
        ],
        logPrint: config.enableLogging ? print : null,
      ),
    );
  }

  return dio;
}