import 'dart:math' as math;
import 'game_metrics_provider.dart';
import '../models/metrics_models.dart';

class NinesMetricsProvider extends GameMetricsProvider {
  @override
  String get gameType => 'Nines';

  @override
  List<String> getAvailableTileIds(String playerName) {
    if (playerName == 'Group Records')
      return ['ninesHighScore', 'ninesLowScore', 'ninesWinStreak'];
    List<String> tiles = [
      'yahtzeeWinRate',
      'winRate',
      'avgPoints',
    ]; // Uses the weighted win rate builder!
    if (playerName == 'Group Metrics') {
      tiles.insert(0, 'gamesPlayed');
      tiles.remove('yahtzeeWinRate');
      tiles.remove('winRate');
    } else {
      tiles.addAll(['ninesHighScore', 'ninesLowScore', 'ninesWinStreak']);
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

    // 1. Calculate Streaks & Records
    for (var game in games.reversed) {
      if (!isValidFinalizedGame(game, 'nines')) continue;
      List<String> pNames = List<String>.from(game['playerNames'] ?? []);
      List<Map<String, dynamic>> rounds = List<Map<String, dynamic>>.from(
        game['rounds'] ?? [],
      );
      if (rounds.isEmpty) continue;
      DateTime gameDate = parseGameDate(game);

      int minScore = 999999;
      List<int> winners = [];
      for (int i = 0; i < pNames.length; i++) {
        int s =
            int.tryParse(rounds.last['p${i + 1}Total']?.toString() ?? '0') ?? 0;
        if (s < minScore) {
          minScore = s;
          winners = [i];
        } else if (s == minScore) {
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
        } else {
          activeWins[pName] = [];
        }
      }
    }

    for (var key in activeWins.keys) {
      if (isTarget(key) &&
          activeWins[key]!.length == payload.longestWinStreak.value &&
          payload.longestWinStreak.value > 0) {
        for (var s in payload.longestWinStreak.setters) {
          if (s.setter == key) s.isOngoing = true;
        }
      }
    }

    // 2. Tally Standard Averages and Win Rates
    for (var game in games) {
      if (!isValidFinalizedGame(game, 'nines')) continue;
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
            // Nines specific logic: Lowest Score Wins!
            if (scores[pIndex] < scores[i])
              beaten += 1.0;
            else if (scores[pIndex] == scores[i])
              beaten += 0.5;
          }
          payload.totalOpponents += totalOpp;
          payload.opponentsBeaten += beaten;
        }

        if (pNames.length > 1 && scores[pIndex] == scores.reduce(math.min)) {
          payload.gamesWon++;
        }

        payload.totalPoints += scores[pIndex];
        payload.highestScore.update(
          scores[pIndex],
          pNames[pIndex],
          gameDate,
          isHigh: true,
        );
        payload.lowestScore.update(
          scores[pIndex],
          pNames[pIndex],
          gameDate,
          isHigh: false,
        );
      }
    }
    return payload;
  }
}
