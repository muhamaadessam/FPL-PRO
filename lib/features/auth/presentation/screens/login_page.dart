import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/cubit/locale_cubit.dart';
import '../../../../l10n/app_localizations.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _entryIdController = TextEditingController();
  String? _entryIdError;

  @override
  void dispose() {
    _entryIdController.dispose();
    super.dispose();
  }

  void _openTeam() {
    final entryId = int.tryParse(_entryIdController.text.trim());
    if (entryId == null || entryId <= 0) {
      setState(
        () => _entryIdError = AppLocalizations.of(context).entryIdInvalid,
      );
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    context.push('/team/$entryId');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: AlignmentDirectional.topEnd,
                    child: TextButton.icon(
                      onPressed: () {
                        context.read<LocaleCubit>().toggle();
                      },
                      icon: const Icon(Icons.translate),
                      label: Text(l10n.language),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    height: 92,
                    width: 92,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Icon(
                      Icons.sports_soccer,
                      size: 48,
                      color: scheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    l10n.loginTitle,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.loginSubtitle,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Card(
                    color: scheme.primaryContainer.withValues(alpha: 0.55),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.appDescription,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => context.push('/login/web'),
                    icon: const Icon(Icons.login),
                    label: Text(l10n.officialSignIn),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.officialWebViewHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _entryIdController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _openTeam(),
                    decoration: InputDecoration(
                      labelText: l10n.entryId,
                      hintText: l10n.entryIdHint,
                      prefixIcon: const Icon(Icons.badge_outlined),
                      errorText: _entryIdError,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _openTeam,
                    icon: const Icon(Icons.groups_outlined),
                    label: Text(l10n.openTeam),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/preview'),
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(l10n.publicPreview),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.publicPreviewSubtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
