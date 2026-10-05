import '../../../fixtures/data/models/fpl_models.dart';
import '../../data/models/team_models.dart';

/// Why a lineup or transfer edit was rejected before reaching the API.
enum SquadEditError {
  notInSquad,
  benchedRole,
  goalkeeperSwap,
  invalidFormation,
  samePlayer,
  differentPosition,
  alreadyInSquad,
  clubLimit,
  insufficientFunds,
  unavailable,
}

class SquadEditException implements Exception {
  const SquadEditException(this.error);

  final SquadEditError error;

  @override
  String toString() => 'SquadEditException($error)';
}

const _startingSlots = 11;
const _benchGoalkeeperSlot = 12;
const _maxPlayersPerClub = 3;
const _defaultHitCost = 4;

/// Pure lineup rules matching the official pick-team screen: 11 starters
/// with exactly one goalkeeper, at least 3 defenders, 2 midfielders and
/// 1 forward, and a captain and vice-captain who both start.
abstract final class SquadEditor {
  /// Swaps two players' slots. Swapping a starter with a substitute hands the
  /// starter's armband to the incoming player, as the official site does.
  static List<TeamPick> swap(
    List<TeamPick> picks,
    int firstElementId,
    int secondElementId, {
    String? chip,
  }) {
    if (firstElementId == secondElementId) {
      throw const SquadEditException(SquadEditError.samePlayer);
    }
    final first = _find(picks, firstElementId);
    final second = _find(picks, secondElementId);
    final firstIsGoalkeeper = first.elementType == 1;
    final secondIsGoalkeeper = second.elementType == 1;
    if (firstIsGoalkeeper != secondIsGoalkeeper) {
      throw const SquadEditException(SquadEditError.goalkeeperSwap);
    }

    final swapped = [
      for (final pick in picks)
        if (pick.elementId == first.elementId)
          pick.copyWith(
            position: second.position,
            isCaptain: second.isCaptain,
            isViceCaptain: second.isViceCaptain,
          )
        else if (pick.elementId == second.elementId)
          pick.copyWith(
            position: first.position,
            isCaptain: first.isCaptain,
            isViceCaptain: first.isViceCaptain,
          )
        else
          pick,
    ];
    final normalized = normalize(swapped, chip: chip);
    final error = validate(normalized);
    if (error != null) throw SquadEditException(error);
    return normalized;
  }

  static List<TeamPick> setCaptain(
    List<TeamPick> picks,
    int elementId, {
    String? chip,
  }) {
    return _setRole(picks, elementId, captain: true, chip: chip);
  }

  static List<TeamPick> setViceCaptain(
    List<TeamPick> picks,
    int elementId, {
    String? chip,
  }) {
    return _setRole(picks, elementId, captain: false, chip: chip);
  }

  static List<TeamPick> _setRole(
    List<TeamPick> picks,
    int elementId, {
    required bool captain,
    String? chip,
  }) {
    final target = _find(picks, elementId);
    if (target.position > _startingSlots) {
      throw const SquadEditException(SquadEditError.benchedRole);
    }
    final previousHolder = picks
        .where((pick) => captain ? pick.isCaptain : pick.isViceCaptain)
        .firstOrNull;
    final updated = [
      for (final pick in picks)
        if (pick.elementId == elementId)
          pick.copyWith(isCaptain: captain, isViceCaptain: !captain)
        else if (pick.elementId == previousHolder?.elementId)
          // The old holder takes the target's other armband, if it had one.
          pick.copyWith(
            isCaptain: !captain && target.isCaptain,
            isViceCaptain: captain && target.isViceCaptain,
          )
        else if (captain ? pick.isCaptain : pick.isViceCaptain)
          pick.copyWith(isCaptain: false, isViceCaptain: false)
        else
          pick,
    ];
    return normalize(updated, chip: chip);
  }

  /// Orders starters by position type and keeps the bench order, giving the
  /// backup goalkeeper slot 12 and recomputing multipliers for [chip].
  static List<TeamPick> normalize(List<TeamPick> picks, {String? chip}) {
    final starters = picks.where((p) => p.position <= _startingSlots).toList()
      ..sort((a, b) {
        final byType = a.elementType.compareTo(b.elementType);
        return byType != 0 ? byType : a.position.compareTo(b.position);
      });
    final bench = picks.where((p) => p.position > _startingSlots).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    final benchGoalkeepers = bench.where((p) => p.elementType == 1);
    final benchOutfield = bench.where((p) => p.elementType != 1);
    final orderedBench = [...benchGoalkeepers, ...benchOutfield];

    final captainMultiplier = chip == FplChipName.tripleCaptain ? 3 : 2;
    final benchMultiplier = chip == FplChipName.benchBoost ? 1 : 0;
    return [
      for (var i = 0; i < starters.length; i++)
        starters[i].copyWith(
          position: i + 1,
          multiplier: starters[i].isCaptain ? captainMultiplier : 1,
        ),
      for (var i = 0; i < orderedBench.length; i++)
        orderedBench[i].copyWith(
          position: starters.length + 1 + i,
          multiplier: benchMultiplier,
          isCaptain: false,
          isViceCaptain: false,
        ),
    ];
  }

  /// Returns the first broken lineup rule, or null when the API should
  /// accept the lineup.
  static SquadEditError? validate(List<TeamPick> picks) {
    final starters = picks.where((p) => p.position <= _startingSlots).toList();
    if (starters.length != _startingSlots) {
      return SquadEditError.invalidFormation;
    }
    int count(int type) => starters.where((p) => p.elementType == type).length;
    if (count(1) != 1 || count(2) < 3 || count(3) < 2 || count(4) < 1) {
      return SquadEditError.invalidFormation;
    }
    final benchGoalkeeper = picks.where(
      (p) => p.position == _benchGoalkeeperSlot,
    );
    if (benchGoalkeeper.isNotEmpty && benchGoalkeeper.first.elementType != 1) {
      return SquadEditError.invalidFormation;
    }
    final captains = picks.where((p) => p.isCaptain).toList();
    final vices = picks.where((p) => p.isViceCaptain).toList();
    if (captains.length != 1 ||
        vices.length != 1 ||
        captains.first.elementId == vices.first.elementId ||
        captains.first.position > _startingSlots ||
        vices.first.position > _startingSlots) {
      return SquadEditError.benchedRole;
    }
    return null;
  }

  static bool sameLineup(List<TeamPick> a, List<TeamPick> b) {
    if (a.length != b.length) return false;
    final byId = {for (final pick in b) pick.elementId: pick};
    return a.every((pick) {
      final other = byId[pick.elementId];
      return other != null &&
          other.position == pick.position &&
          other.isCaptain == pick.isCaptain &&
          other.isViceCaptain == pick.isViceCaptain;
    });
  }

  static TeamPick _find(List<TeamPick> picks, int elementId) {
    final pick = picks.where((p) => p.elementId == elementId).firstOrNull;
    if (pick == null) throw const SquadEditException(SquadEditError.notInSquad);
    return pick;
  }
}

/// A transfer the manager has queued but not confirmed yet.
class PendingTransfer {
  const PendingTransfer({
    required this.outPick,
    required this.inPlayer,
    required this.sellingPrice,
  });

  /// The player as they were in the confirmed squad.
  final TeamPick outPick;
  final FplPlayer inPlayer;
  final int sellingPrice;

  int get purchasePrice => inPlayer.nowCost ?? 0;

  TransferRequest toRequest() => TransferRequest(
    elementIn: inPlayer.id,
    elementOut: outPick.elementId,
    purchasePrice: purchasePrice,
    sellingPrice: sellingPrice,
  );
}

/// Queued transfers on top of the confirmed squad, with the budget, club and
/// points-hit rules the official transfers screen enforces.
class TransferPlan {
  const TransferPlan({
    required this.squad,
    required this.bootstrap,
    required this.bank,
    this.freeTransfers,
    this.hitCost = _defaultHitCost,
    this.transfers = const [],
    this.chip,
  });

  factory TransferPlan.fromTeam(MyTeam team, FplBootstrap bootstrap) {
    final limit = team.transfers.limit;
    final made = team.transfers.made ?? 0;
    return TransferPlan(
      squad: team.picks,
      bootstrap: bootstrap,
      bank: team.transfers.bank ?? team.summary.bank ?? 0,
      freeTransfers: limit == null ? null : (limit - made).clamp(0, limit),
      hitCost: team.transfers.cost ?? _defaultHitCost,
    );
  }

  final List<TeamPick> squad;
  final FplBootstrap bootstrap;
  final int bank;

  /// Free transfers left; null means unlimited (e.g. pre-season or a chip).
  final int? freeTransfers;
  final int hitCost;
  final List<PendingTransfer> transfers;

  /// [FplChipName.wildcard] or [FplChipName.freeHit] when one is selected.
  final String? chip;

  bool get hasChanges => transfers.isNotEmpty;

  int get remainingBank => transfers.fold(
    bank,
    (total, t) => total + t.sellingPrice - t.purchasePrice,
  );

  int get pointsCost {
    final free = freeTransfers;
    if (chip != null || free == null) return 0;
    final paid = transfers.length - free;
    return paid > 0 ? paid * hitCost : 0;
  }

  /// The squad as it will look after the queued transfers. Incoming players
  /// take the outgoing player's slot and armband.
  List<TeamPick> get draftSquad {
    final replacements = {
      for (final t in transfers) t.outPick.elementId: t.inPlayer,
    };
    return [
      for (final pick in squad)
        if (replacements[pick.elementId] case final player?)
          pick.copyWith(
            elementId: player.id,
            elementType: player.positionId,
            purchasePrice: player.nowCost,
            sellingPrice: player.nowCost,
          )
        else
          pick,
    ];
  }

  TransferPlan copyWith({
    List<PendingTransfer>? transfers,
    String? chip,
    bool clearChip = false,
  }) {
    return TransferPlan(
      squad: squad,
      bootstrap: bootstrap,
      bank: bank,
      freeTransfers: freeTransfers,
      hitCost: hitCost,
      transfers: transfers ?? this.transfers,
      chip: clearChip ? null : chip ?? this.chip,
    );
  }

  /// Why [incoming] cannot replace the draft player [outElementId], or null
  /// when the swap fits the budget and squad rules.
  SquadEditError? check(int outElementId, FplPlayer incoming) {
    final draft = draftSquad;
    final outgoing = draft
        .where((p) => p.elementId == outElementId)
        .firstOrNull;
    if (outgoing == null) return SquadEditError.notInSquad;
    if (incoming.id == outElementId) return SquadEditError.samePlayer;
    final outPlayer = bootstrap.players[outElementId];
    final outPosition = outPlayer?.positionId ?? outgoing.elementType;
    if (incoming.positionId != outPosition) {
      return SquadEditError.differentPosition;
    }
    final original = _originalSlot(outElementId);
    final returningOriginal = original.elementId == incoming.id;
    if (!returningOriginal && draft.any((p) => p.elementId == incoming.id)) {
      return SquadEditError.alreadyInSquad;
    }
    if (!returningOriginal && !incoming.canSelect) {
      return SquadEditError.unavailable;
    }
    final clubCount = draft
        .where((p) => p.elementId != outElementId)
        .where((p) => bootstrap.players[p.elementId]?.teamId == incoming.teamId)
        .length;
    if (clubCount >= _maxPlayersPerClub) return SquadEditError.clubLimit;
    final next = _replace(outElementId, incoming);
    if (next.remainingBank < 0) return SquadEditError.insufficientFunds;
    return null;
  }

  TransferPlan replace(int outElementId, FplPlayer incoming) {
    final error = check(outElementId, incoming);
    if (error != null) throw SquadEditException(error);
    return _replace(outElementId, incoming);
  }

  /// Drops the queued transfer for the slot first held by [originalElementId].
  TransferPlan undo(int originalElementId) {
    return copyWith(
      transfers: [
        for (final t in transfers)
          if (t.outPick.elementId != originalElementId) t,
      ],
    );
  }

  TransferPlan _replace(int outElementId, FplPlayer incoming) {
    final original = _originalSlot(outElementId);
    final kept = [
      for (final t in transfers)
        if (t.outPick.elementId != original.elementId) t,
    ];
    if (original.elementId == incoming.id) return copyWith(transfers: kept);
    final originalPlayer = bootstrap.players[original.elementId];
    return copyWith(
      transfers: [
        ...kept,
        PendingTransfer(
          outPick: original,
          inPlayer: incoming,
          sellingPrice: original.sellingPrice ?? originalPlayer?.nowCost ?? 0,
        ),
      ],
    );
  }

  /// The confirmed squad pick whose slot [draftElementId] now occupies.
  TeamPick _originalSlot(int draftElementId) {
    for (final t in transfers) {
      if (t.inPlayer.id == draftElementId) return t.outPick;
    }
    return squad.firstWhere((p) => p.elementId == draftElementId);
  }
}
