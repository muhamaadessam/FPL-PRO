import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/official_session.dart';
import '../../domain/repositories/auth_repository.dart';

sealed class AuthState {
  const AuthState();

  OfficialSession? get session => null;
  bool get isLoading => false;
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

final class AuthLoading extends AuthState {
  const AuthLoading();

  @override
  bool get isLoading => true;
}

final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.session);

  @override
  final OfficialSession session;
}

final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

final class AuthFailure extends AuthState {
  const AuthFailure(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository, {AuthState initialState = const AuthInitial()})
    : super(initialState);

  final AuthRepository _repository;
  Future<OfficialSession?>? _refreshing;

  Future<void> restoreSession() async {
    emit(const AuthLoading());
    try {
      final session = await _repository.restoreSession();
      emit(
        session == null
            ? const AuthUnauthenticated()
            : AuthAuthenticated(session),
      );
    } on Object catch (error, stackTrace) {
      emit(AuthFailure(error, stackTrace));
    }
  }

  /// The session with a token that still works. Access tokens last about an
  /// hour, so a signed-in app left open has to renew them between requests.
  Future<OfficialSession?> freshSession() async {
    final session = state.session;
    if (session == null || session.isGuest || !session.isExpired) {
      return session;
    }
    // Refresh tokens may be single-use, so concurrent loads share one renewal.
    return _refreshing ??= _refresh(session).whenComplete(() {
      _refreshing = null;
    });
  }

  Future<OfficialSession?> _refresh(OfficialSession session) async {
    // A session with no known expiry cannot be judged; let the API decide.
    if (session.refreshToken == null && session.expiresAt == null) {
      return session;
    }
    try {
      final renewed = await _repository.refreshSession(session);
      // Signed out or switched team meanwhile.
      if (isClosed || !identical(state.session, session)) return state.session;
      emit(
        renewed == null
            ? const AuthUnauthenticated()
            : AuthAuthenticated(renewed),
      );
      return renewed;
    } on Object {
      return session;
    }
  }

  Future<void> signIn({
    Future<String> Function(Uri authorizationUri)? authenticate,
    Future<Map<String, String>> Function()? webSessionProvider,
  }) async {
    emit(const AuthLoading());
    try {
      emit(
        AuthAuthenticated(
          await _repository.signIn(
            authenticate: authenticate,
            webSessionProvider: webSessionProvider,
          ),
        ),
      );
    } on Object catch (error, stackTrace) {
      emit(AuthFailure(error, stackTrace));
    }
  }

  Future<int?> lastEntryId() => _repository.lastEntryId();

  Future<void> continueWithEntryId(int entryId) async {
    emit(const AuthLoading());
    try {
      emit(AuthAuthenticated(await _repository.continueWithEntryId(entryId)));
    } on Object catch (error, stackTrace) {
      emit(AuthFailure(error, stackTrace));
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    emit(const AuthUnauthenticated());
  }
}
