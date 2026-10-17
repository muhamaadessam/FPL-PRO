import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Every location the app can show. Web builds expose these as real paths,
/// so each page has its own link.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const loginWeb = '/login/web';

  static const home = '/home';
  static const manageTeam = '/home/manage';
  static const tips = '/tips';
  static const analysis = '/tips/analysis';
  static const players = '/tips/players';
  static const compare = '/tips/compare';
  static const matches = '/matches';
  static const leagues = '/leagues';
  static const settings = '/settings';
  static const privacy = '/settings/privacy';

  static String league(int id) => '$leagues/$id';
  static String team(int entryId) => '/team/$entryId';

  /// Top-level tabs of the dashboard, in navigation order.
  static const tabs = [home, tips, matches, leagues, settings];

  /// Whether [location] belongs to the signed-in dashboard.
  static bool isDashboard(String location) => tabs.any(
    (tab) => location == tab || location.startsWith('$tab/'),
  );
}

/// Opens [page] at [location].
///
/// Pages whose data cannot be rebuilt from the URL travel as the route's
/// `extra`; reloading such a link falls back to its parent page. Without a
/// router (widget tests) the page is pushed directly.
Future<T?> pushPage<T extends Object?>(
  BuildContext context,
  String location,
  Widget page,
) {
  if (GoRouter.maybeOf(context) != null) {
    return context.push<T>(location, extra: page);
  }
  return Navigator.of(
    context,
  ).push<T>(MaterialPageRoute<T>(builder: (_) => page));
}
