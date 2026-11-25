import 'package:flutter/widgets.dart';

/// Calls [onRefresh] when the app returns to the foreground after its data
/// has had time to go out of date.
class RefreshOnResume extends StatefulWidget {
  const RefreshOnResume({
    super.key,
    required this.onRefresh,
    required this.child,
    this.minGap = const Duration(minutes: 5),
  });

  final VoidCallback onRefresh;
  final Widget child;

  /// Quick app switches keep what is on screen.
  final Duration minGap;

  @override
  State<RefreshOnResume> createState() => _RefreshOnResumeState();
}

class _RefreshOnResumeState extends State<RefreshOnResume> {
  late final AppLifecycleListener _listener;
  DateTime _lastRefresh = DateTime.now();

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onResume: () {
        final now = DateTime.now();
        if (now.difference(_lastRefresh) < widget.minGap) return;
        _lastRefresh = now;
        widget.onRefresh();
      },
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
