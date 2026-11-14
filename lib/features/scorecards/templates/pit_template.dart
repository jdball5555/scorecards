import 'package:flutter/material.dart';
import 'dart:math';
import 'game_template.dart';

class PitTemplate extends GameTemplate {
  @override
  String get gameType => 'Pit';

  @override
  int get initialPlayerCount => 3;

  @override
  bool canAddPlayer(int currentPlayerCount, List<Map<String, dynamic>> rounds) {
    return currentPlayerCount < 8 &&
        rounds.length <= 1; // Pit supports 3-8 players
  }

  @override
  List<String> generateInitialPlayerNames() => [
    "Player 1",
    "Player 2",
    "Player 3",
  ];

  @override
  Map<String, dynamic> createNewRound(int roundNum, int playerCount) => {
    'roundNum': roundNum,
  };

  @override
  bool canAddRound(List<Map<String, dynamic>> rounds, int playerCount, {Map<String, dynamic> customSettings = const {}}) {
    if (rounds.isEmpty) return true;
    var lastRound = rounds.last;
    for (int p = 0; p < playerCount; p++) {
      if (lastRound['p${p + 1}Score'] == null ||
          lastRound['p${p + 1}Score'].toString().isEmpty) {
        return false;
      }
    }
    return true;
  }

  @override
  bool isReadyToFinalize(List<Map<String, dynamic>> rounds, int playerCount, {Map<String, dynamic> customSettings = const {}}) {
    if (rounds.isEmpty) return false;
    for (var r in rounds) {
      for (int p = 0; p < playerCount; p++) {
        if (r['p${p + 1}Score'] == null ||
            r['p${p + 1}Score'].toString().isEmpty) {
          return false;
        }
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
    List<int> totals = List.filled(playerCount, 0);
    for (var r in rounds) {
      for (int p = 0; p < playerCount; p++) {
        int score = int.tryParse(r['p${p + 1}Score']?.toString() ?? '') ?? 0;
        totals[p] += score;
        r['p${p + 1}Total'] = totals[p];
      }
    }
  }

  @override
  String getWinnerDeclaration(
    List<String> playerNames,
    List<Map<String, dynamic>> rounds, {
    Map<String, dynamic> customSettings = const {},
  }) {
    List<int> totals = List.generate(playerNames.length, (i) {
      int total = 0;
      for (var r in rounds) {
        total += int.tryParse(r['p${i + 1}Score']?.toString() ?? '') ?? 0;
      }
      return total;
    });

    int maxScore = totals.reduce(max);
    int winnerIndex = totals.indexOf(maxScore);
    return "Declare ${playerNames[winnerIndex]} as the winner with a score of $maxScore?";
  }

  final List<int> _defaultCommodityValues = [50, 60, 70, 75, 80, 85, 100];

  @override
  Widget? buildExtraAssignmentUI({
    required BuildContext context,
    required void Function(VoidCallback fn) setModalState,
    required List<String> playerNames,
    int? activePlayerIndex,
    required Map<String, dynamic> customSettings,
    required void Function(String, dynamic) onSettingsChanged,
  }) {
    List<int> activeValues = List<int>.from(
      customSettings['pitValues'] ??
          _defaultCommodityValues.take(playerNames.length).toList(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          "ACTIVE COMMODITY VALUES",
          style: TextStyle(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _defaultCommodityValues.map((val) {
            bool isActive = activeValues.contains(val);
            return GestureDetector(
              onTap: () {
                setModalState(() {
                  if (isActive) {
                    activeValues.remove(val);
                  } else {
                    activeValues.add(val);
                    activeValues.sort();
                  }
                });
                onSettingsChanged('pitValues', activeValues);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF00A2FF)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFF00A2FF)
                        : Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Text(
                  val.toString(),
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        const Text(
          "Select the point values that match the commodities you are playing with.",
          style: TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(height: 16),
      ],
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
    List<int> activeValues = List<int>.from(
      customSettings['pitValues'] ??
          _defaultCommodityValues.take(playerNames.length).toList(),
    );

    double roundCatWidth = 60.0;
    double minCellWidth = 70.0;
    double requiredWidth = roundCatWidth + (minCellWidth * playerNames.length);
    bool needsScroll = requiredWidth > constraints.maxWidth;

    double actualColWidth = needsScroll
        ? minCellWidth
        : (constraints.maxWidth - roundCatWidth) / playerNames.length;

    Map<int, TableColumnWidth> colWidths = {0: FixedColumnWidth(roundCatWidth)};
    for (int i = 0; i < playerNames.length; i++) {
      colWidths[i + 1] = FixedColumnWidth(actualColWidth);
    }

    List<TableRow> rows = [];

    // Header
    List<Widget> headerCells = [
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Text(
          "ROUND",
          style: TextStyle(
            color: Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: 11.0,
            letterSpacing: 0.5,
          ),
        ),
      ),
    ];

    for (int i = 0; i < playerNames.length; i++) {
      headerCells.add(
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.fill,
          child: InkWell(
            onTap: isFinalized ? null : () => onPlayerTap(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 16.0,
                horizontal: 4.0,
              ),
              child: Center(
                child: Text(
                  playerNames[i],
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
        ),
      );
    }
    rows.add(TableRow(children: headerCells));

    // Rounds
    for (int r = 0; r < rounds.length; r++) {
      List<Widget> roundCells = [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Text(
            "${r + 1}",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14.0,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ];

      for (int p = 0; p < playerNames.length; p++) {
        String score = rounds[r]['p${p + 1}Score']?.toString() ?? "";
        roundCells.add(
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.fill,
            child: InkWell(
              onTap: isFinalized
                  ? null
                  : () {
                      _showScoreDialog(
                        context,
                        r,
                        p,
                        rounds,
                        playerNames[p],
                        activeValues,
                        onDataChanged,
                      );
                    },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border(
                    left: BorderSide(color: Colors.white.withOpacity(0.05)),
                    top: BorderSide(color: Colors.white.withOpacity(0.05)),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 16.0,
                  horizontal: 8.0,
                ),
                child: Center(
                  child: Text(
                    score.isNotEmpty ? score : "-",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
      rows.add(TableRow(children: roundCells));
    }

    // Totals row
    List<Widget> totalsCells = [
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Text(
          "TOTAL",
          style: TextStyle(
            color: Color(0xFF00A2FF),
            fontWeight: FontWeight.w900,
            fontSize: 12.0,
            letterSpacing: 0.5,
          ),
        ),
      ),
    ];

    for (int p = 0; p < playerNames.length; p++) {
      int total = 0;
      for (var r in rounds) {
        total += int.tryParse(r['p${p + 1}Score']?.toString() ?? '') ?? 0;
      }
      totalsCells.add(
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.fill,
          child: Container(
            color: Colors.black.withOpacity(0.3),
            padding: const EdgeInsets.symmetric(
              vertical: 16.0,
              horizontal: 8.0,
            ),
            child: Center(
              child: Text(
                total.toString(),
                style: const TextStyle(
                  color: Color(0xFF00A2FF),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      );
    }
    rows.add(
      TableRow(
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.3)),
        children: totalsCells,
      ),
    );

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

    if (needsScroll) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: tableGrid,
        ),
      );
    }
    return tableGrid;
  }

  void _showScoreDialog(
    BuildContext context,
    int roundIndex,
    int playerIndex,
    List<Map<String, dynamic>> rounds,
    String playerName,
    List<int> activeValues,
    VoidCallback onDataChanged,
  ) {
    String currentScore =
        rounds[roundIndex]['p${playerIndex + 1}Score']?.toString() ?? "";

    // Quick options including common pit scores
    List<String> options = ["0"];
    options.addAll(activeValues.map((v) => v.toString()));
    options.add("-20"); // Bear/Bull penalty

    TextEditingController customController = TextEditingController(
      text: currentScore,
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                "$playerName: Round ${roundIndex + 1}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: options.map((scoreOpt) {
                        final isSelected = currentScore == scoreOpt;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              currentScore = scoreOpt;
                              customController.text = scoreOpt;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 60,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF00A2FF)
                                  : Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF00A2FF)
                                    : Colors.white.withOpacity(0.1),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                scoreOpt,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: customController,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: "Custom Score",
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          currentScore = val;
                        });
                      },
                    ),
                  ],
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
                if (rounds[roundIndex]['p${playerIndex + 1}Score'] != null)
                  TextButton(
                    onPressed: () {
                      rounds[roundIndex].remove('p${playerIndex + 1}Score');
                      onDataChanged();
                      Navigator.pop(ctx);
                    },
                    child: const Text(
                      "CLEAR",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A2FF),
                  ),
                  onPressed: () {
                    if (currentScore.isNotEmpty) {
                      rounds[roundIndex]['p${playerIndex + 1}Score'] =
                          currentScore;
                    }
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
            );
          },
        );
      },
    );
  }
}
