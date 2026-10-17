import 'package:flutter/widgets.dart';

import 'ad_config.dart';

/// Ads only run on the web; other platforms get an empty box.
Widget buildAdSlotView(String slot, AdSize size) => const SizedBox.shrink();
