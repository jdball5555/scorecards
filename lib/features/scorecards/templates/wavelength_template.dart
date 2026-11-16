import 'package:flutter/material.dart';
import 'dart:math';
import '../../../core/shared_widgets/sleek_notification_banner.dart';
import 'game_template.dart';

class WavelengthTemplate extends GameTemplate {
  @override
  String get gameType => 'Wavelength';

  @override
  int get initialPlayerCount => 2; // Default to 1 team of 2 for co-op

  @override
  bool canAddPlayer(
    int currentPlayerCount,
    List<Map<String, dynamic>> rounds,
  ) => currentPlayerCount < 20;

  @override
  List<String> generateInitialPlayerNames() => ["Player 1", "Player 2"];

  @override
  Map<String, dynamic> createNewRound(int roundNum, int playerCount) => {
    'roundNum': roundNum,
  };

  @override
  bool canAddRound(
    List<Map<String, dynamic>> rounds,
    int playerCount, {
    Map<String, dynamic> customSettings = const {},
  }) => true;

  @override
  void onRoundRemoved(List<Map<String, dynamic>> rounds) {}

  @override
  bool isReadyToFinalize(
    List<Map<String, dynamic>> rounds,
    int playerCount, {
    Map<String, dynamic> customSettings = const {},
  }) {
    if (rounds.isEmpty) {
      return false;
    }
    int teams = playerCount ~/ 2;
    for (var round in rounds) {
      for (int t = 1; t <= teams; t++) {
        if (round['t${t}Score'] == null ||
            round['t${t}Score'].toString().trim().isEmpty) {
          return false;
        }
      }
    }
    return true;
  }

  // --- UPDATED: Calculates Catchup points only if active score < 4 ---
  int _getTeamRoundScore(
    int teamIndex,
    Map<String, dynamic> round,
    int totalTeams,
  ) {
    int activeScore =
        int.tryParse(round['t${teamIndex + 1}Score']?.toString() ?? '') ?? 0;
    int catchupPoints = 0;

    for (int other = 0; other < totalTeams; other++) {
      if (other == teamIndex) continue;

      String? otherScoreStr = round['t${other + 1}Score']?.toString();

      // Opponents ONLY get the catch-up point if the active team scored less than 4
      if (otherScoreStr != null &&
          otherScoreStr != '4' &&
          otherScoreStr.isNotEmpty) {
        String? targetDir = round['t${other + 1}Dir'];
        String? myGuess = round['t${teamIndex + 1}GuessT${other + 1}'];

        if (targetDir != null && myGuess != null && targetDir == myGuess) {
          catchupPoints += 1;
        }
      }
    }
    return activeScore + catchupPoints;
  }

  @override
  void recalculateTotals(
    List<Map<String, dynamic>> rounds,
    int playerCount, {
    Map<String, dynamic> customSettings = const {},
  }) {
    int teams = playerCount ~/ 2;
    List<int> runningTotals = List.filled(teams, 0);

    for (var r in rounds) {
      for (int t = 0; t < teams; t++) {
        int activeScore =
            int.tryParse(r['t${t + 1}Score']?.toString() ?? '') ?? 0;
        int totalScore = _getTeamRoundScore(t, r, teams);
        int bonus = totalScore - activeScore;

        if (bonus > 0) {
          r['t${t + 1}bonus'] = bonus;
        } else {
          r.remove('t${t + 1}bonus');
        }

        runningTotals[t] += totalScore;
        r['t${t + 1}Total'] = runningTotals[t];
      }
    }
  }

  @override
  String getWinnerDeclaration(
    List<String> playerNames,
    List<Map<String, dynamic>> rounds, {
    Map<String, dynamic> customSettings = const {},
  }) {
    int teams = playerNames.length ~/ 2;
    List<int> totals = List.filled(teams, 0);

    for (var r in rounds) {
      for (int t = 0; t < teams; t++) {
        totals[t] += _getTeamRoundScore(t, r, teams);
      }
    }

    if (teams == 1) {
      return "Finalize your game with a total co-op score of ${totals[0]}?";
    }

    int maxScore = totals.reduce(max);
    List<int> winningTeams = [];
    for (int i = 0; i < totals.length; i++) {
      if (totals[i] == maxScore) {
        winningTeams.add(i);
      }
    }

    if (winningTeams.length == 1) {
      int w = winningTeams[0];
      return "Declare ${_getTeamName(w, playerNames)} as the winners with a final score of $maxScore?";
    } else {
      return "Declare a tie with a score of $maxScore?";
    }
  }

  int _calculateTotal(
    int teamIndex,
    List<Map<String, dynamic>> rounds,
    int totalTeams,
  ) {
    int total = 0;
    for (var round in rounds) {
      total += _getTeamRoundScore(teamIndex, round, totalTeams);
    }
    return total;
  }

  String _getTeamName(int teamIndex, List<String> playerNames) {
    int p1 = teamIndex * 2;
    int p2 = teamIndex * 2 + 1;
    if (p2 < playerNames.length)
      return "${playerNames[p1]} & ${playerNames[p2]}";
    if (p1 < playerNames.length) return playerNames[p1];
    return "Team ${teamIndex + 1}";
  }

  Widget _buildToggle(
    String text,
    bool isSelected,
    VoidCallback onTap, {
    double width = 60,
    double fontSize = 14,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: width,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00A2FF)
              : Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00A2FF)
                : Colors.white.withOpacity(0.1),
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
            ),
          ),
        ),
      ),
    );
  }

  void _showScoreInputDialog(
    BuildContext context,
    int roundIndex,
    int teamIndex,
    List<Map<String, dynamic>> rounds,
    List<String> playerNames,
    VoidCallback onDataChanged,
    Map<String, dynamic> customSettings,
  ) {
    int teams = playerNames.length ~/ 2;
    String currentScore =
        rounds[roundIndex]['t${teamIndex + 1}Score']?.toString() ?? "";
    String? targetDir = rounds[roundIndex]['t${teamIndex + 1}Dir'];

    Map<int, String?> guesses = {};
    for (int t = 0; t < teams; t++) {
      if (t != teamIndex) {
        guesses[t] = rounds[roundIndex]['t${t + 1}GuessT${teamIndex + 1}'];
      }
    }

    // --- UPDATED: 1 is no longer a valid score, added 4 ---
    final List<String> options = ['0', '2', '3', '4'];

    int p1Idx = teamIndex * 2;
    int p2Idx = teamIndex * 2 + 1;
    String p1 = playerNames[p1Idx];
    String p2 = playerNames[p2Idx];

    String? firstGuesser = rounds.isNotEmpty
        ? rounds[0]['t${teamIndex + 1}Guesser']
        : null;
    String initialGuesser =
        firstGuesser != null && (firstGuesser == p1 || firstGuesser == p2)
        ? firstGuesser
        : p1;
    String initialClueGiver = initialGuesser == p1 ? p2 : p1;

    String currentClueGiver = roundIndex % 2 == 0
        ? initialClueGiver
        : initialGuesser;
    String currentGuesser = roundIndex % 2 == 0
        ? initialGuesser
        : initialClueGiver;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Round ${roundIndex + 1}",
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "$currentGuesser guessing $currentClueGiver's clue",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- UPDATED: Opponent catch-up tracking is ALWAYS visible and BEFORE score if > 1 team ---
                    if (teams > 1) ...[
                      const Text(
                        "Opponent Guesses (1 Pt):",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      for (int t = 0; t < teams; t++)
                        if (t != teamIndex)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _getTeamName(t, playerNames),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Row(
                                  children: [
                                    _buildToggle(
                                      "L",
                                      guesses[t] == 'L',
                                      () => setDialogState(
                                        () => guesses[t] = guesses[t] == 'L'
                                            ? null
                                            : 'L',
                                      ),
                                      width: 44,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildToggle(
                                      "R",
                                      guesses[t] == 'R',
                                      () => setDialogState(
                                        () => guesses[t] = guesses[t] == 'R'
                                            ? null
                                            : 'R',
                                      ),
                                      width: 44,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      const Divider(color: Colors.white12, height: 40),
                    ],

                    const Text(
                      "Score:",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
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
                            width: 50,
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
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    if (currentScore.isNotEmpty && currentScore != '4') ...[
                      const Divider(color: Colors.white12, height: 40),
                      const Text(
                        "Where was the target center?",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildToggle(
                            "LEFT",
                            targetDir == 'L',
                            () => setDialogState(() => targetDir = 'L'),
                            width: 100,
                          ),
                          _buildToggle(
                            "RIGHT",
                            targetDir == 'R',
                            () => setDialogState(() => targetDir = 'R'),
                            width: 100,
                          ),
                        ],
                      ),
                    ],
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
                    // Validation: Must select L/R center direction if not a 4
                    if (currentScore.isNotEmpty && currentScore != '4') {
                      if (targetDir == null) {
                        SleekNotificationBanner.show(
                          "Missing Target Direction",
                          "Please select whether the target center was to the Left or Right of your dial.",
                          icon: Icons.warning_amber_rounded,
                          color: Colors.orangeAccent,
                        );
                        return;
                      }
                    }

                    // Validation: Opponent Guesses
                    if (teams > 1 &&
                        currentScore.isNotEmpty &&
                        currentScore != '4') {
                      for (int t = 0; t < teams; t++) {
                        if (t != teamIndex && guesses[t] == null) {
                          SleekNotificationBanner.show(
                            "Missing Opponent Guesses",
                            "All opposing teams must submit a Left or Right guess before saving.",
                            icon: Icons.warning_amber_rounded,
                            color: Colors.orangeAccent,
                          );
                          return;
                        }
                      }
                    }

                    if (roundIndex == 0 &&
                        rounds[0]['t${teamIndex + 1}Guesser'] == null) {
                      rounds[0]['t${teamIndex + 1}Guesser'] = currentGuesser;
                    }

                    rounds[roundIndex]['t${teamIndex + 1}Score'] = currentScore;

                    if (currentScore.isNotEmpty) {
                      if (currentScore == '4') {
                        rounds[roundIndex].remove('t${teamIndex + 1}Dir');
                      } else {
                        rounds[roundIndex]['t${teamIndex + 1}Dir'] = targetDir;
                      }
                    } else {
                      rounds[roundIndex].remove('t${teamIndex + 1}Dir');
                    }

                    if (teams > 1 && currentScore.isNotEmpty) {
                      for (int t = 0; t < teams; t++) {
                        if (t != teamIndex) {
                          if (guesses[t] != null) {
                            rounds[roundIndex]['t${t + 1}GuessT${teamIndex + 1}'] =
                                guesses[t];
                          } else {
                            rounds[roundIndex].remove(
                              't${t + 1}GuessT${teamIndex + 1}',
                            );
                          }
                        }
                      }
                    } else if (teams > 1) {
                      for (int t = 0; t < teams; t++) {
                        if (t != teamIndex) {
                          rounds[roundIndex].remove(
                            't${t + 1}GuessT${teamIndex + 1}',
                          );
                        }
                      }
                    }

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

  @override
  Widget? buildExtraAssignmentUI({
    required BuildContext context,
    required void Function(VoidCallback fn) setModalState,
    required List<String> playerNames,
    int? activePlayerIndex,
    required Map<String, dynamic> customSettings,
    required void Function(String, dynamic) onSettingsChanged,
  }) {
    if (playerNames.length < 2) return null;
    int numTeams = playerNames.length ~/ 2;

    List<Widget> teamSelectors = [];
    bool showValidationError = customSettings['showValidationError'] == true;

    teamSelectors.add(
      const Padding(
        padding: EdgeInsets.only(bottom: 12.0),
        child: Text(
          "TEAM ROLES",
          style: TextStyle(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );

    for (int t = 1; t <= numTeams; t++) {
      int p1Idx = (t - 1) * 2;
      int p2Idx = p1Idx + 1;

      if (p2Idx >= playerNames.length) continue;

      String p1Name = playerNames[p1Idx];
      String p2Name = playerNames[p2Idx];
      List<String> validNames = [
        p1Name,
        p2Name,
      ].where((n) => !n.startsWith('Player ')).toList();

      String clueGiverKey = 'team_${t}_clueGiver';
      String guesserKey = 'team_${t}_guesser';

      String? firstClueGiver = customSettings[clueGiverKey];
      if (firstClueGiver != null && !validNames.contains(firstClueGiver)) {
        firstClueGiver = null;
      }

      bool highlightError = showValidationError && firstClueGiver == null;
      String? firstGuesser = firstClueGiver != null
          ? (firstClueGiver == p1Name ? p2Name : p1Name)
          : null;

      teamSelectors.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "TEAM $t",
                style: const TextStyle(
                  color: Color(0xFF00A2FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(
                    width: 120,
                    child: Text(
                      "First Clue Giver:",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: highlightError
                          ? const EdgeInsets.symmetric(horizontal: 12)
                          : EdgeInsets.zero,
                      decoration: BoxDecoration(
                        color: highlightError
                            ? Colors.redAccent.withOpacity(0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: highlightError
                              ? Colors.redAccent
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          dropdownColor: const Color(0xFF2C2C2C),
                          hint: Text(
                            highlightError
                                ? "Required Selection"
                                : "Select Player",
                            style: TextStyle(
                              color: highlightError
                                  ? Colors.redAccent
                                  : Colors.white38,
                              fontSize: 13,
                              fontWeight: highlightError
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          value: firstClueGiver,
                          icon: const Icon(
                            Icons.expand_more,
                            color: Colors.white54,
                            size: 20,
                          ),
                          items: validNames
                              .map<DropdownMenuItem<String>>(
                                (p) => DropdownMenuItem<String>(
                                  value: p,
                                  child: Text(
                                    p,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              onSettingsChanged(clueGiverKey, val);
                              onSettingsChanged(
                                guesserKey,
                                val == p1Name ? p2Name : p1Name,
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const SizedBox(
                    width: 120,
                    child: Text(
                      "First Guesser:",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      firstGuesser ?? "---",
                      style: TextStyle(
                        color: firstGuesser != null
                            ? Colors.white
                            : Colors.white38,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (teamSelectors.length == 1)
      return null; // Wait until at least 1 team exists

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...teamSelectors,
          const Text(
            "These roles will automatically alternate every round.",
            style: TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  double _getDynamicFontSize(double baseSize, bool isCrowded) =>
      isCrowded ? baseSize * 0.9 : baseSize;

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
    int teams = playerNames.length ~/ 2;
    double rndWidth = 52.0;
    double minTeamWidth = 90.0;
    double calculatedWidth = (constraints.maxWidth - rndWidth) / teams;
    bool needsScroll = calculatedWidth < minTeamWidth;

    Map<int, TableColumnWidth> colWidths = {0: FixedColumnWidth(rndWidth)};
    for (int t = 0; t < teams; t++) {
      colWidths[t + 1] = needsScroll
          ? FixedColumnWidth(minTeamWidth)
          : const FlexColumnWidth();
    }

    List<TableRow> rows = [];
    rows.add(
      TableRow(
        children: [
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: _buildHeaderCell("RND"),
          ),
          for (int t = 0; t < teams; t++)
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: _buildTeamHeaderCell(
                t,
                playerNames,
                isFinalized,
                onPlayerTap,
                customSettings,
              ),
            ),
        ],
      ),
    );
    for (int r = 0; r < rounds.length; r++) {
      rows.add(
        TableRow(
          children: [
            _buildCell("${r + 1}", isBold: true, color: Colors.white54),
            for (int t = 0; t < teams; t++)
              _buildScoreCell(
                context,
                r,
                t,
                rounds,
                playerNames,
                isFinalized,
                onDataChanged,
                customSettings,
              ),
          ],
        ),
      );
    }
    rows.add(
      TableRow(
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.3)),
        children: [
          _buildCell("TOT", isBold: true, color: const Color(0xFF00A2FF)),
          for (int t = 0; t < teams; t++)
            _buildCell(
              "${_calculateTotal(t, rounds, teams)}",
              isBold: true,
              color: const Color(0xFF00A2FF),
              fontSize: 22,
            ),
        ],
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

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 4.0),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamHeaderCell(
    int teamIndex,
    List<String> playerNames,
    bool isFinalized,
    Function(int) onPlayerTap,
    Map<String, dynamic> customSettings,
  ) {
    int p1Idx = teamIndex * 2;
    int p2Idx = teamIndex * 2 + 1;

    const textStyle = TextStyle(
      color: Color(0xFF00A2FF),
      fontWeight: FontWeight.w900,
      fontSize: 12,
      letterSpacing: 0.5,
    );

    String teamName = _getTeamName(teamIndex, playerNames);

    Widget cellContent = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
      child: Center(
        child: Text(
          teamName,
          textAlign: TextAlign.center,
          style: textStyle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );

    Widget cell = InkWell(
      onTap: isFinalized ? null : () => onPlayerTap(p1Idx),
      child: cellContent,
    );

    return cell;
  }

  Widget _buildCell(
    String text, {
    bool isBold = false,
    Color color = Colors.white,
    double fontSize = 16.0,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 8.0),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: fontSize,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCell(
    BuildContext context,
    int roundIndex,
    int teamIndex,
    List<Map<String, dynamic>> rounds,
    List<String> playerNames,
    bool isFinalized,
    VoidCallback onDataChanged,
    Map<String, dynamic> customSettings,
  ) {
    int teams = playerNames.length ~/ 2;
    var round = rounds[roundIndex];

    bool hasActive =
        round['t${teamIndex + 1}Score'] != null &&
        round['t${teamIndex + 1}Score'].toString().isNotEmpty;
    int activeScore = hasActive
        ? (int.tryParse(round['t${teamIndex + 1}Score'].toString()) ?? 0)
        : 0;

    int totalScore = _getTeamRoundScore(teamIndex, round, teams);
    int catchupPoints = totalScore - activeScore;

    String display;
    if (hasActive) {
      if (catchupPoints > 0) {
        display = "$activeScore +$catchupPoints";
      } else {
        display = activeScore.toString();
      }
    } else if (catchupPoints > 0) {
      display = "+$catchupPoints";
    } else {
      display = "-";
    }

    return InkWell(
      onTap: isFinalized
          ? null
          : () {
              _showScoreInputDialog(
                context,
                roundIndex,
                teamIndex,
                rounds,
                playerNames,
                onDataChanged,
                customSettings,
              );
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 8.0),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              display,
              style: TextStyle(
                color: !hasActive && catchupPoints > 0
                    ? const Color(0xFF54A27E)
                    : Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
