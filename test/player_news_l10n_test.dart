import 'package:fantasy_pl/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const arabic = AppLocalizations(Locale('ar'));
  const english = AppLocalizations(Locale('en'));

  test('translates the fixed FPL news shapes into Arabic', () {
    expect(
      arabic.playerNews('Hamstring injury - Expected back 1 Nov'),
      'إصابة في العضلة الخلفية - العودة المتوقعة 1 نوفمبر',
    );
    expect(
      arabic.playerNews('Knee injury - Unknown return date'),
      'إصابة في الركبة - موعد العودة غير معروف',
    );
    expect(
      arabic.playerNews('Ankle injury - 75% chance of playing'),
      'إصابة في الكاحل - فرصة المشاركة 75٪',
    );
    expect(arabic.playerNews('Suspended until 25 Oct'), 'موقوف حتى 25 أكتوبر');
    expect(
      arabic.playerNews(
        'Has joined Rangers on loan for the rest of the season',
      ),
      'انتقل على سبيل الإعارة',
    );
    expect(arabic.playerNews('Has joined Al Hilal permanently'), 'غادر النادي');
  });

  test('keeps unknown news and English as published', () {
    expect(arabic.playerNews('Personal reasons'), 'Personal reasons');
    expect(
      arabic.playerNews('Elbow injury - Expected back 1 Nov'),
      'Elbow injury - Expected back 1 Nov',
    );
    expect(
      english.playerNews(' Knee injury - Unknown return date '),
      'Knee injury - Unknown return date',
    );
  });
}
