import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'config/env.dart';
import 'core/airline_repository.dart';
import 'core/airport_repository.dart';
import 'core/providers.dart';
import 'core/saved_trips_service.dart';

ThemeMode _parseThemeMode(String? value) {
  switch (value) {
    case 'Light':
      return ThemeMode.light;
    case 'Dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await FlutterDisplayMode.setHighRefreshRate();
  } catch (_) {}
  await dotenv.load(fileName: '.env');
  final config = EnvConfig.load();

  final airportRepo = AirportRepository();
  await airportRepo.load();

  final airlineRepo = AirlineRepository();
  await airlineRepo.load();

  final prefs = await SharedPreferences.getInstance();
  final savedTheme = _parseThemeMode(prefs.getString('settings_theme'));

  runApp(
    ProviderScope(
      overrides: [
        envConfigProvider.overrideWithValue(config),
        airportRepositoryProvider.overrideWithValue(airportRepo),
        airlineRepositoryProvider.overrideWithValue(airlineRepo),
        themeModeProvider.overrideWith(() => ThemeModeNotifier()..initialMode = savedTheme),
        savedTripsServiceProvider.overrideWithValue(SavedTripsService(prefs)),
      ],
      child: const FlyroApp(),
    ),
  );
}
