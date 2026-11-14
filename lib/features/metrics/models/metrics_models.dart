import 'package:flutter/material.dart';

class PlayerMetricData {
  final String playerName;
  final String primaryValue;
  final String subtitle1;
  final String? subtitle2;
  final String? subtitleInfo;
  final String trendText;
  final Color trendColor;
  final Color benchmarkColor;
  final bool isGroupRecord;

  PlayerMetricData({
    required this.playerName,
    required this.primaryValue,
    required this.subtitle1,
    this.subtitle2,
    this.subtitleInfo,
    required this.trendText,
    required this.trendColor,
    required this.benchmarkColor,
    this.isGroupRecord = false,
  });
}

class MetricsUtils {
  static const Color themeBlue = Color(0xFF00A2FF);
  static const Color positiveGreen = Color(0xFF54A27E);
  static const Color negativeRed = Color(0xFFD26A74);
  static const Color neutralGrey = Color(0xFF9BA4B5);

  static String getTrendText(
    double current,
    double previous,
    bool hasCurrent,
    bool hasPrevious,
    int trendNumber,
    String trendUnit, {
    bool isPercent = false,
  }) {
    String unitStr = trendUnit;
    if (trendNumber == 1 && unitStr.endsWith('s'))
      unitStr = unitStr.substring(0, unitStr.length - 1);
    final periodStr = 'last $trendNumber $unitStr';

    if (!hasCurrent && !hasPrevious) return "No recent data";
    if (!hasPrevious) return "No prior data to compare";
    if (!hasCurrent) return "No data in $periodStr";

    final diff = current - previous;
    if (diff.abs() < 0.05) return "Flat in $periodStr";
    final direction = diff > 0 ? "Up" : "Down";
    return "$direction ${diff.abs().toStringAsFixed(1)}${isPercent ? '%' : ''} in $periodStr";
  }

  static Color getTrendColor(
    double current,
    double previous,
    bool hasCurrent,
    bool hasPrevious, {
    bool lowerIsBetter = false,
  }) {
    if (!hasCurrent || !hasPrevious) return neutralGrey;
    final diff = current - previous;
    if (diff.abs() < 0.05) return neutralGrey;
    final improved = lowerIsBetter ? diff < 0 : diff > 0;
    return improved ? positiveGreen : negativeRed;
  }

  static Color getBenchmarkColor(
    double value, {
    required double globalAverage,
    bool lowerIsBetter = false,
  }) {
    if (globalAverage == 0) return neutralGrey;
    double margin = globalAverage > 100
        ? 25.0
        : (globalAverage < 10 ? 0.5 : 2.5);
    double good = lowerIsBetter
        ? globalAverage - margin
        : globalAverage + margin;
    double warning = lowerIsBetter
        ? globalAverage + margin
        : globalAverage - margin;

    if (lowerIsBetter) {
      if (value <= good) return positiveGreen;
      if (value <= warning) return neutralGrey;
      return negativeRed;
    }
    if (value >= good) return positiveGreen;
    if (value >= warning) return neutralGrey;
    return negativeRed;
  }
}

// ============================================================================
// CORE DATA MODELS
// ============================================================================

class RecordDetail {
  final String setter;
  final DateTime date;
  final List<DateTime>? streakDates;
  bool isOngoing;
  RecordDetail(
    this.setter,
    this.date, {
    this.streakDates,
    this.isOngoing = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecordDetail && setter == other.setter && date == other.date;

  @override
  int get hashCode => setter.hashCode ^ date.hashCode;
}

class GameRecord {
  int value;
  List<RecordDetail> setters = [];
  bool get isOngoing => setters.any((s) => s.isOngoing);
  GameRecord({required this.value});

  void update(
    int newValue,
    String setter,
    DateTime date, {
    bool isHigh = true,
    List<DateTime>? streakDates,
  }) {
    var detail = RecordDetail(setter, date, streakDates: streakDates);
    if (isHigh) {
      if (newValue > value) {
        value = newValue;
        setters = [detail];
      } else if (newValue == value && newValue != 0 && newValue != -9999) {
        if (!setters.contains(detail)) setters.add(detail);
      }
    } else {
      if (newValue < value) {
        value = newValue;
        setters = [detail];
      } else if (newValue == value && newValue != 0 && newValue != 9999) {
        if (!setters.contains(detail)) setters.add(detail);
      }
    }
  }

  String get settersText {
    if (setters.isEmpty || value == 0 || value == 9999 || value == -9999)
      return "No records yet";
    var lines = setters.map((s) {
      String statusStr = s.isOngoing ? " (ONGOING)" : "";
      if (s.streakDates != null && s.streakDates!.isNotEmpty) {
        var uniqueDates = s.streakDates!.toSet().toList();
        var datesText = uniqueDates
            .map((d) => "${d.month}/${d.day}/${d.year}")
            .join(', ');
        return "${s.setter}$statusStr:\n  $datesText";
      } else {
        return "${s.setter}$statusStr on ${s.date.month}/${s.date.day}/${s.date.year}";
      }
    }).toList();
    return lines.length > 10
        ? lines.take(10).join('\n\n') + "\n\n...and ${lines.length - 10} more"
        : lines.join('\n\n');
  }

  String get settersShortText {
    if (setters.isEmpty || value == 0 || value == 9999 || value == -9999)
      return "";
    var uniqueNames = setters.map((s) => s.setter).toSet().toList();
    return uniqueNames.take(2).join('\n') +
        (uniqueNames.length > 2 ? "\n..." : "");
  }
}

class MetricPayload {
  // Universal
  int uniqueGamesPlayed = 0;
  int gamesPlayed = 0;
  int competitiveGamesPlayed = 0;
  int gamesWon = 0;
  int totalPoints = 0;

  // Weighted Win Rate
  int totalOpponents = 0;
  double opponentsBeaten = 0.0;

  // Spades
  int roundsPlayed = 0;
  int roundsSet = 0;
  int nilsAttempted = 0;
  int nilsMade = 0;
  int tensAttempted = 0;
  int tensMade = 0;
  int totalNumericBids = 0;
  int numericBidsCount = 0;
  int totalBags = 0;
  int gamesWithBagsCount = 0;

  // Yahtzee
  int totalZeros = 0;
  int upperBonusHits = 0;
  int baseRolled = 0;
  int extraBonuses = 0;
  int totalUpperScore = 0;
  int totalLowerScore = 0;

  // Nerts
  int totalCardsLeft = 0;
  int totalCardsMiddle = 0;

  // Wavelength
  int totalRoundsTo10Points = 0;
  int gamesReached10Points = 0;

  // Universal Records
  GameRecord highestScore = GameRecord(value: -9999);
  GameRecord lowestScore = GameRecord(value: 9999);
  GameRecord longestWinStreak = GameRecord(value: 0);
  GameRecord longestLossStreak = GameRecord(value: 0);
  GameRecord longestPerfectStreak = GameRecord(value: 0);
  GameRecord longestNoBagStreak = GameRecord(value: 0);
  GameRecord longestNoSetStreak = GameRecord(value: 0);
  GameRecord highestTop = GameRecord(value: -9999);
  GameRecord highestBottom = GameRecord(value: -9999);
  GameRecord mostYahtzees = GameRecord(value: -9999);
  GameRecord longestUpperStreak = GameRecord(value: 0);
  GameRecord longest300Streak = GameRecord(value: 0);
  GameRecord longestRoundWinStreak = GameRecord(value: 0);
}
