import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scorecards_app/core/shared_widgets/game_request_link.dart';
import 'package:scorecards_app/core/shared_widgets/sleek_notification_banner.dart';
import 'package:scorecards_app/features/settings/pages/feedback_form.dart';

void main() {
  testWidgets('"Request a game" opens feedback with New Game pre-selected', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: globalMessengerKey,
        theme: ThemeData.dark(),
        home: const Scaffold(body: Center(child: GameRequestLink())),
      ),
    );
    await tester.tap(find.textContaining("Want a game that's not here"));
    await tester.pumpAndSettle();

    expect(find.byType(FeedbackFormScreen), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('WHAT GAME DO YOU WANT?'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('WHAT GAME DO YOU WANT?'), findsOneWidget);
    expect(find.textContaining('Which game should we add?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty feedback is not submitted', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: globalMessengerKey,
        theme: ThemeData.dark(),
        home: const FeedbackFormScreen(),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('SUBMIT FEEDBACK'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('SUBMIT FEEDBACK'));
    await tester.pump();
    expect(find.text('Missing Info'), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
  });
}
