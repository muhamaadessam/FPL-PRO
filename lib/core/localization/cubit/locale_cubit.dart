import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../storage/cache_helper.dart';

class LocaleCubit extends Cubit<Locale> {
  LocaleCubit() : super(_initialLocale());

  void toggle() {
    final locale = state.languageCode == 'ar'
        ? const Locale('en')
        : const Locale('ar');
    emit(locale);
    CacheHelper.put(key: 'language', value: locale.languageCode);
  }
}

Locale _initialLocale() {
  final cachedLanguage = CacheHelper.isInitialized
      ? CacheHelper.get(key: 'language') as String?
      : null;
  if (cachedLanguage == 'ar' || cachedLanguage == 'en') {
    return Locale(cachedLanguage!);
  }

  return Locale(
    PlatformDispatcher.instance.locale.languageCode == 'ar' ? 'ar' : 'en',
  );
}
