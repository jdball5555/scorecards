import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scorecards_app/core/shared_widgets/sleek_notification_banner.dart';
import 'package:scorecards_app/features/premium/premium_beta.dart';
import 'package:scorecards_app/features/settings/pages/feedback_form.dart';

void main() {
  Future<void> pumpFeedback(WidgetTester tester, {required bool premium}) {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          premiumBetaProvider.overrideWith((ref) => Stream.value(premium)),
        ],
        child: MaterialApp(
          scaffoldMessengerKey: globalMessengerKey,
          theme: ThemeData.dark(),
          home: const FeedbackFormScreen(),
        ),
      ),
    );
  }

  testWidgets('template feedback locations need premium beta', (tester) async {
    await pumpFeedback(tester, premium: false);
    await tester.pumpAndSettle();
    expect(find.text('Custom Builder'), findsNothing);
    expect(find.text('AI Rulebook Scan'), findsNothing);
    expect(find.text('Metrics'), findsOneWidget);
  });

  testWidgets('premium beta accounts see them', (tester) async {
    await pumpFeedback(tester, premium: true);
    await tester.pumpAndSettle();
    expect(find.text('Custom Builder'), findsOneWidget);
    expect(find.text('AI Rulebook Scan'), findsOneWidget);
  });

  testWidgets('the Settings note is small and says Premium beta', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PremiumBetaBadge())),
    );
    expect(find.text('Premium beta'), findsOneWidget);
  });
}
