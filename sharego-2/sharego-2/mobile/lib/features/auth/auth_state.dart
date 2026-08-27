import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:state_notifier/state_notifier.dart';
import '../../config/env.dart';
import '../../core/auth_storage.dart';

final envProvider = Provider<EnvConfig>((ref) => throw UnimplementedError());
final authStorageProvider = Provider<AuthStorage>((ref) => AuthStorage());

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._storage) : super(AuthState.initial());

  final AuthStorage _storage;

  Future<void> setToken(String token) async {
    await _storage.saveToken(token);
    state = state.copyWith(token: token, status: AuthStatus.authenticated, error: null);
  }

  Future<void> loadToken() async {
    final existing = await _storage.loadToken();
    if (existing != null && existing.isNotEmpty) {
      state = state.copyWith(token: existing, status: AuthStatus.authenticated);
    }
  }

  Future<void> signOut() async {
    await _storage.clear();
    state = AuthState.initial();
  }
}

enum AuthStatus { idle, requestingOtp, awaitingOtp, authenticated, error }

class AuthState {
  final AuthStatus status;
  final String email;
  final String token;
  final String? error;

  const AuthState({
    required this.status,
    required this.email,
    required this.token,
    required this.error,
  });

  factory AuthState.initial() => const AuthState(
        status: AuthStatus.idle,
        email: '',
        token: '',
        error: null,
      );

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    String? token,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      email: email ?? this.email,
      token: token ?? this.token,
      error: error,
    );
  }
}
