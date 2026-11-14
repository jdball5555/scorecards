import 'dart:math' as math;
import 'game_metrics_provider.dart';
import '../models/metrics_models.dart';

class NertsMetricsProvider extends GameMetricsProvider {
  @override
  String get gameType => 'Nerts';

  @override
  List<String> getAvailableTileIds(String playerName) {
    if (playerName == 'Group Records')
      return [
        'nertsHighScore',
        'nertsLowScore',
        'nertsWinStreak',
        'nertsRoundWinStreak',
      ];
    List<String> tiles = [
      'yahtzeeWinRate',
      'winRate',
      'avgPoints',
      'avgCardsLeft',
      'avgCardsMiddle',
    ]; // Uses weighted win rate builder
    if (playerName == 'Group Metrics') {
      tiles.insert(0, 'gamesPlayed');
      tiles.remove('yahtzeeWinRate');
      tiles.remove('winRate');
    } else {
      tiles.addAll([
        'nertsHighScore',
        'nertsLowScore',
        'nertsWinStreak',
        'nertsRoundWinStreak',
      ]);
    }
    return tiles;
  }

  @override
  MetricPayload calculateData(
    List<Map<String, dynamic>> games,
    String? playerName,
  ) {
    var payload = MetricPayload();
    bool isTarget(String key) =>
        playerName == null ||
        playerName == 'Group Records' ||
        playerName == 'Group Metrics' ||
        key == playerName;

    Map<String, List<DateTime>> activeWins = {};
    Map<String, List<DateTime>> activeRoundWins = {};

    for (var game in games.reversed) {
      if (!isValidFinalizedGame(game, 'nerts')) continue;
      List<String> pNames = List<String>.from(game['playerNames'] ?? []);
      List<Map<String, dynamic>> rounds = List<Map<String, dynamic>>.from(
        game['rounds'] ?? [],
      );
      if (rounds.isEmpty) continue;
      DateTime gameDate = parseGameDate(game);

      int maxScore = -999999;
      List<int> winners = [];
      for (int i = 0; i < pNames.length; i++) {
        int s =
            int.tryParse(rounds.last['p${i + 1}Total']?.toString() ?? '0') ?? 0;
        if (s > maxScore) {
          maxScore = s;
          winners = [i];
        } else if (s == maxScore) {
          winners.add(i);
        }
      }

      for (int i = 0; i < pNames.length; i++) {
        String pName = pNames[i];
        if (winners.contains(i)) {
          activeWins[pName] = (activeWins[pName] ?? [])..add(gameDate);
          if (isTarget(pName))
            payload.longestWinStreak.update(
              activeWins[pName]!.length,
              pName,
              gameDate,
              isHigh: true,
              streakDates: List.from(activeWins[pName]!),
            );
        } else
          activeWins[pName] = [];

        for (var r in rounds) {
          if (r['p${i + 1}Won'] == true) {
            activeRoundWins[pName] = (activeRoundWins[pName] ?? [])
              ..add(gameDate);
            if (isTarget(pName))
              payload.longestRoundWinStreak.update(
                activeRoundWins[pName]!.length,
                pName,
                gameDate,
                isHigh: true,
                streakDates: List.from(activeRoundWins[pName]!),
              );
          } else
            activeRoundWins[pName] = [];
        }
      }
    }

    for (var key in activeWins.keys)
      if (isTarget(key) &&
          activeWins[key]!.length == payload.longestWinStreak.value &&
          payload.longestWinStreak.value > 0)
        for (var s in payload.longestWinStreak.setters)
          if (s.setter == key) s.isOngoing = true;
    for (var key in activeRoundWins.keys)
      if (isTarget(key) &&
          activeRoundWins[key]!.length == payload.longestRoundWinStreak.value &&
          payload.longestRoundWinStreak.value > 0)
        for (var s in payload.longestRoundWinStreak.setters)
          if (s.setter == key) s.isOngoing = true;

    for (var game in games) {
      if (!isValidFinalizedGame(game, 'nerts')) continue;
      List<String> pNames = List<String>.from(game['playerNames'] ?? []);
      List<Map<String, dynamic>> rounds = List<Map<String, dynamic>>.from(
        game['rounds'] ?? [],
      );

      payload.uniqueGamesPlayed++;
      DateTime gameDate = parseGameDate(game);

      List<int> scores = pNames
          .asMap()
          .entries
          .map(
            (e) =>
                int.tryParse(
                  rounds.last['p${e.key + 1}Total']?.toString() ?? '0',
                ) ??
                0,
          )
          .toList();
      List<int> indices = (playerName != null && !playerName.contains('Group'))
          ? (pNames.indexOf(playerName) != -1
                ? [pNames.indexOf(playerName)]
                : [])
          : List.generate(pNames.length, (i) => i);

      for (int pIndex in indices) {
        payload.gamesPlayed++;

        if (pNames.length > 1) {
          payload.competitiveGamesPlayed++;
          int totalOpp = pNames.length - 1;
          double beaten = 0;
          for (int i = 0; i < pNames.length; i++) {
            if (i == pIndex) continue;
            // Nerts specific logic: Highest Score Wins!
            if (scores[pIndex] > scores[i])
              beaten += 1.0;
            else if (scores[pIndex] == scores[i])
              beaten += 0.5;
          }
          payload.totalOpponents += totalOpp;
          payload.opponentsBeaten += beaten;
        }

        int pScore = scores[pIndex];
        if (pNames.length > 1 && pScore == scores.reduce(math.max)) {
          payload.gamesWon++;
        }
        payload.totalPoints += pScore;
        payload.highestScore.update(
          pScore,
          pNames[pIndex],
          gameDate,
          isHigh: true,
        );
        payload.lowestScore.update(
          pScore,
          pNames[pIndex],
          gameDate,
          isHigh: false,
        );

        for (var r in rounds) {
          payload.roundsPlayed++;
          bool won = r['p${pIndex + 1}Won'] == true;
          payload.totalCardsLeft += won
              ? 0
              : (int.tryParse(
                      r['p${pIndex + 1}CardsLeft']?.toString() ?? '0',
                    ) ??
                    0);
          payload.totalCardsMiddle +=
              int.tryParse(r['p${pIndex + 1}CardsMiddle']?.toString() ?? '0') ??
              0;
        }
      }
    }
    return payload;
  }
}
