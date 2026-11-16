import 'package:flutter/material.dart';
import 'game_template.dart';
import 'playable_data_entry_dialog.dart';

/// Renders and scores user-built templates (see TemplateScorecardEditor).
///
/// Data layout inside each round map:
///  * core player cell (1 input):   `player_{p}_Score`
///  * core player cell (n inputs):  `player_{p}_{i}_Score`
///  * per-player custom column:     `{colId}_p{p}_Score`
///  * locked (edge) custom column:  `{colId}_Score`
/// Each also gets a running `_Total` and the raw dialog inputs in `_Raw`.
///
/// `rounds[i]` always corresponds to `layoutRows[i]`. Rows whose id starts
/// with `custom_row_` are optional extras (bonus rows, notes...) and never
/// block a round from being "complete".
class CustomTemplate extends GameTemplate {
  static const _lowWinConditions = {
    'lowest_after_rounds',
    'lowest_score',
    'lowest_when_reached_score',
  };
  static const _targetWinConditions = {
    'first_to_score',
    'lowest_when_reached_score',
  };

  @override
  String get gameType => 'Custom Scorecard';

  @override
  int get initialPlayerCount => 2;

  @override
  bool canAddPlayer(
    int currentPlayerCount,
    List<Map<String, dynamic>> rounds,
  ) => true;

  @override
  List<String> generateInitialPlayerNames() => ['Player 1', 'Player 2'];

  @override
  Map<String, dynamic> createNewRound(int roundNum, int playerCount) {
    return {'id': 'round_${roundNum - 1}'};
  }

  @override
  bool get autoManagesRounds => true;

  @override
  bool canAddRound(
    List<Map<String, dynamic>> rounds,
    int playerCount, {
    Map<String, dynamic> customSettings = const {},
  }) => false;

  // ---------------------------------------------------------------------------
  // Settings helpers (templates can arrive nested under `layoutSettings` or
  // flattened onto the root map, depending on where they were loaded from).
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _layout(Map<String, dynamic> customSettings) {
    final nested = customSettings['layoutSettings'];
    if (nested is Map) return Map<String, dynamic>.from(nested);
    return customSettings;
  }

  int _inputsPerPlayer(Map<String, dynamic> customSettings) {
    final v =
        _layout(customSettings)['inputsPerPlayer'] ??
        customSettings['inputsPerPlayer'];
    return (int.tryParse('$v') ?? 1).clamp(1, 20);
  }

  Map<String, String> _customNames(Map<String, dynamic> customSettings) {
    final names =
        _layout(customSettings)['customNames'] ?? customSettings['customNames'];
    if (names is Map) {
      return names.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return {};
  }

  String _winCondition(Map<String, dynamic> customSettings) =>
      customSettings['winCondition']?.toString() ?? 'highest_score';

  int _targetValue(Map<String, dynamic> customSettings, int fallback) =>
      int.tryParse('${customSettings['targetValue']}') ?? fallback;

  bool _isFixedRounds(Map<String, dynamic> customSettings) {
    final c = _winCondition(customSettings);
    return c == 'highest_after_rounds' || c == 'lowest_after_rounds';
  }

  /// The template's row layout, extended to cover every round in play.
  List<String> _layoutRows(
    Map<String, dynamic> customSettings,
    int roundCount,
  ) {
    final raw =
        _layout(customSettings)['layoutRows'] ?? customSettings['layoutRows'];
    final rows = raw is List
        ? raw.map((e) => e.toString()).toList()
        : <String>['round_0'];
    if (rows.isEmpty) rows.add('round_0');
    int next = rows.length;
    while (rows.length < roundCount) {
      while (rows.contains('round_$next')) {
        next++;
      }
      rows.add('round_${next++}');
    }
    return rows;
  }

  /// Makes sure there is one round map per layout row.
  void _ensureRounds(
    List<Map<String, dynamic>> rounds,
    Map<String, dynamic> customSettings,
  ) {
    final rows = _layoutRows(customSettings, rounds.length);
    while (rounds.length < rows.length) {
      rounds.add({'id': rows[rounds.length]});
    }
  }

  bool _isScoringRow(String rowId) => !rowId.startsWith('custom_row_');

  // Parses the Blueprint layout to find all active columns for this game.
  List<Map<String, dynamic>> _getActiveColumns(
    int playerCount,
    Map<String, dynamic> customSettings,
  ) {
    List<Map<String, dynamic>> activeCols = [];
    final customNames = _customNames(customSettings);
    final layout = _layout(customSettings);

    if (layout['blueprintColumns'] != null ||
        customSettings['layoutSettings'] != null) {
      List<String> lockedLeft = List<String>.from(
        layout['lockedLeftColumns'] ?? [],
      );
      List<String> blueprint = List<String>.from(
        layout['blueprintColumns'] ?? ['player_core'],
      );
      if (!blueprint.contains('player_core'))
        blueprint.insert(0, 'player_core');
      List<String> lockedRight = List<String>.from(
        layout['lockedRightColumns'] ?? [],
      );

      for (var col in lockedLeft) {
        activeCols.add({
          'id': col,
          'configSource': col,
          'isCore': false,
          'pIndex': null,
          'label': customNames[col] ?? 'Custom',
        });
      }
      for (int p = 0; p < playerCount; p++) {
        for (var bCol in blueprint) {
          if (bCol == 'player_core') {
            activeCols.add({
              'id': 'player_$p',
              'configSource': 'player_core',
              'isCore': true,
              'pIndex': p,
              'label': "Player ${p + 1}",
            });
          } else {
            activeCols.add({
              'id': '${bCol}_p$p',
              'configSource': bCol,
              'isCore': false,
              'pIndex': p,
              'label': customNames[bCol] ?? 'Custom',
            });
          }
        }
      }
      for (var col in lockedRight) {
        activeCols.add({
          'id': col,
          'configSource': col,
          'isCore': false,
          'pIndex': null,
          'label': customNames[col] ?? 'Custom',
        });
      }
    } else {
      // Legacy template fallback
      List<String> layoutColumns = customSettings['layoutColumns'] != null
          ? List<String>.from(customSettings['layoutColumns'])
          : List.generate(playerCount, (i) => 'player_$i');
      for (var col in layoutColumns) {
        if (col.startsWith('player_')) {
          int p = int.tryParse(col.split('_')[1]) ?? 0;
          activeCols.add({
            'id': col,
            'configSource': col,
            'isCore': true,
            'pIndex': p,
            'label': "Player ${p + 1}",
          });
        } else {
          activeCols.add({
            'id': col,
            'configSource': col,
            'isCore': false,
            'pIndex': null,
            'label': customNames[col] ?? 'Custom',
          });
        }
      }
    }
    return activeCols;
  }

  // ---------------------------------------------------------------------------
  // Scoring logic
  // ---------------------------------------------------------------------------

  bool _hasValue(dynamic v) => v != null && v.toString().trim().isNotEmpty;

  bool _isRoundComplete(
    Map<String, dynamic> round,
    List<Map<String, dynamic>> activeCols,
    int inputsPerPlayer,
  ) {
    for (var col in activeCols) {
      if (!col['isCore']) continue;
      if (inputsPerPlayer > 1) {
        for (int i = 0; i < inputsPerPlayer; i++) {
          if (!_hasValue(round['${col['id']}_${i}_Score'])) return false;
        }
      } else if (!_hasValue(round['${col['id']}_Score'])) {
        return false;
      }
    }
    return true;
  }

  bool _isRoundPartiallyFilled(
    Map<String, dynamic> round,
    List<Map<String, dynamic>> activeCols,
    int inputsPerPlayer,
  ) {
    for (var col in activeCols) {
      if (!col['isCore']) continue;
      if (inputsPerPlayer > 1) {
        for (int i = 0; i < inputsPerPlayer; i++) {
          if (_hasValue(round['${col['id']}_${i}_Score'])) return true;
        }
      } else if (_hasValue(round['${col['id']}_Score'])) {
        return true;
      }
    }
    return false;
  }

  int _num(dynamic v) => int.tryParse(v?.toString().trim() ?? '') ?? 0;

  int _getPlayerTotal(
    List<Map<String, dynamic>> rounds,
    String colId,
    int inputsPerPlayer,
  ) {
    int total = 0;
    for (var r in rounds) {
      if (inputsPerPlayer > 1) {
        for (int i = 0; i < inputsPerPlayer; i++) {
          total += _num(r['${colId}_${i}_Score']);
        }
      } else {
        total += _num(r['${colId}_Score']);
      }
    }
    return total;
  }

  /// Final total per player/team (sum of their core score cells).
  List<int> playerTotals(
    List<Map<String, dynamic>> rounds,
    int playerCount, {
    Map<String, dynamic> customSettings = const {},
  }) {
    final ipp = _inputsPerPlayer(customSettings);
    return List.generate(
      playerCount,
      (p) => _getPlayerTotal(rounds, 'player_$p', ipp),
    );
  }

  bool _targetReached(
    List<Map<String, dynamic>> rounds,
    int playerCount,
    Map<String, dynamic> customSettings,
  ) {
    final target = _targetValue(customSettings, 100);
    if (target <= 0) return false;
    return playerTotals(
      rounds,
      playerCount,
      customSettings: customSettings,
    ).any((t) => t >= target);
  }

  @override
  bool isReadyToFinalize(
    List<Map<String, dynamic>> rounds,
    int playerCount, {
    Map<String, dynamic> customSettings = const {},
  }) {
    if (rounds.isEmpty) return false;
    _ensureRounds(rounds, customSettings);
    final winCondition = _winCondition(customSettings);
    final activeCols = _getActiveColumns(playerCount, customSettings);
    final ipp = _inputsPerPlayer(customSettings);
    final rows = _layoutRows(customSettings, rounds.length);

    bool anyComplete = false;
    for (int i = 0; i < rounds.length; i++) {
      if (!_isScoringRow(rows[i])) continue;
      final complete = _isRoundComplete(rounds[i], activeCols, ipp);
      final partial = _isRoundPartiallyFilled(rounds[i], activeCols, ipp);
      if (complete) {
        anyComplete = true;
      } else if (_isFixedRounds(customSettings) || partial) {
        // Fixed-round games need every round; others can't end mid-round.
        return false;
      }
    }

    if (_targetWinConditions.contains(winCondition)) {
      return _targetReached(rounds, playerCount, customSettings);
    }
    return anyComplete;
  }

  @override
  bool onDataUpdated(
    List<Map<String, dynamic>> rounds,
    int playerCount, {
    Map<String, dynamic> customSettings = const {},
  }) {
    final before = rounds.length;
    _ensureRounds(rounds, customSettings);
    if (_isFixedRounds(customSettings)) return rounds.length != before;

    if (_targetWinConditions.contains(_winCondition(customSettings)) &&
        _targetReached(rounds, playerCount, customSettings)) {
      return rounds.length != before;
    }

    final activeCols = _getActiveColumns(playerCount, customSettings);
    final ipp = _inputsPerPlayer(customSettings);
    final rows = _layoutRows(customSettings, rounds.length);

    // Add a fresh round once the last scoring round is fully filled in.
    for (int i = rounds.length - 1; i >= 0; i--) {
      if (!_isScoringRow(rows[i])) continue;
      if (_isRoundComplete(rounds[i], activeCols, ipp)) {
        final nextRows = _layoutRows(customSettings, rounds.length + 1);
        rounds.add({'id': nextRows[rounds.length]});
        return true;
      }
      break;
    }
    return rounds.length != before;
  }

  @override
  void onRoundRemoved(List<Map<String, dynamic>> rounds) {}

  @override
  void recalculateTotals(
    List<Map<String, dynamic>> rounds,
    int playerCount, {
    Map<String, dynamic> customSettings = const {},
  }) {
    final activeCols = _getActiveColumns(playerCount, customSettings);
    final ipp = _inputsPerPlayer(customSettings);

    Map<String, int> runningTotals = {};
    for (var r in rounds) {
      for (var col in activeCols) {
        if (col['isCore'] && ipp > 1) {
          for (int i = 0; i < ipp; i++) {
            String key = '${col['id']}_$i';
            runningTotals[key] =
                (runningTotals[key] ?? 0) + _num(r['${key}_Score']);
            r['${key}_Total'] = runningTotals[key];
          }
        } else {
          String key = col['id'];
          runningTotals[key] =
              (runningTotals[key] ?? 0) + _num(r['${key}_Score']);
          r['${key}_Total'] = runningTotals[key];
        }
      }
    }
  }

  /// Indices of the winning player(s)/team(s) under the template's rules.
  List<int> winnerIndices(
    List<Map<String, dynamic>> rounds,
    int playerCount, {
    Map<String, dynamic> customSettings = const {},
  }) {
    if (playerCount == 0) return [];
    final totals = playerTotals(
      rounds,
      playerCount,
      customSettings: customSettings,
    );
    final lowWins = _lowWinConditions.contains(_winCondition(customSettings));
    final best = lowWins
        ? totals.reduce((a, b) => a < b ? a : b)
        : totals.reduce((a, b) => a > b ? a : b);
    return [
      for (int i = 0; i < totals.length; i++)
        if (totals[i] == best) i,
    ];
  }

  @override
  String getWinnerDeclaration(
    List<String> playerNames,
    List<Map<String, dynamic>> rounds, {
    Map<String, dynamic> customSettings = const {},
  }) {
    if (playerNames.isEmpty) return "Finalize this game?";
    final totals = playerTotals(
      rounds,
      playerNames.length,
      customSettings: customSettings,
    );
    final winners = winnerIndices(
      rounds,
      playerNames.length,
      customSettings: customSettings,
    );
    final lowWins = _lowWinConditions.contains(_winCondition(customSettings));

    String pts(int v) => "$v ${v.abs() == 1 ? 'point' : 'points'}";
    final names = winners.map((i) => playerNames[i]).toList();

    final headline = winners.length > 1
        ? "It's a tie between ${names.join(' & ')} with ${pts(totals[winners.first])}!"
        : "${names.first} wins with ${pts(totals[winners.first])}!";

    final order = List.generate(playerNames.length, (i) => i)
      ..sort(
        (a, b) => lowWins
            ? totals[a].compareTo(totals[b])
            : totals[b].compareTo(totals[a]),
      );
    final standings = order
        .map((i) => "${playerNames[i]}: ${totals[i]}")
        .join("\n");

    return "$headline\n\n$standings";
  }

  // ---------------------------------------------------------------------------
  // Grid
  // ---------------------------------------------------------------------------

  double _getDynamicFontSize(double baseSize, bool isCrowded) {
    return isCrowded ? baseSize * 0.85 : baseSize;
  }

  Widget _buildCell(
    String text, {
    bool isBold = false,
    Color color = Colors.white,
    required bool isCrowded,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 6.0),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: _getDynamicFontSize(16, isCrowded),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCell(
    String text,
    bool isCrowded, {
    Color color = Colors.white,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: _getDynamicFontSize(14, isCrowded),
          ),
        ),
      ),
    );
  }

  String _display(dynamic v) => _hasValue(v) ? "$v" : "-";

  @override
  Widget buildGrid({
    required BuildContext context,
    required BoxConstraints constraints,
    required List<String> playerNames,
    required List<Map<String, dynamic>> rounds,
    required bool isFinalized,
    required VoidCallback onDataChanged,
    required Function(int) onPlayerTap,
    Map<String, dynamic> customSettings = const {},
  }) {
    final activeCols = _getActiveColumns(playerNames.length, customSettings);
    final customNames = _customNames(customSettings);
    final Map<String, dynamic> cellConfigs =
        customSettings['cellConfigs'] is Map
        ? Map<String, dynamic>.from(customSettings['cellConfigs'])
        : {};
    final int inputsPerPlayer = _inputsPerPlayer(customSettings);
    final bool showTotalRow =
        _layout(customSettings)['showTotalRow'] ??
        customSettings['showTotalRow'] ??
        true;

    _ensureRounds(rounds, customSettings);
    final layoutRows = _layoutRows(customSettings, rounds.length);

    // --- Column sizing: fill the width, or scroll horizontally if cramped ---
    const double rndWidth = 48.0;
    const double minCellWidth = 58.0;
    double totalUnits = 0;
    for (var col in activeCols) {
      totalUnits += (col['isCore'] && inputsPerPlayer > 1)
          ? inputsPerPlayer.toDouble()
          : 1.0;
    }
    if (totalUnits == 0) totalUnits = 1;
    final double availableWidth = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : MediaQuery.of(context).size.width;
    final bool needsScroll =
        rndWidth + totalUnits * minCellWidth > availableWidth;
    final bool isCrowded =
        needsScroll || (availableWidth - rndWidth) / totalUnits < 72;

    Map<int, TableColumnWidth> colWidths = {
      0: const FixedColumnWidth(rndWidth),
    };
    for (int i = 0; i < activeCols.length; i++) {
      final units = (activeCols[i]['isCore'] && inputsPerPlayer > 1)
          ? inputsPerPlayer.toDouble()
          : 1.0;
      colWidths[i + 1] = needsScroll
          ? FixedColumnWidth(minCellWidth * units)
          : FlexColumnWidth(units);
    }

    List<TableRow> rows = [];

    // Header Row
    List<Widget> headerCells = [
      TableCell(
        verticalAlignment: TableCellVerticalAlignment.middle,
        child: _buildHeaderCell("RND", isCrowded, color: Colors.white54),
      ),
    ];

    for (var col in activeCols) {
      if (col['isCore']) {
        String label =
            col['pIndex'] != null && col['pIndex'] < playerNames.length
            ? playerNames[col['pIndex']]
            : col['label'];
        headerCells.add(
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: InkWell(
              onTap: isFinalized ? null : () => onPlayerTap(col['pIndex']),
              child: _buildHeaderCell(
                label,
                isCrowded,
                color: const Color(0xFF00A2FF),
              ),
            ),
          ),
        );
      } else {
        headerCells.add(
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: _buildHeaderCell(
              col['label'],
              isCrowded,
              color: Colors.white70,
            ),
          ),
        );
      }
    }
    rows.add(TableRow(children: headerCells));

    // Data Rows
    int roundCounter = 0;
    for (int r = 0; r < layoutRows.length; r++) {
      String rowId = layoutRows[r];
      final bool isScoring = _isScoringRow(rowId);
      if (isScoring) roundCounter++;
      String rLabel = isScoring
          ? "$roundCounter"
          : (customNames[rowId] ?? "Cust");
      String rTitle = isScoring ? "Round $roundCounter" : rLabel;

      List<Widget> rowCells = [
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: _buildCell(
            rLabel,
            isBold: true,
            color: Colors.white54,
            isCrowded: isCrowded,
          ),
        ),
      ];

      for (int c = 0; c < activeCols.length; c++) {
        var col = activeCols[c];
        String configKey = '${rowId}_${col['configSource']}';
        String playerName =
            col['pIndex'] != null && col['pIndex'] < playerNames.length
            ? playerNames[col['pIndex']]
            : "";
        String defaultTitle = col['isCore']
            ? "$rTitle: $playerName"
            : (playerName.isEmpty
                  ? "$rTitle: ${col['label']}"
                  : "$rTitle: ${col['label']} ($playerName)");

        if (col['isCore'] && inputsPerPlayer > 1) {
          rowCells.add(
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: Row(
                children: List.generate(inputsPerPlayer, (i) {
                  final dataKey = '${col['id']}_$i';
                  final score = rounds[r]['${dataKey}_Score'];

                  return Expanded(
                    child: InkWell(
                      onTap: isFinalized
                          ? null
                          : () {
                              final config =
                                  cellConfigs['${configKey}_$i'] ??
                                  cellConfigs['round_0_${col['configSource']}_$i'] ??
                                  cellConfigs['${col['configSource']}_$i'];
                              _openDataEntry(
                                context,
                                rounds[r],
                                '${dataKey}_Score',
                                config,
                                "$defaultTitle (${i + 1})",
                                onDataChanged,
                              );
                            },
                      child: Container(
                        decoration: i < inputsPerPlayer - 1
                            ? BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                              )
                            : null,
                        child: _buildCell(
                          _display(score),
                          isCrowded: isCrowded,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          );
        } else {
          final dataKey = col['id'];
          final score = rounds[r]['${dataKey}_Score'];

          rowCells.add(
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: InkWell(
                onTap: isFinalized
                    ? null
                    : () {
                        final config =
                            cellConfigs[configKey] ??
                            (isScoring
                                ? cellConfigs['round_0_${col['configSource']}']
                                : null) ??
                            cellConfigs[col['configSource']];
                        _openDataEntry(
                          context,
                          rounds[r],
                          '${dataKey}_Score',
                          config,
                          defaultTitle,
                          onDataChanged,
                        );
                      },
                child: _buildCell(_display(score), isCrowded: isCrowded),
              ),
            ),
          );
        }
      }
      rows.add(TableRow(children: rowCells));
    }

    // Total Row
    if (showTotalRow) {
      List<Widget> totalCells = [
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: _buildCell(
            "TOT",
            isBold: true,
            color: Colors.white,
            isCrowded: isCrowded,
          ),
        ),
      ];

      for (var col in activeCols) {
        if (col['isCore'] && inputsPerPlayer > 1) {
          totalCells.add(
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: Row(
                children: List.generate(inputsPerPlayer, (i) {
                  final dataKey = '${col['id']}_$i';
                  final total = rounds.isNotEmpty
                      ? rounds.last['${dataKey}_Total'] ?? 0
                      : 0;
                  return Expanded(
                    child: Container(
                      decoration: i < inputsPerPlayer - 1
                          ? BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                            )
                          : null,
                      child: _buildCell(
                        "$total",
                        isBold: true,
                        color: Colors.white,
                        isCrowded: isCrowded,
                      ),
                    ),
                  );
                }),
              ),
            ),
          );
        } else {
          final total = rounds.isNotEmpty
              ? rounds.last['${col['id']}_Total'] ?? 0
              : 0;
          totalCells.add(
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: _buildCell(
                "$total",
                isBold: true,
                color: col['isCore'] ? Colors.white : Colors.white70,
                isCrowded: isCrowded,
              ),
            ),
          );
        }
      }
      rows.add(
        TableRow(
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3)),
          children: totalCells,
        ),
      );
    }

    final table = Table(
      columnWidths: colWidths,
      border: TableBorder(
        horizontalInside: BorderSide(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
        verticalInside: BorderSide(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      children: rows,
    );

    if (!needsScroll) return table;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: availableWidth),
        child: table,
      ),
    );
  }

  void _openDataEntry(
    BuildContext context,
    Map<String, dynamic> roundData,
    String dataKey,
    Map<String, dynamic>? config,
    String defaultTitle,
    VoidCallback onDataChanged,
  ) {
    if (config != null) {
      final raw = roundData['${dataKey}_Raw'];
      showDialog(
        context: context,
        builder: (context) => PlayableDataEntryDialog(
          config: Map<String, dynamic>.from(config),
          defaultTitle: defaultTitle,
          initialRawInputs: raw is Map ? Map<String, dynamic>.from(raw) : null,
          initialScore: roundData[dataKey],
        ),
      ).then((result) {
        if (result != null && result is Map) {
          roundData[dataKey] = result['score'];
          roundData['${dataKey}_Raw'] = result['rawInputs'];
          onDataChanged();
        }
      });
      return;
    }

    // No configuration for this cell: plain number entry.
    TextEditingController controller = TextEditingController(
      text: roundData[dataKey]?.toString() ?? "",
    );
    void save(BuildContext ctx) {
      final text = controller.text.trim();
      roundData[dataKey] = text.isEmpty ? null : (int.tryParse(text) ?? text);
      onDataChanged();
      Navigator.pop(ctx);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(defaultTitle, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => save(ctx),
          style: const TextStyle(color: Colors.white, fontSize: 24),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: "0",
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => save(ctx),
            child: const Text(
              "SAVE",
              style: TextStyle(color: Color(0xFF00A2FF)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget? buildExtraAssignmentUI({
    required BuildContext context,
    required void Function(VoidCallback fn) setModalState,
    required List<String> playerNames,
    int? activePlayerIndex,
    required Map<String, dynamic> customSettings,
    required void Function(String key, dynamic value) onSettingsChanged,
  }) {
    return null;
  }
}
