import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:upgrader/upgrader.dart';

/// Prompts for a newer store version on Android (Google Play in-app updates)
/// and iOS (App Store lookup). The check runs on launch and every time the
/// app comes back to the foreground, so a release published while the app was
/// in the background is still offered.
class UpdateChecker extends StatefulWidget {
  const UpdateChecker({super.key, required this.child});

  final Widget child;

  @override
  State<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<UpdateChecker>
    with WidgetsBindingObserver {
  /// Resuming repeatedly must not hammer Play or nag after a dismissed prompt.
  static const _minCheckGap = Duration(hours: 1);

  final Upgrader _upgrader = Upgrader(
    durationUntilAlertAgain: const Duration(hours: 12),
  );
  DateTime? _lastAndroidCheck;
  bool _checking = false;

  // In-app updates only exist for builds installed from Google Play.
  bool get _androidUpdatesEnabled =>
      kReleaseMode &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkForAndroidUpdate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkForAndroidUpdate();
  }

  Future<void> _checkForAndroidUpdate() async {
    if (!_androidUpdatesEnabled || _checking) return;
    final last = _lastAndroidCheck;
    if (last != null && DateTime.now().difference(last) < _minCheckGap) return;
    _checking = true;
    try {
      final info = await InAppUpdate.checkForUpdate();
      _lastAndroidCheck = DateTime.now();

      if (info.installStatus == InstallStatus.downloaded) {
        await InAppUpdate.completeFlexibleUpdate();
        return;
      }
      final availability = info.updateAvailability;
      if (availability ==
          UpdateAvailability.developerTriggeredUpdateInProgress) {
        // An immediate update was interrupted; Play resumes it.
        await InAppUpdate.performImmediateUpdate();
      } else if (availability == UpdateAvailability.updateAvailable) {
        if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        } else if (info.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (error) {
      log('Error checking for update: $error');
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // The iOS alert re-checks the App Store itself when the app resumes.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return UpgradeAlert(
        upgrader: _upgrader,
        showIgnore: false,
        child: widget.child,
      );
    }
    return widget.child;
  }
}
