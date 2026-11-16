import 'package:flutter/material.dart';
import 'dart:math';
import '../../../core/shared_widgets/sleek_notification_banner.dart';
import 'game_template.dart';

class NertsTemplate extends GameTemplate {
  @override
  String get gameType => 'Nerts';

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
    for (int i = 0; i < playerCount; i++) {
      int total = 0;
      for (var r in rounds) {
        total += int.tryParse(r['p${i + 1}Score']?.toString() ?? '') ?? 0;
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

  @override
  Widget? buildExtraAssignmentUI({
    required BuildContext context,
    required void Function(VoidCallback fn) setModalState,
    required List<String> playerNames,
    int? activePlayerIndex,
    required Map<String, dynamic> customSettings,
    required void Function(String, dynamic) onSettingsChanged,
  }) => null;

  void _showScoreDialog(
    BuildContext context,
    int roundIndex,
    int playerIndex,
    List<Map<String, dynamic>> rounds,
    List<String> playerNames,
    VoidCallback onDataChanged,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        // Variables held outside StatefulBuilder so they can be reloaded without closing the dialog
        int currentPlayerIndex = playerIndex;
        bool won = false;
        bool someoneElseWon = false;
        int cardsLeft = 3;
        int cardsMiddle = 5;
        TextEditingController overrideController = TextEditingController();

        void updateScore() {
          // Nerts Math: 50 for win, +1 per middle card, -2 per card left in Nerts pile
          int basePoints = (won ? 50 : 0) + cardsMiddle - (cardsLeft * 2);
          overrideController.text = basePoints.toString();
        }

        // Helper to load a specific player's data into the dialog's state
        void loadPlayer(int index) {
          currentPlayerIndex = index;

          // Check if anyone else has already claimed the win for this round
          someoneElseWon = false;
          for (int i = 0; i < playerNames.length; i++) {
            if (i != currentPlayerIndex &&
                rounds[roundIndex]['p${i + 1}Won'] == true) {
              someoneElseWon = true;
              break;
            }
          }

          won = rounds[roundIndex]['p${currentPlayerIndex + 1}Won'] == true;

          cardsLeft =
              int.tryParse(
                rounds[roundIndex]['p${currentPlayerIndex + 1}CardsLeft']
                        ?.toString() ??
                    '3',
              ) ??
              3;

          cardsMiddle =
              int.tryParse(
                rounds[roundIndex]['p${currentPlayerIndex + 1}CardsMiddle']
                        ?.toString() ??
                    '5',
              ) ??
              5;

          String existingScore =
              rounds[roundIndex]['p${currentPlayerIndex + 1}Score']
                  ?.toString() ??
              "";

          if (existingScore.isNotEmpty) {
            overrideController.text = existingScore;
          } else {
            updateScore();
          }
        }

        // Initial load for the tapped player
        loadPlayer(currentPlayerIndex);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                "Round ${roundIndex + 1}: ${playerNames[currentPlayerIndex]}",
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
                    if (someoneElseWon)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.redAccent.withOpacity(0.5),
                          ),
                        ),
                        child: const Text(
                          "Another player has already been marked as the winner for this round.",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeColor: const Color(0xFF00A2FF),
                        title: const Text(
                          "Did you win? (+50)",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        value: won,
                        onChanged: (val) {
                          setDialogState(() {
                            won = val;
                            if (won) cardsLeft = 0;
                            updateScore();
                          });
                        },
                      ),
                    const Divider(color: Colors.white12),
                    if (!won) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              "Cards left in stack (-2 each)",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.white54,
                                ),
                                onPressed: () {
                                  if (cardsLeft > 0) {
                                    setDialogState(() {
                                      cardsLeft--;
                                      updateScore();
                                    });
                                  }
                                },
                              ),
                              Text(
                                "$cardsLeft",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.add_circle_outline,
                                  color: cardsLeft < 10
                                      ? Colors.white
                                      : Colors.white24,
                                ),
                                onPressed: cardsLeft < 10
                                    ? () {
                                        setDialogState(() {
                                          cardsLeft++;
                                          updateScore();
                                        });
                                      }
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white12),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            "Cards in middle (+1 each)",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.white54,
                              ),
                              onPressed: () {
                                if (cardsMiddle > 0) {
                                  setDialogState(() {
                                    cardsMiddle--;
                                    updateScore();
                                  });
                                }
                              },
                            ),
                            Text(
                              "$cardsMiddle",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle_outline,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  cardsMiddle++;
                                  updateScore();
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: overrideController,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: false,
                      ),
                      style: const TextStyle(
                        color: Color(0xFF00A2FF),
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: "Calculated Score",
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
                    // 1. Process Win Status
                    if (won) {
                      rounds[roundIndex]['p${currentPlayerIndex + 1}Won'] =
                          true;
                    } else {
                      rounds[roundIndex].remove(
                        'p${currentPlayerIndex + 1}Won',
                      );
                    }

                    // 2. Process Cards Left
                    if (cardsLeft > 0) {
                      rounds[roundIndex]['p${currentPlayerIndex + 1}CardsLeft'] =
                          cardsLeft;
                    } else {
                      rounds[roundIndex].remove(
                        'p${currentPlayerIndex + 1}CardsLeft',
                      );
                    }

                    // 3. Process Cards Middle
                    rounds[roundIndex]['p${currentPlayerIndex + 1}CardsMiddle'] =
                        cardsMiddle;

                    // 4. Save Score (with fallback to '0' to prevent loop logic errors)
                    rounds[roundIndex]['p${currentPlayerIndex + 1}Score'] =
                        overrideController.text.isEmpty
                        ? '0'
                        : overrideController.text;

                    // 5. Recalculate and update UI grid behind the dialog
                    recalculateTotals(rounds, playerNames.length);
                    onDataChanged();

                    // --- SMOOTH AUTO-ADVANCE LOGIC ---
                    int nextPlayerIndex = -1;

                    // Check subsequent players first
                    for (
                      int i = currentPlayerIndex + 1;
                      i < playerNames.length;
                      i++
                    ) {
                      if (rounds[roundIndex]['p${i + 1}Score'] == null ||
                          rounds[roundIndex]['p${i + 1}Score']
                              .toString()
                              .isEmpty) {
                        nextPlayerIndex = i;
                        break;
                      }
                    }

                    // If not found, wrap around to the beginning
                    if (nextPlayerIndex == -1) {
                      for (int i = 0; i < currentPlayerIndex; i++) {
                        if (rounds[roundIndex]['p${i + 1}Score'] == null ||
                            rounds[roundIndex]['p${i + 1}Score']
                                .toString()
                                .isEmpty) {
                          nextPlayerIndex = i;
                          break;
                        }
                      }
                    }

                    // If we found someone missing a score, update the dialog state seamlessly
                    if (nextPlayerIndex != -1) {
                      setDialogState(() {
                        loadPlayer(nextPlayerIndex);
                      });
                    } else {
                      // Everyone is scored! Close the dialog safely.
                      Navigator.pop(context);
                    }
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
          for (var rnd in rounds) {
            total += int.tryParse(rnd['p${p + 1}Score']?.toString() ?? '') ?? 0;
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
  ) {
    final score = rounds[roundIndex]['p${playerIndex + 1}Score'];
    bool won = rounds[roundIndex]['p${playerIndex + 1}Won'] == true;

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
