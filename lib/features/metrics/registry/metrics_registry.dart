import 'package:flutter/material.dart';
import '../models/metrics_models.dart';
import '../providers/game_metrics_provider.dart';
import '../providers/spades_metrics_provider.dart';
import '../providers/yahtzee_metrics_provider.dart';
import '../providers/nerts_metrics_provider.dart';
import '../providers/nines_metrics_provider.dart';
import '../providers/standard_metrics_provider.dart';
import '../providers/wavelength_metrics_provider.dart';

class MetricTileBuilder {
  final String title;
  final VoidCallback? Function(BuildContext context)? getInfo;
  final PlayerMetricData Function(
    String tileId,
    String gameType,
    String playerName,
    MetricPayload lifetime,
    MetricPayload historical,
    MetricPayload current,
    MetricPayload global,
    int trendNumber,
    String trendUnit,
    bool isGroup,
    bool isRecords,
  )
  build;

  MetricTileBuilder({required this.title, this.getInfo, required this.build});
}

class MetricsRegistry {
  static final Map<String, GameMetricsProvider> _providers = {
    'spades': SpadesMetricsProvider(),
    'yahtzee': YahtzeeMetricsProvider(),
    'nerts': NertsMetricsProvider(),
    'nines': NinesMetricsProvider(),
    'wavelength': WavelengthMetricsProvider(),
  };

  static GameMetricsProvider? getProvider(String gameType) {
    if (_providers.containsKey(gameType.toLowerCase())) {
      return _providers[gameType.toLowerCase()];
    }
    return StandardMetricsProvider(gameType);
  }

  // Helper for generating standard Unit tiles (like Averages)
  static PlayerMetricData _buildUnit(
    String pName,
    bool isGrp,
    MetricPayload l,
    MetricPayload h,
    MetricPayload g,
    int tNum,
    String tUnit,
    double lVal,
    double hVal,
    double gVal,
    String primary,
    String sub1,
    String sub2, {
    bool lowerIsBetter = false,
  }) {
    return PlayerMetricData(
      playerName: isGrp ? "Group Average" : pName,
      primaryValue: primary,
      subtitle1: sub1,
      subtitle2: sub2,
      trendText: MetricsUtils.getTrendText(
        lVal,
        hVal,
        l.gamesPlayed > 0,
        h.gamesPlayed > 0,
        tNum,
        tUnit,
      ),
      trendColor: MetricsUtils.getTrendColor(
        lVal,
        hVal,
        l.gamesPlayed > 0,
        h.gamesPlayed > 0,
        lowerIsBetter: lowerIsBetter,
      ),
      benchmarkColor: MetricsUtils.getBenchmarkColor(
        lVal,
        globalAverage: gVal,
        lowerIsBetter: lowerIsBetter,
      ),
    );
  }

  // Helper for generating standard Percentage tiles (like Win Rates)
  static PlayerMetricData _buildPercent(
    String pName,
    bool isGrp,
    bool isRec,
    MetricPayload l,
    MetricPayload h,
    MetricPayload g,
    int tNum,
    String tUnit,
    double lVal,
    double hVal,
    double gVal,
    String primary,
    String sub1,
    String? sub2, {
    bool lowerIsBetter = false,
    bool hideBench = false,
  }) {
    return PlayerMetricData(
      playerName: isGrp ? "Group Average" : (isRec ? "Group Records" : pName),
      primaryValue: primary,
      subtitle1: sub1,
      subtitle2: sub2,
      trendText: MetricsUtils.getTrendText(
        lVal,
        hVal,
        l.gamesPlayed > 0,
        h.gamesPlayed > 0,
        tNum,
        tUnit,
        isPercent: true,
      ),
      trendColor: MetricsUtils.getTrendColor(
        lVal,
        hVal,
        l.gamesPlayed > 0,
        h.gamesPlayed > 0,
        lowerIsBetter: lowerIsBetter,
      ),
      benchmarkColor: hideBench
          ? MetricsUtils.neutralGrey
          : MetricsUtils.getBenchmarkColor(
              lVal,
              globalAverage: gVal,
              lowerIsBetter: lowerIsBetter,
            ),
    );
  }

  // Helper for generating Records (High Scores, Streaks)
  static PlayerMetricData _buildRecord(
    String id,
    String pName,
    GameRecord pRec,
    GameRecord gRec,
    String unit,
    bool isRecGrp,
  ) {
    bool isHighest =
        pRec.value == gRec.value &&
        pRec.value != 9999 &&
        pRec.value != -9999 &&
        (pRec.value != 0 ||
            id.contains('Score') ||
            id.contains('Top') ||
            id.contains('Bottom'));
    String valStr = pRec.value == -9999 || pRec.value == 9999
        ? "0${unit.isNotEmpty ? ' $unit' : ''}"
        : "${pRec.value}${unit.isNotEmpty ? ' $unit' : ''}";

    return PlayerMetricData(
      playerName: pName,
      primaryValue: valStr,
      subtitle1: pRec.settersShortText,
      subtitleInfo: pRec.settersText,
      trendText: pRec.isOngoing ? "ONGOING" : "",
      trendColor: pRec.isOngoing
          ? MetricsUtils.themeBlue
          : MetricsUtils.neutralGrey,
      benchmarkColor: MetricsUtils.themeBlue,
      isGroupRecord: isHighest && !isRecGrp && pName != 'Group Metrics',
    );
  }

  // THE MASTER LIST OF ALL TILES
  static final Map<String, MetricTileBuilder> allTiles = {
    // --- UNIVERSAL ---
    'gamesPlayed': MetricTileBuilder(
      title: "Total Games",
      build: (id, gType, pName, l, h, c, g, tNum, tUnit, isGrp, isRec) =>
          PlayerMetricData(
            playerName: isGrp ? "Group Total" : pName,
            primaryValue: isGrp ? "${l.uniqueGamesPlayed}" : "${l.gamesPlayed}",
            subtitle1: isGrp ? "Total tracked games" : "Total appearances",
            trendText: tUnit == 'games'
                ? ""
                : (isGrp
                      ? "${c.uniqueGamesPlayed} games in selected period"
                      : "${c.gamesPlayed} games in selected period"),
            trendColor: tUnit == 'games'
                ? MetricsUtils.neutralGrey
                : MetricsUtils.themeBlue,
            benchmarkColor: MetricsUtils.neutralGrey,
          ),
    ),
    'winRate': MetricTileBuilder(
      title: "Win Rate",
      build: (id, gType, pName, l, h, c, g, tNum, tUnit, isGrp, isRec) {
        double lVal = l.competitiveGamesPlayed == 0
            ? 0.0
            : (l.gamesWon / l.competitiveGamesPlayed) * 100;
        double hVal = h.competitiveGamesPlayed == 0
            ? 0.0
            : (h.gamesWon / h.competitiveGamesPlayed) * 100;
        double gVal = g.competitiveGamesPlayed == 0
            ? 0.0
            : (g.gamesWon / g.competitiveGamesPlayed) * 100;

        String gLbl = isGrp ? "Player-Games" : "Games";
        String wLbl = isGrp ? "Player-Wins" : "Wins";

        return _buildPercent(
          pName,
          isGrp,
          isRec,
          l,
          h,
          g,
          tNum,
          tUnit,
          lVal,
          hVal,
          gVal,
          l.competitiveGamesPlayed == 0
              ? "N/A"
              : (isRec ? "N/A" : "${lVal.toStringAsFixed(1)}%"),
          "$gLbl: ${l.competitiveGamesPlayed}",
          isRec ? null : "$wLbl: ${l.gamesWon}",
        );
      },
    ),
    'yahtzeeWinRate': MetricTileBuilder(
      title: "Weighted Win Rate",
      getInfo: (ctx) =>
          () => showDialog(
            context: ctx,
            builder: (c) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                "Weighted Win Rate",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: const Text(
                  "Calculates the percentage of opponents you beat across all multiplayer games. Ties count as half a win.",
                  style: TextStyle(color: Colors.white70, height: 1.5),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text(
                    "Got it",
                    style: TextStyle(color: Color(0xFF00A2FF)),
                  ),
                ),
              ],
            ),
          ),
      build: (id, gType, pName, l, h, c, g, tNum, tUnit, isGrp, isRec) {
        double lVal = l.totalOpponents == 0
            ? 0.0
            : (l.opponentsBeaten / l.totalOpponents) * 100;
        double hVal = h.totalOpponents == 0
            ? 0.0
            : (h.opponentsBeaten / h.totalOpponents) * 100;
        double gVal = g.totalOpponents == 0
            ? 0.0
            : (g.opponentsBeaten / g.totalOpponents) * 100;
        return _buildPercent(
          pName,
          isGrp,
          isRec,
          l,
          h,
          g,
          tNum,
          tUnit,
          lVal,
          hVal,
          gVal,
          isRec
              ? "${l.opponentsBeaten.toStringAsFixed(1)} Beaten"
              : "${lVal.toStringAsFixed(1)}%",
          "Opponents Faced: ${l.totalOpponents}",
          isRec
              ? null
              : "Opponents Beaten: ${l.opponentsBeaten.toStringAsFixed(1)}",
          hideBench: l.totalOpponents == 0,
        );
      },
    ),
    'avgPoints': MetricTileBuilder(
      title: "Scoring Average",
      build: (id, gType, pName, l, h, c, g, tNum, tUnit, isGrp, isRec) {
        double lVal = l.gamesPlayed == 0 ? 0.0 : l.totalPoints / l.gamesPlayed;
        double hVal = h.gamesPlayed == 0 ? 0.0 : h.totalPoints / h.gamesPlayed;
        double gVal = g.gamesPlayed == 0 ? 0.0 : g.totalPoints / g.gamesPlayed;
        bool lowIsBest = gType.toLowerCase() == 'nines';
        String gLbl = isGrp ? "Player-Games" : "Games";

        return _buildUnit(
          pName,
          isGrp,
          l,
          h,
          g,
          tNum,
          tUnit,
          lVal,
          hVal,
          gVal,
          "${lVal.toStringAsFixed(1)} pts",
          "Total Points: ${l.totalPoints}",
          "$gLbl: ${l.gamesPlayed}",
          lowerIsBetter: lowIsBest,
        );
      },
    ),

    // --- SPADES SPECIFIC ---
    'setRate': MetricTileBuilder(
      title: "Set Rate",
      build: (id, gType, pName, l, h, c, g, tNum, tUnit, isGrp, isRec) {
        double lVal = l.roundsPlayed == 0
            ? 0.0
            : (l.roundsSet / l.roundsPlayed) * 100;
        double hVal = h.roundsPlayed == 0
            ? 0.0
            : (h.roundsSet / h.roundsPlayed) * 100;
        double gVal = g.roundsPlayed == 0
            ? 0.0
            : (g.roundsSet / g.roundsPlayed) * 100;
        String rLbl = isGrp ? "Player-Rounds" : "Total Rounds";
        String sLbl = isGrp ? "Player-Sets" : "Total Sets";

        return _buildPercent(
          pName,
          isGrp,
          false,
          l,
          h,
          g,
          tNum,
          tUnit,
          lVal,
          hVal,
          gVal,
          "${lVal.toStringAsFixed(1)}%",
          "$rLbl: ${l.roundsPlayed}",
          "$sLbl: ${l.roundsSet}",
          lowerIsBetter: true,
        );
      },
    ),
    'nilRate': MetricTileBuilder(
      title: "Nil Success Rate",
      build: (id, gType, pName, l, h, c, g, tNum, tUnit, isGrp, isRec) {
        double lVal = l.nilsAttempted == 0
            ? 0.0
            : (l.nilsMade / l.nilsAttempted) * 100;
        double hVal = h.nilsAttempted == 0
            ? 0.0
            : (h.nilsMade / h.nilsAttempted) * 100;
        double gVal = g.nilsAttempted == 0
            ? 0.0
            : (g.nilsMade / g.nilsAttempted) * 100;
        return _buildPercent(
          pName,
          isGrp,
          false,
          l,
          h,
          g,
          tNum,
          tUnit,
          lVal,
          hVal,
          gVal,
          l.nilsAttempted > 0 ? "${lVal.toStringAsFixed(1)}%" : "N/A",
          "Attempted: ${l.nilsAttempted}",
          "Made: ${l.nilsMade}",
          hideBench: l.nilsAttempted == 0,
        );
      },
    ),
    'tenRate': MetricTileBuilder(
      title: "10-for-200 Success",
      build: (id, gType, pName, l, h, c, g, tNum, tUnit, isGrp, isRec) {
        double lVal = l.tensAttempted == 0
            ? 0.0
            : (l.tensMade / l.tensAttempted) * 100;
        double hVal = h.tensAttempted == 0
            ? 0.0
            : (h.tensMade / h.tensAttempted) * 100;
        double gVal = g.tensAttempted == 0
            ? 0.0
            : (g.tensMade / g.tensAttempted) * 100;
        return _buildPercent(
          pName,
          isGrp,
          false,
          l,
          h,
          g,
          tNum,
          tUnit,
          lVal,
          hVal,
          gVal,
          l.tensAttempted > 0 ? "${lVal.toStringAsFixed(1)}%" : "N/A",
          "10s Attempted: ${l.tensAttempted}",
          "10s Made: ${l.tensMade}",
          hideBench: l.tensAttempted == 0,
        );
      },
    ),
    'avgBags': MetricTileBuilder(
      title: "Bag Average",
      build: (id, gType, pName, l, h, c, g, tNum, tUnit, isGrp, isRec) {
        double lVal = l.gamesWithBagsCount == 0
            ? 0.0
            : l.totalBags / l.gamesWithBagsCount;
        double hVal = h.gamesWithBagsCount == 0
            ? 0.0
            : h.totalBags / h.gamesWithBagsCount;
        double gVal = g.gamesWithBagsCount == 0
            ? 0.0
            : g.totalBags / g.gamesWithBagsCount;
        String gLbl = isGrp ? "Player-Games" : "Games";

        return _buildUnit(
          pName,
          isGrp,
          l,
          h,
          g,
          tNum,
          tUnit,
          lVal,
          hVal,
          gVal,
          "${lVal.toStringAsFixed(1)} bags",
          "Total Bags: ${l.totalBags}",
          "$gLbl w/ Bags: ${l.gamesWithBagsCount}",
          lowerIsBetter: true,
        );
      },
    ),
    'avgBid': MetricTileBuilder(
      title: "Average Bid",
      build: (id, gType, pName, l, h, c, g, tNum, tUnit, isGrp, isRec) {
        double lVal = l.numericBidsCount == 0
            ? 0.0
            : l.totalNumericBids / l.numericBidsCount;
        double hVal = h.numericBidsCount == 0
            ? 0.0
            : h.totalNumericBids / h.numericBidsCount;
        double gVal = g.numericBidsCount == 0
            ? 0.0
            : g.totalNumericBids / g.numericBidsCount;
        return _buildUnit(
          pName,
          isGrp,
          l,
          h,
          g,
          tNum,
          tUnit,
          lVal,
          hVal,
          gVal,
          "${lVal.toStringAsFixed(2)} tricks",
          "Total Numeric Bids: ${l.totalNumericBids}",
          "Bid Count: ${l.numericBidsCount}",
        );
      },
    ),

    // --- YAHTZEE SPECIFIC ---
    'yahtzeeAvgScore': MetricTileBuilder(
      title: "Average Score",
      build: (id, gType, pName, l, h, c, g, tNum, tUnit, isGrp, isRec) {
        double lVal = l.gamesPlayed == 0 ? 0.0 : l.totalPoints / l.gamesPlayed;
        double hVal = h.gamesPlayed == 0 ? 0.0 : h.totalPoints / h.gamesPlayed;
        double gVal = g.gamesPlayed == 0 ? 0.0 : g.totalPoints / g.gamesPlayed;
        String gLbl = isGrp ? "Player-Games" : "Games";

        return _buildUnit(
          pName,
          isGrp,
          l,
          h,
          g,
          tNum,
          tUnit,
          lVal,
          hVal,
          gVal,
          "${lVal.toStringAsFixed(1)} pts",
          "$gLbl: ${l.gamesPlayed}",
          "High Score: ${l.highestScore.value == -9999 ? 0 : l.highestScore.value}",
        );
      },
    ),
    'yahtzeeAvgUpper': MetricTileBuilder(
      title: "Average Upper Score",
      build: (id, gType, pName, l, h, c, g, tNum, tUnit, isGrp, isRec) {
        double lVal = l.gamesPlayed == 0
            ? 0.0
            : l.totalUpperScore / l.gamesPlayed;
        double hVal = h.gamesPlayed == 0
            ? 0.0
            : h.totalUpperScore / h.gamesPlayed;
        double gVal = g.gamesPlayed == 0
            ? 0.0
            : g.totalUpperScore / g.gamesPlayed;
        String gLbl = isGrp ? "Player-Games" : "Games";

        return _buildUnit(
          pName,
          isGrp,
          l,
          h,
          g,
          tNum,
          tUnit,
          lVal,
          hVal,
          gVal,
          isRec
              ? "${l.totalUpperScore} Total"
              : "${lVal.toStringAsFixed(1)} pts",
          "$gLbl: ${l.gamesPlayed}",
          isRec ? "Avg: ${lVal.toStringAsFixed(1)}" : "",
        );
      },
    ),
    'yahtzeeAvgLower': MetricTileBuilder(
      title: "Average Lower Score",
      build: (id, gType, pName, l, h, c, g, tNum, tUnit, isGrp, isRec) {
        double lVal = l.gamesPlayed == 0
            ? 0.0
            : l.totalLowerScore / l.gamesPlayed;
        double hVal = h.gamesPlayed == 0
            ? 0.0
            : h.totalLowerScore / h.gamesPlayed;
        double gVal = g.gamesPlayed == 0
            ? 0.0
            : g.totalLowerScore / g.gamesPlayed;
        String gLbl = isGrp ? "Player-Games" : "Games";

        return _buildUnit(
          pName,
          isGrp,
          l,
          h,
          g,
          tNum,
          tUnit,
          lVal,
          hVal,
          gVal,
          isRec
              ? "${l.totalLowerScore} Total"
              : "${lVal.toStringAsFixed(1)} pts",
          "$gLbl: ${l.gamesPlayed}",
          isRec ? "Avg: ${lVal.toStringAsFixed(1)}" : "",
        );
      },
    ),
    'yahtzeeUpper': MetricTileBuilder(
      title: "Upper Bonus Consistency",
      build: (id, gType, pName, l, h, c, g, tNum, tUnit, isGrp, isRec) {
        double lVal = l.gamesPlayed == 0
            ? 0.0
            : (l.upperBonusHits / l.gamesPlayed) * 100;
        double hVal = h.gamesPlayed == 0
            ? 0.0
            : (h.upperBonusHits / h.gamesPlayed) * 100;
        double gVal = g.gamesPlayed == 0
            ? 0.0
            : (g.upperBonusHits / g.gamesPlayed) * 100;
        String gLbl = isGrp ? "Player-Games" : "Games";

        return _buildPercent(
          pName,
          isGrp,
          isRec,
          l,
          h,
          g,
          tNum,
          tUnit,
          lVal,
          hVal,
          gVal,
          isRec ? "${l.upperBonusHits} Hits" : "${lVal.toStringAsFixed(1)}%",
          isRec
              ? "$gLbl: ${l.gamesPlayed}"
              : "Secured: ${l.upperBonusHits} times",
          isRec ? null : "$gLbl: ${l.gamesPlayed}",
        );
      },
    ),
    'yahtzeeRolls': MetricTileBuilder(
      title: "Average Yahtzees Per Game",
      build: (id, gType, pName, l, h, c, g, tNum, tUnit, isGrp, isRec) {
        double lVal = l.gamesPlayed == 0
            ? 0.0
            : (l.baseRolled + l.extraBonuses) / l.gamesPlayed;
        double hVal = h.gamesPlayed == 0
            ? 0.0
            : (h.baseRolled + h.extraBonuses) / h.gamesPlayed;
        double gVal = g.gamesPlayed == 0
            ? 0.0
            : (g.baseRolled + g.extraBonuses) / g.gamesPlayed;
        return _buildUnit(
          pName,
          isGrp,
          l,
          h,
          g,
          tNum,
          tUnit,
          lVal,
          hVal,
          gVal,
          isRec
              ? "${l.baseRolled + l.extraBonuses} Total"
              : "${lVal.toStringAsFixed(1)} / game",
          isRec ? "Base: ${l.baseRolled}" : "Total Yahtzees: ${l.baseRolled}",
          isRec
              ? "Bonuses: ${l.extraBonuses}"
              : "Total Bonuses: ${l.extraBonuses}",
        );
      },
    ),
    'yahtzeeZeros': MetricTileBuilder(
      title: "Average Zeros",
      build: (id, gType, pName, l, h, c, g, tNum, tUnit, isGrp, isRec) {
        double lVal = l.gamesPlayed == 0 ? 0.0 : l.totalZeros / l.gamesPlayed;
        double hVal = h.gamesPlayed == 0 ? 0.0 : h.totalZeros / h.gamesPlayed;
        double gVal = g.gamesPlayed == 0 ? 0.0 : g.totalZeros / g.gamesPlayed;
        String gLbl = isGrp ? "Player-Games" : "Games";

        return _buildUnit(
          pName,
          isGrp,
          l,
          h,
          g,
          tNum,
          tUnit,
          lVal,
          hVal,
          gVal,
          isRec ? "${l.totalZeros} Zeros" : "${lVal.toStringAsFixed(1)} zeros",
          isRec ? "$gLbl: ${l.gamesPlayed}" : "Total Zeros: ${l.totalZeros}",
          "",
          lowerIsBetter: true,
        );
      },
    ),

    // --- NERTS SPECIFIC ---
    'avgCardsLeft': MetricTileBuilder(
      title: "Avg Cards Left (Nerts Pile)",
      build: (id, gType, pName, l, h, c, g, tNum, tUnit, isGrp, isRec) {
        double lVal = l.roundsPlayed == 0
            ? 0.0
            : l.totalCardsLeft / l.roundsPlayed;
        double hVal = h.roundsPlayed == 0
            ? 0.0
            : h.totalCardsLeft / h.roundsPlayed;
        double gVal = g.roundsPlayed == 0
            ? 0.0
            : g.totalCardsLeft / g.roundsPlayed;
        String rLbl = isGrp ? "Player-Rounds" : "Total Rounds";

        return _buildUnit(
          pName,
          isGrp,
          l,
          h,
          g,
          tNum,
          tUnit,
          lVal,
          hVal,
          gVal,
          "${lVal.toStringAsFixed(1)} cards",
          "Total Cards Left: ${l.totalCardsLeft}",
          "$rLbl: ${l.roundsPlayed}",
          lowerIsBetter: true,
        );
      },
    ),
    'avgCardsMiddle': MetricTileBuilder(
      title: "Avg Cards Played (Middle)",
      build: (id, gType, pName, l, h, c, g, tNum, tUnit, isGrp, isRec) {
        double lVal = l.roundsPlayed == 0
            ? 0.0
            : l.totalCardsMiddle / l.roundsPlayed;
        double hVal = h.roundsPlayed == 0
            ? 0.0
            : h.totalCardsMiddle / h.roundsPlayed;
        double gVal = g.roundsPlayed == 0
            ? 0.0
            : g.totalCardsMiddle / g.roundsPlayed;
        String rLbl = isGrp ? "Player-Rounds" : "Total Rounds";

        return _buildUnit(
          pName,
          isGrp,
          l,
          h,
          g,
          tNum,
          tUnit,
          lVal,
          hVal,
          gVal,
          "${lVal.toStringAsFixed(1)} cards",
          "Total Cards Played: ${l.totalCardsMiddle}",
          "$rLbl: ${l.roundsPlayed}",
        );
      },
    ),

    // --- UNIVERSAL RECORDS ---
    'spadesHighScore': MetricTileBuilder(
      title: "Highest Score",
      build: (id, gt, p, l, h, c, g, tn, tu, ig, ir) =>
          _buildRecord(id, p, l.highestScore, g.highestScore, "pts", ir),
    ),
    'spadesLowScore': MetricTileBuilder(
      title: "Lowest Score",
      build: (id, gt, p, l, h, c, g, tn, tu, ig, ir) =>
          _buildRecord(id, p, l.lowestScore, g.lowestScore, "pts", ir),
    ),
    'spadesWinStreak': MetricTileBuilder(
      title: "Longest Win Streak",
      build: (id, gt, p, l, h, c, g, tn, tu, ig, ir) => _buildRecord(
        id,
        p,
        l.longestWinStreak,
        g.longestWinStreak,
        "Games",
        ir,
      ),
    ),
    'spadesLossStreak': MetricTileBuilder(
      title: "Longest Loss Streak",
      build: (id, gt, p, l, h, c, g, tn, tu, ig, ir) => _buildRecord(
        id,
        p,
        l.longestLossStreak,
        g.longestLossStreak,
        "Games",
        ir,
      ),
    ),
    'spadesPerfectStreak': MetricTileBuilder(
      title: "Longest Perfect Streak",
      build: (id, gt, p, l, h, c, g, tn, tu, ig, ir) => _buildRecord(
        id,
        p,
        l.longestPerfectStreak,
        g.longestPerfectStreak,
        "Rounds",
        ir,
      ),
    ),
    'spadesNoBagStreak': MetricTileBuilder(
      title: "Longest No-Bag Streak",
      build: (id, gt, p, l, h, c, g, tn, tu, ig, ir) => _buildRecord(
        id,
        p,
        l.longestNoBagStreak,
        g.longestNoBagStreak,
        "Rounds",
        ir,
      ),
    ),
    'spadesNoSetStreak': MetricTileBuilder(
      title: "Longest No-Set Streak",
      build: (id, gt, p, l, h, c, g, tn, tu, ig, ir) => _buildRecord(
        id,
        p,
        l.longestNoSetStreak,
        g.longestNoSetStreak,
        "Rounds",
        ir,
      ),
    ),

    'yahtzeeHighScore': MetricTileBuilder(
      title: "Highest Score",
      build: (id, gt, p, l, h, c, g, tn, tu, ig, ir) =>
          _buildRecord(id, p, l.highestScore, g.highestScore, "pts", ir),
    ),
    'yahtzeeLowScore': MetricTileBuilder(
      title: "Lowest Score",
      build: (id, gt, p, l, h, c, g, tn, tu, ig, ir) =>
          _buildRecord(id, p, l.lowestScore, g.lowestScore, "pts", ir),
    ),
    'yahtzeeHighTop': MetricTileBuilder(
      title: "Highest Upper Score",
      build: (id, gt, p, l, h, c, g, tn, tu, ig, ir) =>
          _buildRecord(id, p, l.highestTop, g.highestTop, "pts", ir),
    ),
    'yahtzeeHighBottom': MetricTileBuilder(
      title: "Highest Lower Score",
      build: (id, gt, p, l, h, c, g, tn, tu, ig, ir) =>
          _buildRecord(id, p, l.highestBottom, g.highestBottom, "pts", ir),
    ),
    'yahtzeeMostYahtzees': MetricTileBuilder(
      title: "Most Yahtzees in Game",
      build: (id, gt, p, l, h, c, g, tn, tu, ig, ir) =>
          _buildRecord(id, p, l.mostYahtzees, g.mostYahtzees, "", ir),
    ),
    'yahtzeeUpperStreak': MetricTileBuilder(
      title: "Longest Upper Bonus Streak",
      build: (id, gt, p, l, h, c, g, tn, tu, ig, ir) => _buildRecord(
        id,
        p,
        l.longestUpperStreak,
        g.longestUpperStreak,
        "Games",
        ir,
      ),
    ),
    'yahtzee300Streak': MetricTileBuilder(
      title: "Longest 300+ Score Streak",
      build: (id, gt, p, l, h, c, g, tn, tu, ig, ir) => _buildRecord(
        id,
        p,
        l.longest300Streak,
        g.longest300Streak,
        "Games",
        ir,
      ),
    ),
    'yahtzeeWinStreak': MetricTileBuilder(
      title: "Longest Win Streak",
      build: (id, gt, p, l, h, c, g, tn, tu, ig, ir) => _buildRecord(
        id,
        p,
        l.longestWinStreak,
        g.longestWinStreak,
        "Games",
        ir,
      ),
    ),

    'nertsHighScore': MetricTileBuilder(
      title: "Highest Score",
      build: (id, gt, p, l, h, c, g, tn, tu, ig, ir) =>
          _buildRecord(id, p, l.highestScore, g.highestScore, "pts", ir),
    ),
    'nertsLowScore': MetricTileBuilder(
      title: "Lowest Score",
      build: (id, gt, p, l, h, c, g, tn, tu, ig, ir) =>
          _buildRecord(id, p, l.lowestScore, g.lowestScore, "pts", ir),
    ),
    'nertsWinStreak': MetricTileBuilder(
      title: "Longest Win Streak",
      build: (id, gt, p, l, h, c, g, tn, tu, ig, ir) => _buildRecord(
        id,
        p,
        l.longestWinStreak,
        g.longestWinStreak,
        "Games",
        ir,
      ),
    ),
    'nertsRoundWinStreak': MetricTileBuilder(
      title: "Longest Round Win Streak",
      build: (id, gt, p, l, h, c, g, tn, tu, ig, ir) => _buildRecord(
        id,
        p,
        l.longestRoundWinStreak,
        g.longestRoundWinStreak,
        "Rounds",
        ir,
      ),
    ),

    'ninesHighScore': MetricTileBuilder(
      title: "Highest Score",
      build: (id, gt, p, l, h, c, g, tn, tu, ig, ir) =>
          _buildRecord(id, p, l.highestScore, g.highestScore, "pts", ir),
    ),
    'ninesLowScore': MetricTileBuilder(
      title: "Lowest Score",
      build: (id, gt, p, l, h, c, g, tn, tu, ig, ir) =>
          _buildRecord(id, p, l.lowestScore, g.lowestScore, "pts", ir),
    ),
    'ninesWinStreak': MetricTileBuilder(
      title: "Longest Win Streak",
      build: (id, gt, p, l, h, c, g, tn, tu, ig, ir) => _buildRecord(
        id,
        p,
        l.longestWinStreak,
        g.longestWinStreak,
        "Games",
        ir,
      ),
    ),
    'standardWinStreak': MetricTileBuilder(
      title: "Longest Win Streak",
      build: (id, gt, p, l, h, c, g, tn, tu, ig, ir) => _buildRecord(
        id,
        p,
        l.longestWinStreak,
        g.longestWinStreak,
        "Games",
        ir,
      ),
    ),
    'wavelengthRoundsTo10': MetricTileBuilder(
      title: "Avg Rounds To 10 Points",
      build: (id, gType, pName, l, h, c, g, tNum, tUnit, isGrp, isRec) {
        double lVal = l.gamesReached10Points == 0
            ? 0.0
            : l.totalRoundsTo10Points / l.gamesReached10Points;
        double hVal = h.gamesReached10Points == 0
            ? 0.0
            : h.totalRoundsTo10Points / h.gamesReached10Points;
        double gVal = g.gamesReached10Points == 0
            ? 0.0
            : g.totalRoundsTo10Points / g.gamesReached10Points;

        String pLbl = isGrp ? "Avg Rounds" : "Avg Rounds";
        String sLbl = isGrp ? "Games Reached 10" : "Games Reached 10";

        return _buildUnit(
          pName,
          isGrp,
          l,
          h,
          g,
          tNum,
          tUnit,
          lVal,
          hVal,
          gVal,
          isRec ? "N/A" : lVal.toStringAsFixed(1),
          "$sLbl: ${l.gamesReached10Points}",
          "",
          lowerIsBetter: true,
        );
      },
    ),
  };
}
