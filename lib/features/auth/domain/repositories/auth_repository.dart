import '../entities/official_session.dart';

abstract interface class AuthRepository {
  Future<OfficialSession?> restoreSession();

  /// A renewed copy of an expired signed-in [session], or null when the
  /// provider no longer accepts it and the user must sign in again.
  Future<OfficialSession?> refreshSession(OfficialSession session);

  Future<OfficialSession> signIn({
    Future<String> Function(Uri authorizationUri)? authenticate,
    Future<Map<String, String>> Function()? webSessionProvider,
  });

  /// The team ID last used to sign in or continue, kept after logout.
  Future<int?> lastEntryId();

  /// Opens a read-only session for [entryId] without signing in.
  Future<OfficialSession> continueWithEntryId(int entryId);

  Future<void> logout();
}
