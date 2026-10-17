import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/cubit/locale_cubit.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/themes/cubit/theme_cubit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../fixtures/data/datasources/fpl_api_client.dart';
import '../../../team/domain/repositories/team_repository.dart';
import '../cubit/auth_cubit.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      _glowController.repeat(reverse: true);
    }

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textPrimary = AppColors.textPrimary(isDark);
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final dividerColor =
        isDark ? AppColors.darkCardBorder : const Color(0xffe5e0f0);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Ambient Radial Background Glows
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (isDark ? AppColors.plPurple : const Color(0xff6a1b9a))
                        .withValues(alpha: isDark ? 0.45 : 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 140,
            left: -100,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.plMint.withValues(alpha: isDark ? 0.12 : 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.plCyan.withValues(alpha: isDark ? 0.10 : 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main Scrollable Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Bar: Controls (Theme & Language)
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ThemeToggle(
                              isDark: isDark,
                              onToggle: () {
                                context.read<ThemeCubit>().setThemeMode(
                                  isDark ? ThemeMode.light : ThemeMode.dark,
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            _LanguageToggle(
                              isDark: isDark,
                              isArabic: l10n.isArabic,
                              onTap: () => context.read<LocaleCubit>().toggle(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Hero Emblem
                      Center(
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: child,
                            );
                          },
                          child: _HeroEmblem(isDark: isDark),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Brand Name: FPL PRO
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'FPL',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xff00ff87),
                                    Color(0xff00cc66),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xff00ff87)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'PRO',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xff07030e),
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      const SizedBox(height: 10),

                      // Main Title
                      Text(
                        l10n.loginTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                          letterSpacing: -0.4,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Primary: open the app from a team ID
                      _TeamIdForm(isDark: isDark),
                      const SizedBox(height: 20),

                      // Official sign-in runs through a native WebView, so the
                      // web build offers the team ID entry only.
                      if (!kIsWeb) ...[
                      // Divider with "OR"
                      Row(
                        children: [
                          Expanded(child: Divider(color: dividerColor)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              l10n.isArabic ? 'أو' : 'OR',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: textMuted,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: dividerColor)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Official sign-in for team management and transfers
                      _OfficialSignInButton(
                        onPressed: () => context.push('/login/web'),
                        label: l10n.officialSignIn,
                        isDark: isDark,
                        isArabic: l10n.isArabic,
                      ),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Interactive Language switcher pill
class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({
    required this.isDark,
    required this.isArabic,
    required this.onTap,
  });

  final bool isDark;
  final bool isArabic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkCard.withValues(alpha: 0.85)
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? AppColors.darkCardBorder
                  : const Color(0xffe2dced),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.language_rounded,
                size: 15,
                color: isDark ? AppColors.plMint : AppColors.plMintDark,
              ),
              const SizedBox(width: 6),
              Text(
                isArabic ? 'English' : 'العربية',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Interactive Theme mode switcher (Light / Dark)
class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({
    required this.isDark,
    required this.onToggle,
  });

  final bool isDark;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkCard.withValues(alpha: 0.85)
                : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark
                  ? AppColors.darkCardBorder
                  : const Color(0xffe2dced),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            size: 16,
            color: isDark ? const Color(0xffffb547) : AppColors.plPurple,
          ),
        ),
      ),
    );
  }
}

/// Central glowing hero emblem
class _HeroEmblem extends StatelessWidget {
  const _HeroEmblem({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 104,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Glow
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.plMint.withValues(alpha: isDark ? 0.35 : 0.22),
                  blurRadius: 26,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: AppColors.plPurple.withValues(alpha: isDark ? 0.65 : 0.25),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
          ),

          // Central Circular Emblem
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: isDark
                    ? const [
                        Color(0xff2d174d),
                        Color(0xff120824),
                      ]
                    : const [
                        Color(0xff37003c),
                        Color(0xff200024),
                      ],
                stops: const [0.3, 1.0],
              ),
              border: Border.all(
                color: AppColors.plMint.withValues(alpha: 0.7),
                width: 2.2,
              ),
            ),
            child: ClipOval(
              child: Transform.scale(
                scale: 1.28,
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.sports_soccer_rounded,
                    size: 48,
                    color: AppColors.plMint,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Official Premier League sign-in, needed for team management and transfers.
class _OfficialSignInButton extends StatelessWidget {
  const _OfficialSignInButton({
    required this.onPressed,
    required this.label,
    required this.isDark,
    required this.isArabic,
  });

  final VoidCallback onPressed;
  final String label;
  final bool isDark;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final foreground = isDark ? AppColors.plMint : AppColors.plPurple;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.login_rounded, size: 20),
      label: Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: foreground.withValues(alpha: 0.5), width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

/// Team ID field that opens the app in read-only mode for that team. It is
/// filled in with the last team used, and the ID is checked against the
/// public entry endpoint before continuing.
class _TeamIdForm extends StatefulWidget {
  const _TeamIdForm({required this.isDark});

  final bool isDark;

  @override
  State<_TeamIdForm> createState() => _TeamIdFormState();
}

class _TeamIdFormState extends State<_TeamIdForm> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fillLastEntryId();
  }

  Future<void> _fillLastEntryId() async {
    int? entryId;
    try {
      entryId = await context.read<AuthCubit>().lastEntryId();
    } on Object {
      // Prefilling is a convenience; an empty field still works.
    }
    if (!mounted || entryId == null || _controller.text.isNotEmpty) return;
    _controller.text = '$entryId';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final entryId = int.tryParse(_controller.text.trim());
    if (entryId == null || entryId <= 0) {
      setState(() => _error = l10n.entryIdInvalid);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<TeamRepository>().getEntry(entryId);
    } on FplApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = switch (error.kind) {
          FplApiErrorKind.network => l10n.networkError,
          FplApiErrorKind.rateLimited => l10n.rateLimited,
          _ => error.statusCode == 404 ? l10n.entryNotFound : l10n.genericError,
        };
      });
      return;
    } on Object {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = l10n.genericError;
      });
      return;
    }
    if (!mounted) return;
    await context.read<AuthCubit>().continueWithEntryId(entryId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = widget.isDark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.go,
          enabled: !_submitting,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: l10n.entryId,
            hintText: l10n.entryIdHint,
            helperText: l10n.teamIdHelp,
            helperMaxLines: 2,
            errorText: _error,
            errorMaxLines: 2,
            prefixIcon: const Icon(Icons.tag_rounded),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: isDark ? AppColors.plMint : AppColors.plPurple,
            foregroundColor: isDark ? AppColors.darkBackground : Colors.white,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  l10n.openTeam,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
      ],
    );
  }
}
