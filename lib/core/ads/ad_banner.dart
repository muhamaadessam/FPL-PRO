import 'package:flutter/material.dart';

import 'ad_config.dart';
import 'ad_slot_view_stub.dart'
    if (dart.library.js_interop) 'ad_slot_view_web.dart';

export 'ad_config.dart';

/// One AdSense unit of a fixed [size]. Takes no space when ads are off or
/// the unit's slot ID was not provided.
class AdBanner extends StatelessWidget {
  const AdBanner({
    super.key,
    required this.size,
    this.padding = EdgeInsets.zero,
  });

  final AdSize size;
  final EdgeInsetsGeometry padding;

  String get _slot =>
      size == AdSize.halfPage ? AdConfig.railSlot : AdConfig.bannerSlot;

  static bool isAvailable(AdSize size) =>
      AdConfig.enabled &&
      (size == AdSize.halfPage ? AdConfig.railSlot : AdConfig.bannerSlot)
          .isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!isAvailable(size)) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: buildAdSlotView(_slot, size),
        ),
      ),
    );
  }
}
