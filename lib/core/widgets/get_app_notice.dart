import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';

/// The app's Google Play listing.
final playStoreUri = Uri.parse(
  'https://play.google.com/store/apps/details?id=me.muhammadessam.FPLpro',
);

/// Tells web visitors that team management (lineup, armbands, chips and
/// transfers) lives in the mobile app, which can sign in to the official FPL
/// account; the browser cannot.
class GetAppNotice extends StatelessWidget {
  const GetAppNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Container(
      key: const Key('get-app-notice'),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.phone_android_rounded, size: 18, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.getAppForManagement,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: colors.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            key: const Key('get-app-button'),
            onPressed: () =>
                launchUrl(playStoreUri, mode: LaunchMode.externalApplication),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(l10n.getAppAction),
          ),
        ],
      ),
    );
  }
}
