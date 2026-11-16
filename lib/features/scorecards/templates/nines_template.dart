import 'package:flutter/material.dart';
import 'dart:math';
import '../../../core/shared_widgets/sleek_notification_banner.dart';
import 'game_template.dart';

class NinesTemplate extends GameTemplate {
  @override
  String get gameType => 'Nines';

  @override
  int get initialPlayerCount => 2;

  @override
  bool canAddPlayer(int currentPlayerCount, List<Map<String, dynamic>> rounds) {
    // Allows 2-12 players during the Setup phase
    return currentPlayerCount < 12;
  }

  @override
  List<String> generateInitialPlayerNames() => ["Player 1", "Player 2"];

  @override
  Map<String, dynamic> createNewRound(int roundNum, int playerCount) => {
    'roundNum': roundNum,
  };

  bool _isRoundComplete(Map<String, dynamic> round, int playerCount) {
    for (int i = 0; i < playerCount; i++) {
      if (round['p${i + 1}Score'] == null ||
          round['p${i + 1}Score'].toString().isEmpty) {
        return false;
      }
    }
    return true;
  }

  @override
  bool canAddRound(
    List<Map<String, dynamic>> rounds,
    int playerCount, {
    Map<String, dynamic> customSettings = const {},
  }) {
    if (rounds.isEmpty) return true;
    return _isRoundComplete(rounds.last, playerCount);
  }

  @override
  bool isReadyToFinalize(
    List<Map<String, dynamic>> rounds,
    int playerCount, {
    Map<String, dynamic> customSettings = const {},
  }) {
    if (rounds.isEmpty) return false;
    for (var r in rounds) {
      if (!_isRoundComplete(r, playerCount)) return false;
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
    // Reads the rule from the root of the scorecard
    bool exactly100bonus = customSettings['exactly100bonus'] ?? true;

    for (int i = 0; i < playerCount; i++) {
      int total = 0;
      for (int rIndex = 0; rIndex < rounds.length; rIndex++) {
        var r = rounds[rIndex];

        // Safety check: actively scrub the RULE from the round if it got stuck there previously
        r.remove('exactly100bonus');

        total += int.tryParse(r['p${i + 1}Score']?.toString() ?? '') ?? 0;

        // Logs the EVENT (e.g., p1Exactly100Bonus: true) into the specific round
        if (exactly100bonus && total == 100) {
          total = 0;
          r['p${i + 1}Exactly100Bonus'] = true;
        } else {
          r.remove('p${i + 1}Exactly100Bonus');
        }
      }
      if (rounds.isNotEmpty) {
        rounds.last['p${i + 1}Total'] = total.toString();
      }
    }
  }

  @override
  String getWinnerDeclaration(
    List<String> playerNames,
    List<Map<String, dynamic>> rounds, {
    Map<String, dynamic> customSettings = const {},
  }) {
    bool exactly100bonus = customSettings['exactly100bonus'] ?? true;

    List<int> totals = List.generate(playerNames.length, (i) {
      int total = 0;
      for (var r in rounds) {
        total += int.tryParse(r['p${i + 1}Score']?.toString() ?? '') ?? 0;
        if (exactly100bonus && total == 100) {
          total = 0;
        }
      }
      return total;
    });

    // In Nines, the LOWEST score typically wins.
    int minScore = totals.reduce(min);
    int winnerIndex = totals.indexOf(minScore);

    return "Declare ${playerNames[winnerIndex]} as the winner with a low score of $minScore?";
  }

  @override
  Widget? buildExtraAssignmentUI({
    required BuildContext context,
    required void Function(VoidCallback fn) setModalState,
    required List<String> playerNames,
    int? activePlayerIndex,
    required Map<String, dynamic> customSettings,
    required void Function(String, dynamic) onSettingsChanged,
  }) {
    bool exactly100bonus = customSettings['exactly100bonus'] ?? true;

    // Ensure it saves default if touched
    if (!customSettings.containsKey('exactly100bonus')) {
      Future.microtask(() => onSettingsChanged('exactly100bonus', true));
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        activeColor: const Color(0xFF00A2FF),
        title: const Text(
          "Exactly 100 Bonus",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: const Text(
          "If a player hits exactly 100, their score goes back to 0",
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        value: exactly100bonus,
        onChanged: (val) {
          setModalState(() {
            onSettingsChanged('exactly100bonus', val);
          });
        },
      ),
    );
  }

  void _showScoreDialog(
    BuildContext context,
    int roundIndex,
    int playerIndex,
    List<Map<String, dynamic>> rounds,
    List<String> playerNames,
    VoidCallback onDataChanged,
    Map<String, dynamic> customSettings,
  ) {
    bool someoneElseOut = false;
    for (int i = 0; i < playerNames.length; i++) {
      if (i != playerIndex && rounds[roundIndex]['p${i + 1}FirstOut'] == true) {
        someoneElseOut = true;
      }
    }

    bool firstOut = rounds[roundIndex]['p${playerIndex + 1}FirstOut'] == true;
    bool doubleScorePenalty =
        rounds[roundIndex]['p${playerIndex + 1}DoubleScorePenalty'] == true;

    int totalScore =
        int.tryParse(
          rounds[roundIndex]['p${playerIndex + 1}Score']?.toString() ?? '0',
        ) ??
        0;
    int baseScore = totalScore;
    if (firstOut && doubleScorePenalty) {
      baseScore = totalScore ~/ 2;
    }

    TextEditingController overrideController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            int totalScore =
                baseScore * (firstOut && doubleScorePenalty ? 2 : 1);
            overrideController.text = totalScore.toString();

            Widget buildAdjustButton(int amount) {
              return InkWell(
                onTap: () {
                  setDialogState(() {
                    baseScore += amount;
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A2FF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF00A2FF),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      amount > 0 ? "+$amount" : "$amount",
                      style: const TextStyle(
                        color: Color(0xFF00A2FF),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                "Round ${roundIndex + 1}: ${playerNames[playerIndex]}",
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
                    if (someoneElseOut)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.redAccent.withOpacity(0.5),
                          ),
                        ),
                        child: const Text(
                          "Another player is already marked as First to Go Out.",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),

                    const Text(
                      "Base Score",
                      style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        buildAdjustButton(-5),
                        const SizedBox(width: 8),
                        buildAdjustButton(-1),
                        Container(
                          width: 65,
                          alignment: Alignment.center,
                          child: Text(
                            "$baseScore",
                            style: const TextStyle(
                              color: Color(0xFF00A2FF),
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        buildAdjustButton(1),
                        const SizedBox(width: 8),
                        buildAdjustButton(5),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(color: Colors.white12),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: const Color(0xFF00A2FF),
                      title: const Text(
                        "First to Go Out?",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      value: firstOut,
                      onChanged: someoneElseOut
                          ? null
                          : (val) {
                              setDialogState(() {
                                firstOut = val;
                              });
                            },
                    ),
                    if (firstOut) ...[
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeColor: const Color(0xFF00A2FF),
                        title: const Text(
                          "Highest Score Penalty",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: const Text(
                          "Double Score",
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        value: doubleScorePenalty,
                        onChanged: (val) {
                          setDialogState(() {
                            doubleScorePenalty = val;
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                    TextField(
                      controller: overrideController,
                      readOnly: true, // Prevents keyboard, acts as a display
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: "Total Calculated Score",
                        labelStyle: const TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
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
                    // Remove legacy BaseScore to clean up Firestore
                    rounds[roundIndex].remove('p${playerIndex + 1}BaseScore');

                    if (firstOut) {
                      rounds[roundIndex]['p${playerIndex + 1}FirstOut'] = true;
                      if (doubleScorePenalty) {
                        rounds[roundIndex]['p${playerIndex + 1}DoubleScorePenalty'] =
                            true;
                      } else {
                        rounds[roundIndex].remove(
                          'p${playerIndex + 1}DoubleScorePenalty',
                        );
                      }
                    } else {
                      rounds[roundIndex].remove('p${playerIndex + 1}FirstOut');
                      rounds[roundIndex].remove(
                        'p${playerIndex + 1}DoubleScorePenalty',
                      );
                    }
                    rounds[roundIndex].remove(
                      'p${playerIndex + 1}Penalty',
                    ); // clean up old data if present

                    rounds[roundIndex]['p${playerIndex + 1}Score'] =
                        overrideController.text;

                    // Pass customSettings so recalculations read the root rule
                    recalculateTotals(
                      rounds,
                      playerNames.length,
                      customSettings: customSettings,
                    );
                    onDataChanged();
                    Navigator.pop(context);
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

  // Identical Yahtzee/Nerts style row for the Total
  TableRow _buildCalculatedRow(
    String label,
    List<String> playerNames,
    String Function(int) calculator, {
    required Color color,
    bool isBold = false,
    bool isGrandTotal = false,
  }) {
    List<Widget> cells = [
      TableCell(
        verticalAlignment: TableCellVerticalAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 2.0),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: isGrandTotal ? 14.0 : 12.0,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    ];

    for (int p = 0; p < playerNames.length; p++) {
      String calcValue = calculator(p);

      cells.add(
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: 16.0,
              horizontal: 4.0,
            ),
            child: Center(
              child: Text(
                calcValue,
                style: TextStyle(
                  color: isGrandTotal ? const Color(0xFF00A2FF) : color,
                  fontSize: isGrandTotal ? 22 : 16,
                  fontWeight: isBold || isGrandTotal
                      ? FontWeight.w900
                      : FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return TableRow(
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.3)),
      children: cells,
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
    double rndWidth = 45.0;
    double minCellWidth = 65.0;
    double requiredWidth = rndWidth + (minCellWidth * playerNames.length);
    bool needsScroll = requiredWidth > constraints.maxWidth;

    double actualColWidth = needsScroll
        ? minCellWidth
        : (constraints.maxWidth - rndWidth) / playerNames.length;
    double usableTextWidth = actualColWidth - 8.0;

    bool isCrowded = false;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (String name in playerNames) {
      textPainter.text = TextSpan(
        text: name,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 14.0,
          letterSpacing: 1.0,
        ),
      );
      textPainter.layout();
      if (textPainter.width > usableTextWidth) {
        isCrowded = true;
        break;
      }
    }

    Map<int, TableColumnWidth> colWidths = {0: FixedColumnWidth(rndWidth)};
    for (int i = 0; i < playerNames.length; i++) {
      colWidths[i + 1] = FixedColumnWidth(actualColWidth);
    }

    List<TableRow> rows = [];

    // HEADER ROW
    List<Widget> headerCells = [_buildHeaderCell("RND", isCrowded)];
    for (int i = 0; i < playerNames.length; i++) {
      headerCells.add(_buildPlayerHeaderCell(i, isCrowded, playerNames));
    }
    rows.add(TableRow(children: headerCells));

    // ROUND ROWS
    for (int r = 0; r < rounds.length; r++) {
      List<Widget> rowCells = [
        _buildCell(
          "${r + 1}",
          isBold: true,
          color: Colors.white54,
          isCrowded: isCrowded,
        ),
      ];

      for (int p = 0; p < playerNames.length; p++) {
        rowCells.add(
          _buildScoreCell(
            context,
            r,
            p,
            isCrowded,
            rounds,
            playerNames,
            isFinalized,
            onDataChanged,
            customSettings,
          ),
        );
      }
      rows.add(TableRow(children: rowCells));
    }

    // --- YAHTZEE STYLE TALL TOTAL ROW ---
    rows.add(
      _buildCalculatedRow(
        "TOT",
        playerNames,
        (p) {
          int total = 0;
          bool exactly100bonus = customSettings['exactly100bonus'] ?? true;
          for (var rnd in rounds) {
            total += int.tryParse(rnd['p${p + 1}Score']?.toString() ?? '') ?? 0;
            if (exactly100bonus && total == 100) {
              total = 0;
            }
          }
          return total.toString();
        },
        color: Colors.white,
        isBold: true,
        isGrandTotal: true,
      ),
    );

    Widget tableGrid = Table(
      columnWidths: colWidths,
      border: TableBorder(
        horizontalInside: BorderSide(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        verticalInside: BorderSide(
          color: Colors.white.withOpacity(0.2),
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

  double _getDynamicFontSize(bool isCrowded) => isCrowded ? 12.0 : 14.0;

  Widget _buildHeaderCell(String text, bool isCrowded) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 4.0),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontWeight: FontWeight.bold,
              fontSize: _getDynamicFontSize(isCrowded),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerHeaderCell(
    int playerIndex,
    bool isCrowded,
    List<String> names,
  ) {
    final textStyle = TextStyle(
      color: const Color(0xFF00A2FF),
      fontWeight: FontWeight.w900,
      fontSize: _getDynamicFontSize(isCrowded),
      letterSpacing: 1.0,
    );

    Widget cellContent = Center(
      child: isCrowded
          ? ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 75),
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(
                  names[playerIndex],
                  style: textStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
          : Text(
              names[playerIndex],
              textAlign: TextAlign.center,
              style: textStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
    );

    return InkWell(
      onTap: () {
        SleekNotificationBanner.show(
          "Action Not Allowed",
          "You cannot adjust players mid-game.",
          icon: Icons.block,
          color: Colors.orangeAccent,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 4.0),
        child: cellContent,
      ),
    );
  }

  Widget _buildCell(
    String text, {
    bool isBold = false,
    Color color = Colors.white,
    required bool isCrowded,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: _getDynamicFontSize(isCrowded) + 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCell(
    BuildContext context,
    int roundIndex,
    int playerIndex,
    bool isCrowded,
    List<Map<String, dynamic>> rounds,
    List<String> names,
    bool isFinalized,
    VoidCallback onChanged,
    Map<String, dynamic> customSettings,
  ) {
    final score = rounds[roundIndex]['p${playerIndex + 1}Score'];
    bool won = rounds[roundIndex]['p${playerIndex + 1}FirstOut'] == true;

    return InkWell(
      onTap: isFinalized
          ? null
          : () => _showScoreDialog(
              context,
              roundIndex,
              playerIndex,
              rounds,
              names,
              onChanged,
              customSettings,
            ),
      child: Container(
        color: won
            ? const Color(0xFF00A2FF).withOpacity(0.15)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              score != null && score.toString().isNotEmpty ? "$score" : "-",
              style: TextStyle(
                color: won ? const Color(0xFF00A2FF) : Colors.white,
                fontSize: _getDynamicFontSize(isCrowded) + 4,
                fontWeight: won ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
