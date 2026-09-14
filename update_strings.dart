import 'dart:io';

void main() {
  final teamFile = File(
    'lib/features/team/presentation/screens/team_view.dart',
  );
  String teamContent = teamFile.readAsStringSync();

  teamContent = teamContent.replaceFirst(
    "label: 'Avg',",
    "label: l10n.averageScore,",
  );
  teamContent = teamContent.replaceFirst(
    "label: 'Highest',",
    "label: l10n.highestScore,",
  );

  teamFile.writeAsStringSync(teamContent);

  final pitchFile = File(
    'lib/features/team/presentation/widgets/pitch_view.dart',
  );
  String pitchContent = pitchFile.readAsStringSync();

  pitchContent = pitchContent.replaceFirst(
    "Text(\n                  'PTS',",
    "Text(\n                  AppLocalizations.of(context).ptsCue,",
  );

  pitchFile.writeAsStringSync(pitchContent);
}
