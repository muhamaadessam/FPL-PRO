import '../entities/official_session.dart';

abstract interface class AuthRepository {
  Future<OfficialSession?> restoreSession();

  Future<OfficialSession> signIn({
    Future<String> Function(Uri authorizationUri)? authenticate,
    Future<Map<String, String>> Function()? webSessionProvider,
  });

  Future<void> logout();
}
