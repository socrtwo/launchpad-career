import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:launchpad_app/src/app/app.dart';
import 'package:launchpad_app/src/features/goal/goal_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('end to end: choose a goal and continue', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LaunchpadApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Prepare for interviews'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.byType(GoalPage), findsOneWidget);
    expect(find.text('What happens next'), findsOneWidget);
  });
}
