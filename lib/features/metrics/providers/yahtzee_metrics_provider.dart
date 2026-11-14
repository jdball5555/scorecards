import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_metrics_provider.dart';
import '../models/metrics_models.dart';
import '../pages/specific_metrics_screen.dart';

class YahtzeeMetricsProvider extends GameMetricsProvider {
  @override
  String get gameType => 'Yahtzee';

  @override
  List<String> getAvailableTileIds(String playerName) {
    if (playerName == 'Group Records')
      return [
        'yahtzeeHighScore',
        'yahtzeeLowScore',
        'yahtzeeHighTop',
        'yahtzeeHighBottom',
        'yahtzeeMostYahtzees',
        'yahtzeeUpperStreak',
        'yahtzee300Streak',
        'yahtzeeWinStreak',
      ];

    // --- MOVED yahtzeeWinRate TO THE FRONT ---
    List<String> tiles = [
      'yahtzeeWinRate',
      'yahtzeeAvgScore',
      'yahtzeeAvgUpper',
      'yahtzeeAvgLower',
      'yahtzeeUpper',
      'yahtzeeRolls',
      'yahtzeeZeros',
    ];

    if (playerName == 'Group Metrics') {
      tiles.insert(0, 'gamesPlayed');
      tiles.remove('yahtzeeWinRate');
    } else {
      tiles.addAll([
        'yahtzeeHighScore',
        'yahtzeeLowScore',
        'yahtzeeHighTop',
        'yahtzeeHighBottom',
        'yahtzeeMostYahtzees',
        'yahtzeeUpperStreak',
        'yahtzee300Streak',
        'yahtzeeWinStreak',
      ]);
    }
    return tiles;
  }

  @override
  VoidCallback? getOnTapCallback(
    BuildContext context,
    String tileId,
    String playerName,
    List<Map<String, dynamic>> lifetimeGames,
    String scopeDisplay,
    String gameTypeDisplay,
    String playerDisplay,
  ) {
    if (playerName == 'Group Metrics' || playerName == 'Group Records')
      return null;

    if (tileId == 'yahtzeeAvgScore') {
      return () {
        List<MetricDataPoint> points = [];
        for (var game in lifetimeGames) {
          if (!isValidFinalizedGame(game, 'yahtzee')) continue;
          List<String> pNames = List<String>.from(game['playerNames'] ?? []);
          int pIndex = pNames.indexOf(playerName);
          if (pIndex == -1) continue;

          List<Map<String, dynamic>> rounds = List<Map<String, dynamic>>.from(
            game['rounds'] ?? [],
          );
          int score = _getYahtzeeScore(rounds, pIndex);
          points.add(
            MetricDataPoint(date: parseGameDate(game), value: score.toDouble()),
          );
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SpecificMetricScreen(
              title: "Average Score",
              playerName: playerName,
              dataPoints: points,
              isHigherBetter: true,
              scopeDisplay: scopeDisplay,
              gameTypeDisplay: gameTypeDisplay,
              playerDisplay: playerDisplay,
            ),
          ),
        );
      };
    }
    return null;
  }

  int _getYahtzeeScore(List<Map<String, dynamic>> rounds, int pIndex) {
    int score = 0;
    int upper = 0;
    for (var r in rounds) {
      String? cat = r['p${pIndex + 1}Category'] ?? r['category'];
      int val = int.tryParse(r['p${pIndex + 1}Score']?.toString() ?? '0') ?? 0;
      if (cat != null &&
          ['Aces', 'Twos', 'Threes', 'Fours', 'Fives', 'Sixes'].contains(cat)) {
        upper += val;
      }
      if (cat != 'YAHTZEE BONUS') score += val;

      var yb = r['p${pIndex + 1}YahtzeeBonus'];
      if (yb == true || yb == 'true')
        score += 100;
      else if (yb != null)
        score += (int.tryParse(yb.toString()) ?? 0);

      if (cat == 'YAHTZEE BONUS') score += val;
    }
    if (upper >= 63) score += 35;
    return score;
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

    Map<String, List<DateTime>> activeUpper = {};
    Map<String, List<DateTime>> active300 = {};
    Map<String, List<DateTime>> activeWins = {};

    for (var game in games.reversed) {
      if (!isValidFinalizedGame(game, 'yahtzee')) continue;
      List<String> pNames = List<String>.from(game['playerNames'] ?? []);
      List<Map<String, dynamic>> rounds = List<Map<String, dynamic>>.from(
        game['rounds'] ?? [],
      );
      if (rounds.isEmpty) continue;

      DateTime gameDate = parseGameDate(game);
      int count = pNames.length;
      bool isSolo = count == 1;

      List<int> scores = [];
      for (int i = 0; i < count; i++) scores.add(_getYahtzeeScore(rounds, i));
      int maxScore = isSolo ? 0 : scores.reduce(math.max);

      for (int i = 0; i < count; i++) {
        String pName = pNames[i];
        int upper = 0;
        for (var r in rounds) {
          String? cat = r['p${i + 1}Category'] ?? r['category'];
          int val = int.tryParse(r['p${i + 1}Score']?.toString() ?? '0') ?? 0;
          if (cat != null &&
              [
                'Aces',
                'Twos',
                'Threes',
                'Fours',
                'Fives',
                'Sixes',
              ].contains(cat))
            upper += val;
        }

        if (upper >= 63) {
          activeUpper[pName] = (activeUpper[pName] ?? [])..add(gameDate);
          if (isTarget(pName))
            payload.longestUpperStreak.update(
              activeUpper[pName]!.length,
              pName,
              gameDate,
              isHigh: true,
              streakDates: List.from(activeUpper[pName]!),
            );
        } else
          activeUpper[pName] = [];

        if (scores[i] >= 300) {
          active300[pName] = (active300[pName] ?? [])..add(gameDate);
          if (isTarget(pName))
            payload.longest300Streak.update(
              active300[pName]!.length,
              pName,
              gameDate,
              isHigh: true,
              streakDates: List.from(active300[pName]!),
            );
        } else
          active300[pName] = [];

        if (!isSolo) {
          int numWinners = scores.where((s) => s == maxScore).length;
          if (scores[i] == maxScore && numWinners == 1) {
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

    for (var key in activeUpper.keys)
      if (isTarget(key) &&
          activeUpper[key]!.length == payload.longestUpperStreak.value &&
          payload.longestUpperStreak.value > 0)
        for (var s in payload.longestUpperStreak.setters)
          if (s.setter == key) s.isOngoing = true;
    for (var key in active300.keys)
      if (isTarget(key) &&
          active300[key]!.length == payload.longest300Streak.value &&
          payload.longest300Streak.value > 0)
        for (var s in payload.longest300Streak.setters)
          if (s.setter == key) s.isOngoing = true;
    for (var key in activeWins.keys)
      if (isTarget(key) &&
          activeWins[key]!.length == payload.longestWinStreak.value &&
          payload.longestWinStreak.value > 0)
        for (var s in payload.longestWinStreak.setters)
          if (s.setter == key) s.isOngoing = true;

    for (var game in games) {
      if (!isValidFinalizedGame(game, 'yahtzee')) continue;
      List<String> pNames = List<String>.from(game['playerNames'] ?? []);
      List<Map<String, dynamic>> rounds = List<Map<String, dynamic>>.from(
        game['rounds'] ?? [],
      );
      payload.uniqueGamesPlayed++;
      DateTime gameDate = parseGameDate(game);

      List<int> indices =
          (playerName != null &&
              playerName != 'Group Metrics' &&
              playerName != 'Group Records')
          ? (pNames.indexOf(playerName) != -1
                ? [pNames.indexOf(playerName)]
                : [])
          : List.generate(pNames.length, (i) => i);

      for (int pIndex in indices) {
        String pName = pNames[pIndex];
        payload.gamesPlayed++;

        int score = _getYahtzeeScore(rounds, pIndex);
        payload.totalPoints += score;
        payload.highestScore.update(score, pName, gameDate, isHigh: true);
        payload.lowestScore.update(score, pName, gameDate, isHigh: false);

        int upper = 0,
            lower = 0,
            zeros = 0,
            baseYahtzees = 0,
            extraYahtzees = 0,
            yBonus = 0;
        for (var r in rounds) {
          String? cat = r['p${pIndex + 1}Category'] ?? r['category'];
          String scoreStr = r['p${pIndex + 1}Score']?.toString() ?? '';
          int val = int.tryParse(scoreStr) ?? 0;

          if (cat != null && cat != 'YAHTZEE BONUS') {
            if ([
              'Aces',
              'Twos',
              'Threes',
              'Fours',
              'Fives',
              'Sixes',
            ].contains(cat))
              upper += val;
            else
              lower += val;
            if (scoreStr == '0') zeros++;
            if (cat.toUpperCase() == 'YAHTZEE' && val == 50) baseYahtzees++;
          }
          var yb = r['p${pIndex + 1}YahtzeeBonus'];
          if (yb == true || yb == 'true') {
            yBonus += 100;
            extraYahtzees++;
          } else if (yb != null) {
            int ybVal = int.tryParse(yb.toString()) ?? 0;
            yBonus += ybVal;
            extraYahtzees += (ybVal ~/ 100);
          }
          if (cat == 'YAHTZEE BONUS') {
            int ybVal = int.tryParse(scoreStr) ?? 0;
            yBonus += ybVal;
            extraYahtzees += (ybVal ~/ 100);
          }
        }

        bool hitUpperBonus = upper >= 63;
        int bonus = hitUpperBonus ? 35 : 0;
        payload.totalUpperScore += (upper + bonus);
        payload.totalLowerScore += (lower + yBonus);
        if (hitUpperBonus) payload.upperBonusHits++;
        payload.baseRolled += baseYahtzees;
        payload.extraBonuses += extraYahtzees;
        payload.totalZeros += zeros;

        payload.highestTop.update(upper + bonus, pName, gameDate, isHigh: true);
        payload.highestBottom.update(
          lower + yBonus,
          pName,
          gameDate,
          isHigh: true,
        );
        payload.mostYahtzees.update(
          baseYahtzees + extraYahtzees,
          pName,
          gameDate,
          isHigh: true,
        );

        if (pNames.length > 1) {
          payload.competitiveGamesPlayed++;
          int totalOpp = pNames.length - 1;
          double beaten = 0;
          for (int i = 0; i < pNames.length; i++) {
            if (i == pIndex) continue;
            int oppScore = _getYahtzeeScore(rounds, i);
            if (score > oppScore)
              beaten += 1.0;
            else if (score == oppScore)
              beaten += 0.5;
          }
          payload.totalOpponents += totalOpp;
          payload.opponentsBeaten += beaten;
        }
      }
    }
    return payload;
  }
}
