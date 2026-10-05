import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../fixtures/data/models/fpl_models.dart';
import '../../domain/usecases/recommendation_engine.dart';

class PlayerDirectoryPage extends StatefulWidget {
  const PlayerDirectoryPage({
    super.key,
    required this.bootstrap,
    required this.fixtures,
    required this.gameweekId,
  });

  final FplBootstrap bootstrap;
  final List<FplFixture> fixtures;
  final int gameweekId;

  @override
  State<PlayerDirectoryPage> createState() => _PlayerDirectoryPageState();
}

class _PlayerDirectoryPageState extends State<PlayerDirectoryPage> {
  final _searchController = TextEditingController();
  late final List<PlayerProjection> _projections;
  final _selectedIds = <int>[];
  int? _positionFilter;
  int? _teamFilter;

  @override
  void initState() {
    super.initState();
    _projections = const RecommendationEngine().buildPlayerProjections(
      bootstrap: widget.bootstrap,
      fixtures: widget.fixtures,
      gameweekId: widget.gameweekId,
    );
    _searchController.addListener(_refreshResults);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_refreshResults)
      ..dispose();
    super.dispose();
  }

  void _refreshResults() => setState(() {});

  List<PlayerProjection> get _filteredPlayers {
    final query = _searchController.text.trim().toLowerCase();
    return _projections
        .where((projection) {
          final player = projection.player;
          final team = widget.bootstrap.teams[player.teamId];
          final fullName =
              '${player.firstName ?? ''} ${player.secondName ?? ''}'
                  .trim()
                  .toLowerCase();
          final matchesQuery =
              query.isEmpty ||
              player.webName.toLowerCase().contains(query) ||
              fullName.contains(query) ||
              (team?.name.toLowerCase().contains(query) ?? false) ||
              (team?.shortName.toLowerCase().contains(query) ?? false);
          return matchesQuery &&
              (_positionFilter == null ||
                  player.positionId == _positionFilter) &&
              (_teamFilter == null || player.teamId == _teamFilter);
        })
        .toList(growable: false);
  }

  void _togglePlayer(int playerId) {
    if (_selectedIds.contains(playerId)) {
      setState(() => _selectedIds.remove(playerId));
      return;
    }
    if (_selectedIds.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).maxTwoPlayers)),
      );
      return;
    }
    setState(() => _selectedIds.add(playerId));
  }

  void _openComparison() {
    if (_selectedIds.length != 2) return;
    final selected = _selectedIds
        .map(
          (id) => _projections.firstWhere(
            (projection) => projection.player.id == id,
          ),
        )
        .toList(growable: false);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerComparisonPage(
          left: selected[0],
          right: selected[1],
          bootstrap: widget.bootstrap,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final players = _filteredPlayers;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.playerDirectory)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.searchPlayersHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.clear_rounded),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _FilterDropdown(
                    value: _positionFilter,
                    hint: l10n.allPositions,
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(l10n.allPositions),
                      ),
                      for (var position = 1; position <= 4; position++)
                        DropdownMenuItem<int?>(
                          value: position,
                          child: Text(l10n.positionName(position)),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _positionFilter = value),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _FilterDropdown(
                    value: _teamFilter,
                    hint: l10n.allTeams,
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(l10n.allTeams),
                      ),
                      ...widget.bootstrap.teams.values.map(
                        (team) => DropdownMenuItem<int?>(
                          value: team.id,
                          child: Text(team.shortName),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _teamFilter = value),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: players.isEmpty
                ? Center(child: Text(l10n.noPlayersFound))
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      12,
                      4,
                      12,
                      _selectedIds.isEmpty ? 24 : 96,
                    ),
                    itemCount: players.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final projection = players[index];
                      return _PlayerDirectoryTile(
                        projection: projection,
                        team: widget.bootstrap.teams[projection.player.teamId],
                        selected: _selectedIds.contains(projection.player.id),
                        onTap: () => _togglePlayer(projection.player.id),
                      );
                    },
                  ),
          ),
          if (_selectedIds.isNotEmpty)
            SafeArea(
              top: false,
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_selectedIds.length}/2 ${_selectedIds.length == 1 ? l10n.selectOneMorePlayer : l10n.comparePlayers}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _selectedIds.length == 2
                            ? _openComparison
                            : null,
                        icon: const Icon(Icons.compare_arrows_rounded),
                        label: Text(l10n.compareSelected),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final int? value;
  final String hint;
  final List<DropdownMenuItem<int?>> items;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: value,
          isExpanded: true,
          isDense: true,
          hint: Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _PlayerDirectoryTile extends StatelessWidget {
  const _PlayerDirectoryTile({
    required this.projection,
    required this.team,
    required this.selected,
    required this.onTap,
  });

  final PlayerProjection projection;
  final FplTeam? team;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final player = projection.player;
    final colors = Theme.of(context).colorScheme;
    final risk = player.isUnavailableNextRound || player.isDoubtfulNextRound;
    return Material(
      color: selected
          ? colors.primaryContainer
          : colors.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: CircleAvatar(
          backgroundColor: colors.surfaceContainerHigh,
          child: Text(
            team?.shortName ?? 'PL',
            style: TextStyle(
              color: colors.primary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        title: Text(
          player.webName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${team?.name ?? l10n.unknown} • ${l10n.positionName(player.positionId)}${risk ? ' • ${_statusLabel(l10n, player)}' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: SizedBox(
          width: selected ? 104 : 76,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    projection.nextPoints.toStringAsFixed(1),
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    '${player.totalPoints} ${l10n.points}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
              if (selected) ...[
                const SizedBox(width: 6),
                Icon(Icons.check_circle, color: colors.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class PlayerComparisonPage extends StatelessWidget {
  const PlayerComparisonPage({
    super.key,
    required this.left,
    required this.right,
    required this.bootstrap,
    this.transfer,
    this.onTransfer,
  });

  final PlayerProjection left;
  final PlayerProjection right;
  final FplBootstrap bootstrap;
  final TransferSuggestion? transfer;
  final Future<void> Function(TransferSuggestion transfer)? onTransfer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.comparePlayers)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ComparisonPlayerHeader(
                      projection: left,
                      bootstrap: bootstrap,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 28),
                    child: Icon(Icons.compare_arrows_rounded),
                  ),
                  Expanded(
                    child: _ComparisonPlayerHeader(
                      projection: right,
                      bootstrap: bootstrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.comparisonDisclaimer,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              Text(
                l10n.compareData,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              _ComparisonTable(left: left, right: right, l10n: l10n),
              const SizedBox(height: 16),
              _NewsComparison(left: left, right: right, l10n: l10n),
              if (transfer != null && onTransfer != null) ...[
                const SizedBox(height: 20),
                _ComparisonTransferButton(
                  transfer: transfer!,
                  onTransfer: onTransfer!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ComparisonPlayerHeader extends StatelessWidget {
  const _ComparisonPlayerHeader({
    required this.projection,
    required this.bootstrap,
  });

  final PlayerProjection projection;
  final FplBootstrap bootstrap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final player = projection.player;
    final team = bootstrap.teams[player.teamId];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: colors.primaryContainer,
            child: Text(
              team?.shortName ?? 'PL',
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            player.webName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          Text(
            team?.name ?? '',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 8),
          Text(
            projection.nextPoints.toStringAsFixed(1),
            style: TextStyle(
              color: colors.primary,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({
    required this.left,
    required this.right,
    required this.l10n,
  });

  final PlayerProjection left;
  final PlayerProjection right;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final leftPlayer = left.player;
    final rightPlayer = right.player;
    return Column(
      children: [
        _row(
          context,
          l10n.expectedNextGameweekPoints,
          left.nextPoints,
          right.nextPoints,
        ),
        _row(
          context,
          l10n.projectedThreeGameweeks,
          left.horizonPoints,
          right.horizonPoints,
        ),
        _row(
          context,
          l10n.availability,
          _chance(left),
          _chance(right),
          suffix: '%',
        ),
        _row(
          context,
          l10n.nextFixtures,
          left.nextFixtureCount,
          right.nextFixtureCount,
        ),
        _row(
          context,
          l10n.fixtureDifficulty,
          _averageDifficulty(left),
          _averageDifficulty(right),
          decimals: 1,
        ),
        _row(
          context,
          l10n.totalPoints,
          leftPlayer.totalPoints,
          rightPlayer.totalPoints,
        ),
        _row(
          context,
          l10n.playerPrice,
          _price(leftPlayer.nowCost),
          _price(rightPlayer.nowCost),
          suffix: 'm',
        ),
        _row(context, l10n.currentForm, leftPlayer.form, rightPlayer.form),
        _row(
          context,
          l10n.seasonAverage,
          leftPlayer.pointsPerGame,
          rightPlayer.pointsPerGame,
        ),
        _row(
          context,
          l10n.selectedBy,
          leftPlayer.selectedByPercent,
          rightPlayer.selectedByPercent,
          suffix: '%',
        ),
        _row(
          context,
          l10n.minutesPlayed,
          leftPlayer.minutes,
          rightPlayer.minutes,
        ),
        _row(context, l10n.starts, leftPlayer.starts, rightPlayer.starts),
        _row(
          context,
          l10n.expectedGoalInvolvements,
          leftPlayer.expectedGoalInvolvements,
          rightPlayer.expectedGoalInvolvements,
        ),
        _row(
          context,
          l10n.expectedGoalsConceded,
          leftPlayer.expectedGoalsConceded,
          rightPlayer.expectedGoalsConceded,
        ),
        _row(
          context,
          l10n.defensiveContribution,
          leftPlayer.defensiveContribution,
          rightPlayer.defensiveContribution,
        ),
        _row(
          context,
          l10n.cleanSheets,
          leftPlayer.cleanSheets,
          rightPlayer.cleanSheets,
        ),
        _row(context, l10n.saves, leftPlayer.saves, rightPlayer.saves),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    num leftValue,
    num rightValue, {
    int decimals = 1,
    String suffix = '',
  }) {
    final colors = Theme.of(context).colorScheme;
    final leftColor = leftValue > rightValue ? colors.primary : null;
    final rightColor = rightValue > leftValue ? colors.primary : null;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label)),
          Expanded(
            child: Text(
              '${leftValue.toStringAsFixed(decimals)}$suffix',
              textAlign: TextAlign.end,
              style: TextStyle(color: leftColor, fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: Text(
              '${rightValue.toStringAsFixed(decimals)}$suffix',
              textAlign: TextAlign.end,
              style: TextStyle(color: rightColor, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  double _chance(PlayerProjection projection) =>
      projection.player.nextRoundChanceOfPlaying?.toDouble() ??
      projection.availability * 100;

  double _averageDifficulty(PlayerProjection projection) {
    if (projection.nextDifficulties.isEmpty) return 0;
    return projection.nextDifficulties.reduce((a, b) => a + b) /
        projection.nextDifficulties.length;
  }

  double _price(int? cost) => (cost ?? 0) / 10;
}

class _NewsComparison extends StatelessWidget {
  const _NewsComparison({
    required this.left,
    required this.right,
    required this.l10n,
  });

  final PlayerProjection left;
  final PlayerProjection right;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _news(context, left, colors)),
        const SizedBox(width: 8),
        Expanded(child: _news(context, right, colors)),
      ],
    );
  }

  Widget _news(
    BuildContext context,
    PlayerProjection projection,
    ColorScheme colors,
  ) {
    final player = projection.player;
    final status = _statusLabel(l10n, player);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(status, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(player.news.trim().isEmpty ? l10n.noNews : player.news.trim()),
        ],
      ),
    );
  }
}

class _ComparisonTransferButton extends StatefulWidget {
  const _ComparisonTransferButton({
    required this.transfer,
    required this.onTransfer,
  });

  final TransferSuggestion transfer;
  final Future<void> Function(TransferSuggestion transfer) onTransfer;

  @override
  State<_ComparisonTransferButton> createState() =>
      _ComparisonTransferButtonState();
}

class _ComparisonTransferButtonState extends State<_ComparisonTransferButton> {
  bool _isSubmitting = false;

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      await widget.onTransfer(widget.transfer);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).transferSubmitted)),
      );
    } on Object {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).genericError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isSubmitting ? null : _submit,
        icon: _isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.swap_horiz_rounded),
        label: Text(l10n.confirmTransfer),
      ),
    );
  }
}

String _statusLabel(AppLocalizations l10n, FplPlayer player) {
  return switch (player.status.toLowerCase()) {
    'i' => l10n.injured,
    's' => l10n.suspended,
    'd' => l10n.doubtful,
    'u' || 'n' => l10n.unavailable,
    _ => l10n.availability,
  };
}
