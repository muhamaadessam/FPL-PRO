import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'fixtures_view.dart';

class PublicMatchesPage extends StatelessWidget {
  const PublicMatchesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.matches)),
      body: const FixturesView(),
    );
  }
}
