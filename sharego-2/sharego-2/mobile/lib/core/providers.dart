import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../features/ai/ai_service.dart';
import '../features/auth/auth_service.dart';
import '../features/booking/feature_a_service.dart';
import '../features/chat/chat_realtime.dart';
import '../features/chat/chat_service.dart';
import '../features/marketplace/marketplace_service.dart';
import '../features/profile/profile_service.dart';
import '../features/trips/trip_service.dart';
import '../features/wallet/wallet_service.dart';

import 'airline_repository.dart';
import 'airport_repository.dart';
import 'location_service.dart';
import 'api_client.dart';
import 'auth_storage.dart';
import 'saved_trips_service.dart';

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  ThemeMode? initialMode;

  @override
  ThemeMode build() => initialMode ?? ThemeMode.system;

  void set(ThemeMode mode) => state = mode;
}


final envConfigProvider = Provider<EnvConfig>((ref) {
  throw UnimplementedError('envConfigProvider must be overridden in main.dart');
});

final airportRepositoryProvider = Provider<AirportRepository>((ref) {
  throw UnimplementedError('airportRepositoryProvider must be overridden in main.dart');
});

final airlineRepositoryProvider = Provider<AirlineRepository>((ref) {
  throw UnimplementedError('airlineRepositoryProvider must be overridden in main.dart');
});

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

final authStorageProvider = Provider<AuthStorage>((ref) => AuthStorage());

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(envConfigProvider);
  final storage = ref.watch(authStorageProvider);
  return buildDio(config, storage);
});

final authServiceProvider = Provider<AuthService>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthService(dio);
});

final tripServiceProvider = Provider<TripService>((ref) {
  final dio = ref.watch(dioProvider);
  return TripService(dio);
});

final featureAServiceProvider = Provider<FeatureAService>((ref) {
  final dio = ref.watch(dioProvider);
  return FeatureAService(dio);
});

final marketplaceServiceProvider = Provider<MarketplaceService>((ref) {
  final dio = ref.watch(dioProvider);
  return MarketplaceService(dio);
});

final profileServiceProvider = Provider<ProfileService>((ref) {
  final dio = ref.watch(dioProvider);
  return ProfileService(dio);
});

final aiServiceProvider = Provider<AiService>((ref) {
  final dio = ref.watch(dioProvider);
  return AiService(dio);
});

final aiChatHistoryProvider =
    NotifierProvider<AiChatHistoryNotifier, List<AiChatMsg>>(AiChatHistoryNotifier.new);

class AiChatHistoryNotifier extends Notifier<List<AiChatMsg>> {
  static const _welcome =
      "Hi! I'm your Flyro assistant. Ask me about escrow, bookings, "
      "marketplace rules, shipping policies, travel safety, or what items "
      "you can courier from different countries.";

  @override
  List<AiChatMsg> build() => [AiChatMsg(isUser: false, text: _welcome)];

  void append(AiChatMsg msg) {
    state = [...state, msg];
  }
}

final chatServiceProvider = Provider<ChatService>((ref) {
  final dio = ref.watch(dioProvider);
  return ChatService(dio);
});

final chatRealtimeProvider = Provider<ChatRealtimeClient>((ref) {
  final client = ChatRealtimeClient(
    apiBaseUrl: ref.watch(envConfigProvider).apiBaseUrl,
    getToken: () => ref.watch(authStorageProvider).loadToken(),
  );
  ref.onDispose(client.dispose);
  return client;
});

final walletServiceProvider = Provider<WalletService>((ref) {
  final dio = ref.watch(dioProvider);
  return WalletService(dio);
});

final savedTripsServiceProvider = Provider<SavedTripsService>((ref) {
  throw UnimplementedError('Override in main.dart');
});
