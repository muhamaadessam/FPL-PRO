import 'package:flutter_test/flutter_test.dart';

import 'package:fantasy_pl/features/fixtures/data/models/fpl_models.dart';
import 'package:fantasy_pl/features/team/data/models/team_models.dart';
import 'package:fantasy_pl/features/team/domain/usecases/squad_editor.dart';

// 1-4-4-2 starters, bench: GK 12, DEF 13, MID 14, FWD 15.
const _types = [1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 1, 2, 3, 4];

List<TeamPick> _squad() => [
  for (var i = 0; i < 15; i++)
    TeamPick(
      elementId: i + 1,
      position: i + 1,
      multiplier: i < 11 ? 1 : 0,
      isCaptain: i == 9,
      isViceCaptain: i == 10,
      elementType: _types[i],
      sellingPrice: 50,
    ),
];

TeamPick _pick(List<TeamPick> picks, int id) =>
    picks.firstWhere((p) => p.elementId == id);

FplBootstrap _bootstrap(List<FplPlayer> extra) => FplBootstrap(
  gameweeks: const [],
  teams: const {},
  players: {
    for (var i = 0; i < 15; i++)
      i + 1: FplPlayer(
        id: i + 1,
        webName: 'P${i + 1}',
        teamId: i + 1,
        positionId: _types[i],
        nowCost: 50,
      ),
    for (final player in extra) player.id: player,
  },
);

void main() {
  group('SquadEditor', () {
    test('subbing a defender for a forward gives a legal 3-4-3', () {
      final result = SquadEditor.swap(_squad(), 2, 15);

      expect(_pick(result, 15).position, lessThanOrEqualTo(11));
      expect(_pick(result, 2).position, greaterThan(11));
      expect(SquadEditor.validate(result), isNull);
      // Starters stay ordered GK, DEF, MID, FWD.
      final starters = result.where((p) => p.position <= 11).toList()
        ..sort((a, b) => a.position.compareTo(b.position));
      expect(starters.map((p) => p.elementType).toList(), [
        1,
        2,
        2,
        2,
        3,
        3,
        3,
        3,
        4,
        4,
        4,
      ]);
    });

    test('rejects a lineup with only two defenders', () {
      final threeAtBack = SquadEditor.swap(_squad(), 2, 15);
      expect(
        () => SquadEditor.swap(threeAtBack, 3, 14),
        throwsA(
          isA<SquadEditException>().having(
            (e) => e.error,
            'error',
            SquadEditError.invalidFormation,
          ),
        ),
      );
    });

    test('goalkeepers only swap with goalkeepers', () {
      expect(
        () => SquadEditor.swap(_squad(), 1, 13),
        throwsA(isA<SquadEditException>()),
      );
      final result = SquadEditor.swap(_squad(), 1, 12);
      expect(_pick(result, 12).position, 1);
      expect(_pick(result, 1).position, 12);
    });

    test('benching the captain hands the armband to the substitute', () {
      final result = SquadEditor.swap(_squad(), 10, 15);
      expect(_pick(result, 15).isCaptain, isTrue);
      expect(_pick(result, 10).isCaptain, isFalse);
    });

    test('making the vice captain swaps the armbands', () {
      final result = SquadEditor.setCaptain(_squad(), 11);
      expect(_pick(result, 11).isCaptain, isTrue);
      expect(_pick(result, 10).isViceCaptain, isTrue);
      expect(_pick(result, 11).multiplier, 2);
    });

    test('a substitute cannot take an armband', () {
      expect(
        () => SquadEditor.setViceCaptain(_squad(), 13),
        throwsA(isA<SquadEditException>()),
      );
    });

    test('chips change multipliers', () {
      final tripleCaptain = SquadEditor.normalize(
        _squad(),
        chip: FplChipName.tripleCaptain,
      );
      expect(_pick(tripleCaptain, 10).multiplier, 3);
      final benchBoost = SquadEditor.normalize(
        _squad(),
        chip: FplChipName.benchBoost,
      );
      expect(_pick(benchBoost, 13).multiplier, 1);
    });
  });

  group('TransferPlan', () {
    const cheapMid = FplPlayer(
      id: 100,
      webName: 'Cheap',
      teamId: 20,
      positionId: 3,
      nowCost: 45,
    );
    const priceyMid = FplPlayer(
      id: 101,
      webName: 'Pricey',
      teamId: 20,
      positionId: 3,
      nowCost: 130,
    );

    TransferPlan plan({int bank = 10, int? free = 1}) => TransferPlan(
      squad: _squad(),
      bootstrap: _bootstrap([cheapMid, priceyMid]),
      bank: bank,
      freeTransfers: free,
    );

    test('queues a transfer and updates the bank', () {
      final next = plan().replace(6, cheapMid);
      expect(
        next.transfers.single.toRequest(),
        const TransferRequest(
          elementIn: 100,
          elementOut: 6,
          purchasePrice: 45,
          sellingPrice: 50,
        ),
      );
      expect(next.remainingBank, 15);
      expect(next.pointsCost, 0);
      expect(_pick(next.draftSquad, 100).position, 6);
    });

    test('blocks unaffordable, wrong-position and duplicate players', () {
      expect(plan().check(6, priceyMid), SquadEditError.insufficientFunds);
      expect(plan().check(2, cheapMid), SquadEditError.differentPosition);
      expect(
        plan().check(6, _bootstrap(const []).players[7]!),
        SquadEditError.alreadyInSquad,
      );
    });

    test('limits three players per club', () {
      final sameClub = [
        for (var id = 200; id < 204; id++)
          FplPlayer(
            id: id,
            webName: 'C$id',
            teamId: 30,
            positionId: 3,
            nowCost: 50,
          ),
      ];
      var next = TransferPlan(
        squad: _squad(),
        bootstrap: _bootstrap(sameClub),
        bank: 0,
        freeTransfers: 1,
      );
      next = next.replace(6, sameClub[0]).replace(7, sameClub[1]);
      next = next.replace(8, sameClub[2]);
      expect(next.check(9, sameClub[3]), SquadEditError.clubLimit);
    });

    test('charges four points per extra transfer unless a chip is played', () {
      final two = plan(bank: 100).replace(6, cheapMid).replace(7, priceyMid);
      expect(two.pointsCost, 4);
      expect(two.copyWith(chip: FplChipName.wildcard).pointsCost, 0);
    });

    test('re-replacing an incoming player keeps one transfer', () {
      final next = plan(bank: 100).replace(6, cheapMid).replace(100, priceyMid);
      expect(next.transfers, hasLength(1));
      expect(next.transfers.single.outPick.elementId, 6);
      expect(next.transfers.single.inPlayer.id, 101);
      // Bringing the original player back cancels the transfer.
      final undone = next.replace(101, _bootstrap(const []).players[6]!);
      expect(undone.transfers, isEmpty);
    });
  });
}
