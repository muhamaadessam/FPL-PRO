import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/datasources/official_auth_client.dart';
import '../cubit/auth_cubit.dart';

class OfficialWebLoginPage extends StatefulWidget {
  const OfficialWebLoginPage({super.key});

  @override
  State<OfficialWebLoginPage> createState() => _OfficialWebLoginPageState();
}

class _OfficialWebLoginPageState extends State<OfficialWebLoginPage> {
  late final WebViewController _controller;
  Completer<String>? _callbackCompleter;
  String? _errorMessage;
  bool _ready = false;
  Map<String, String> _webSession = const {};

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (_isOAuthCallback(uri)) {
              unawaited(_completeCallback(request.url));
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_startLogin());
    });
  }

  Future<void> _startLogin() async {
    if (mounted) {
      setState(() {
        _errorMessage = null;
        _ready = false;
        _webSession = const {};
      });
    }

    await context.read<AuthCubit>().signIn(
      authenticate: _authenticate,
      webSessionProvider: _readWebSession,
    );

    if (!mounted) return;
    final auth = context.read<AuthCubit>().state;
    if (auth is AuthFailure) {
      setState(() {
        _ready = false;
        _errorMessage = _messageFor(auth.error, AppLocalizations.of(context));
      });
    }
  }

  Future<void> _completeCallback(String callbackUrl) async {
    _webSession = await _readDocumentCookies();
    final completer = _callbackCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(callbackUrl);
    }
  }

  Future<Map<String, String>> _readWebSession() async => _webSession;

  Future<Map<String, String>> _readDocumentCookies() async {
    try {
      final raw = await _controller.runJavaScriptReturningResult(
        'document.cookie',
      );
      final decoded = raw is String && raw.startsWith('"')
          ? jsonDecode(raw) as String
          : '$raw';
      final cookies = <String, String>{};
      for (final part in decoded.split(';')) {
        final separator = part.indexOf('=');
        if (separator <= 0) continue;
        final name = part.substring(0, separator).trim();
        if (name == 'csrftoken' || name == 'ACCESS_TOKEN') {
          cookies[name] = part.substring(separator + 1).trim();
        }
      }
      final header = cookies.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .join('; ');
      return {
        if (header.isNotEmpty) 'cookieHeader': header,
        if (cookies['csrftoken'] != null) 'csrfToken': cookies['csrftoken']!,
      };
    } on Object {
      return const {};
    }
  }

  Future<String> _authenticate(Uri authorizationUri) {
    final completer = Completer<String>();
    _callbackCompleter = completer;
    if (mounted) {
      setState(() => _ready = true);
    }
    _controller.loadRequest(authorizationUri);
    return completer.future;
  }

  bool _isOAuthCallback(Uri? uri) {
    if (uri == null) return false;
    final redirect = Uri.parse(officialOidcWebRedirectUri);
    final parameters = uri.queryParameters;
    return uri.scheme == redirect.scheme &&
        uri.host == redirect.host &&
        uri.path == redirect.path &&
        parameters.containsKey('state') &&
        (parameters.containsKey('code') || parameters.containsKey('error'));
  }

  String _messageFor(Object error, AppLocalizations l10n) {
    if (error is OfficialAuthException) {
      return switch (error.error) {
        OfficialAuthError.cancelled => l10n.loginCancelled,
        OfficialAuthError.invalidCallback => l10n.invalidCallback,
        OfficialAuthError.providerRejected => l10n.providerRejected,
        OfficialAuthError.tokenExchangeFailed => l10n.tokenExchangeFailed,
        OfficialAuthError.entryIdMissing => l10n.entryIdMissing,
        OfficialAuthError.sessionMissing => l10n.sessionMissing,
        OfficialAuthError.network => l10n.networkError,
        _ => l10n.genericError,
      };
    }
    return l10n.genericError;
  }

  @override
  void dispose() {
    final completer = _callbackCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(
        const OfficialAuthException(OfficialAuthError.cancelled),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.officialSignIn)),
      body: _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _startLogin,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                if (_ready) WebViewWidget(controller: _controller),
                if (!_ready) const Center(child: CircularProgressIndicator()),
              ],
            ),
    );
  }
}
