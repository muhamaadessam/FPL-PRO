import 'package:fantasy_pl/features/news/domain/player_news.dart';
import 'package:fantasy_pl/features/news/presentation/screens/player_news_page.dart';
import 'package:fantasy_pl/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpl_engine/fpl_engine.dart';

FplBootstrap _bootstrap() => FplBootstrap.fromJson({
  'events': [
    {
      'id': 1,
      'name': 'Gameweek 1',
      'deadline_time': '2026-08-14T17:30:00Z',
      'finished': true,
    },
    {
      'id': 2,
      'name': 'Gameweek 2',
      'deadline_time': '2026-08-21T17:30:00Z',
      'is_current': true,
    },
    {
      'id': 3,
      'name': 'Gameweek 3',
      'deadline_time': '2026-08-28T17:30:00Z',
      'is_next': true,
    },
  ],
  'teams': [
    {'id': 1, 'name': 'Arsenal', 'short_name': 'ARS'},
  ],
  'elements': [
    _player(
      1,
      'Saka',
      'Hamstring injury - Expected back 1 Nov',
      'i',
      40.1,
      '2026-08-10T12:00:00Z',
    ),
    _player(
      2,
      'Rice',
      'Knock - 75% chance of playing',
      'd',
      20.0,
      '2026-08-25T09:00:00Z',
    ),
    _player(
      3,
      'Nwaneri',
      'Knee injury - Unknown return date',
      'i',
      0.4,
      '2026-08-26T09:00:00Z',
    ),
    _player(4, 'Raya', '', 'a', 30.0, null),
    // After every deadline, so it belongs to the next one.
    _player(
      5,
      'White',
      'Suspended until 25 Oct',
      's',
      1.2,
      '2026-09-01T09:00:00Z',
    ),
  ],
});

Map<String, Object?> _player(
  int id,
  String name,
  String news,
  String status,
  double owned,
  String? added,
) => {
  'id': id,
  'web_name': name,
  'team': 1,
  'element_type': 3,
  'status': status,
  'news': news,
  'news_added': added,
  'selected_by_percent': '$owned',
  'chance_of_playing_next_round': switch (status) {
    'd' => 75,
    'a' => null,
    _ => 0,
  },
};

void main() {
  test('groups news by the deadline it came before, newest first', () {
    final groups = groupPlayerNews(_bootstrap(), squadIds: {3});

    expect(groups.map((group) => group.gameweek.id), [3, 1]);
    // Squad first, then ownership; Raya has no news.
    expect(groups.first.items.map((item) => item.player.webName), [
      'Nwaneri',
      'Rice',
      'White',
    ]);
    expect(groups.last.items.single.player.webName, 'Saka');
    // Squad players are key news whatever their ownership.
    expect(groups.first.keyItems.map((item) => item.player.webName), [
      'Nwaneri',
      'Rice',
    ]);
  });

  testWidgets('shows key news in Arabic and reveals the rest', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: PlayerNewsPage(bootstrap: _bootstrap(), squadIds: const {3}),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('قبل deadline الجولة 3'), findsOneWidget);
    expect(
      find.text('إصابة في الركبة - موعد العودة غير معروف'),
      findsOneWidget,
    );
    expect(find.text('في فريقك'), findsOneWidget);
    expect(find.textContaining('White'), findsNothing);

    await tester.tap(find.text('1 خبر تاني أقل أهمية'));
    await tester.pumpAndSettle();
    expect(find.text('موقوف حتى 25 أكتوبر'), findsOneWidget);
  });
}
