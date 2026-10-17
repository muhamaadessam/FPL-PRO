import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';

/// The app's Google Play listing.
final playStoreUri = Uri.parse(
  'https://play.google.com/store/apps/details?id=me.muhammadessam.FPLpro',
);

/// The Google Group whose members can install the closed-testing build.
/// Joining it is what lets the Play listing open for a new tester.
final testersGroupUri = Uri.parse('https://groups.google.com/g/essam-apps');

/// Tells web visitors that team management (lineup, armbands, chips and
/// transfers) lives in the mobile app, which can sign in to the official FPL
/// account; the browser cannot.
class GetAppNotice extends StatelessWidget {
  const GetAppNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final textStyle = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      height: 1.35,
      color: colors.onPrimaryContainer,
    );
    const buttonText = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700);
    return Container(
      key: const Key('get-app-notice'),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 8, 8),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.phone_android_rounded,
                size: 18,
                color: colors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${l10n.getAppForManagement} ${l10n.joinTestersFirst}',
                  style: textStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 6,
            runSpacing: 4,
            children: [
              TextButton(
                key: const Key('join-testers-button'),
                onPressed: () => launchUrl(
                  testersGroupUri,
                  mode: LaunchMode.externalApplication,
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: buttonText,
                ),
                child: Text(l10n.joinTestersAction),
              ),
              FilledButton.tonal(
                key: const Key('get-app-button'),
                onPressed: () => launchUrl(
                  playStoreUri,
                  mode: LaunchMode.externalApplication,
                ),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: buttonText,
                ),
                child: Text(l10n.getAppAction),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
