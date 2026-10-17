import '../entities/official_session.dart';

abstract interface class AuthRepository {
  Future<OfficialSession?> restoreSession();

  Future<OfficialSession> signIn({
    Future<String> Function(Uri authorizationUri)? authenticate,
    Future<Map<String, String>> Function()? webSessionProvider,
  });

  /// Opens a read-only session for [entryId] without signing in.
  Future<OfficialSession> continueWithEntryId(int entryId);

  Future<void> logout();
}
