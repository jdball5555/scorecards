import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scorecards_app/features/metrics/pages/specific_metrics_screen.dart';

List<MetricDataPoint> scores(int n, {bool winLoss = false}) {
  final r = Random(7);
  return [
    for (int i = 0; i < n; i++)
      MetricDataPoint(
        date: DateTime(2025, 1, 1).add(Duration(days: i * 3)),
        value: winLoss
            ? (r.nextBool() ? 100 : 0)
            : (150 + r.nextInt(150)).toDouble(),
        subtitle: winLoss ? 'Win (300 to 250)' : null,
      ),
  ];
}

void main() {
  for (final size in const [Size(360, 740), Size(1280, 900)]) {
    for (final winLoss in [false, true]) {
      for (final n in [1, 7, 140]) {
        testWidgets(
          '${winLoss ? 'win rate' : 'average score'}, $n games, ${size.width.toInt()} wide',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData.dark(),
                home: SpecificMetricScreen(
                  title: winLoss ? 'Win Rate' : 'Average Score',
                  playerName: 'Sam',
                  dataPoints: scores(n, winLoss: winLoss),
                  unit: winLoss ? '%' : '',
                  scopeDisplay: 'All Groups',
                  gameTypeDisplay: winLoss ? 'Spades' : 'Yahtzee',
                  playerDisplay: 'Sam',
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            // Every range works too.
            for (final label in ['Last 10', 'Last 50', '1M', '1Y', 'All']) {
              final chip = find.text(label);
              if (chip.evaluate().isEmpty) continue;
              await tester.tap(chip.first);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull, reason: label);
            }
            await tester.drag(find.byType(ListView), const Offset(0, -3000));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('games list starts closed and loads 10 at a time', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: SpecificMetricScreen(
          title: 'Average Score',
          playerName: 'Sam',
          dataPoints: scores(34),
          scopeDisplay: 'All Groups',
          gameTypeDisplay: 'Yahtzee',
          playerDisplay: 'Sam',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final page = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    final rows = find.textContaining(', 2025');
    // Closed: only the best/lowest dates in the stat cards mention a date.
    final closedDates = rows.evaluate().length;
    await tester.scrollUntilVisible(find.text('Show'), 300, scrollable: page);
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    expect(rows.evaluate().length, closedDates + 10);
    expect(find.text('Load 10 more  ·  24 left'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Load 10 more'),
      300,
      scrollable: page,
    );
    await tester.tap(find.textContaining('Load 10 more'));
    await tester.pumpAndSettle();
    expect(rows.evaluate().length, closedDates + 20);
    expect(find.text('Load 10 more  ·  14 left'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
