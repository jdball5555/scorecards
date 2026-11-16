import 'package:flutter/material.dart';
import 'dart:math';
import '../../../core/shared_widgets/sleek_notification_banner.dart';
import 'game_template.dart';

class YahtzeeTemplate extends GameTemplate {
  @override
  String get gameType => 'Yahtzee';

  @override
  int get initialPlayerCount => 1;

  @override
  bool canAddPlayer(int currentPlayerCount, List<Map<String, dynamic>> rounds) {
    if (rounds.length > 1) {
      return false;
    }

    for (int p = 0; p < currentPlayerCount; p++) {
      for (var r in rounds) {
        if (r['p${p + 1}Category'] != null ||
            (r['category'] != null &&
                r['category'] != 'YAHTZEE BONUS' &&
                r['p${p + 1}Score'] != null &&
                r['p${p + 1}Score'].toString().isNotEmpty)) {
          return false;
        }
      }
    }
    return true;
  }

  @override
  List<String> generateInitialPlayerNames() => ["Player 1"];

  @override
  Map<String, dynamic> createNewRound(int roundNum, int playerCount) => {
    'roundNum': roundNum,
  };

  @override
  bool canAddRound(
    List<Map<String, dynamic>> rounds,
    int playerCount, {
    Map<String, dynamic> customSettings = const {},
  }) => false;

  final List<String> _categories = [
    'Aces',
    'Twos',
    'Threes',
    'Fours',
    'Fives',
    'Sixes',
    '3 of a Kind',
    '4 of a Kind',
    'Full House',
    'Sm. Straight',
    'Lg. Straight',
    'YAHTZEE',
    'Chance',
    'YAHTZEE BONUS',
  ];

  final List<String> _howToScoreRules = [
    'Count and Add Only Aces',
    'Count and Add Only Twos',
    'Count and Add Only Threes',
    'Count and Add Only Fours',
    'Count and Add Only Fives',
    'Count and Add Only Sixes',
    'Add Total of All Dice',
    'Add Total of All Dice',
    'SCORE 25',
    'SCORE 30',
    'SCORE 40',
    'SCORE 50',
    'Add Total of All Dice',
    'SCORE 100 PER EXTRA YAHTZEE',
  ];

  @override
  bool isReadyToFinalize(
    List<Map<String, dynamic>> rounds,
    int playerCount, {
    Map<String, dynamic> customSettings = const {},
  }) {
    for (int p = 0; p < playerCount; p++) {
      int count = 0;
      for (var r in rounds) {
        if (r['p${p + 1}Category'] != null ||
            (r['category'] != null &&
                r['category'] != 'YAHTZEE BONUS' &&
                r['p${p + 1}Score'] != null &&
                r['p${p + 1}Score'].toString().isNotEmpty)) {
          count++;
        }
      }
      if (count < 13) {
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
    List<int> upper = List.filled(playerCount, 0);
    List<int> lower = List.filled(playerCount, 0);
    List<int> yBonus = List.filled(playerCount, 0);

    for (var r in rounds) {
      for (int p = 0; p < playerCount; p++) {
        String? cat = r['p${p + 1}Category'] ?? r['category'];
        int score = int.tryParse(r['p${p + 1}Score']?.toString() ?? '') ?? 0;

        if (cat != null && cat != 'YAHTZEE BONUS') {
          if ([
            'Aces',
            'Twos',
            'Threes',
            'Fours',
            'Fives',
            'Sixes',
          ].contains(cat)) {
            upper[p] += score;
          } else {
            lower[p] += score;
          }
        }
        var yb = r['p${p + 1}YahtzeeBonus'];
        if (yb == true || yb == 100 || yb == "100") {
          yBonus[p] += 100;
        }

        int bonus = upper[p] >= 63 ? 35 : 0;
        r['p${p + 1}Total'] = upper[p] + lower[p] + bonus + yBonus[p];
      }
    }
  }

  @override
  String getWinnerDeclaration(
    List<String> playerNames,
    List<Map<String, dynamic>> rounds, {
    Map<String, dynamic> customSettings = const {},
  }) {
    if (playerNames.length == 1) {
      int total = _getGrandTotal(rounds, 0);
      return "Finalize your game with a Grand Total of $total?";
    }

    List<int> totals = List.generate(
      playerNames.length,
      (i) => _getGrandTotal(rounds, i),
    );
    int maxScore = totals.reduce(max);
    int winnerIndex = totals.indexOf(maxScore);

    return "Declare ${playerNames[winnerIndex]} as the winner with a score of $maxScore?";
  }

  String _getCategoryScore(
    List<Map<String, dynamic>> rounds,
    int playerIndex,
    String category,
  ) {
    for (var r in rounds) {
      if (r['p${playerIndex + 1}Category'] == category ||
          r['category'] == category) {
        return r['p${playerIndex + 1}Score']?.toString() ?? "";
      }
    }
    return "";
  }

  int _getYahtzeeBonusTotal(
    List<Map<String, dynamic>> rounds,
    int playerIndex,
  ) {
    int yBonus = 0;
    for (var r in rounds) {
      var yb = r['p${playerIndex + 1}YahtzeeBonus'];
      if (yb == true) {
        yBonus += 100;
      } else if (yb != null) {
        yBonus += int.tryParse(yb.toString()) ?? 0;
      }
      var cat = r['category'] ?? r['p${playerIndex + 1}Category'];
      if (cat == 'YAHTZEE BONUS') {
        yBonus +=
            int.tryParse(r['p${playerIndex + 1}Score']?.toString() ?? '0') ?? 0;
      }
    }
    return yBonus;
  }

  void _setCategoryScore(
    List<Map<String, dynamic>> rounds,
    int playerIndex,
    String category,
    String score,
  ) {
    for (var r in rounds) {
      if (r['p${playerIndex + 1}Category'] == category ||
          r['category'] == category) {
        if (score.isEmpty) {
          r.remove('p${playerIndex + 1}Category');
          r.remove('p${playerIndex + 1}Score');
          if (r['category'] == category) r.remove('category');
        } else {
          r['p${playerIndex + 1}Score'] = score;
        }
        return;
      }
    }

    if (score.isEmpty) {
      return;
    }

    for (int i = 0; i < 13; i++) {
      if (i >= rounds.length) {
        rounds.add({'roundNum': i + 1});
      }
      if (rounds[i]['p${playerIndex + 1}Category'] == null &&
          rounds[i]['category'] == null) {
        rounds[i]['p${playerIndex + 1}Category'] = category;
        rounds[i]['p${playerIndex + 1}Score'] = score;
        return;
      }
    }
  }

  int _getScore(
    List<Map<String, dynamic>> rounds,
    int catIndex,
    int playerIndex,
  ) {
    String val = _getCategoryScore(rounds, playerIndex, _categories[catIndex]);
    return int.tryParse(val) ?? 0;
  }

  int _getUpperTotal(List<Map<String, dynamic>> rounds, int playerIndex) {
    int total = 0;
    for (int i = 0; i <= 5; i++) {
      total += _getScore(rounds, i, playerIndex);
    }
    return total;
  }

  int _getUpperBonus(List<Map<String, dynamic>> rounds, int playerIndex) {
    return _getUpperTotal(rounds, playerIndex) >= 63 ? 35 : 0;
  }

  int _getLowerTotal(List<Map<String, dynamic>> rounds, int playerIndex) {
    int total = 0;
    for (int i = 6; i <= 12; i++) {
      total += _getScore(rounds, i, playerIndex);
    }
    return total;
  }

  int _getGrandTotal(List<Map<String, dynamic>> rounds, int playerIndex) {
    return _getUpperTotal(rounds, playerIndex) +
        _getUpperBonus(rounds, playerIndex) +
        _getLowerTotal(rounds, playerIndex) +
        _getYahtzeeBonusTotal(rounds, playerIndex);
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

  int _getCurrentPlayerIndex(
    List<Map<String, dynamic>> rounds,
    int playerCount,
  ) {
    List<int> filledCounts = List.filled(playerCount, 0);
    for (int p = 0; p < playerCount; p++) {
      int count = 0;
      for (var r in rounds) {
        String? cat = r['p${p + 1}Category'] ?? r['category'];
        if (cat != null && cat != 'YAHTZEE BONUS') count++;
      }
      filledCounts[p] = count;
    }

    int minCount = filledCounts.reduce(min);
    if (minCount == 13) {
      return -1; // game over
    }
    if (minCount >= rounds.length) {
      return -1; // all players finished current round
    }

    for (int p = 0; p < playerCount; p++) {
      if (filledCounts[p] == minCount) {
        return p;
      }
    }
    return 0;
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
    bool showHowToScore = customSettings['showHowToScore'] ?? true;

    double catWidth = 90.0;
    double rulesWidth = showHowToScore ? 110.0 : 0.0;
    double minCellWidth = 60.0;
    double requiredWidth =
        catWidth + rulesWidth + (minCellWidth * playerNames.length);
    bool needsScroll = requiredWidth > constraints.maxWidth;

    int currentPlayerIndex = _getCurrentPlayerIndex(rounds, playerNames.length);

    double actualColWidth = needsScroll
        ? minCellWidth
        : (constraints.maxWidth - catWidth - rulesWidth) / playerNames.length;

    Map<int, TableColumnWidth> colWidths = {0: FixedColumnWidth(catWidth)};
    int colIndexOffset = 1;

    if (showHowToScore) {
      colWidths[1] = FixedColumnWidth(rulesWidth);
      colIndexOffset = 2;
    }

    for (int i = 0; i < playerNames.length; i++) {
      colWidths[i + colIndexOffset] = FixedColumnWidth(actualColWidth);
    }

    List<TableRow> rows = [];

    List<Widget> headerCells = [_buildHeaderCell("CATEGORY")];
    if (showHowToScore) headerCells.add(_buildHeaderCell("HOW TO SCORE"));

    for (int i = 0; i < playerNames.length; i++) {
      headerCells.add(
        _buildPlayerHeaderCell(i, playerNames, isFinalized, currentPlayerIndex),
      );
    }
    rows.add(TableRow(children: headerCells));

    for (int r = 0; r <= 5; r++) {
      rows.add(
        _buildCategoryRow(
          context,
          r,
          rounds,
          playerNames,
          showHowToScore,
          isFinalized,
          onDataChanged,
          currentPlayerIndex,
        ),
      );
    }

    rows.add(
      _buildCalculatedRow(
        "UPPER TOTAL",
        playerNames,
        showHowToScore,
        (p) => _getUpperTotal(rounds, p).toString(),
        color: Colors.white70,
        currentPlayerIndex: currentPlayerIndex,
        isFinalized: isFinalized,
      ),
    );

    rows.add(
      _buildCalculatedRow(
        "BONUS (>=63)",
        playerNames,
        showHowToScore,
        (p) {
          int currentUpper = _getUpperTotal(rounds, p);
          if (currentUpper >= 63) return "35";

          bool allUpperFilled = true;
          for (int i = 0; i <= 5; i++) {
            String s = _getCategoryScore(rounds, p, _categories[i]);
            if (s.isEmpty) {
              allUpperFilled = false;
              break;
            }
          }

          if (allUpperFilled) return "0";
          return "Need ${63 - currentUpper}";
        },
        color: const Color(0xFF7855C1),
        ruleText: "SCORE 35",
        currentPlayerIndex: currentPlayerIndex,
        isFinalized: isFinalized,
      ),
    );

    rows.add(
      _buildCalculatedRow(
        "TOTAL UPPER",
        playerNames,
        showHowToScore,
        (p) =>
            (_getUpperTotal(rounds, p) + _getUpperBonus(rounds, p)).toString(),
        color: const Color(0xFF00A2FF),
        isBold: true,
        currentPlayerIndex: currentPlayerIndex,
        isFinalized: isFinalized,
      ),
    );

    for (int r = 6; r <= 13; r++) {
      rows.add(
        _buildCategoryRow(
          context,
          r,
          rounds,
          playerNames,
          showHowToScore,
          isFinalized,
          onDataChanged,
          currentPlayerIndex,
        ),
      );
    }

    rows.add(
      _buildCalculatedRow(
        "TOTAL LOWER",
        playerNames,
        showHowToScore,
        (p) => _getLowerTotal(rounds, p).toString(),
        color: const Color(0xFF00A2FF),
        isBold: true,
        currentPlayerIndex: currentPlayerIndex,
        isFinalized: isFinalized,
      ),
    );
    rows.add(
      _buildCalculatedRow(
        "GRAND TOTAL",
        playerNames,
        showHowToScore,
        (p) => _getGrandTotal(rounds, p).toString(),
        color: Colors.white,
        isBold: true,
        isGrandTotal: true,
        currentPlayerIndex: currentPlayerIndex,
        isFinalized: isFinalized,
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

    Widget finalGrid = needsScroll
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: tableGrid,
            ),
          )
        : tableGrid;

    return finalGrid;
  }

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white54,
          fontWeight: FontWeight.bold,
          fontSize: 11.0,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildPlayerHeaderCell(
    int playerIndex,
    List<String> names,
    bool isFinalized,
    int currentPlayerIndex,
  ) {
    bool isCurrentPlayerTurn = playerIndex == currentPlayerIndex;
    bool shouldHighlight = isCurrentPlayerTurn && !isFinalized;

    Widget cellContent = Text(
      names[playerIndex],
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFF00A2FF),
        fontWeight: FontWeight.w900,
        fontSize: 14.0,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.fill,
      child: Container(
        color: shouldHighlight
            ? const Color(0xFF00A2FF).withOpacity(0.15)
            : Colors.transparent,
        child: InkWell(
          onTap: () {
            SleekNotificationBanner.show(
              "Action Not Allowed",
              "You cannot adjust players mid-game.",
              icon: Icons.block,
              color: Colors.orangeAccent,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 16.0,
              horizontal: 4.0,
            ),
            child: Center(child: cellContent),
          ),
        ),
      ),
    );
  }

  String _getYahtzeeBonusDisplay(List<Map<String, dynamic>> rounds, int p) {
    String yahtzeeScore = _getCategoryScore(rounds, p, 'YAHTZEE');
    if (yahtzeeScore == '0') return '0';

    int filled = 0;
    for (var r in rounds) {
      String? cat = r['p${p + 1}Category'] ?? r['category'];
      if (cat != null && cat != 'YAHTZEE BONUS') filled++;
    }

    int yBonus = _getYahtzeeBonusTotal(rounds, p);
    if (filled >= 13 && yBonus == 0) return '0';

    if (yBonus > 0) return yBonus.toString();
    return '';
  }

  TableRow _buildCategoryRow(
    BuildContext context,
    int catIndex,
    List<Map<String, dynamic>> rounds,
    List<String> playerNames,
    bool showHowToScore,
    bool isFinalized,
    VoidCallback onDataChanged,
    int currentPlayerIndex,
  ) {
    List<Widget> cells = [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Text(
          _categories[catIndex],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12.0,
          ),
        ),
      ),
    ];

    if (showHowToScore) {
      cells.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Text(
            _howToScoreRules[catIndex],
            style: const TextStyle(color: Colors.white54, fontSize: 10.0),
          ),
        ),
      );
    }

    for (int p = 0; p < playerNames.length; p++) {
      bool isYahtzeeBonus = catIndex == 13;
      String currentScore = isYahtzeeBonus
          ? _getYahtzeeBonusDisplay(rounds, p)
          : _getCategoryScore(rounds, p, _categories[catIndex]);

      bool hasValue = currentScore.isNotEmpty;
      bool isCurrentPlayerTurn = p == currentPlayerIndex;
      bool shouldHighlight = isCurrentPlayerTurn && !isFinalized;

      bool wasScoredThisRound = false;
      if (hasValue && rounds.isNotEmpty) {
        var lastRound = rounds.last;
        if (isYahtzeeBonus) {
          if (lastRound['p${p + 1}YahtzeeBonus'] != null) {
            wasScoredThisRound = true;
          }
        } else {
          if (lastRound['p${p + 1}Category'] == _categories[catIndex] ||
              lastRound['category'] == _categories[catIndex]) {
            wasScoredThisRound = true;
          }
        }
      }

      cells.add(
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.fill,
          child: InkWell(
            onTap: isFinalized
                ? null
                : () {
                    void proceed() {
                      if (isYahtzeeBonus) {
                        _showYahtzeeBonusDialog(
                          context,
                          p,
                          rounds,
                          playerNames[p],
                          onDataChanged,
                        );
                      } else {
                        _showScoreDialog(
                          context,
                          catIndex,
                          p,
                          rounds,
                          playerNames[p],
                          wasScoredThisRound,
                          onDataChanged,
                        );
                      }
                    }

                    if (hasValue && !isYahtzeeBonus && !wasScoredThisRound) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF1E1E1E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: const Text(
                            "Edit Score?",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          content: const Text(
                            "Are you sure? You shouldn't be doing this unless you made a mistake.",
                            style: TextStyle(color: Colors.white70),
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
                                Navigator.pop(ctx);
                                proceed();
                              },
                              child: const Text(
                                "EDIT",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                      return;
                    }

                    if (!hasValue && !isYahtzeeBonus && !isCurrentPlayerTurn) {
                      if (currentPlayerIndex == -1) {
                        SleekNotificationBanner.show(
                          "Round Not Finalized",
                          "Please finalize the round before submitting another entry.",
                          icon: Icons.warning_amber_rounded,
                          color: Colors.orangeAccent,
                        );
                        return;
                      }
                      SleekNotificationBanner.show(
                        "Not Your Turn",
                        "Please wait for ${playerNames[currentPlayerIndex]} to submit their score first.",
                        icon: Icons.hourglass_empty,
                        color: Colors.orangeAccent,
                      );
                      return;
                    }

                    int currentActiveRound = rounds.length;

                    if (isYahtzeeBonus) {
                      String yScore = _getCategoryScore(rounds, p, 'YAHTZEE');
                      if (yScore != '50') {
                        SleekNotificationBanner.show(
                          "Action Not Allowed",
                          "You cannot score a Yahtzee Bonus without first scoring 50 in the YAHTZEE category.",
                          icon: Icons.warning_amber_rounded,
                          color: Colors.orangeAccent,
                        );
                        return;
                      }

                      int yahtzeeTurnIndex = -1;
                      for (int i = 0; i < rounds.length; i++) {
                        if (rounds[i]['p${p + 1}Category'] == 'YAHTZEE' ||
                            rounds[i]['category'] == 'YAHTZEE') {
                          yahtzeeTurnIndex = i;
                          break;
                        }
                      }

                      if (yahtzeeTurnIndex + 1 == currentActiveRound) {
                        SleekNotificationBanner.show(
                          "Action Not Allowed",
                          "You cannot score a Yahtzee Bonus in the same round you scored your first Yahtzee.",
                          icon: Icons.warning_amber_rounded,
                          color: Colors.orangeAccent,
                        );
                        return;
                      }
                    } else {
                      int filledCount = 0;
                      for (var r in rounds) {
                        String? cat = r['p${p + 1}Category'] ?? r['category'];
                        if (cat != null && cat != 'YAHTZEE BONUS')
                          filledCount++;
                      }

                      if (filledCount >= currentActiveRound &&
                          !wasScoredThisRound) {
                        SleekNotificationBanner.show(
                          "Round Not Finalized",
                          "Please finalize the round before submitting another entry, or wait for all players to submit a score.",
                          icon: Icons.warning_amber_rounded,
                          color: Colors.orangeAccent,
                        );
                        return;
                      }
                    }

                    proceed();
                  },
            child: Container(
              decoration: BoxDecoration(
                color: shouldHighlight
                    ? const Color(0xFF00A2FF).withOpacity(0.15)
                    : Colors.transparent,
              ),
              padding: const EdgeInsets.symmetric(
                vertical: 16.0,
                horizontal: 8.0,
              ),
              child: Center(
                child: Text(
                  hasValue ? currentScore : "-",
                  style: TextStyle(
                    color: shouldHighlight
                        ? const Color(0xFF00A2FF)
                        : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return TableRow(children: cells);
  }

  TableRow _buildCalculatedRow(
    String label,
    List<String> playerNames,
    bool showHowToScore,
    String Function(int) calculator, {
    required Color color,
    bool isBold = false,
    bool isGrandTotal = false,
    String? ruleText,
    int? currentPlayerIndex,
    bool isFinalized = false,
  }) {
    List<Widget> cells = [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
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
    ];

    if (showHowToScore) {
      cells.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Text(
            ruleText ?? "",
            style: const TextStyle(color: Colors.white54, fontSize: 10.0),
          ),
        ),
      );
    }

    for (int p = 0; p < playerNames.length; p++) {
      String calcValue = calculator(p);
      bool isNeedText = calcValue.startsWith("Need");
      bool isCurrentPlayerTurn = p == currentPlayerIndex;
      bool shouldHighlight = isCurrentPlayerTurn && !isFinalized;

      cells.add(
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.fill,
          child: Container(
            color: shouldHighlight
                ? const Color(0xFF00A2FF).withOpacity(0.15)
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(
              vertical: 16.0,
              horizontal: 8.0,
            ),
            child: Center(
              child: Text(
                calcValue,
                style: TextStyle(
                  color: isGrandTotal
                      ? const Color(0xFF00A2FF)
                      : (isNeedText ? Colors.white38 : color),
                  fontSize: isGrandTotal ? 22 : (isNeedText ? 12 : 16),
                  fontWeight: isBold || isGrandTotal
                      ? FontWeight.w900
                      : (isNeedText ? FontWeight.normal : FontWeight.bold),
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

  void _showYahtzeeBonusDialog(
    BuildContext context,
    int playerIndex,
    List<Map<String, dynamic>> rounds,
    String playerName,
    VoidCallback onDataChanged,
  ) {
    int currentActiveRound = rounds.length;

    int roundIndex = currentActiveRound - 1;
    if (roundIndex >= 13) {
      roundIndex = 12;
    }

    while (rounds.length <= roundIndex) {
      rounds.add({'roundNum': rounds.length + 1});
    }

    bool gotBonus =
        rounds[roundIndex]['p${playerIndex + 1}YahtzeeBonus'] == true ||
        rounds[roundIndex]['p${playerIndex + 1}YahtzeeBonus'] == 100 ||
        rounds[roundIndex]['p${playerIndex + 1}YahtzeeBonus'] == "100";

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            "$playerName: YAHTZEE BONUS",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: const Color(0xFF00A2FF),
            title: const Text(
              "Did you get a Yahtzee bonus this round?",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            value: gotBonus,
            onChanged: (val) => setDialogState(() => gotBonus = val),
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
                if (gotBonus) {
                  rounds[roundIndex]['p${playerIndex + 1}YahtzeeBonus'] = true;
                  SleekNotificationBanner.show(
                    "Bonus Recorded",
                    "This did not count as your turn. You can still submit a category.",
                    icon: Icons.check_circle,
                    color: Colors.green,
                  );
                } else {
                  rounds[roundIndex].remove('p${playerIndex + 1}YahtzeeBonus');
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
        ),
      ),
    );
  }

  void _showScoreDialog(
    BuildContext context,
    int catIndex,
    int playerIndex,
    List<Map<String, dynamic>> rounds,
    String playerName,
    bool wasScoredThisRound,
    VoidCallback onDataChanged,
  ) {
    String originalScore = _getCategoryScore(
      rounds,
      playerIndex,
      _categories[catIndex],
    );
    String currentScore = originalScore;
    List<String> options = _getOptionsForCategory(catIndex);

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
                "$playerName: ${_categories[catIndex]}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              content: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: options.map((scoreOpt) {
                  final isSelected = currentScore == scoreOpt;
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        currentScore = isSelected ? "" : scoreOpt;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 55,
                      height: 55,
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
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: scoreOpt.length > 2 ? 14 : 18,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                if (originalScore.isNotEmpty && wasScoredThisRound)
                  TextButton(
                    onPressed: () {
                      _setCategoryScore(
                        rounds,
                        playerIndex,
                        _categories[catIndex],
                        "",
                      );
                      if (catIndex == 11) {
                        for (var r in rounds) {
                          r.remove('p${playerIndex + 1}YahtzeeBonus');
                        }
                      }
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
                    if (originalScore.isNotEmpty &&
                        currentScore.isEmpty &&
                        !wasScoredThisRound) {
                      SleekNotificationBanner.show(
                        "Cannot Clear",
                        "You cannot completely clear a score from a finalized round. You can only change its value.",
                        icon: Icons.block,
                        color: Colors.orangeAccent,
                      );
                      return;
                    }
                    if (originalScore.isEmpty && currentScore.isEmpty) {
                      Navigator.pop(ctx);
                      return;
                    }

                    _setCategoryScore(
                      rounds,
                      playerIndex,
                      _categories[catIndex],
                      currentScore,
                    );

                    if (catIndex == 11 && currentScore != '50') {
                      for (var r in rounds) {
                        r.remove('p${playerIndex + 1}YahtzeeBonus');
                      }
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

  List<String> _getOptionsForCategory(int catIndex) {
    switch (catIndex) {
      case 0:
        return ["0", "1", "2", "3", "4", "5"];
      case 1:
        return ["0", "2", "4", "6", "8", "10"];
      case 2:
        return ["0", "3", "6", "9", "12", "15"];
      case 3:
        return ["0", "4", "8", "12", "16", "20"];
      case 4:
        return ["0", "5", "10", "15", "20", "25"];
      case 5:
        return ["0", "6", "12", "18", "24", "30"];
      case 8:
        return ["0", "25"];
      case 9:
        return ["0", "30"];
      case 10:
        return ["0", "40"];
      case 11:
        return ["0", "50"];
      case 6:
      case 7:
      case 12:
        return ["0", ...List.generate(26, (i) => (i + 5).toString())];
      default:
        return ["0"];
    }
  }
}
