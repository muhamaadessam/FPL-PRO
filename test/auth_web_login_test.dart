import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'package:fantasy_pl/core/security/session_store.dart';
import 'package:fantasy_pl/features/auth/application/auth_controller.dart';
import 'package:fantasy_pl/features/auth/data/official_auth_client.dart';
import 'package:fantasy_pl/features/auth/presentation/official_web_login_page.dart';
import 'package:fantasy_pl/l10n/app_localizations.dart';

void main() {
  testWidgets('starts sign-in after the first frame', (tester) async {
    WebViewPlatform.instance = _FakeWebViewPlatform();
    final client = _FailingAuthClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [officialAuthClientProvider.overrideWithValue(client)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const OfficialWebLoginPage(),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(client.loginCalls, 1);
  });
}

class _FakeWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => _FakeWebViewController(params);

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => _FakeNavigationDelegate(params);
}

class _FakeWebViewController extends PlatformWebViewController {
  _FakeWebViewController(super.params) : super.implementation();

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}
}

class _FakeNavigationDelegate extends PlatformNavigationDelegate {
  _FakeNavigationDelegate(super.params) : super.implementation();

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async {}
}

class _FailingAuthClient extends OfficialAuthClient {
  _FailingAuthClient() : super(SessionStore());

  int loginCalls = 0;

  @override
  Future<OfficialSession?> restoreSession() async => null;

  @override
  Future<OfficialSession> startOfficialLogin({
    Future<String> Function(Uri authorizationUri)? authenticate,
  }) async {
    loginCalls++;
    throw const OfficialAuthException(OfficialAuthError.configurationRequired);
  }
}
