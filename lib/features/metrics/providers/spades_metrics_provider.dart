import 'package:flutter/material.dart';
import 'game_metrics_provider.dart';
import '../models/metrics_models.dart';
import '../pages/specific_metrics_screen.dart';

class SpadesMetricsProvider extends GameMetricsProvider {
  @override
  String get gameType => 'Spades';

  @override
  List<String> getAvailableTileIds(String playerName) {
    if (playerName == 'Group Records')
      return [
        'spadesHighScore',
        'spadesLowScore',
        'spadesWinStreak',
        'spadesLossStreak',
        'spadesPerfectStreak',
        'spadesNoBagStreak',
        'spadesNoSetStreak',
      ];
    List<String> tiles = [
      'winRate',
      'setRate',
      'nilRate',
      'tenRate',
      'avgPoints',
      'avgBags',
      'avgBid',
    ];
    if (playerName == 'Group Metrics') {
      tiles.insert(0, 'gamesPlayed');
      tiles.remove('winRate');
    } else {
      tiles.addAll([
        'spadesHighScore',
        'spadesLowScore',
        'spadesWinStreak',
        'spadesLossStreak',
        'spadesPerfectStreak',
        'spadesNoBagStreak',
        'spadesNoSetStreak',
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

    if (tileId == 'winRate') {
      return () {
        List<MetricDataPoint> points = [];
        for (var game in lifetimeGames) {
          if (!isValidFinalizedGame(game, 'spades')) continue;
          List<String> pNames = List<String>.from(game['playerNames'] ?? []);
          if (pNames.length < 4) continue;

          List<int> indices = [];
          if (playerName.contains(' & ')) {
            List<String> teamNames = playerName.split(' & ');
            int p1Idx = pNames.indexOf(teamNames[0]);
            int p2Idx = pNames.indexOf(teamNames[1]);
            if (p1Idx != -1 && p2Idx != -1) {
              bool sameTeam =
                  (p1Idx == 0 || p1Idx == 1) && (p2Idx == 0 || p2Idx == 1) ||
                  (p1Idx == 2 || p1Idx == 3) && (p2Idx == 2 || p2Idx == 3);
              if (sameTeam) indices.add(p1Idx);
            }
          } else {
            int idx = pNames.indexOf(playerName);
            if (idx != -1) indices.add(idx);
          }
          if (indices.isEmpty) continue;

          List<Map<String, dynamic>> rounds = List<Map<String, dynamic>>.from(
            game['rounds'] ?? [],
          );
          if (rounds.isEmpty) continue;

          int pIndex = indices.first;
          int tIndex = (pIndex == 0 || pIndex == 1) ? 1 : 2;
          int oIndex = (tIndex == 1) ? 2 : 1;

          var lastRound = rounds.last;
          int myScore =
              int.tryParse(lastRound['t${tIndex}Total']?.toString() ?? '0') ??
              0;
          int opScore =
              int.tryParse(lastRound['t${oIndex}Total']?.toString() ?? '0') ??
              0;

          double winVal = (myScore > opScore) ? 100.0 : 0.0;
          DateTime date = parseGameDate(game);

          String resultText = myScore > opScore
              ? "Win ($myScore to $opScore)"
              : (myScore < opScore
                    ? "Loss ($myScore to $opScore)"
                    : "Tie ($myScore to $opScore)");
          points.add(
            MetricDataPoint(date: date, value: winVal, subtitle: resultText),
          );
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SpecificMetricScreen(
              title: "Win Rate",
              playerName: playerName,
              dataPoints: points,
              unit: "%",
              isHigherBetter: true,
              scopeDisplay: scopeDisplay,
              gameTypeDisplay: gameTypeDisplay,
              playerDisplay: playerDisplay,
              showIndividualScoresToggle: false,
            ),
          ),
        );
      };
    }
    return null;
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
        key == playerName ||
        key.contains(playerName);

    Map<String, List<DateTime>> activeWins = {};
    Map<String, List<DateTime>> activeLosses = {};
    Map<String, List<DateTime>> activePerfect = {};
    Map<String, List<DateTime>> activeNoBags = {};
    Map<String, List<DateTime>> activeNoSet = {};

    for (var game in games.reversed) {
      if (!isValidFinalizedGame(game, 'spades')) continue;
      List<String> pNames = List<String>.from(game['playerNames'] ?? []);
      if (pNames.length < 4) continue;
      List<Map<String, dynamic>> rounds = List<Map<String, dynamic>>.from(
        game['rounds'] ?? [],
      );
      if (rounds.isEmpty) continue;

      DateTime gameDate = parseGameDate(game);
      int t1Score =
          int.tryParse(rounds.last['t1Total']?.toString() ?? '0') ?? 0;
      int t2Score =
          int.tryParse(rounds.last['t2Total']?.toString() ?? '0') ?? 0;

      List<String> t1Names = [pNames[0], pNames[1]]..sort();
      String t1Key = "${t1Names[0]} & ${t1Names[1]}";
      List<String> t2Names = [pNames[2], pNames[3]]..sort();
      String t2Key = "${t2Names[0]} & ${t2Names[1]}";

      if (t1Score > t2Score) {
        activeWins[t1Key] = (activeWins[t1Key] ?? [])..add(gameDate);
        activeLosses[t2Key] = (activeLosses[t2Key] ?? [])..add(gameDate);
        activeWins[t2Key] = [];
        activeLosses[t1Key] = [];
        if (isTarget(t1Key))
          payload.longestWinStreak.update(
            activeWins[t1Key]!.length,
            t1Key,
            gameDate,
            isHigh: true,
            streakDates: List.from(activeWins[t1Key]!),
          );
        if (isTarget(t2Key))
          payload.longestLossStreak.update(
            activeLosses[t2Key]!.length,
            t2Key,
            gameDate,
            isHigh: true,
            streakDates: List.from(activeLosses[t2Key]!),
          );
      } else if (t2Score > t1Score) {
        activeWins[t2Key] = (activeWins[t2Key] ?? [])..add(gameDate);
        activeLosses[t1Key] = (activeLosses[t1Key] ?? [])..add(gameDate);
        activeWins[t1Key] = [];
        activeLosses[t2Key] = [];
        if (isTarget(t2Key))
          payload.longestWinStreak.update(
            activeWins[t2Key]!.length,
            t2Key,
            gameDate,
            isHigh: true,
            streakDates: List.from(activeWins[t2Key]!),
          );
        if (isTarget(t1Key))
          payload.longestLossStreak.update(
            activeLosses[t1Key]!.length,
            t1Key,
            gameDate,
            isHigh: true,
            streakDates: List.from(activeLosses[t1Key]!),
          );
      } else {
        activeWins[t1Key] = [];
        activeWins[t2Key] = [];
        activeLosses[t1Key] = [];
        activeLosses[t2Key] = [];
      }

      for (var r in rounds) {
        bool t1Set = r['t1Set'] == true || r['t1Set'] == 'true';
        bool t2Set = r['t2Set'] == true || r['t2Set'] == 'true';
        bool t1NoBags = (r['t1Hand']?.toString() ?? '0').endsWith('0');
        bool t2NoBags = (r['t2Hand']?.toString() ?? '0').endsWith('0');

        bool p1F =
            (r['p1Bid'] == 'N' || r['p1Bid'] == 'NIL' || r['p1Bid'] == 'BN') &&
            (r['p1NilSuccess'] == false || r['p1NilSuccess'] == 'false');
        bool p3F =
            (r['p3Bid'] == 'N' || r['p3Bid'] == 'NIL' || r['p3Bid'] == 'BN') &&
            (r['p3NilSuccess'] == false || r['p3NilSuccess'] == 'false');
        bool p2F =
            (r['p2Bid'] == 'N' || r['p2Bid'] == 'NIL' || r['p2Bid'] == 'BN') &&
            (r['p2NilSuccess'] == false || r['p2NilSuccess'] == 'false');
        bool p4F =
            (r['p4Bid'] == 'N' || r['p4Bid'] == 'NIL' || r['p4Bid'] == 'BN') &&
            (r['p4NilSuccess'] == false || r['p4NilSuccess'] == 'false');

        if (!t1Set && t1NoBags && !p1F && !p3F) {
          activePerfect[t1Key] = (activePerfect[t1Key] ?? [])..add(gameDate);
          if (isTarget(t1Key))
            payload.longestPerfectStreak.update(
              activePerfect[t1Key]!.length,
              t1Key,
              gameDate,
              isHigh: true,
              streakDates: List.from(activePerfect[t1Key]!),
            );
        } else {
          activePerfect[t1Key] = [];
        }

        if (t1NoBags) {
          activeNoBags[t1Key] = (activeNoBags[t1Key] ?? [])..add(gameDate);
          if (isTarget(t1Key))
            payload.longestNoBagStreak.update(
              activeNoBags[t1Key]!.length,
              t1Key,
              gameDate,
              isHigh: true,
              streakDates: List.from(activeNoBags[t1Key]!),
            );
        } else {
          activeNoBags[t1Key] = [];
        }

        if (!t1Set) {
          activeNoSet[t1Key] = (activeNoSet[t1Key] ?? [])..add(gameDate);
          if (isTarget(t1Key))
            payload.longestNoSetStreak.update(
              activeNoSet[t1Key]!.length,
              t1Key,
              gameDate,
              isHigh: true,
              streakDates: List.from(activeNoSet[t1Key]!),
            );
        } else {
          activeNoSet[t1Key] = [];
        }

        if (!t2Set && t2NoBags && !p2F && !p4F) {
          activePerfect[t2Key] = (activePerfect[t2Key] ?? [])..add(gameDate);
          if (isTarget(t2Key))
            payload.longestPerfectStreak.update(
              activePerfect[t2Key]!.length,
              t2Key,
              gameDate,
              isHigh: true,
              streakDates: List.from(activePerfect[t2Key]!),
            );
        } else {
          activePerfect[t2Key] = [];
        }

        if (t2NoBags) {
          activeNoBags[t2Key] = (activeNoBags[t2Key] ?? [])..add(gameDate);
          if (isTarget(t2Key))
            payload.longestNoBagStreak.update(
              activeNoBags[t2Key]!.length,
              t2Key,
              gameDate,
              isHigh: true,
              streakDates: List.from(activeNoBags[t2Key]!),
            );
        } else {
          activeNoBags[t2Key] = [];
        }

        if (!t2Set) {
          activeNoSet[t2Key] = (activeNoSet[t2Key] ?? [])..add(gameDate);
          if (isTarget(t2Key))
            payload.longestNoSetStreak.update(
              activeNoSet[t2Key]!.length,
              t2Key,
              gameDate,
              isHigh: true,
              streakDates: List.from(activeNoSet[t2Key]!),
            );
        } else {
          activeNoSet[t2Key] = [];
        }
      }
    }

    for (var key in activeWins.keys)
      if (isTarget(key) &&
          activeWins[key]!.length == payload.longestWinStreak.value &&
          payload.longestWinStreak.value > 0)
        for (var s in payload.longestWinStreak.setters)
          if (s.setter == key) s.isOngoing = true;
    for (var key in activeLosses.keys)
      if (isTarget(key) &&
          activeLosses[key]!.length == payload.longestLossStreak.value &&
          payload.longestLossStreak.value > 0)
        for (var s in payload.longestLossStreak.setters)
          if (s.setter == key) s.isOngoing = true;
    for (var key in activePerfect.keys)
      if (isTarget(key) &&
          activePerfect[key]!.length == payload.longestPerfectStreak.value &&
          payload.longestPerfectStreak.value > 0)
        for (var s in payload.longestPerfectStreak.setters)
          if (s.setter == key) s.isOngoing = true;
    for (var key in activeNoBags.keys)
      if (isTarget(key) &&
          activeNoBags[key]!.length == payload.longestNoBagStreak.value &&
          payload.longestNoBagStreak.value > 0)
        for (var s in payload.longestNoBagStreak.setters)
          if (s.setter == key) s.isOngoing = true;
    for (var key in activeNoSet.keys)
      if (isTarget(key) &&
          activeNoSet[key]!.length == payload.longestNoSetStreak.value &&
          payload.longestNoSetStreak.value > 0)
        for (var s in payload.longestNoSetStreak.setters)
          if (s.setter == key) s.isOngoing = true;

    for (var game in games) {
      if (!isValidFinalizedGame(game, 'spades')) continue;
      List<String> pNames = List<String>.from(game['playerNames'] ?? []);
      List<Map<String, dynamic>> rounds = List<Map<String, dynamic>>.from(
        game['rounds'] ?? [],
      );

      payload.uniqueGamesPlayed++;
      DateTime gameDate = parseGameDate(game);

      List<int> indices = [];
      bool isTeam = false;
      if (playerName != null &&
          playerName != 'Group Metrics' &&
          playerName != 'Group Records') {
        if (playerName.contains(' & ')) {
          isTeam = true;
          List<String> teamNames = playerName.split(' & ');
          int p1Idx = pNames.indexOf(teamNames[0]);
          int p2Idx = pNames.indexOf(teamNames[1]);
          if (p1Idx != -1 &&
              p2Idx != -1 &&
              ((p1Idx < 2 && p2Idx < 2) || (p1Idx >= 2 && p2Idx >= 2)))
            indices.add(p1Idx);
        } else {
          int idx = pNames.indexOf(playerName);
          if (idx != -1) indices.add(idx);
        }
      } else {
        indices = List.generate(pNames.length, (i) => i);
      }

      for (int pIndex in indices) {
        int tIndex = (pIndex == 0 || pIndex == 1) ? 1 : 2;
        int oIndex = (tIndex == 1) ? 2 : 1;
        int myScore =
            int.tryParse(rounds.last['t${tIndex}Total']?.toString() ?? '0') ??
            0;
        int opScore =
            int.tryParse(rounds.last['t${oIndex}Total']?.toString() ?? '0') ??
            0;

        payload.gamesPlayed++;
        if (pNames.length > 2) payload.competitiveGamesPlayed++; // Spades usually has 4 players. If it has 4, it's competitive. Actually, if there is an opponent, it's competitive. We assume > 0 opScore exists.
        if (myScore > opScore) payload.gamesWon++;
        payload.totalPoints += myScore;
        payload.gamesWithBagsCount++;
        int bagOuts = 0;
        for (var r in rounds) if (r['t${tIndex}Bagged'] == true) bagOuts++;
        payload.totalBags += (myScore.abs() % 10) + (bagOuts * 10);

        String teamName = pNames.length >= 4
            ? (tIndex == 1
                  ? "${pNames[0]} & ${pNames[1]}"
                  : "${pNames[2]} & ${pNames[3]}")
            : "Team $tIndex";
        payload.highestScore.update(myScore, teamName, gameDate, isHigh: true);
        payload.lowestScore.update(myScore, teamName, gameDate, isHigh: false);

        for (var r in rounds) {
          String myBid = (r['p${pIndex + 1}Bid']?.toString() ?? '')
              .toUpperCase();
          int partnerIndex = tIndex == 1
              ? (pIndex == 0 ? 1 : 0)
              : (pIndex == 2 ? 3 : 2);
          String partnerBid = (r['p${partnerIndex + 1}Bid']?.toString() ?? '')
              .toUpperCase();
          bool isTeamHandScored =
              r['t${tIndex}Hand'] != null &&
              r['t${tIndex}Hand'].toString().isNotEmpty;

          if (isTeamHandScored) {
            payload.roundsPlayed++;
            if (r['t${tIndex}Set'] == true) payload.roundsSet++;
          }

          int numA = int.tryParse(myBid) ?? 0;
          int numB = int.tryParse(partnerBid) ?? 0;

          if (isTeam) {
            if (isTeamHandScored) {
              if (myBid == 'N' || myBid == 'NIL' || myBid == 'BN') {
                payload.nilsAttempted++;
                if (r['p${pIndex + 1}NilSuccess'] == true ||
                    r['p${pIndex + 1}BlindNilSuccess'] == true)
                  payload.nilsMade++;
              } else if (myBid.isNotEmpty)
                payload.totalNumericBids += numA;

              if (partnerBid == 'N' ||
                  partnerBid == 'NIL' ||
                  partnerBid == 'BN') {
                payload.nilsAttempted++;
                if (r['p${partnerIndex + 1}NilSuccess'] == true ||
                    r['p${partnerIndex + 1}BlindNilSuccess'] == true)
                  payload.nilsMade++;
              } else if (partnerBid.isNotEmpty)
                payload.totalNumericBids += numB;

              if ((myBid.isNotEmpty &&
                      myBid != 'N' &&
                      myBid != 'NIL' &&
                      myBid != 'BN') ||
                  (partnerBid.isNotEmpty &&
                      partnerBid != 'N' &&
                      partnerBid != 'NIL' &&
                      partnerBid != 'BN')) {
                payload.numericBidsCount++;
              }

              if ((numA + numB) == 10) {
                payload.tensAttempted++;
                if (r['t${tIndex}Set'] != true) payload.tensMade++;
              }
            }
          } else {
            if (myBid.isEmpty) continue;
            if (myBid == 'N' || myBid == 'NIL' || myBid == 'BN') {
              if (isTeamHandScored) {
                payload.nilsAttempted++;
                if (r['p${pIndex + 1}NilSuccess'] == true ||
                    r['p${pIndex + 1}BlindNilSuccess'] == true)
                  payload.nilsMade++;
              }
            } else {
              payload.totalNumericBids += numA;
              payload.numericBidsCount++;
            }

            if ((numA + numB) == 10 && isTeamHandScored) {
              payload.tensAttempted++;
              if (r['t${tIndex}Set'] != true) payload.tensMade++;
            }
          }
        }
      }
    }
    return payload;
  }
}
