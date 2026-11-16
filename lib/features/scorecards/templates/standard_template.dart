import 'package:flutter/material.dart';
import '../../../core/shared_widgets/sleek_notification_banner.dart';
import 'game_template.dart';
import 'playable_data_entry_dialog.dart';

class StandardTemplate extends GameTemplate {
  @override
  String get gameType => 'Standard Scorecard';

  @override
  int get initialPlayerCount => 2;

  @override
  bool canAddPlayer(
    int currentPlayerCount,
    List<Map<String, dynamic>> rounds,
  ) => currentPlayerCount < 12;

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
    if (rounds.isEmpty) return false;
    for (var round in rounds) {
      for (int p = 1; p <= playerCount; p++) {
        if (round['p${p}Score'] == null ||
            round['p${p}Score'].toString().trim().isEmpty)
          return false;
      }
    }
    return true;
  }

  @override
  void recalculateTotals(
    List<Map<String, dynamic>> rounds,
    int playerCount, {
    Map<String, dynamic> customSettings = const {},
  }) {
    List<int> runningTotals = List.filled(playerCount, 0);
    for (var r in rounds) {
      for (int p = 0; p < playerCount; p++) {
        runningTotals[p] +=
            int.tryParse(r['p${p + 1}Score']?.toString() ?? '') ?? 0;
        r['p${p + 1}Total'] = runningTotals[p];
      }
    }
  }

  @override
  String getWinnerDeclaration(
    List<String> playerNames,
    List<Map<String, dynamic>> rounds, {
    Map<String, dynamic> customSettings = const {},
  }) {
    List<int> totals = List.filled(playerNames.length, 0);
    for (var r in rounds) {
      for (int p = 0; p < playerNames.length; p++) {
        totals[p] += int.tryParse(r['p${p + 1}Score']?.toString() ?? '') ?? 0;
      }
    }
    int maxScore = totals[0];
    int maxIndex = 0;
    for (int i = 1; i < totals.length; i++) {
      if (totals[i] > maxScore) {
        maxScore = totals[i];
        maxIndex = i;
      }
    }
    return "Declare ${playerNames[maxIndex]} as the winner with a final score of $maxScore?";
  }

  int _calculateTotal(int playerIndex, List<Map<String, dynamic>> rounds) {
    int total = 0;
    for (var round in rounds)
      total +=
          int.tryParse(round['p${playerIndex + 1}Score']?.toString() ?? '') ??
          0;
    return total;
  }

  void _showScoreInputDialog(
    BuildContext context,
    int roundIndex,
    int playerIndex,
    List<Map<String, dynamic>> rounds,
    List<String> playerNames,
    VoidCallback onDataChanged,
    Map<String, dynamic> customSettings,
  ) {
    final cellConfigs = customSettings['cellConfigs'] as Map<String, dynamic>?;
    final String configKey = 'round_${roundIndex}_player_$playerIndex';
    final String generalPlayerKey = 'player_$playerIndex';

    final Map<String, dynamic>? config =
        cellConfigs?[configKey] ?? cellConfigs?[generalPlayerKey];

    if (config != null) {
      showDialog(
        context: context,
        builder: (context) {
          return PlayableDataEntryDialog(
            config: config,
            defaultTitle:
                "Round ${roundIndex + 1}: ${playerNames[playerIndex]}",
          );
        },
      ).then((result) {
        if (result != null && result is Map) {
          rounds[roundIndex]['p${playerIndex + 1}Score'] = result['score'];
          rounds[roundIndex]['p${playerIndex + 1}RawInputs'] =
              result['rawInputs'];
          onDataChanged();
        }
      });
      return;
    }

    TextEditingController scoreController = TextEditingController(
      text: rounds[roundIndex]['p${playerIndex + 1}Score']?.toString() ?? "",
    );
    showDialog(
      context: context,
      builder: (context) {
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
          content: TextField(
            controller: scoreController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(
              signed: true,
              decimal: false,
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: "0",
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (value) {
              rounds[roundIndex]['p${playerIndex + 1}Score'] = value;
              onDataChanged();
              Navigator.pop(context);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () {
                rounds[roundIndex]['p${playerIndex + 1}Score'] =
                    scoreController.text;
                onDataChanged();
                Navigator.pop(context);
              },
              child: const Text(
                "SAVE",
                style: TextStyle(
                  color: Color(0xFF00A2FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
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
  }) => null;

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
    double rndWidth = 52.0;
    double minPlayerWidth = 48.0;
    double calculatedWidth =
        (constraints.maxWidth - rndWidth) / playerNames.length;
    bool needsScroll = calculatedWidth < minPlayerWidth;
    double actualColWidth = needsScroll ? minPlayerWidth : calculatedWidth;
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
    for (int i = 0; i < playerNames.length; i++)
      colWidths[i + 1] = needsScroll
          ? FixedColumnWidth(minPlayerWidth)
          : const FlexColumnWidth();

    List<TableRow> rows = [];
    rows.add(
      TableRow(
        children: [
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: _buildHeaderCell("RND", isCrowded),
          ),
          for (int i = 0; i < playerNames.length; i++)
            TableCell(
              verticalAlignment: isCrowded
                  ? TableCellVerticalAlignment.bottom
                  : TableCellVerticalAlignment.middle,
              child: _buildPlayerHeaderCell(
                i,
                isCrowded,
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
            _buildCell(
              "${r + 1}",
              isBold: true,
              color: Colors.white54,
              isCrowded: isCrowded,
            ),
            for (int p = 0; p < playerNames.length; p++)
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
          ],
        ),
      );
    }
    rows.add(
      TableRow(
        children: [
          _buildCell(
            "TOT",
            isBold: true,
            color: const Color(0xFF00A2FF),
            isCrowded: isCrowded,
          ),
          for (int p = 0; p < playerNames.length; p++)
            _buildCell(
              "${_calculateTotal(p, rounds)}",
              isBold: true,
              color: const Color(0xFF00A2FF),
              isCrowded: isCrowded,
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
    if (needsScroll)
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: tableGrid,
        ),
      );
    return tableGrid;
  }

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
              fontSize: _getDynamicFontSize(12, isCrowded),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerHeaderCell(
    int playerIndex,
    bool isCrowded,
    List<String> playerNames,
    bool isFinalized,
    Function(int) onPlayerTap,
    Map<String, dynamic> customSettings,
  ) {
    final textStyle = TextStyle(
      color: const Color(0xFF00A2FF),
      fontWeight: FontWeight.w900,
      fontSize: _getDynamicFontSize(14, isCrowded),
      letterSpacing: 1.0,
    );

    bool isGroupGame = customSettings['isGroupGame'] == true;
    bool isUnassigned =
        isGroupGame && playerNames[playerIndex].startsWith('Player ');

    Widget cellContent = Center(
      child: isCrowded
          ? ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 75),
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(
                  playerNames[playerIndex],
                  style: textStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
          : Text(
              playerNames[playerIndex],
              textAlign: TextAlign.center,
              style: textStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
    );

    Widget cell = InkWell(
      onTap: isFinalized ? null : () => onPlayerTap(playerIndex),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 4.0),
        child: cellContent,
      ),
    );

    if (isUnassigned && !isFinalized) {
      return _PulsingGlow(color: const Color(0xFF00A2FF), child: cell);
    }

    return cell;
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
              fontSize: _getDynamicFontSize(16, isCrowded),
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
    List<String> playerNames,
    bool isFinalized,
    VoidCallback onDataChanged,
    Map<String, dynamic> customSettings,
  ) {
    final score = rounds[roundIndex]['p${playerIndex + 1}Score'];

    bool isGroupGame = customSettings['isGroupGame'] == true;
    bool anyUnassigned =
        isGroupGame && playerNames.any((n) => n.startsWith('Player '));

    return InkWell(
      onTap: isFinalized
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
              _showScoreInputDialog(
                context,
                roundIndex,
                playerIndex,
                rounds,
                playerNames,
                onDataChanged,
                customSettings,
              );
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              score != null && score.toString().isNotEmpty ? "$score" : "-",
              style: TextStyle(
                color: Colors.white,
                fontSize: _getDynamicFontSize(18, isCrowded),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
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
