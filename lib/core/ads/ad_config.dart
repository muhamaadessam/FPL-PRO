import 'package:flutter/foundation.dart';

/// Google AdSense settings, passed at build time so no IDs live in the repo:
///
///   flutter build web --dart-define=ADSENSE_CLIENT=ca-pub-XXXX \
///     --dart-define=ADSENSE_SLOT_BANNER=1234567890 \
///     --dart-define=ADSENSE_SLOT_RAIL=0987654321
///
/// Without ADSENSE_CLIENT the web app shows no ads, and the mobile apps never
/// do. ADSENSE_TEST=true asks Google for test ads that earn nothing.
abstract final class AdConfig {
  static const client = String.fromEnvironment('ADSENSE_CLIENT');
  static const bannerSlot = String.fromEnvironment('ADSENSE_SLOT_BANNER');
  static const railSlot = String.fromEnvironment('ADSENSE_SLOT_RAIL');
  static const testMode = bool.fromEnvironment('ADSENSE_TEST');

  static bool get enabled => kIsWeb && client.isNotEmpty;
}

/// Fixed ad sizes used by the app shell.
enum AdSize {
  /// Phone banner above the bottom navigation bar.
  mobileBanner(320, 50),

  /// Tablet and desktop banner at the bottom of the page.
  leaderboard(728, 90),

  /// Side rail on very wide screens.
  halfPage(300, 600);

  const AdSize(this.width, this.height);

  final double width;
  final double height;
}
