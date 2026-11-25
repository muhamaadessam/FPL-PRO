import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fantasy_pl/core/widgets/refresh_on_resume.dart';

void main() {
  Future<int> resumes(WidgetTester tester, Duration gap) async {
    var calls = 0;
    await tester.pumpWidget(
      RefreshOnResume(
        minGap: gap,
        onRefresh: () => calls++,
        child: const SizedBox(),
      ),
    );
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    return calls;
  }

  testWidgets('refreshes when the data is old', (tester) async {
    expect(await resumes(tester, Duration.zero), 1);
  });

  testWidgets('keeps fresh data on a quick switch', (tester) async {
    expect(await resumes(tester, const Duration(minutes: 5)), 0);
  });
}
