import '../../../fixtures/data/models/fpl_models.dart';
import '../../../team/data/models/team_models.dart';
import '../usecases/recommendation_engine.dart';

class RecommendationData {
  const RecommendationData({
    required this.result,
    required this.gameweek,
    required this.bootstrap,
    required this.team,
  });

  final RecommendationResult result;
  final Gameweek gameweek;
  final FplBootstrap bootstrap;
  final MyTeam team;
}
