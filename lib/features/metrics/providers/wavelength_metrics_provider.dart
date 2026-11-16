import 'dart:math' as math;
import 'game_metrics_provider.dart';
import '../models/metrics_models.dart';

class WavelengthMetricsProvider extends GameMetricsProvider {
  @override
  String get gameType => 'Wavelength';

  @override
  List<String> getAvailableTileIds(String playerName) {
    if (playerName == 'Group Records') return ['standardWinStreak'];
    List<String> tiles = ['winRate', 'avgPoints', 'wavelengthRoundsTo10'];
    if (playerName == 'Group Metrics') {
      tiles.insert(0, 'gamesPlayed');
      tiles.remove('winRate');
    } else {
      tiles.addAll(['standardWinStreak']);
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

    for (var game in games.reversed) {
      if (!isValidFinalizedGame(game, gameType)) continue;
      List<String> pNames = List<String>.from(game['playerNames'] ?? []);
      int teams = pNames.length ~/ 2;
      if (teams == 0) continue;

      List<Map<String, dynamic>> rounds = List<Map<String, dynamic>>.from(
        game['rounds'] ?? [],
      );
      if (rounds.isEmpty) continue;
      DateTime gameDate = parseGameDate(game);

      int maxScore = -999999;
      List<int> winners = [];
      for (int t = 0; t < teams; t++) {
        int s =
            int.tryParse(rounds.last['t${t + 1}Total']?.toString() ?? '0') ?? 0;
        if (s > maxScore) {
          maxScore = s;
          winners = [t];
        } else if (s == maxScore) {
          winners.add(t);
        }
      }

      for (int t = 0; t < teams; t++) {
        String teamName = "${pNames[t * 2]} & ${pNames[t * 2 + 1]}";
        // To simplify streaking, if we just use player names:
        for (int p = 0; p < 2; p++) {
          String pName = pNames[t * 2 + p];
          if (winners.contains(t) && teams > 1) {
            // Competitive win
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
        }
      }
    }

    for (var key in activeWins.keys)
      if (isTarget(key) &&
          activeWins[key]!.length == payload.longestWinStreak.value &&
          payload.longestWinStreak.value > 0)
        for (var s in payload.longestWinStreak.setters)
          if (s.setter == key) s.isOngoing = true;

    for (var game in games) {
      if (!isValidFinalizedGame(game, gameType)) continue;
      List<String> pNames = List<String>.from(game['playerNames'] ?? []);
      int teams = pNames.length ~/ 2;
      if (teams == 0) continue;

      List<Map<String, dynamic>> rounds = List<Map<String, dynamic>>.from(
        game['rounds'] ?? [],
      );

      payload.uniqueGamesPlayed++;
      DateTime gameDate = parseGameDate(game);

      List<int> scores = [];
      for (int t = 0; t < teams; t++) {
        scores.add(
          int.tryParse(rounds.last['t${t + 1}Total']?.toString() ?? '0') ?? 0,
        );
      }

      List<int> pIndices = (playerName != null && !playerName.contains('Group'))
          ? (pNames.indexOf(playerName) != -1
                ? [pNames.indexOf(playerName)]
                : [])
          : List.generate(pNames.length, (i) => i);

      for (int pIndex in pIndices) {
        payload.gamesPlayed++;
        int tIndex = pIndex ~/ 2;

        if (teams > 1) {
          payload.competitiveGamesPlayed++;
          int totalOpp = teams - 1;
          double beaten = 0;
          for (int i = 0; i < teams; i++) {
            if (i == tIndex) continue;
            // Highest Score Wins
            if (scores[tIndex] > scores[i])
              beaten += 1.0;
            else if (scores[tIndex] == scores[i])
              beaten += 0.5;
          }
          payload.totalOpponents += totalOpp;
          payload.opponentsBeaten += beaten;
        }

        int pScore = scores[tIndex];
        if (teams > 1 && pScore == scores.reduce(math.max)) {
          payload.gamesWon++;
        }

        payload.totalPoints += pScore;

        // Compute Rounds to 10 points
        int roundReached10 = -1;
        for (int r = 0; r < rounds.length; r++) {
          int runningTotal =
              int.tryParse(
                rounds[r]['t${tIndex + 1}Total']?.toString() ?? '0',
              ) ??
              0;
          if (runningTotal >= 10) {
            roundReached10 = r + 1; // 1-indexed round number
            break;
          }
        }

        if (roundReached10 != -1) {
          payload.gamesReached10Points++;
          payload.totalRoundsTo10Points += roundReached10;
        }

        String teamName = "${pNames[tIndex * 2]} & ${pNames[tIndex * 2 + 1]}";
        payload.highestScore.update(pScore, teamName, gameDate, isHigh: true);
        payload.lowestScore.update(pScore, teamName, gameDate, isHigh: false);
      }
    }
    return payload;
  }
}
