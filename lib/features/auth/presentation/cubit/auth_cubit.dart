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

  Future<void> logout() async {
    await _repository.logout();
    emit(const AuthUnauthenticated());
  }
}
