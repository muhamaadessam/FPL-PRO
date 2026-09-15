import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/dashboard/presentation/cubit/home_preload_cubit.dart';
import '../../l10n/app_localizations.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndPreload(context.read<AuthCubit>().state);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _checkAuthAndPreload(AuthState authState) {
    if (authState.session != null) {
      final preloadCubit = context.read<HomePreloadCubit>();
      if (preloadCubit.state.status == PreloadStatus.initial ||
          preloadCubit.state.status == PreloadStatus.failure ||
          preloadCubit.state.entryId != authState.session?.entryId) {
        preloadCubit.load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return MultiBlocListener(
      listeners: [
        BlocListener<AuthCubit, AuthState>(
          listener: (context, state) {
            _checkAuthAndPreload(state);
          },
        ),
        BlocListener<HomePreloadCubit, HomePreloadState>(
          listener: (context, state) {
            if (state.status == PreloadStatus.success &&
                state.entryId ==
                    context.read<AuthCubit>().state.session?.entryId) {
              context.go('/home');
            }
          },
        ),
      ],
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: BlocBuilder<HomePreloadCubit, HomePreloadState>(
                builder: (context, preloadState) {
                  final isFailure =
                      preloadState.status == PreloadStatus.failure;
                  final authLoading = context
                      .watch<AuthCubit>()
                      .state
                      .isLoading;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Custom loading visualization
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            'assets/icon/app_icon.png',
                            width: 40,
                            height: 40,
                          ),
                          AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle:
                                    MediaQuery.maybeOf(
                                          context,
                                        )?.disableAnimations ==
                                        true
                                    ? 0
                                    : _controller.value * 2 * math.pi,
                                child: child,
                              );
                            },
                            child: CustomPaint(
                              size: const Size(80, 80),
                              painter: _FplLoadingPainter(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text(
                        l10n.appName,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (isFailure) ...[
                        Text(
                          l10n.errorLoadingData,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonal(
                          onPressed: () =>
                              context.read<HomePreloadCubit>().load(),
                          child: Text(l10n.retry),
                        ),
                      ] else if (preloadState.status ==
                          PreloadStatus.loading) ...[
                        Text(l10n.loadingData),
                      ] else if (authLoading) ...[
                        Text(l10n.authenticating),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FplLoadingPainter extends CustomPainter {
  _FplLoadingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius =
        math.min(size.width / 2, size.height / 2) - paint.strokeWidth / 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      1.5 * math.pi,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _FplLoadingPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
