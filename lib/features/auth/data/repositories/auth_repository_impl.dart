import '../../domain/entities/official_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/official_auth_client.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._client);

  final OfficialAuthClient _client;

  @override
  Future<OfficialSession?> restoreSession() => _client.restoreSession();

  @override
  Future<OfficialSession> signIn({
    Future<String> Function(Uri authorizationUri)? authenticate,
    Future<Map<String, String>> Function()? webSessionProvider,
  }) {
    return _client.startOfficialLogin(
      authenticate: authenticate,
      webSessionProvider: webSessionProvider,
    );
  }

  @override
  Future<void> logout() => _client.logout();
}
