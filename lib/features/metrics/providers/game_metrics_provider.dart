import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/metrics_models.dart';
import '../registry/metrics_registry.dart';

abstract class GameMetricsProvider {
  String get gameType;

  // Implemented by each game
  List<String> getAvailableTileIds(String playerName);
  MetricPayload calculateData(
    List<Map<String, dynamic>> games,
    String? playerName,
  );

  // Deep Link optional overrides
  VoidCallback? getOnTapCallback(
    BuildContext context,
    String tileId,
    String playerName,
    List<Map<String, dynamic>> lifetimeGames,
    String scopeDisplay,
    String gameTypeDisplay,
    String playerDisplay,
  ) => null;

  // Uses Registry Automagically
  String getTileTitle(String tileId) =>
      MetricsRegistry.allTiles[tileId]?.title ?? tileId;
  VoidCallback? getInfoCallback(BuildContext context, String tileId) =>
      MetricsRegistry.allTiles[tileId]?.getInfo?.call(context);

  PlayerMetricData buildMetricData({
    required BuildContext context,
    required String tileId,
    required String playerName,
    required List<Map<String, dynamic>> lifetimeGames,
    required List<Map<String, dynamic>> currentTrendGames,
    required List<Map<String, dynamic>> previousTrendGames,
    required List<Map<String, dynamic>> globalGames,
    required int trendNumber,
    required String trendUnit,
  }) {
    var lifetime = calculateData(lifetimeGames, playerName);
    var current = calculateData(currentTrendGames, playerName);
    var historical = calculateData(
      lifetimeGames.skip(currentTrendGames.length).toList(),
      playerName,
    );
    var global = calculateData(globalGames, null);

    bool isGroup = playerName == 'Group Metrics';
    bool isRecords = playerName == 'Group Records';

    var builder = MetricsRegistry.allTiles[tileId];
    if (builder != null) {
      return builder.build(
        tileId,
        gameType,
        playerName,
        lifetime,
        historical,
        current,
        global,
        trendNumber,
        trendUnit,
        isGroup,
        isRecords,
      );
    }

    return PlayerMetricData(
      playerName: playerName,
      primaryValue: "N/A",
      subtitle1: "",
      trendText: "",
      trendColor: MetricsUtils.neutralGrey,
      benchmarkColor: MetricsUtils.neutralGrey,
    );
  }

  DateTime parseGameDate(Map<String, dynamic> game) {
    final value = game['createdDate'] ?? game['date'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  bool isValidFinalizedGame(Map<String, dynamic> game, String targetGameType) {
    final String currentType = game['gameType']?.toString().toLowerCase() ?? '';
    return currentType == targetGameType.toLowerCase() &&
        game['isFinalized'] == true;
  }
}
