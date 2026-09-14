import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/session_store.dart';
import '../data/official_auth_client.dart';

final sessionStoreProvider = Provider<SessionStore>((ref) {
  return SessionStore();
});

final officialAuthClientProvider = Provider<OfficialAuthClient>((ref) {
  return OfficialAuthClient(ref.read(sessionStoreProvider));
});

final authControllerProvider =
    AsyncNotifierProvider<AuthController, OfficialSession?>(AuthController.new);

class AuthController extends AsyncNotifier<OfficialSession?> {
  @override
  Future<OfficialSession?> build() {
    return ref.read(officialAuthClientProvider).restoreSession();
  }

  Future<void> signIn({
    Future<String> Function(Uri authorizationUri)? authenticate,
  }) async {
    state = const AsyncLoading();
    try {
      final session = await ref
          .read(officialAuthClientProvider)
          .startOfficialLogin(authenticate: authenticate);
      state = AsyncData(session);
    } on Object catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> logout() async {
    await ref.read(officialAuthClientProvider).logout();
    state = const AsyncData(null);
  }
}
