import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../application/auth_controller.dart';
import '../data/official_auth_client.dart';

class OfficialWebLoginPage extends ConsumerStatefulWidget {
  const OfficialWebLoginPage({super.key});

  @override
  ConsumerState<OfficialWebLoginPage> createState() =>
      _OfficialWebLoginPageState();
}

class _OfficialWebLoginPageState extends ConsumerState<OfficialWebLoginPage> {
  late final WebViewController _controller;
  Completer<String>? _callbackCompleter;
  String? _errorMessage;
  bool _ready = false;

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
              final completer = _callbackCompleter;
              if (completer != null && !completer.isCompleted) {
                completer.complete(request.url);
              }
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
      });
    }

    await ref
        .read(authControllerProvider.notifier)
        .signIn(authenticate: _authenticate);

    if (!mounted) return;
    final auth = ref.read(authControllerProvider);
    if (auth.hasError) {
      setState(() {
        _ready = false;
        _errorMessage = _messageFor(auth.error!, AppLocalizations.of(context));
      });
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
