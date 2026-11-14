import 'package:flutter_test/flutter_test.dart';
import 'package:scorecards_app/features/scorecards/scan/rulebook_parser.dart';

void main() {
  group('RulebookParser', () {
    test('first-to target score, player range and title', () {
      final r = RulebookParser.parse('''
RUMMIKUB
Official Rules
For 2 to 4 players, ages 8+
The first player to reach 500 points wins the game.
''');
      expect(r.gameName, 'Rummikub');
      expect(r.minPlayers, 2);
      expect(r.maxPlayers, 4);
      expect(r.winCondition, 'first_to_score');
      expect(r.targetValue, 500);
      expect(r.gameMode, 'player');
      expect(r.foundAnything, isTrue);
    });

    test('lowest score when someone reaches a target (Hearts style)', () {
      final r = RulebookParser.parse('''
Hearts
3-6 Players
The game ends when a player reaches 100 points.
The player with the lowest score wins.
''');
      expect(r.winCondition, 'lowest_when_reached_score');
      expect(r.targetValue, 100);
      expect(r.minPlayers, 3);
      expect(r.maxPlayers, 6);
    });

    test('fixed rounds written as words, team play', () {
      final r = RulebookParser.parse('''
Played by four players in two partnerships.
The game lasts ten rounds. Most points after the last round wins.
''');
      expect(r.winCondition, 'highest_after_rounds');
      expect(r.targetValue, 10);
      expect(r.gameMode, 'team');
    });

    test('lowest after fixed rounds', () {
      final r = RulebookParser.parse(
        'Golf is played over 9 hands. The player with the fewest points wins.',
      );
      expect(r.winCondition, 'lowest_after_rounds');
      expect(r.targetValue, 9);
    });

    test('comma thousands and "play to"', () {
      final r = RulebookParser.parse('Teams play to 1,000 points.');
      expect(r.winCondition, 'first_to_score');
      expect(r.targetValue, 1000);
    });

    test('labelled player count and "or more"', () {
      expect(RulebookParser.parse('Players: 3 - 5').minPlayers, 3);
      expect(RulebookParser.parse('Players: 3 - 5').maxPlayers, 5);
      final more = RulebookParser.parse('For 3 or more players');
      expect(more.minPlayers, 3);
      expect(more.maxPlayers, 12);
    });

    test('"first one to reach" is not mangled by number-word conversion', () {
      final r = RulebookParser.parse('The first one to reach 250 wins!');
      expect(r.winCondition, 'first_to_score');
      expect(r.targetValue, 250);
    });

    test('either mode', () {
      final r = RulebookParser.parse(
        'Can be played individually or in teams of two.',
      );
      expect(r.gameMode, 'either');
    });

    test('nothing recognisable falls back to defaults', () {
      final r = RulebookParser.parse('lorem ipsum dolor sit amet 12');
      expect(r.winCondition, 'highest_score');
      expect(r.targetValue, 0);
      expect(r.minPlayers, isNull);
      final s = r.toSettings();
      expect(s['gameType'], 'Custom Scorecard');
      expect(s['minPlayers'], 2);
      expect(s['maxPlayers'], 8);
    });

    test('section headings are not mistaken for the title', () {
      final r = RulebookParser.parse('''
OBJECT OF THE GAME
Scoring
Be the first to score 61 points.
''');
      expect(r.gameName, isNull);
      expect(r.targetValue, 61);
    });
  });
}
