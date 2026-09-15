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
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

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
        backgroundColor: const Color(0xff0b0515),
        body: Stack(
          children: [
            // Ambient Radial Gradient Halo
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.85,
                    colors: [
                      const Color(0xff00ff87).withValues(alpha: 0.10),
                      const Color(0xff2d124d).withValues(alpha: 0.35),
                      const Color(0xff0b0515),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),

            // Subtle Background Accent rings
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.03),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -80,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xff00ff87).withValues(alpha: 0.04),
                    width: 1.5,
                  ),
                ),
              ),
            ),

            // Main Content
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: BlocBuilder<HomePreloadCubit, HomePreloadState>(
                    builder: (context, preloadState) {
                      final isFailure =
                          preloadState.status == PreloadStatus.failure;
                      final authLoading =
                          context.watch<AuthCubit>().state.isLoading;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(flex: 3),

                          // Hero Logo with Orbiting Neon Glow
                          _HeroLogoBadge(
                            controller: _controller,
                            pulseAnimation: _pulseAnimation,
                          ),

                          const SizedBox(height: 36),

                          // Brand Name: FPL PRO
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'FPL',
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xff00ff87),
                                      Color(0xff00b853),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xff00ff87)
                                          .withValues(alpha: 0.45),
                                      blurRadius: 14,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'PRO',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xff07030e),
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Subtitle / Tagline
                          Text(
                            l10n.isArabic
                                ? 'الرفيق الذكي لفانتازي الدوري الإنجليزي'
                                : 'Premier Fantasy Companion & Analytics',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.65),
                              letterSpacing: 0.2,
                            ),
                          ),

                          const Spacer(flex: 2),

                          // Loading State / Failure
                          if (isFailure) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xff2d111d),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xffef4444).withValues(alpha: 0.4),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    l10n.errorLoadingData,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xfffca5a5),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  FilledButton.icon(
                                    onPressed: () =>
                                        context.read<HomePreloadCubit>().load(),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xff00ff87),
                                      foregroundColor: const Color(0xff07030e),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    icon: const Icon(Icons.refresh_rounded, size: 18),
                                    label: Text(
                                      l10n.retry,
                                      style: const TextStyle(fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            // Modern Slim Shimmer Progress Bar
                            _AnimatedProgressBar(controller: _controller),
                            const SizedBox(height: 16),
                            AnimatedBuilder(
                              animation: _controller,
                              builder: (context, child) {
                                final opacity = 0.55 +
                                    (0.45 *
                                        math.sin(_controller.value * 2 * math.pi)
                                            .abs());
                                return Opacity(
                                  opacity: opacity,
                                  child: Text(
                                    preloadState.status == PreloadStatus.loading
                                        ? l10n.loadingData
                                        : (authLoading
                                            ? l10n.authenticating
                                            : l10n.loadingData),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withValues(alpha: 0.75),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],

                          const Spacer(flex: 1),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroLogoBadge extends StatelessWidget {
  const _HeroLogoBadge({
    required this.controller,
    required this.pulseAnimation,
  });

  final AnimationController controller;
  final Animation<double> pulseAnimation;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rotating glowing neon orbit arc
          AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: controller.value * 2 * math.pi,
                child: CustomPaint(
                  size: const Size(146, 146),
                  painter: _SleekOrbitPainter(),
                ),
              );
            },
          ),

          // Outer ambient pulse glow
          AnimatedBuilder(
            animation: pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: pulseAnimation.value,
                child: Container(
                  width: 106,
                  height: 106,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff00ff87).withValues(alpha: 0.35),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: const Color(0xff37003c).withValues(alpha: 0.7),
                        blurRadius: 36,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // The Squircle Card containing the Logo
          Container(
            width: 106,
            height: 106,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xff2d174d),
                  Color(0xff120824),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xff00ff87).withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Transform.scale(
                scale: 1.26,
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SleekOrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Background faint ring
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, bgPaint);

    // Glowing active sweep arc
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweepGradient = SweepGradient(
      colors: [
        const Color(0xff00ff87).withValues(alpha: 0.0),
        const Color(0xff00ff87).withValues(alpha: 0.3),
        const Color(0xff00ff87),
      ],
      stops: const [0.0, 0.6, 1.0],
    );

    final arcPaint = Paint()
      ..shader = sweepGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, math.pi * 1.25, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AnimatedProgressBar extends StatelessWidget {
  const _AnimatedProgressBar({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(2),
      ),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final trackWidth = constraints.maxWidth;
              const pillWidth = 40.0;
              final progress = controller.value;
              final left = (trackWidth - pillWidth) * progress;

              return Stack(
                children: [
                  Positioned(
                    left: left,
                    top: 0,
                    bottom: 0,
                    width: pillWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xff00ff87),
                            Color(0xff55d49c),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xff00ff87).withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
