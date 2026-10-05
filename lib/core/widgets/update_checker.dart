import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:upgrader/upgrader.dart';

class UpdateChecker extends StatefulWidget {
  const UpdateChecker({super.key, required this.child});

  final Widget child;

  @override
  State<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<UpdateChecker> {
  @override
  void initState() {
    super.initState();
    _checkForAndroidUpdate();
  }

  Future<void> _checkForAndroidUpdate() async {
    if (!kReleaseMode || !Platform.isAndroid) return;
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (error) {
      log('Error checking for update: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) return UpgradeAlert(child: widget.child);
    return widget.child;
  }
}
