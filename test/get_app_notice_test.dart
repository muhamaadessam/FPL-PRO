import 'package:fantasy_pl/core/widgets/get_app_notice.dart';
import 'package:fantasy_pl/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Locale locale) => MaterialApp(
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: const Scaffold(body: GetAppNotice()),
);

void main() {
  test('links to the Play Store listing', () {
    expect(playStoreUri.host, 'play.google.com');
    expect(playStoreUri.queryParameters['id'], 'me.muhammadessam.FPLpro');
  });

  testWidgets('explains team management lives in the app', (tester) async {
    await tester.pumpWidget(_app(const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.textContaining('get the FPL Pro app'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Get the app'), findsOneWidget);
  });

  testWidgets('shows the Arabic message', (tester) async {
    await tester.pumpWidget(_app(const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.textContaining('لإدارة فريقك'), findsOneWidget);
    expect(find.text('حمّل التطبيق'), findsOneWidget);
  });
}
