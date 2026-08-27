# Developer notes

- Uses `flutter_dotenv` to load `.env`.
- Dio client configured in `lib/core/api_client.dart` with retry interceptor (`dio_smart_retry`).
- Placeholder UI shows the dev API base URL for now.
- Run `flutter pub get` after updating `.env`/dependencies.
