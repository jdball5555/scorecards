import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scorecards_app/core/shared_widgets/sleek_notification_banner.dart';
import 'package:scorecards_app/features/scorecards/scorecard_template_create/template_create_screen.dart';
import 'package:scorecards_app/features/scorecards/scorecard_template_create/template_scorecard_editor.dart';
import 'package:scorecards_app/features/scorecards/templates/custom_template.dart';
import 'package:scorecards_app/features/scorecards/templates/playable_data_entry_dialog.dart';

Map<String, dynamic> settings({
  String win = 'highest_score',
  int target = 0,
  int inputs = 1,
  List<String> rows = const ['round_0'],
  List<String> blueprint = const ['player_core'],
}) => {
  'gameType': 'Test Game',
  'gameMode': 'player',
  'minPlayers': 2,
  'maxPlayers': 8,
  'winCondition': win,
  'targetValue': target,
  'layoutSettings': {
    'inputsPerPlayer': inputs,
    'showTotalRow': true,
    'blueprintColumns': blueprint,
    'lockedLeftColumns': <String>[],
    'lockedRightColumns': <String>[],
    'layoutRows': rows,
    'customNames': {'custom_row_1': 'Bonus', 'custom_col_1': 'Bid'},
  },
  'cellConfigs': <String, dynamic>{},
};

/// Simulates the scoring screen's update cycle after a cell is edited.
void update(
  CustomTemplate t,
  List<Map<String, dynamic>> rounds,
  int players,
  Map<String, dynamic> s,
) {
  t.recalculateTotals(rounds, players, customSettings: s);
  if (t.onDataUpdated(rounds, players, customSettings: s)) {
    t.recalculateTotals(rounds, players, customSettings: s);
  }
}

Future<void> setScreen(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> tapVisible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
}

Widget app(Widget home) => MaterialApp(
  scaffoldMessengerKey: globalMessengerKey,
  theme: ThemeData.dark(),
  home: home,
);

void main() {
  group('CustomTemplate scoring', () {
    final t = CustomTemplate();

    test('auto-adds rounds, totals and highest score wins', () {
      final s = settings();
      final rounds = [t.createNewRound(1, 2)];
      rounds[0]['player_0_Score'] = 10;
      update(t, rounds, 2, s);
      expect(rounds.length, 1, reason: 'round not complete yet');
      rounds[0]['player_1_Score'] = 4;
      update(t, rounds, 2, s);
      expect(rounds.length, 2, reason: 'new round once round 1 is filled');

      rounds[1]['player_0_Score'] = 5;
      rounds[1]['player_1_Score'] = 30;
      update(t, rounds, 2, s);

      expect(t.playerTotals(rounds, 2, customSettings: s), [15, 34]);
      expect(t.isReadyToFinalize(rounds, 2, customSettings: s), isTrue);
      expect(t.winnerIndices(rounds, 2, customSettings: s), [1]);
      expect(
        t.getWinnerDeclaration(['Ann', 'Bob'], rounds, customSettings: s),
        startsWith('Bob wins with 34 points!'),
      );
    });

    test('cannot finalize with a half-filled round', () {
      final s = settings();
      final rounds = [t.createNewRound(1, 2)];
      rounds[0]['player_0_Score'] = 10;
      update(t, rounds, 2, s);
      expect(t.isReadyToFinalize(rounds, 2, customSettings: s), isFalse);
    });

    test('lowest score when someone reaches the target', () {
      final s = settings(win: 'lowest_when_reached_score', target: 50);
      final rounds = [t.createNewRound(1, 2)];
      rounds[0]['player_0_Score'] = 20;
      rounds[0]['player_1_Score'] = 30;
      update(t, rounds, 2, s);
      expect(t.isReadyToFinalize(rounds, 2, customSettings: s), isFalse);
      rounds[1]['player_0_Score'] = 5;
      rounds[1]['player_1_Score'] = 25; // Bob hits 55
      update(t, rounds, 2, s);
      expect(rounds.length, 2, reason: 'no new round once target reached');
      expect(t.isReadyToFinalize(rounds, 2, customSettings: s), isTrue);
      expect(t.winnerIndices(rounds, 2, customSettings: s), [0]);
    });

    test('fixed number of rounds must all be played', () {
      final s = settings(
        win: 'lowest_after_rounds',
        target: 3,
        rows: ['round_0', 'round_1', 'round_2'],
      );
      final rounds = [t.createNewRound(1, 2)];
      update(t, rounds, 2, s);
      expect(rounds.length, 3);
      for (int r = 0; r < 2; r++) {
        rounds[r]['player_0_Score'] = 1;
        rounds[r]['player_1_Score'] = 2;
      }
      update(t, rounds, 2, s);
      expect(rounds.length, 3, reason: 'fixed games never add rounds');
      expect(t.isReadyToFinalize(rounds, 2, customSettings: s), isFalse);
      rounds[2]['player_0_Score'] = 9;
      rounds[2]['player_1_Score'] = 0;
      update(t, rounds, 2, s);
      expect(t.isReadyToFinalize(rounds, 2, customSettings: s), isTrue);
      expect(t.winnerIndices(rounds, 2, customSettings: s), [1]); // 4 < 11
    });

    test('multiple inputs per player are summed', () {
      final s = settings(inputs: 2);
      final rounds = [t.createNewRound(1, 2)];
      rounds[0]
        ..['player_0_0_Score'] = 3
        ..['player_0_1_Score'] = 4
        ..['player_1_0_Score'] = 10
        ..['player_1_1_Score'] = -2;
      update(t, rounds, 2, s);
      expect(t.playerTotals(rounds, 2, customSettings: s), [7, 8]);
      expect(rounds.length, 2);
    });

    test('custom rows are optional but count toward totals', () {
      final s = settings(rows: ['round_0', 'custom_row_1']);
      final rounds = [t.createNewRound(1, 2)];
      rounds[0]['player_0_Score'] = 10;
      rounds[0]['player_1_Score'] = 10;
      update(t, rounds, 2, s);
      expect(t.isReadyToFinalize(rounds, 2, customSettings: s), isTrue);
      rounds[1]['player_1_Score'] = 5; // bonus row
      update(t, rounds, 2, s);
      expect(t.playerTotals(rounds, 2, customSettings: s), [10, 15]);
    });

    test('ties are reported', () {
      final s = settings();
      final rounds = [
        {'id': 'round_0', 'player_0_Score': 5, 'player_1_Score': 5},
      ];
      expect(
        t.getWinnerDeclaration(['Ann', 'Bob'], rounds, customSettings: s),
        startsWith("It's a tie between Ann & Bob"),
      );
    });
  });

  group('PlayableDataEntryDialog', () {
    Future<Map?> runDialog(
      WidgetTester tester,
      Map<String, dynamic> config, {
      Map<String, dynamic>? raw,
      dynamic score,
      Future<void> Function()? interact,
    }) async {
      Map? result;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showDialog(
                      context: context,
                      builder: (_) => PlayableDataEntryDialog(
                        config: config,
                        defaultTitle: 'Round 1: Ann',
                        initialRawInputs: raw,
                        initialScore: score,
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      if (interact != null) await interact();
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('hidden calculated score still sums the inputs', (
      tester,
    ) async {
      final result = await runDialog(
        tester,
        {
          'inputs': [
            {'type': 'standard', 'header': 'Tricks'},
            {'type': 'standard', 'header': 'Bonus'},
          ],
          'showCalcScore': false,
        },
        interact: () async {
          await tester.enterText(find.byType(TextField).at(0), '7');
          await tester.enterText(find.byType(TextField).at(1), '3');
        },
      );
      expect(result?['score'], 10);
    });

    testWidgets('re-opening a cell keeps the previous values', (tester) async {
      final result = await runDialog(
        tester,
        {
          'inputs': [
            {'type': 'standard'},
            {
              'type': 'toggle',
              'name': 'Won?',
              'worthPoints': true,
              'points': 5,
            },
          ],
        },
        raw: {'input_0': '12', 'input_1': true},
        score: 17,
      );
      expect(result?['score'], 17);
      expect(result?['rawInputs'], {'input_0': '12', 'input_1': true});
    });

    testWidgets('cell saved with no inputs still accepts a score', (
      tester,
    ) async {
      final result = await runDialog(tester, {
        'inputs': [],
      }, interact: () => tester.enterText(find.byType(TextField).first, '42'));
      expect(result?['score'], 42);
    });
  });

  group('Layout (no overflow on small phones)', () {
    testWidgets('setup questions walk through to the editor', (tester) async {
      await setScreen(tester, const Size(320, 568)); // iPhone SE (1st gen)
      await tester.pumpWidget(
        app(const TemplateCreateScreen(isGroupGame: false)),
      );
      await tapVisible(tester, find.text("Let's Go"));
      await tester.pumpAndSettle();

      // Empty name shows an error instead of silently doing nothing.
      await tapVisible(tester, find.text('Next'));
      await tester.pump();
      expect(find.textContaining('Please enter a name'), findsOneWidget);

      // Built-in names are rejected.
      await tester.enterText(find.byType(TextField), 'Spades');
      await tapVisible(tester, find.text('Next'));
      await tester.pump();
      expect(find.textContaining('already a built-in'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Oh Hell');
      await tapVisible(tester, find.text('Next'));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('Teams Only'));
      await tapVisible(tester, find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.textContaining('teams'), findsWidgets);
      await tapVisible(tester, find.text('Next'));
      await tester.pumpAndSettle();

      await tapVisible(
        tester,
        find.text('Most points after locked amount of rounds'),
      );
      await tester.pump();
      await tapVisible(tester, find.text('Finish'));
      await tester.pump();
      expect(find.textContaining('how many rounds'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byType(TextField),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.enterText(find.byType(TextField), '5');
      await tapVisible(tester, find.text('Finish'));
      await tester.pumpAndSettle();

      expect(find.byType(TemplateScorecardEditor), findsOneWidget);
      expect(find.text('OH HELL'), findsOneWidget);
      // 5 fixed rounds -> rows 1..5
      expect(find.text('5'), findsWidgets);
    });

    testWidgets('scan prefill skips intro and shows review banner', (
      tester,
    ) async {
      await setScreen(tester, const Size(360, 640));
      await tester.pumpWidget(
        app(
          const TemplateCreateScreen(
            isGroupGame: false,
            initialSettings: {
              'gameType': 'Rummikub',
              'minPlayers': 2,
              'maxPlayers': 4,
              'winCondition': 'first_to_score',
              'targetValue': 500,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Review Scan'), findsOneWidget);
      expect(find.textContaining('Pre-filled from your scan'), findsOneWidget);
      expect(find.text('Rummikub'), findsOneWidget);
    });

    testWidgets('editor: configure a cell and add columns', (tester) async {
      await setScreen(tester, const Size(320, 568));
      await tester.pumpWidget(
        app(TemplateScorecardEditor(customSettings: settings())),
      );
      await tester.pumpAndSettle();

      // Tap the blueprint score cell (row 1) -> builder opens with a
      // ready-to-use standard input.
      final cell = find.byWidgetPredicate(
        (w) => w is GestureDetector && w.onTap != null && w.child is Padding,
      );
      expect(cell, findsWidgets);
      await tester.tap(cell.first);
      await tester.pumpAndSettle();
      expect(find.text('STANDARD INPUT'), findsOneWidget);
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      expect(find.text('✓'), findsWidgets);

      // Add 3 more internal inputs to force the crowded / scrolling layout.
      for (int i = 0; i < 3; i++) {
        await tester.tapAt(
          tester.getCenter(find.text('BLUEPRINT\n(Player/Team)')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add internal input'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('gameplay grid with 8 players scrolls instead of squashing', (
      tester,
    ) async {
      await setScreen(tester, const Size(360, 640));
      final t = CustomTemplate();
      final s = settings(blueprint: ['player_core', 'custom_col_1']);
      final rounds = [t.createNewRound(1, 8)];
      await tester.pumpWidget(
        app(
          Scaffold(
            body: SingleChildScrollView(
              child: LayoutBuilder(
                builder: (context, c) => t.buildGrid(
                  context: context,
                  constraints: c,
                  playerNames: List.generate(8, (i) => 'Player ${i + 1}'),
                  rounds: rounds,
                  isFinalized: false,
                  onDataChanged: () {},
                  onPlayerTap: (_) {},
                  customSettings: s,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(SingleChildScrollView), findsNWidgets(2));
      expect(find.text('Bid'), findsNWidgets(8));
      expect(tester.takeException(), isNull);
    });
  });
}
