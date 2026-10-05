import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'package:fantasy_pl/features/auth/data/datasources/session_store.dart';
import 'package:fantasy_pl/features/auth/data/datasources/official_auth_client.dart';
import 'package:fantasy_pl/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:fantasy_pl/features/auth/domain/entities/official_session.dart';
import 'package:fantasy_pl/features/auth/presentation/screens/official_web_login_page.dart';
import 'package:fantasy_pl/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:fantasy_pl/l10n/app_localizations.dart';
import 'package:fantasy_pl/core/app/router.dart';

void main() {
  test('keeps the login route while sign-in is loading', () {
    expect(authRedirect(const AuthLoading(), '/login'), isNull);
    expect(authRedirect(const AuthLoading(), '/login/web'), isNull);
    expect(authRedirect(const AuthLoading(), '/preview'), isNull);
    expect(authRedirect(const AuthLoading(), '/team/123'), isNull);
  });

  testWidgets('starts sign-in after the first frame', (tester) async {
    WebViewPlatform.instance = _FakeWebViewPlatform();
    final client = _FailingAuthClient();

    await tester.pumpWidget(
      BlocProvider(
        create: (_) => AuthCubit(AuthRepositoryImpl(client))..restoreSession(),
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
    Future<Map<String, String>> Function()? webSessionProvider,
  }) async {
    loginCalls++;
    throw const OfficialAuthException(OfficialAuthError.configurationRequired);
  }
}
