import 'package:flutter/material.dart';
import 'dart:math';
import '../../../core/shared_widgets/sleek_notification_banner.dart';
import '../../../core/shared_widgets/glass_card.dart';
import 'game_template.dart';

class PokerTemplate extends GameTemplate {
  @override
  String get gameType => 'Poker';

  @override
  int get initialPlayerCount => 2; // Default to 2 players

  Map<String, dynamic> _normalizePhases(dynamic phasesData) {
    if (phasesData is List) {
      Map<String, dynamic> map = {'0': [], '1': [], '2': [], '3': []};
      for (int i = 0; i < phasesData.length; i++) {
        map[i.toString()] = phasesData[i];
      }
      return map;
    } else if (phasesData is Map) {
      return Map<String, dynamic>.from(phasesData);
    }
    return {'0': [], '1': [], '2': [], '3': []};
  }

  Map<String, dynamic>? _getLatestAction(
    Map<String, dynamic> round,
    int phase,
    int pIndex,
  ) {
    if (round['phases'] != null) {
      Map<String, dynamic> phasesMap = _normalizePhases(round['phases']);
      List phaseLog = phasesMap[phase.toString()] as List? ?? [];
      for (int i = phaseLog.length - 1; i >= 0; i--) {
        if (phaseLog[i]['pIndex'] == pIndex) {
          return Map<String, dynamic>.from(phaseLog[i]);
        }
      }
    } else {
      if (round['p${pIndex + 1}_${phase}_act'] != null) {
        return {
          'act': round['p${pIndex + 1}_${phase}_act'],
          'amt':
              int.tryParse(
                round['p${pIndex + 1}_${phase}_amt']?.toString() ?? '0',
              ) ??
              0,
        };
      }
    }
    return null;
  }

  bool _roundHasActions(Map<String, dynamic> round) {
    if (round['phases'] != null) {
      Map<String, dynamic> pMap = _normalizePhases(round['phases']);
      for (var val in pMap.values) {
        if (val is List && val.isNotEmpty) return true;
      }
    } else {
      for (var k in round.keys) {
        if (k.endsWith('_act')) return true;
      }
    }
    return false;
  }

  List<int>? _getExpectedTurn(
    List<Map<String, dynamic>> rounds,
    int roundIndex,
    int playerCount,
  ) {
    if (rounds.isEmpty || roundIndex >= rounds.length) return null;
    if (rounds[roundIndex]['winner'] != null &&
        rounds[roundIndex]['winner'].toString().isNotEmpty) {
      return null;
    }

    bool isPlayerActive(int p, int phase) {
      for (int i = 0; i <= phase; i++) {
        var action = _getLatestAction(rounds[roundIndex], i, p);
        if (action != null && action['act'] == 'F') {
          return false;
        }
      }
      return true;
    }

    int getCurrentPhaseMaxBet(int phase) {
      int maxBet = 0;
      for (int i = 0; i < playerCount; i++) {
        var action = _getLatestAction(rounds[roundIndex], phase, i);
        if (action != null) {
          int a = action['amt'] as int;
          if (a > maxBet) maxBet = a;
        }
      }
      return maxBet;
    }

    bool isPhaseComplete(int phase) {
      int maxBet = getCurrentPhaseMaxBet(phase);
      int activeCount = 0;
      int actedCount = 0;
      int matchedCount = 0;

      for (int p = 0; p < playerCount; p++) {
        if (isPlayerActive(p, phase)) {
          activeCount++;
          String act = '';
          int amt = 0;
          var action = _getLatestAction(rounds[roundIndex], phase, p);
          if (action != null) {
            act = action['act'];
            amt = action['amt'];
          }

          if (act.isNotEmpty) actedCount++;
          if (amt == maxBet) matchedCount++;
        }
      }
      if (activeCount <= 1) return true;
      return actedCount == activeCount && matchedCount == activeCount;
    }

    int currentPhase = 0;
    while (currentPhase < 4 && isPhaseComplete(currentPhase)) {
      currentPhase++;
    }

    if (currentPhase >= 4) return [4, 0];

    Map<String, dynamic>? phasesMap;
    if (rounds[roundIndex]['phases'] != null) {
      phasesMap = _normalizePhases(rounds[roundIndex]['phases']);
    }
    List phaseLog = phasesMap?[currentPhase.toString()] as List? ?? [];

    if (phaseLog.isEmpty) {
      int step = roundIndex % playerCount;
      while (!isPlayerActive(step, currentPhase)) {
        step = (step + 1) % playerCount;
      }
      return [currentPhase, step];
    } else {
      int maxBet = getCurrentPhaseMaxBet(currentPhase);
      int lastPIndex =
          int.tryParse(phaseLog.last['pIndex']?.toString() ?? '0') ?? 0;
      int step = (lastPIndex + 1) % playerCount;
      for (int i = 0; i < playerCount; i++) {
        if (isPlayerActive(step, currentPhase)) {
          var actData = _getLatestAction(
            rounds[roundIndex],
            currentPhase,
            step,
          );
          if (actData == null ||
              actData['act'] == '' ||
              actData['amt'] < maxBet) {
            return [currentPhase, step];
          }
        }
        step = (step + 1) % playerCount;
      }
    }
    return null;
  }

  @override
  bool canAddPlayer(int currentPlayerCount, List<Map<String, dynamic>> rounds) {
    if (currentPlayerCount >= 10) return false;
    if (rounds.length > 1) return false;
    if (rounds.isNotEmpty) {
      for (int p = 0; p < currentPlayerCount; p++) {
        for (int phase = 0; phase < 4; phase++) {
          if (_getLatestAction(rounds.first, phase, p) != null) {
            return false;
          }
        }
      }
    }
    return true;
  }

  @override
  List<String> generateInitialPlayerNames() {
    return List.generate(initialPlayerCount, (i) => "Player ${i + 1}");
  }

  @override
  Map<String, dynamic> createNewRound(int roundNum, int playerCount) => {
    'roundNum': roundNum,
    'phases': {'0': [], '1': [], '2': [], '3': []},
  };

  bool _isRoundComplete(Map<String, dynamic> round) {
    return round['winner'] != null && round['winner'].toString().isNotEmpty;
  }

  @override
  bool canAddRound(
    List<Map<String, dynamic>> rounds,
    int playerCount, {
    Map<String, dynamic> customSettings = const {},
  }) {
    if (rounds.isEmpty) return true;
    return _isRoundComplete(rounds.last);
  }

  final List<String> _phases = ['Pre-Flop', 'Flop', 'Turn', 'River'];

  @override
  bool isReadyToFinalize(
    List<Map<String, dynamic>> rounds,
    int playerCount, {
    Map<String, dynamic> customSettings = const {},
  }) {
    if (rounds.isEmpty) return false;
    for (var r in rounds) {
      if (r['winner'] == null || r['winner'].toString().isEmpty) {
        if (r == rounds.last) {
          if (!_roundHasActions(r))
            return true; // Last round is completely empty, safe to finalize and ignore
        }
        return false;
      }
    }
    return true;
  }

  @override
  void onRoundRemoved(List<Map<String, dynamic>> rounds) {}

  @override
  void recalculateTotals(
    List<Map<String, dynamic>> rounds,
    int playerCount, {
    Map<String, dynamic> customSettings = const {},
  }) {
    List<int> runningTotals = List.filled(playerCount, 0);

    for (int i = 0; i < rounds.length; i++) {
      int roundBuyIn = int.tryParse(rounds[i]['buyIn']?.toString() ?? '2') ?? 2;
      bool hasActions = _roundHasActions(rounds[i]);
      int effectiveBuyIn = hasActions ? roundBuyIn : 0;
      int pot = 0;
      List<int> spentThisRound = List.filled(playerCount, effectiveBuyIn);

      // Sum up points spent across all 4 phases for each player
      for (int p = 0; p < playerCount; p++) {
        for (int phase = 0; phase < 4; phase++) {
          var action = _getLatestAction(rounds[i], phase, p);
          if (action != null) {
            spentThisRound[p] += action['amt'] as int;
          }
        }
        pot += spentThisRound[p];
      }

      rounds[i]['pot'] = pot;
      String? winner = rounds[i]['winner'];

      // Calculate net profit cumulatively
      for (int p = 0; p < playerCount; p++) {
        int roundNet = -spentThisRound[p];
        if (winner == 'p${p + 1}') {
          roundNet += pot;
        }
        runningTotals[p] += roundNet;
        rounds[i]['p${p + 1}Total'] = runningTotals[p].toString();
      }
    }
  }

  @override
  String getWinnerDeclaration(
    List<String> playerNames,
    List<Map<String, dynamic>> rounds, {
    Map<String, dynamic> customSettings = const {},
  }) {
    if (playerNames.isEmpty || rounds.isEmpty) return "Finalize game?";

    var lastRound = rounds.last;
    List<int> totals = List.generate(
      playerNames.length,
      (i) => int.tryParse(lastRound['p${i + 1}Total']?.toString() ?? '0') ?? 0,
    );

    int maxScore = totals.reduce(max);
    int winnerIndex = totals.indexOf(maxScore);

    return "Declare ${playerNames[winnerIndex]} as the biggest winner with a net profit of +$maxScore?";
  }

  @override
  Widget? buildExtraAssignmentUI({
    required BuildContext context,
    required void Function(VoidCallback fn) setModalState,
    required List<String> playerNames,
    int? activePlayerIndex,
    required Map<String, dynamic> customSettings,
    required void Function(String, dynamic) onSettingsChanged,
  }) => null;

  bool _hasFolded(
    List<Map<String, dynamic>> rounds,
    int roundIndex,
    int playerIndex,
    int currentPhase,
  ) {
    for (int i = 0; i < currentPhase; i++) {
      var action = _getLatestAction(rounds[roundIndex], i, playerIndex);
      if (action != null && action['act'] == 'F') {
        return true;
      }
    }
    return false;
  }

  Widget _buildHandRankingsChart() {
    final List<Map<String, dynamic>> hands = [
      {
        "name": "Royal Flush",
        "cards": [
          ["A", "♠", Colors.black],
          ["K", "♠", Colors.black],
          ["Q", "♠", Colors.black],
          ["J", "♠", Colors.black],
          ["10", "♠", Colors.black],
        ],
      },
      {
        "name": "Straight Flush",
        "cards": [
          ["9", "♥", Colors.redAccent],
          ["8", "♥", Colors.redAccent],
          ["7", "♥", Colors.redAccent],
          ["6", "♥", Colors.redAccent],
          ["5", "♥", Colors.redAccent],
        ],
      },
      {
        "name": "Four of a Kind",
        "cards": [
          ["8", "♣", Colors.black],
          ["8", "♦", Colors.redAccent],
          ["8", "♥", Colors.redAccent],
          ["8", "♠", Colors.black],
          ["4", "♥", Colors.redAccent],
        ],
      },
      {
        "name": "Full House",
        "cards": [
          ["K", "♠", Colors.black],
          ["K", "♥", Colors.redAccent],
          ["K", "♣", Colors.black],
          ["7", "♦", Colors.redAccent],
          ["7", "♠", Colors.black],
        ],
      },
      {
        "name": "Flush",
        "cards": [
          ["Q", "♦", Colors.redAccent],
          ["9", "♦", Colors.redAccent],
          ["6", "♦", Colors.redAccent],
          ["4", "♦", Colors.redAccent],
          ["2", "♦", Colors.redAccent],
        ],
      },
      {
        "name": "Straight",
        "cards": [
          ["J", "♠", Colors.black],
          ["10", "♥", Colors.redAccent],
          ["9", "♣", Colors.black],
          ["8", "♦", Colors.redAccent],
          ["7", "♠", Colors.black],
        ],
      },
      {
        "name": "Three of a Kind",
        "cards": [
          ["5", "♣", Colors.black],
          ["5", "♠", Colors.black],
          ["5", "♥", Colors.redAccent],
          ["Q", "♦", Colors.redAccent],
          ["8", "♠", Colors.black],
        ],
      },
      {
        "name": "Two Pair",
        "cards": [
          ["J", "♥", Colors.redAccent],
          ["J", "♣", Colors.black],
          ["4", "♠", Colors.black],
          ["4", "♦", Colors.redAccent],
          ["9", "♥", Colors.redAccent],
        ],
      },
      {
        "name": "Pair",
        "cards": [
          ["10", "♠", Colors.black],
          ["10", "♦", Colors.redAccent],
          ["K", "♥", Colors.redAccent],
          ["6", "♣", Colors.black],
          ["3", "♠", Colors.black],
        ],
      },
      {
        "name": "High Card",
        "cards": [
          ["A", "♣", Colors.black],
          ["J", "♦", Colors.redAccent],
          ["8", "♥", Colors.redAccent],
          ["5", "♠", Colors.black],
          ["2", "♣", Colors.black],
        ],
      },
    ];

    Widget buildCard(String rank, String suit, Color color) {
      return Container(
        width: 22,
        height: 32,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 2,
              offset: const Offset(1, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 3),
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  rank,
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 2, right: 3),
              child: Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  suit,
                  style: TextStyle(color: color, fontSize: 10, height: 1),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF00A2FF).withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00A2FF).withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.format_list_numbered,
                color: Color(0xFF00A2FF),
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                "POKER HAND RANKINGS",
                style: TextStyle(
                  color: Color(0xFF00A2FF),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(hands.length, (index) {
              final hand = hands[index];
              final cards = hand["cards"] as List;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${index + 1}.",
                          style: const TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          hand["name"],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: cards
                          .map(
                            (c) => buildCard(
                              c[0] as String,
                              c[1] as String,
                              c[2] as Color,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

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
    bool showNetColumn = customSettings['showNetColumn'] == true;
    double rndWidth = 40.0;
    double buyInWidth = 55.0;
    double potWidth = 105.0;
    double minPlayerColWidth = showNetColumn ? 175.0 : 140.0;

    // Dynamic edge-to-edge calculation (Same architecture as Yahtzee)
    double requiredWidth =
        rndWidth +
        buyInWidth +
        potWidth +
        (minPlayerColWidth * playerNames.length);
    bool needsScroll = requiredWidth > constraints.maxWidth;

    double actualPlayerColWidth = needsScroll
        ? minPlayerColWidth
        : (constraints.maxWidth - rndWidth - buyInWidth - potWidth) /
              playerNames.length;

    Map<int, TableColumnWidth> colWidths = {0: FixedColumnWidth(rndWidth)};
    colWidths[1] = FixedColumnWidth(buyInWidth);
    for (int i = 0; i < playerNames.length; i++) {
      colWidths[i + 2] = FixedColumnWidth(actualPlayerColWidth);
    }
    colWidths[playerNames.length + 2] = FixedColumnWidth(potWidth);

    List<TableRow> rows = [];

    // --- HEADER ROW ---
    List<Widget> headerCells = [_buildHeaderCell("RND")];
    headerCells.add(_buildHeaderCell("BUY\nIN"));
    for (int i = 0; i < playerNames.length; i++) {
      headerCells.add(
        _buildPlayerHeaderCell(
          i,
          playerNames,
          rounds,
          isFinalized,
          onPlayerTap,
          customSettings,
        ),
      );
    }
    headerCells.add(_buildHeaderCell("POT /\nWIN", isPot: true));
    rows.add(TableRow(children: headerCells));

    // --- DATA ROWS ---
    for (int r = 0; r < rounds.length; r++) {
      List<int>? expectedTurn = _getExpectedTurn(rounds, r, playerNames.length);

      List<Widget> rowCells = [
        _buildCell("${r + 1}", isBold: true, color: Colors.white54),
      ];

      rowCells.add(
        _buildBuyInCell(context, r, rounds, isFinalized, onDataChanged),
      );

      for (int p = 0; p < playerNames.length; p++) {
        rowCells.add(
          _buildPlayerPhaseRow(
            context,
            r,
            p,
            rounds,
            playerNames,
            isFinalized,
            onDataChanged,
            customSettings,
            expectedTurn,
          ),
        );
      }

      rowCells.add(
        _buildPotCell(
          context,
          r,
          rounds,
          playerNames,
          isFinalized,
          onDataChanged,
        ),
      );

      rows.add(
        TableRow(
          decoration: BoxDecoration(
            color: r % 2 == 0
                ? Colors.transparent
                : Colors.white.withOpacity(0.02),
          ),
          children: rowCells,
        ),
      );
    }

    Widget tableGrid = Table(
      columnWidths: colWidths,
      border: TableBorder(
        horizontalInside: BorderSide(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        verticalInside: BorderSide(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      children: rows,
    );

    Widget gridWidget;
    if (needsScroll) {
      gridWidget = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: tableGrid,
        ),
      );
    } else {
      gridWidget = tableGrid;
    }

    if (customSettings['showHandRankings'] == true) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [_buildHandRankingsChart(), gridWidget],
      );
    }
    return gridWidget;
  }

  Widget _buildHeaderCell(String text, {bool isPot = false}) {
    Widget cellContent = Padding(
      padding: EdgeInsets.symmetric(
        vertical: isPot ? 8.0 : 24.0,
        horizontal: 4.0,
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isPot ? Colors.white : Colors.white54,
              fontWeight: FontWeight.bold,
              fontSize: isPot ? 14.0 : 12.0,
              height: 1.2,
            ),
          ),
        ),
      ),
    );

    if (isPot) {
      return TableCell(
        verticalAlignment: TableCellVerticalAlignment.fill,
        child: Container(
          color: Colors.black.withOpacity(0.3),
          child: cellContent,
        ),
      );
    }

    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: cellContent,
    );
  }

  Widget _buildBuyInCell(
    BuildContext context,
    int roundIndex,
    List<Map<String, dynamic>> rounds,
    bool isFinalized,
    VoidCallback onDataChanged,
  ) {
    int buyIn =
        int.tryParse(rounds[roundIndex]['buyIn']?.toString() ?? '2') ?? 2;
    bool hasActions = _roundHasActions(rounds[roundIndex]);

    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.fill,
      child: InkWell(
        onTap: (isFinalized || hasActions)
            ? null
            : () {
                int currentBuyIn = buyIn;
                showDialog(
                  context: context,
                  builder: (ctx) => StatefulBuilder(
                    builder: (context, setDialogState) => AlertDialog(
                      backgroundColor: const Color(0xFF1E1E1E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Text(
                        "Round Buy-In / Ante",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      content: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.white54,
                              size: 32,
                            ),
                            onPressed: currentBuyIn > 0
                                ? () => setDialogState(() => currentBuyIn--)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            "$currentBuyIn",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(
                              Icons.add_circle_outline,
                              color: Colors.white,
                              size: 32,
                            ),
                            onPressed: () =>
                                setDialogState(() => currentBuyIn++),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            "Cancel",
                            style: TextStyle(color: Colors.white54),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00A2FF),
                          ),
                          onPressed: () {
                            rounds[roundIndex]['buyIn'] = currentBuyIn;
                            onDataChanged();
                            Navigator.pop(ctx);
                          },
                          child: const Text(
                            "SAVE",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
        child: Container(
          color: Colors.white.withOpacity(0.02),
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 4.0),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                buyIn.toString(),
                style: TextStyle(
                  color: (isFinalized || hasActions)
                      ? Colors.white54
                      : const Color(0xFF00A2FF),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerHeaderCell(
    int playerIndex,
    List<String> names,
    List<Map<String, dynamic>> rounds,
    bool isFinalized,
    Function(int) onPlayerTap,
    Map<String, dynamic> customSettings,
  ) {
    bool isGroupGame = customSettings['isGroupGame'] == true;
    bool isUnassigned = isGroupGame && names[playerIndex].startsWith('Player ');
    bool showNetColumn = customSettings['showNetColumn'] == true;

    int totalNet = 0;
    if (rounds.isNotEmpty) {
      totalNet =
          int.tryParse(
            rounds.last['p${playerIndex + 1}Total']?.toString() ?? '0',
          ) ??
          0;
    }
    String netStr = totalNet > 0
        ? "+$totalNet"
        : (totalNet < 0 ? "$totalNet" : "0");
    Color netColor = totalNet > 0
        ? Colors.greenAccent
        : (totalNet < 0 ? Colors.redAccent : Colors.white54);

    Widget netHeaderTop = Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border(left: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              netStr,
              style: TextStyle(
                color: netColor,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );

    Widget topRow = showNetColumn
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 4,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      names[playerIndex],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF00A2FF),
                        fontWeight: FontWeight.w900,
                        fontSize: 14.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              Expanded(flex: 1, child: netHeaderTop),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      names[playerIndex],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF00A2FF),
                        fontWeight: FontWeight.w900,
                        fontSize: 14.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 50, child: netHeaderTop),
            ],
          );

    Widget cellContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 5, child: topRow),
        Container(height: 1, color: Colors.white.withOpacity(0.1)),
        Expanded(
          flex: 3,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSubHeader("PF"),
              _buildSubHeader("FL"),
              _buildSubHeader("TU"),
              _buildSubHeader("RI"),
              if (showNetColumn)
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      border: Border(
                        left: BorderSide(color: Colors.white.withOpacity(0.05)),
                      ),
                    ),
                    child: const Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "NET",
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    Widget cell = InkWell(
      onTap: isFinalized ? null : () => onPlayerTap(playerIndex),
      child: cellContent,
    );

    if (isUnassigned && !isFinalized) {
      return TableCell(
        verticalAlignment: TableCellVerticalAlignment.fill,
        child: _PulsingGlow(color: const Color(0xFF00A2FF), child: cell),
      );
    }

    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.fill,
      child: cell,
    );
  }

  Widget _buildSubHeader(String text) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCell(
    String text, {
    bool isBold = false,
    Color color = Colors.white,
  }) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 4.0),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerPhaseRow(
    BuildContext context,
    int roundIndex,
    int playerIndex,
    List<Map<String, dynamic>> rounds,
    List<String> names,
    bool isFinalized,
    VoidCallback onDataChanged,
    Map<String, dynamic> customSettings,
    List<int>? expectedTurn,
  ) {
    bool showNetColumn = customSettings['showNetColumn'] == true;
    int roundBuyIn =
        int.tryParse(rounds[roundIndex]['buyIn']?.toString() ?? '2') ?? 2;
    bool hasActions = _roundHasActions(rounds[roundIndex]);

    int spent = hasActions ? roundBuyIn : 0;
    for (int phase = 0; phase < 4; phase++) {
      var actionData = _getLatestAction(rounds[roundIndex], phase, playerIndex);
      if (actionData != null) {
        spent += actionData['amt'] as int;
      }
    }
    int roundPot =
        int.tryParse(rounds[roundIndex]['pot']?.toString() ?? '0') ?? 0;
    String? winner = rounds[roundIndex]['winner'];
    int roundNet = -spent;
    if (winner == 'p${playerIndex + 1}') {
      roundNet += roundPot;
    }
    String roundNetStr = roundNet > 0
        ? "+$roundNet"
        : (roundNet < 0 ? "$roundNet" : "0");
    Color roundNetColor = roundNet > 0
        ? Colors.greenAccent
        : (roundNet < 0 ? Colors.redAccent : Colors.white54);

    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.fill,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildActionCell(
            context,
            roundIndex,
            playerIndex,
            0,
            rounds,
            names,
            isFinalized,
            onDataChanged,
            customSettings,
            expectedTurn,
          ),
          _buildActionCell(
            context,
            roundIndex,
            playerIndex,
            1,
            rounds,
            names,
            isFinalized,
            onDataChanged,
            customSettings,
            expectedTurn,
          ),
          _buildActionCell(
            context,
            roundIndex,
            playerIndex,
            2,
            rounds,
            names,
            isFinalized,
            onDataChanged,
            customSettings,
            expectedTurn,
          ),
          _buildActionCell(
            context,
            roundIndex,
            playerIndex,
            3,
            rounds,
            names,
            isFinalized,
            onDataChanged,
            customSettings,
            expectedTurn,
          ),
          if (showNetColumn)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  border: Border(
                    left: BorderSide(color: Colors.white.withOpacity(0.05)),
                  ),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      roundNetStr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: roundNetColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionCell(
    BuildContext context,
    int roundIndex,
    int playerIndex,
    int phaseIndex,
    List<Map<String, dynamic>> rounds,
    List<String> names,
    bool isFinalized,
    VoidCallback onDataChanged,
    Map<String, dynamic> customSettings,
    List<int>? expectedTurn,
  ) {
    bool isGroupGame = customSettings['isGroupGame'] == true;
    bool anyUnassigned =
        isGroupGame && names.any((n) => n.startsWith('Player '));
    bool folded = _hasFolded(rounds, roundIndex, playerIndex, phaseIndex);
    bool roundHasWinner =
        rounds[roundIndex]['winner'] != null &&
        rounds[roundIndex]['winner'].toString().isNotEmpty;

    var actionData = _getLatestAction(
      rounds[roundIndex],
      phaseIndex,
      playerIndex,
    );
    String action = actionData?['act']?.toString() ?? "";
    String amtStr = actionData?['amt']?.toString() ?? "0";

    Color textColor = Colors.white24;
    String display = "-";

    if (folded) {
      textColor = Colors.white12;
      display = "X"; // Folded prior
    } else if (action.isNotEmpty) {
      textColor = Colors.white;
      switch (action) {
        case 'F':
          display = "F";
          break;
        case 'K':
          display = "K"; // Check
          break;
        case 'B':
          display = "B\n$amtStr";
          break;
        case 'C':
          display = "C\n$amtStr";
          break;
        case 'R':
          display = "R\n$amtStr";
          break;
      }
    } else if (roundHasWinner) {
      textColor = Colors.white12;
      display = "X";
    }

    bool shouldGlow = false;
    if (!isFinalized && !anyUnassigned && expectedTurn != null) {
      if (expectedTurn[0] == phaseIndex && expectedTurn[1] == playerIndex) {
        shouldGlow = true;
      }
    }

    Widget cellWidget = InkWell(
      onTap: (isFinalized || folded || roundHasWinner)
          ? null
          : () {
              if (anyUnassigned) {
                SleekNotificationBanner.show(
                  "Assign Players",
                  "Please assign all players to the group before scoring.",
                  icon: Icons.group,
                  color: Colors.orangeAccent,
                );
                return;
              }

              if (!shouldGlow) {
                if (expectedTurn != null && expectedTurn[0] >= 4) {
                  SleekNotificationBanner.show(
                    "Showdown",
                    "Betting is complete. Please tap the POT / WIN cell to assign the winner.",
                    icon: Icons.check_circle_outline,
                    color: Colors.greenAccent,
                  );
                  return;
                }

                String expectedName = "the next player";
                String phaseName = "the next phase";
                if (expectedTurn != null && expectedTurn[1] < names.length) {
                  expectedName = names[expectedTurn[1]];
                  if (expectedTurn[0] < _phases.length) {
                    phaseName = _phases[expectedTurn[0]];
                  }
                }
                SleekNotificationBanner.show(
                  "Not Your Turn",
                  "It is currently $expectedName's turn to act in the $phaseName.",
                  icon: Icons.hourglass_empty,
                  color: Colors.orangeAccent,
                );
                return;
              }

              int targetPhase = phaseIndex;
              int targetPlayer = playerIndex;

              if (expectedTurn != null) {
                targetPhase = expectedTurn[0];
                targetPlayer = expectedTurn[1];
              }

              _showPhaseActionDialog(
                context,
                roundIndex,
                targetPhase,
                targetPlayer,
                rounds,
                names,
                onDataChanged,
                customSettings,
              );
            },
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              display,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );

    if (shouldGlow) {
      return Expanded(
        child: _PulsingGlow(color: const Color(0xFF00A2FF), child: cellWidget),
      );
    }
    return Expanded(child: cellWidget);
  }

  Widget _buildPotCell(
    BuildContext context,
    int roundIndex,
    List<Map<String, dynamic>> rounds,
    List<String> names,
    bool isFinalized,
    VoidCallback onDataChanged,
  ) {
    int pot = int.tryParse(rounds[roundIndex]['pot']?.toString() ?? '0') ?? 0;
    String winnerCode = rounds[roundIndex]['winner']?.toString() ?? "";

    String winnerName = "-";
    if (winnerCode.startsWith('p')) {
      int wIdx = int.tryParse(winnerCode.substring(1)) ?? 0;
      if (wIdx > 0 && wIdx <= names.length) {
        winnerName = names[wIdx - 1];
      }
    }

    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.fill,
      child: InkWell(
        onTap: isFinalized
            ? null
            : () => _showWinnerDialog(
                context,
                roundIndex,
                rounds,
                names,
                onDataChanged,
              ),
        child: Container(
          color: Colors.black.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    pot > 0 ? "$pot" : "-",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    winnerName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF00A2FF),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPhaseActionDialog(
    BuildContext context,
    int roundIndex,
    int initialPhaseIndex,
    int startingPlayerIndex,
    List<Map<String, dynamic>> rounds,
    List<String> playerNames,
    VoidCallback onDataChanged,
    Map<String, dynamic> customSettings,
  ) {
    int currentStep = startingPlayerIndex;
    int phaseIndex = initialPhaseIndex;
    bool enteringAmount = false;
    String pendingAction = '';
    TextEditingController amountCtrl = TextEditingController();

    List<int> stepHistory = [];
    List<int> phaseHistory = [];

    if (rounds[roundIndex]['phases'] != null) {
      Map<String, dynamic> phasesMap = _normalizePhases(
        rounds[roundIndex]['phases'],
      );
      for (int ph = 0; ph < 4; ph++) {
        List pLog = phasesMap[ph.toString()] as List? ?? [];
        for (var act in pLog) {
          stepHistory.add(act['pIndex'] as int);
          phaseHistory.add(ph);
        }
      }
    }

    int roundBuyIn =
        int.tryParse(rounds[roundIndex]['buyIn']?.toString() ?? '2') ?? 2;

    int getCurrentPhaseMaxBet(int phase) {
      if (phase >= 4) return 0;
      int maxBet = 0;
      for (int i = 0; i < playerNames.length; i++) {
        var action = _getLatestAction(rounds[roundIndex], phase, i);
        if (action != null) {
          int a = action['amt'] as int;
          if (a > maxBet) maxBet = a;
        }
      }
      return maxBet;
    }

    bool isPlayerActive(int p, int phase) {
      if (phase >= 4) phase = 3;
      for (int i = 0; i <= phase; i++) {
        var action = _getLatestAction(rounds[roundIndex], i, p);
        if (action != null && action['act'] == 'F') {
          return false;
        }
      }
      return true;
    }

    bool isPhaseComplete(int phase) {
      if (phase >= 4) return true;
      int maxBet = getCurrentPhaseMaxBet(phase);
      int activeCount = 0;
      int actedCount = 0;
      int matchedCount = 0;

      for (int p = 0; p < playerNames.length; p++) {
        if (isPlayerActive(p, phase)) {
          activeCount++;
          String act = '';
          int amt = 0;
          var action = _getLatestAction(rounds[roundIndex], phase, p);
          if (action != null) {
            act = action['act'];
            amt = action['amt'];
          }

          if (act.isNotEmpty) actedCount++;
          if (amt == maxBet) matchedCount++;
        }
      }
      if (activeCount <= 1) return true;
      return actedCount == activeCount && matchedCount == activeCount;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String currentPlayerName = currentStep < playerNames.length
                ? playerNames[currentStep]
                : '';
            int currentPhaseMaxBet = getCurrentPhaseMaxBet(phaseIndex);
            bool hasBet = currentPhaseMaxBet > 0;

            bool hasRaise = false;
            for (int p = 0; p < playerNames.length; p++) {
              var action = _getLatestAction(rounds[roundIndex], phaseIndex, p);
              if (action != null && action['act'] == 'R') {
                hasRaise = true;
                break;
              }
            }

            int roundBuyIn =
                int.tryParse(rounds[roundIndex]['buyIn']?.toString() ?? '2') ??
                2;
            bool hasActions = _roundHasActions(rounds[roundIndex]);
            List<int> spentThisRound = List.filled(
              playerNames.length,
              hasActions ? roundBuyIn : 0,
            );
            for (int p = 0; p < playerNames.length; p++) {
              for (int phase = 0; phase < 4; phase++) {
                var action = _getLatestAction(rounds[roundIndex], phase, p);
                if (action != null) {
                  spentThisRound[p] += action['amt'] as int;
                }
              }
            }

            void saveAction(String act, int amt) {
              stepHistory.add(currentStep);
              phaseHistory.add(phaseIndex);

              if (rounds[roundIndex]['phases'] == null ||
                  rounds[roundIndex]['phases'] is List) {
                rounds[roundIndex]['phases'] = _normalizePhases(
                  rounds[roundIndex]['phases'],
                );
              }

              Map<String, dynamic> phasesMap =
                  rounds[roundIndex]['phases'] as Map<String, dynamic>;
              if (!phasesMap.containsKey(phaseIndex.toString())) {
                phasesMap[phaseIndex.toString()] = [];
              }
              (phasesMap[phaseIndex.toString()] as List).add({
                'pIndex': currentStep,
                'act': act,
                'amt': amt,
              });

              int activePlayers = 0;
              int lastActivePlayer = -1;
              for (int p = 0; p < playerNames.length; p++) {
                if (isPlayerActive(p, phaseIndex)) {
                  activePlayers++;
                  lastActivePlayer = p;
                }
              }

              if (activePlayers == 1 && lastActivePlayer != -1) {
                rounds[roundIndex]['winner'] = 'p${lastActivePlayer + 1}';
                if (roundIndex == rounds.length - 1) {
                  rounds.add({
                    'roundNum': rounds.length + 1,
                    'phases': {'0': [], '1': [], '2': [], '3': []},
                    'buyIn':
                        int.tryParse(
                          rounds[roundIndex]['buyIn']?.toString() ?? '2',
                        ) ??
                        2,
                  });
                }
                recalculateTotals(rounds, playerNames.length);
                onDataChanged();
                Navigator.pop(ctx);
                return;
              }

              if (activePlayers > 1 && rounds[roundIndex]['winner'] != null) {
                rounds[roundIndex].remove('winner');
              }

              // Recalculate everything to keep pot updated immediately
              recalculateTotals(rounds, playerNames.length);
              onDataChanged();

              if (isPhaseComplete(phaseIndex)) {
                if (phaseIndex < 3) {
                  phaseIndex++;
                  currentStep = roundIndex % playerNames.length;
                  while (!isPlayerActive(currentStep, phaseIndex)) {
                    currentStep = (currentStep + 1) % playerNames.length;
                  }
                } else {
                  phaseIndex = 4;
                  currentStep = 0;
                }
              } else {
                int maxBet = getCurrentPhaseMaxBet(phaseIndex);
                while (true) {
                  currentStep = (currentStep + 1) % playerNames.length;
                  if (isPlayerActive(currentStep, phaseIndex)) {
                    var actData = _getLatestAction(
                      rounds[roundIndex],
                      phaseIndex,
                      currentStep,
                    );
                    if (actData == null ||
                        actData['act'] == '' ||
                        actData['amt'] < maxBet) {
                      break;
                    }
                  }
                }
              }

              setDialogState(() {
                enteringAmount = false;
                pendingAction = '';
                amountCtrl.clear();
              });
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "Hand ${roundIndex + 1}: ${phaseIndex < 4 ? _phases[phaseIndex] : 'Showdown'}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (phaseIndex < 4)
                    Text(
                      "${currentStep + 1} / ${playerNames.length}",
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (phaseIndex < 4) ...[
                      Text(
                        currentPlayerName,
                        style: const TextStyle(
                          color: Color(0xFF00A2FF),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentPhaseMaxBet > 0
                            ? "Current Max Bet: $currentPhaseMaxBet"
                            : "No bets yet.",
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else ...[
                      const Text(
                        "Showdown",
                        style: TextStyle(
                          color: Color(0xFF00A2FF),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Betting complete.",
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 24),
                    ],

                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: GlassCard(
                          accentColor: const Color(0xFF00A2FF),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  "CURRENT POT",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${rounds[roundIndex]['pot'] ?? 0}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Divider(color: Colors.white12, height: 1),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 12,
                                  alignment: WrapAlignment.center,
                                  children: List.generate(playerNames.length, (
                                    p,
                                  ) {
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          playerNames[p],
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "${spentThisRound[p]}",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    if (phaseIndex >= 4) ...[
                      const Text(
                        "Select the winner of this hand:",
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          ...List.generate(playerNames.length, (i) {
                            bool isWinner =
                                rounds[roundIndex]['winner'] == 'p${i + 1}';
                            return GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  rounds[roundIndex]['winner'] = 'p${i + 1}';
                                });
                                if (roundIndex == rounds.length - 1) {
                                  rounds.add({
                                    'roundNum': rounds.length + 1,
                                    'phases': {
                                      '0': [],
                                      '1': [],
                                      '2': [],
                                      '3': [],
                                    },
                                    'buyIn':
                                        int.tryParse(
                                          rounds[roundIndex]['buyIn']
                                                  ?.toString() ??
                                              '2',
                                        ) ??
                                        2,
                                  });
                                }
                                recalculateTotals(rounds, playerNames.length);
                                onDataChanged();
                                Navigator.pop(ctx);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: isWinner
                                      ? const Color(0xFF00A2FF)
                                      : Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isWinner
                                        ? const Color(0xFF00A2FF)
                                        : Colors.white24,
                                  ),
                                ),
                                child: Text(
                                  playerNames[i],
                                  style: TextStyle(
                                    color: isWinner
                                        ? Colors.white
                                        : Colors.white70,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }),
                          GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                rounds[roundIndex].remove('winner');
                              });
                              recalculateTotals(rounds, playerNames.length);
                              onDataChanged();
                              Navigator.pop(ctx);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.redAccent),
                              ),
                              child: const Text(
                                "Clear Winner",
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if (!enteringAmount) ...[
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildActionButton(
                            "FOLD",
                            const Color(0xFF00A2FF),
                            () {
                              saveAction('F', 0);
                            },
                          ),
                          if (!hasBet)
                            _buildActionButton(
                              "CHECK",
                              const Color(0xFF00A2FF),
                              () {
                                saveAction('K', 0);
                              },
                            ),
                          if (!hasBet)
                            _buildActionButton(
                              "BET",
                              const Color(0xFF00A2FF),
                              () {
                                setDialogState(() {
                                  enteringAmount = true;
                                  pendingAction = 'B';
                                  amountCtrl.text = currentPhaseMaxBet
                                      .toString();
                                });
                              },
                            ),
                          if (hasBet)
                            _buildActionButton(
                              "CALL",
                              const Color(0xFF00A2FF),
                              () {
                                saveAction('C', currentPhaseMaxBet);
                              },
                            ),
                          if (hasBet)
                            _buildActionButton(
                              hasRaise ? "RE-RAISE" : "RAISE",
                              const Color(0xFF00A2FF),
                              () {
                                setDialogState(() {
                                  enteringAmount = true;
                                  pendingAction = 'R';
                                  amountCtrl.text = currentPhaseMaxBet
                                      .toString();
                                });
                              },
                            ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildBetAdjustButton("-25", () {
                            setDialogState(() {
                              int val = int.tryParse(amountCtrl.text) ?? 0;
                              amountCtrl.text = max(0, val - 25).toString();
                            });
                          }),
                          const SizedBox(width: 8),
                          _buildBetAdjustButton("-5", () {
                            setDialogState(() {
                              int val = int.tryParse(amountCtrl.text) ?? 0;
                              amountCtrl.text = max(0, val - 5).toString();
                            });
                          }),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: amountCtrl,
                              autofocus: false,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    signed: false,
                                    decimal: false,
                                  ),
                              style: const TextStyle(
                                color: Color(0xFF00A2FF),
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                hintText: "0",
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.2),
                                ),
                                filled: true,
                                fillColor: Colors.black.withOpacity(0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildBetAdjustButton("+5", () {
                            setDialogState(() {
                              int val = int.tryParse(amountCtrl.text) ?? 0;
                              amountCtrl.text = (val + 5).toString();
                            });
                          }),
                          const SizedBox(width: 8),
                          _buildBetAdjustButton("+25", () {
                            setDialogState(() {
                              int val = int.tryParse(amountCtrl.text) ?? 0;
                              amountCtrl.text = (val + 25).toString();
                            });
                          }),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () {
                              setDialogState(() {
                                enteringAmount = false;
                                pendingAction = '';
                              });
                            },
                            child: const Text(
                              "Cancel Action",
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00A2FF),
                            ),
                            onPressed: () {
                              int val = int.tryParse(amountCtrl.text) ?? 0;
                              saveAction(pendingAction, val);
                            },
                            child: const Text(
                              "CONFIRM",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (!enteringAmount && stepHistory.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setDialogState(() {
                        int prevStep = stepHistory.removeLast();
                        int prevPhase = phaseHistory.removeLast();

                        if (rounds[roundIndex]['phases'] != null) {
                          if (rounds[roundIndex]['phases'] is List) {
                            rounds[roundIndex]['phases'] = _normalizePhases(
                              rounds[roundIndex]['phases'],
                            );
                          }
                          Map<String, dynamic> phasesMap =
                              rounds[roundIndex]['phases']
                                  as Map<String, dynamic>;
                          List? phaseLog =
                              phasesMap[prevPhase.toString()] as List?;
                          if (phaseLog != null && phaseLog.isNotEmpty) {
                            phaseLog.removeLast();
                          }
                        } else {
                          rounds[roundIndex].remove(
                            'p${prevStep + 1}_${prevPhase}_act',
                          );
                          rounds[roundIndex].remove(
                            'p${prevStep + 1}_${prevPhase}_amt',
                          );
                        }

                        int activePlayers = 0;
                        for (int p = 0; p < playerNames.length; p++) {
                          if (isPlayerActive(p, prevPhase)) {
                            activePlayers++;
                          }
                        }
                        if (activePlayers > 1 &&
                            rounds[roundIndex]['winner'] != null) {
                          rounds[roundIndex].remove('winner');
                        }

                        recalculateTotals(rounds, playerNames.length);
                        onDataChanged();

                        currentStep = prevStep;
                        phaseIndex = prevPhase;
                      });
                    },
                    child: const Text(
                      "Change Previous Action",
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                else if (!enteringAmount)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      "Close",
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBetAdjustButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: const Color(0xFF00A2FF).withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF00A2FF), width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF00A2FF),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  // Restored helper method
  Widget _buildActionButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 60,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  void _showWinnerDialog(
    BuildContext context,
    int roundIndex,
    List<Map<String, dynamic>> rounds,
    List<String> playerNames,
    VoidCallback onDataChanged,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            "Hand ${roundIndex + 1} Winner",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ...List.generate(playerNames.length, (i) {
                return GestureDetector(
                  onTap: () {
                    rounds[roundIndex]['winner'] = 'p${i + 1}';
                    if (roundIndex == rounds.length - 1) {
                      rounds.add({
                        'roundNum': rounds.length + 1,
                        'phases': {'0': [], '1': [], '2': [], '3': []},
                        'buyIn':
                            int.tryParse(
                              rounds[roundIndex]['buyIn']?.toString() ?? '2',
                            ) ??
                            2,
                      });
                    }
                    recalculateTotals(rounds, playerNames.length);
                    onDataChanged();
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      playerNames[i],
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              }),
              GestureDetector(
                onTap: () {
                  rounds[roundIndex].remove('winner');
                  recalculateTotals(rounds, playerNames.length);
                  onDataChanged();
                  Navigator.pop(ctx);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: const Text(
                    "Clear Winner",
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PulsingGlow extends StatefulWidget {
  final Widget child;
  final Color color;

  const _PulsingGlow({Key? key, required this.child, required this.color})
    : super(key: key);

  @override
  State<_PulsingGlow> createState() => _PulsingGlowState();
}

class _PulsingGlowState extends State<_PulsingGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.1,
      end: 0.6,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: widget.color.withOpacity(_animation.value * 0.4),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(_animation.value),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
