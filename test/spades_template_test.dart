import 'package:flutter_test/flutter_test.dart';
import 'package:scorecards_app/features/scorecards/templates/spades_template.dart';

/// A finished round. Hand scores keep the bags in the last digit, the way
/// the hand dialog saves them (e.g. bid 5 + 1 bag = "51", set on 5 = "-50").
Map<String, dynamic> round(
  List<String> bids,
  String t1Hand,
  String t2Hand, {
  bool t1Set = false,
  bool t2Set = false,
  Map<String, dynamic> extra = const {},
}) => {
  'p1Bid': bids[0],
  'p2Bid': bids[1],
  'p3Bid': bids[2],
  'p4Bid': bids[3],
  't1Hand': t1Hand,
  't2Hand': t2Hand,
  if (t1Set) 't1Set': true,
  if (t2Set) 't2Set': true,
  ...extra,
};

void main() {
  final spades = SpadesTemplate();
  const names = ['Alex', 'Sam', 'Jordan', 'Riley'];

  group('tricks add up to 13', () {
    test('both teams make their bids', () {
      expect(
        spades.isRoundMathValid(round(['3', '2', '4', '3'], '51', '70')),
        isTrue,
      );
    });

    test('one trick short is caught and explained', () {
      final rounds = [
        round(['3', '2', '4', '3'], '50', '70'),
      ];
      expect(spades.isRoundMathValid(rounds[0]), isFalse);
      expect(
        spades.trickProblem(0, rounds, names),
        'Round 1 adds up to 12 tricks: Alex & Sam bid 5 + 0 bags, '
        'Jordan & Riley bid 7 + 0 bags.',
      );
    });

    test('a set team took fewer than their bid', () {
      // Set on 5 (took at most 4), so the other team took at least 9.
      expect(
        spades.isRoundMathValid(
          round(['3', '2', '4', '3'], '-50', '72', t1Set: true),
        ),
        isTrue,
      );
      expect(
        spades.isRoundMathValid(
          round(['3', '2', '4', '3'], '-50', '70', t1Set: true),
        ),
        isFalse,
      );
    });

    test("a missed nil's tricks aren't in the hand score", () {
      // Alex bid nil and took 2 tricks; Sam made 4 exactly: -100 + 40.
      final r = round(
        ['N', '4', '4', '3'],
        '-60',
        '70',
        extra: {'p1NilSuccess': false},
      );
      expect(spades.isRoundMathValid(r), isTrue);
    });

    test('a missed nil still has to fit in 13', () {
      final rounds = [
        round(
          ['N', '4', '6', '4'],
          '-60',
          '100',
          extra: {'p1NilSuccess': false},
        ),
      ];
      expect(spades.isRoundMathValid(rounds[0]), isFalse);
      expect(
        spades.trickProblem(0, rounds, names),
        'Round 1 adds up to at least 14 tricks: Alex & Sam bid 4 + 0 bags '
        '(missed nil), Jordan & Riley bid 10 + 0 bags.',
      );
    });

    test('a made nil counts no tricks', () {
      final r = round(
        ['N', '4', '5', '3'],
        '141',
        '80',
        extra: {'p1NilSuccess': true},
      );
      expect(spades.isRoundMathValid(r), isTrue);
    });

    test('an unfinished round is not flagged', () {
      final r = round(['3', '2', '4', '3'], '51', '');
      expect(spades.isRoundMathValid(r), isTrue);
    });
  });

  group('adding rounds and finalizing', () {
    test('an earlier round that does not add up blocks adding a round', () {
      final rounds = [
        round(['3', '2', '4', '3'], '50', '70'), // 12 tricks
        round(['3', '2', '4', '3'], '51', '70'),
      ];
      expect(spades.canAddRound(rounds, 4), isFalse);
      expect(spades.isReadyToFinalize(rounds, 4), isFalse);
      expect(spades.firstTrickProblem(rounds, names), startsWith('Round 1 '));
    });

    test('the last round is checked before finalizing', () {
      final rounds = [
        round(['3', '2', '4', '3'], '51', '70'),
        round(['3', '2', '4', '3'], '52', '70'), // 14 tricks
      ];
      expect(spades.isReadyToFinalize(rounds, 4), isFalse);
      expect(
        spades.firstTrickProblem(rounds, names),
        startsWith('Round 2 adds up to 14'),
      );
    });

    test('all rounds adding up can add a round and finalize', () {
      final rounds = [
        round(['3', '2', '4', '3'], '51', '70'),
        round(['4', '4', '2', '2'], '80', '41', t1Set: false),
      ];
      expect(spades.canAddRound(rounds, 4), isTrue);
      expect(spades.isReadyToFinalize(rounds, 4), isTrue);
      expect(spades.firstTrickProblem(rounds, names), isNull);
    });
  });
}
