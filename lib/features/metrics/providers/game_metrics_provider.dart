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
    var lifetime = _calculate(lifetimeGames, playerName);
    var current = _calculate(currentTrendGames, playerName);
    var historical = _calculate(
      lifetimeGames,
      playerName,
      skip: currentTrendGames.length,
    );
    var global = _calculate(globalGames, null);

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

  // Every tile on the Metrics page asks for the same four payloads (one
  // full pass over the games each). Remember them per list so a page of
  // tiles costs four passes instead of four per tile. Keyed by the list
  // object itself: the Metrics page hands out new lists whenever the data
  // or filters change, so a stale result can't be returned.
  final List<(List<Map<String, dynamic>>, int, String?, MetricPayload)> _memo =
      [];

  MetricPayload _calculate(
    List<Map<String, dynamic>> games,
    String? playerName, {
    int skip = 0,
  }) {
    for (final m in _memo) {
      if (identical(m.$1, games) && m.$2 == skip && m.$3 == playerName) {
        return m.$4;
      }
    }
    final result = calculateData(
      skip == 0 ? games : games.skip(skip).toList(),
      playerName,
    );
    _memo.add((games, skip, playerName, result));
    if (_memo.length > 64) _memo.removeAt(0);
    return result;
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
