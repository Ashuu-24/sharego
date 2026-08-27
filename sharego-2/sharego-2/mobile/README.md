# Flyro Mobile (Flutter)

Flutter app for Flyro (Feature A personal shopping + Feature B marketplace). Uses Dio for REST and Riverpod/BLoC for state.

## Quick start (dev)
- Create `.env` from `.env.example` and set dev API URL (defaults to localhost).
- Run `flutter pub get` (includes `flutter_dotenv`, `dio`, `dio_smart_retry`, `flutter_riverpod`, `shared_preferences`) then `flutter run`.

## Configuration (env)
See `.env.example` for base URLs and feature flags. Currency PKR, timezone Asia/Karachi are assumed in UI formatting.
