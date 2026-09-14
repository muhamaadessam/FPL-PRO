import 'dart:ui';

import 'package:flutter_riverpod/legacy.dart';

import '../storage/cache_helper.dart';

final localeProvider = StateProvider<Locale>((ref) {
  final cachedLanguage = CacheHelper.isInitialized
      ? CacheHelper.get(key: 'language') as String?
      : null;
  if (cachedLanguage == 'ar' || cachedLanguage == 'en') {
    return Locale(cachedLanguage!);
  }

  final languageCode = PlatformDispatcher.instance.locale.languageCode;
  return Locale(languageCode == 'ar' ? 'ar' : 'en');
});
