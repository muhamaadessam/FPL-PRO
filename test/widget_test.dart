import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fantasy_pl/app/app.dart';
import 'package:fantasy_pl/core/security/session_store.dart';
import 'package:fantasy_pl/features/auth/application/auth_controller.dart';
import 'package:fantasy_pl/features/auth/data/official_auth_client.dart';

void main() {
  testWidgets('team lookup page exposes public team access', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          officialAuthClientProvider.overrideWithValue(_FakeAuthClient()),
        ],
        child: const FantasyPlApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Open your team'), findsOneWidget);
    expect(find.text('Sign in officially'), findsOneWidget);
    expect(find.text('Open my team'), findsOneWidget);
    expect(find.text('Browse public matches'), findsOneWidget);
  });
}

class _FakeAuthClient extends OfficialAuthClient {
  _FakeAuthClient() : super(SessionStore());

  @override
  Future<OfficialSession?> restoreSession() async => null;
}
