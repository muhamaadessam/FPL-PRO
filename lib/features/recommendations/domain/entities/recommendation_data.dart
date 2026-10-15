import '../../../fixtures/data/models/fpl_models.dart';
import '../../../team/data/models/team_models.dart';
import '../usecases/recommendation_engine.dart';

class RecommendationData {
  const RecommendationData({
    required this.result,
    required this.gameweek,
    required this.bootstrap,
    required this.team,
    this.fixtures = const [],
    this.projections = const [],
    this.updatedAt,
  });

  final RecommendationResult result;
  final Gameweek gameweek;
  final FplBootstrap bootstrap;
  final MyTeam team;
  final List<FplFixture> fixtures;

  /// Every player's projection, as used for [result]; screens read these so
  /// the same player never shows two different numbers.
  final List<PlayerProjection> projections;
  final DateTime? updatedAt;
}
