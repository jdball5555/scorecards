import 'package:flutter/material.dart';
import '../../../core/shared_widgets/sleek_notification_banner.dart';
import '../../../core/shared_widgets/glass_card.dart';
import 'game_template.dart';

class SpadesTemplate extends GameTemplate {
  @override
  String get gameType => 'Spades';

  @override
  int get initialPlayerCount => 4;

  @override
  bool canAddPlayer(
    int currentPlayerCount,
    List<Map<String, dynamic>> rounds,
  ) => false;

  @override
  List<String> generateInitialPlayerNames() => [
    "Player 1",
    "Player 2",
    "Player 3",
    "Player 4",
  ];

  @override
  Map<String, dynamic> createNewRound(int roundNum, int playerCount) => {
    'roundNum': roundNum,
  };

  bool _isRoundComplete(Map<String, dynamic> round) {
    if (round['p1Bid'] == null || round['p1Bid'].toString().isEmpty) {
      return false;
    }
    if (round['p2Bid'] == null || round['p2Bid'].toString().isEmpty) {
      return false;
    }
    if (round['p3Bid'] == null || round['p3Bid'].toString().isEmpty) {
      return false;
    }
    if (round['p4Bid'] == null || round['p4Bid'].toString().isEmpty) {
      return false;
    }
    if (round['t1Hand'] == null || round['t1Hand'].toString().isEmpty) {
      return false;
    }
    if (round['t2Hand'] == null || round['t2Hand'].toString().isEmpty) {
      return false;
    }
    return true;
  }

  bool isRoundMathValid(Map<String, dynamic> round) {
    if (!_isRoundComplete(round)) return true;

    int getBid(String? b) {
      if (b == 'N' || b == 'NIL' || b == 'BN') return 0;
      return int.tryParse(b ?? '') ?? 0;
    }

    int t1Bid =
        getBid(round['p1Bid']?.toString()) + getBid(round['p2Bid']?.toString());
    int t2Bid =
        getBid(round['p3Bid']?.toString()) + getBid(round['p4Bid']?.toString());

    int hand1 = int.tryParse(round['t1Hand']?.toString() ?? '') ?? 0;
    int t1Bags = hand1.abs() % 10;
    bool t1Set = round['t1Set'] == true;

    int hand2 = int.tryParse(round['t2Hand']?.toString() ?? '') ?? 0;
    int t2Bags = hand2.abs() % 10;
    bool t2Set = round['t2Set'] == true;

    if (!t1Set && !t2Set) {
      return (t1Bid + t1Bags + t2Bid + t2Bags) == 13;
    } else if (t1Set && !t2Set) {
      return (t2Bid + t2Bags) >= (14 - t1Bid);
    } else if (!t1Set && t2Set) {
      return (t1Bid + t1Bags) >= (14 - t2Bid);
    } else {
      return (t1Bid + t2Bid) > 13;
    }
  }

  @override
  bool canAddRound(
    List<Map<String, dynamic>> rounds,
    int playerCount, {
    Map<String, dynamic> customSettings = const {},
  }) {
    if (rounds.isEmpty) {
      return true;
    }
    return _isRoundComplete(rounds.last) && isRoundMathValid(rounds.last);
  }

  bool _isBidRoundEmpty(Map<String, dynamic> round) {
    for (int i = 1; i <= 4; i++) {
      final bid = round['p${i}Bid'];
      if (bid != null && bid.toString().isNotEmpty) {
        return false;
      }
    }
    return true;
  }

  @override
  bool isReadyToFinalize(
    List<Map<String, dynamic>> rounds,
    int playerCount, {
    Map<String, dynamic> customSettings = const {},
  }) {
    if (rounds.isEmpty) {
      return false;
    }
    for (var r in rounds) {
      if (!_isRoundComplete(r) || !isRoundMathValid(r)) {
        return false;
      }
    }
    return true;
  }

  @override
  void onRoundRemoved(List<Map<String, dynamic>> rounds) {
    recalculateTotals(rounds, 4);
  }

  @override
  String getWinnerDeclaration(
    List<String> playerNames,
    List<Map<String, dynamic>> rounds, {
    Map<String, dynamic> customSettings = const {},
  }) {
    int t1Tot = int.tryParse(rounds.last['t1Total']?.toString() ?? '0') ?? 0;
    int t2Tot = int.tryParse(rounds.last['t2Total']?.toString() ?? '0') ?? 0;

    if (t1Tot > t2Tot) {
      return "Declare ${playerNames[0]} and ${playerNames[1]} as the winners with a final score of $t1Tot to $t2Tot?";
    } else if (t2Tot > t1Tot) {
      return "Declare ${playerNames[2]} and ${playerNames[3]} as the winners with a final score of $t2Tot to $t1Tot?";
    } else {
      return "Declare a tie with a final score of $t1Tot to $t2Tot?";
    }
  }

  @override
  void recalculateTotals(
    List<Map<String, dynamic>> rounds,
    int playerCount, {
    Map<String, dynamic> customSettings = const {},
  }) {
    int t1Points = 0;
    int t1Bags = 0;
    int t2Points = 0;
    int t2Bags = 0;

    for (int i = 0; i < rounds.length; i++) {
      int hand1 = int.tryParse(rounds[i]['t1Hand']?.toString() ?? '') ?? 0;
      int bags1 = hand1.abs() % 10;
      int base1 = hand1 >= 0 ? (hand1 - bags1) : (hand1 + bags1);

      t1Points += base1;
      t1Bags += bags1;

      if (t1Bags >= 10) {
        t1Points -= 100;
        t1Bags -= 10;
        rounds[i]['t1Bagged'] = true;
      } else {
        rounds[i].remove('t1Bagged');
      }

      int t1DisplayTotal = t1Points >= 0
          ? (t1Points + t1Bags)
          : (t1Points - t1Bags);
      rounds[i]['t1Total'] = t1DisplayTotal.toString();

      int hand2 = int.tryParse(rounds[i]['t2Hand']?.toString() ?? '') ?? 0;
      int bags2 = hand2.abs() % 10;
      int base2 = hand2 >= 0 ? (hand2 - bags2) : (hand2 + bags2);

      t2Points += base2;
      t2Bags += bags2;

      if (t2Bags >= 10) {
        t2Points -= 100;
        t2Bags -= 10;
        rounds[i]['t2Bagged'] = true;
      } else {
        rounds[i].remove('t2Bagged');
      }

      int t2DisplayTotal = t2Points >= 0
          ? (t2Points + t2Bags)
          : (t2Points - t2Bags);
      rounds[i]['t2Total'] = t2DisplayTotal.toString();
    }
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
    if (playerNames.length < 4) {
      return null;
    }

    List<String> uniquePlayers = playerNames.toSet().toList();

    String? firstBidder = customSettings['firstBidder'];
    if (firstBidder != null && !uniquePlayers.contains(firstBidder)) {
      firstBidder = null;
    }
    firstBidder ??= playerNames[0];

    List<String> t1 = [playerNames[0], playerNames[1]];
    List<String> t2 = [playerNames[2], playerNames[3]];

    List<String> getOpposing(String player) {
      return t1.contains(player) ? t2 : t1;
    }

    String? secondBidder = customSettings['secondBidder'];
    if (secondBidder != null &&
        !getOpposing(firstBidder).contains(secondBidder)) {
      secondBidder = getOpposing(firstBidder)[0];
    }
    secondBidder ??= getOpposing(firstBidder)[0];

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "BIDDING ORDER",
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(
                width: 100,
                child: Text(
                  "1st Bidder:",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: false,
                      dropdownColor: const Color(0xFF2C2C2C),
                      value: firstBidder,
                      icon: const Icon(
                        Icons.expand_more,
                        color: Colors.white54,
                        size: 20,
                      ),
                      items: uniquePlayers
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
                          onSettingsChanged('firstBidder', val);
                          onSettingsChanged(
                            'secondBidder',
                            getOpposing(val)[0],
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const SizedBox(
                width: 100,
                child: Text(
                  "2nd Bidder:",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: false,
                      dropdownColor: const Color(0xFF2C2C2C),
                      value: secondBidder,
                      icon: const Icon(
                        Icons.expand_more,
                        color: Colors.white54,
                        size: 20,
                      ),
                      items: getOpposing(firstBidder)
                          .toSet()
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
                          onSettingsChanged('secondBidder', val);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBidDialog(
    BuildContext context,
    int roundIndex,
    int playerIndex,
    List<Map<String, dynamic>> rounds,
    List<String> playerNames,
    VoidCallback onDataChanged,
  ) {
    String currentBid =
        rounds[roundIndex]['p${playerIndex + 1}Bid']?.toString() ?? "";
    final List<String> bidOptions = [
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      '10',
      '11',
      '12',
      '13',
      'N',
      'BN',
    ];

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
                "Round ${roundIndex + 1}: ${playerNames[playerIndex]} Bid",
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
                children: bidOptions.map((bid) {
                  final isSelected = currentBid == bid;
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        currentBid = isSelected ? "" : bid;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 52,
                      height: 52,
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
                          bid,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: bid.length > 1 ? 16 : 20,
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
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A2FF),
                  ),
                  onPressed: () {
                    rounds[roundIndex]['p${playerIndex + 1}Bid'] = currentBid;
                    onDataChanged();
                    Navigator.pop(ctx);

                    if (_isRoundComplete(rounds[roundIndex]) &&
                        !isRoundMathValid(rounds[roundIndex])) {
                      SleekNotificationBanner.show(
                        "Invalid Scores",
                        "The total tricks no longer equal 13. Please adjust the hands.",
                        icon: Icons.calculate,
                        color: Colors.redAccent,
                      );
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

  // --- UPDATED: Reads directly from rounds data saved during setup ---
  List<String> _getBiddingOrder(
    List<String> playerNames,
    List<Map<String, dynamic>> rounds,
  ) {
    if (playerNames.length < 4) return playerNames;
    String? s1;
    String? s2;

    if (rounds.isNotEmpty) {
      s1 = rounds.first['firstBidder'];
      s2 = rounds.first['secondBidder'];
    }

    List<String> t1 = [playerNames[0], playerNames[1]];
    List<String> t2 = [playerNames[2], playerNames[3]];

    if (s1 == null || !playerNames.contains(s1)) {
      s1 = playerNames[0];
    }

    bool s1IsT1 = t1.contains(s1);
    List<String> oppTeam = s1IsT1 ? t2 : t1;
    List<String> sameTeam = s1IsT1 ? t1 : t2;

    if (s2 == null || !oppTeam.contains(s2)) {
      s2 = oppTeam[0];
    }

    String s3 = sameTeam.firstWhere((n) => n != s1, orElse: () => sameTeam[0]);
    String s4 = oppTeam.firstWhere((n) => n != s2, orElse: () => oppTeam[0]);

    return [s1, s2, s3, s4];
  }

  void _showQuickBidDialog(
    BuildContext context,
    int roundIndex,
    List<Map<String, dynamic>> rounds,
    List<String> playerNames,
    Map<String, dynamic> customSettings,
    VoidCallback onDataChanged,
  ) {
    List<String> baseOrder = _getBiddingOrder(playerNames, rounds);
    List<String> roundOrder = [];
    for (int i = 0; i < 4; i++) {
      roundOrder.add(baseOrder[(roundIndex + i) % 4]);
    }

    List<int> playerIndices = roundOrder
        .map((n) => playerNames.indexOf(n))
        .toList();

    int currentStep = 0;
    List<String> bids = ["", "", "", ""];
    for (int i = 0; i < 4; i++) {
      bids[i] =
          rounds[roundIndex]['p${playerIndices[i] + 1}Bid']?.toString() ?? "";
    }

    int t1Tot = 0;
    int t2Tot = 0;
    for (var rnd in rounds) {
      if (rnd['t1Total'] != null) {
        t1Tot = int.tryParse(rnd['t1Total'].toString()) ?? t1Tot;
      }
      if (rnd['t2Total'] != null) {
        t2Tot = int.tryParse(rnd['t2Total'].toString()) ?? t2Tot;
      }
    }

    String getBidForPlayer(int pIdx) {
      int step = playerIndices.indexOf(pIdx);
      return (step != -1 && step < 4) ? bids[step] : "";
    }

    final List<String> bidOptions = [
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      '10',
      '11',
      '12',
      '13',
      'N',
      'BN',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentPlayerName = roundOrder[currentStep];

            String b1 = getBidForPlayer(0);
            String b2 = getBidForPlayer(1);
            String b3 = getBidForPlayer(2);
            String b4 = getBidForPlayer(3);

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
                      "Round ${roundIndex + 1}: $currentPlayerName Bid",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${currentStep + 1} of 4",
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          bool isCurrent = index == currentStep;
                          bool isPast = index < currentStep;
                          return Row(
                            children: [
                              Text(
                                roundOrder[index],
                                style: TextStyle(
                                  color: isCurrent
                                      ? const Color(0xFF00A2FF)
                                      : (isPast
                                            ? Colors.white70
                                            : Colors.white38),
                                  fontWeight: isCurrent
                                      ? FontWeight.w900
                                      : FontWeight.bold,
                                  fontSize: isCurrent ? 14 : 12,
                                ),
                              ),
                              if (index < 3)
                                const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 4.0,
                                  ),
                                  child: Icon(
                                    Icons.arrow_forward_ios,
                                    size: 10,
                                    color: Colors.white24,
                                  ),
                                ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: GlassCard(
                        accentColor: const Color(0xFF7855C1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text(
                                        "${playerNames[0]} & ${playerNames[1]}",
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "$t1Tot",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "${playerNames[0]}: ${b1.isEmpty ? '-' : b1}",
                                        style: TextStyle(
                                          color:
                                              currentStep ==
                                                  playerIndices.indexOf(0)
                                              ? const Color(0xFF00A2FF)
                                              : Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        "${playerNames[1]}: ${b2.isEmpty ? '-' : b2}",
                                        style: TextStyle(
                                          color:
                                              currentStep ==
                                                  playerIndices.indexOf(1)
                                              ? const Color(0xFF00A2FF)
                                              : Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const VerticalDivider(
                                  color: Colors.white24,
                                  thickness: 1,
                                  width: 24,
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text(
                                        "${playerNames[2]} & ${playerNames[3]}",
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "$t2Tot",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 32,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "${playerNames[2]}: ${b3.isEmpty ? '-' : b3}",
                                        style: TextStyle(
                                          color:
                                              currentStep ==
                                                  playerIndices.indexOf(2)
                                              ? const Color(0xFF00A2FF)
                                              : Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        "${playerNames[3]}: ${b4.isEmpty ? '-' : b4}",
                                        style: TextStyle(
                                          color:
                                              currentStep ==
                                                  playerIndices.indexOf(3)
                                              ? const Color(0xFF00A2FF)
                                              : Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: bidOptions.map((bid) {
                      final isSelected = bids[currentStep] == bid;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            bids[currentStep] = bid;

                            for (int i = 0; i <= currentStep; i++) {
                              if (bids[i].isNotEmpty) {
                                rounds[roundIndex]['p${playerIndices[i] + 1}Bid'] =
                                    bids[i];
                              }
                            }
                            onDataChanged();

                            if (currentStep < 3) {
                              currentStep++;
                            } else {
                              Navigator.pop(ctx);
                              if (_isRoundComplete(rounds[roundIndex]) &&
                                  !isRoundMathValid(rounds[roundIndex])) {
                                SleekNotificationBanner.show(
                                  "Invalid Scores",
                                  "The total tricks no longer equal 13. Please adjust the hands.",
                                  icon: Icons.calculate,
                                  color: Colors.redAccent,
                                );
                              }
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 52,
                          height: 52,
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
                              bid,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: bid.length > 1 ? 16 : 20,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                if (currentStep > 0)
                  TextButton(
                    onPressed: () {
                      setDialogState(() {
                        bids[currentStep] = "";
                        rounds[roundIndex].remove(
                          'p${playerIndices[currentStep] + 1}Bid',
                        );
                        currentStep--;
                        bids[currentStep] = "";
                        rounds[roundIndex].remove(
                          'p${playerIndices[currentStep] + 1}Bid',
                        );
                        onDataChanged();
                      });
                    },
                    child: const Text(
                      "Back",
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                else
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
                    if (currentStep < 3) {
                      setDialogState(() {
                        currentStep++;
                      });
                    } else {
                      onDataChanged();
                      Navigator.pop(ctx);
                      if (_isRoundComplete(rounds[roundIndex]) &&
                          !isRoundMathValid(rounds[roundIndex])) {
                        SleekNotificationBanner.show(
                          "Invalid Scores",
                          "The total tricks no longer equal 13. Please adjust the hands.",
                          icon: Icons.calculate,
                          color: Colors.redAccent,
                        );
                      }
                    }
                  },
                  child: Text(
                    currentStep < 3 ? "NEXT" : "SAVE ALL",
                    style: const TextStyle(
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

  void _showTeamHandDialog(
    BuildContext context,
    int roundIndex,
    int teamIndex,
    List<Map<String, dynamic>> rounds,
    List<String> playerNames,
    VoidCallback onDataChanged,
  ) {
    int p1Idx = teamIndex == 0 ? 0 : 2;
    int p2Idx = teamIndex == 0 ? 1 : 3;

    String b1 = (rounds[roundIndex]['p${p1Idx + 1}Bid']?.toString() ?? '')
        .toUpperCase();
    String b2 = (rounds[roundIndex]['p${p2Idx + 1}Bid']?.toString() ?? '')
        .toUpperCase();

    bool isSet = rounds[roundIndex]['t${teamIndex + 1}Set'] == true;
    bool n1Success =
        rounds[roundIndex]['p${p1Idx + 1}NilSuccess'] == true ||
        rounds[roundIndex]['p${p1Idx + 1}BlindNilSuccess'] == true;
    bool n2Success =
        rounds[roundIndex]['p${p2Idx + 1}NilSuccess'] == true ||
        rounds[roundIndex]['p${p2Idx + 1}BlindNilSuccess'] == true;

    int currentHand =
        int.tryParse(
          rounds[roundIndex]['t${teamIndex + 1}Hand']?.toString() ?? '',
        ) ??
        0;
    int bags = currentHand.abs() % 10;

    int initialBase = 0;
    int initialNumericBid = 0;

    if (b1 == 'N' || b1 == 'NIL') {
      initialBase += n1Success ? 100 : -100;
    } else if (b1 == 'BN') {
      initialBase += n1Success ? 200 : -200;
    } else {
      initialNumericBid += int.tryParse(b1) ?? 0;
    }

    if (b2 == 'N' || b2 == 'NIL') {
      initialBase += n2Success ? 100 : -100;
    } else if (b2 == 'BN') {
      initialBase += n2Success ? 200 : -200;
    } else {
      initialNumericBid += int.tryParse(b2) ?? 0;
    }

    if (initialNumericBid == 13) {
      if (isSet) {
        initialBase -= 500;
      } else {
        initialBase += 500;
      }
    } else if (initialNumericBid == 10) {
      if (isSet) {
        initialBase -= 200;
      } else {
        initialBase += 200;
      }
    } else {
      if (isSet) {
        initialBase -= (initialNumericBid * 10);
      } else {
        initialBase += (initialNumericBid * 10);
      }
    }

    int initialDisplayScore = initialBase >= 0
        ? (initialBase + bags)
        : (initialBase - bags);

    String existingHand =
        rounds[roundIndex]['t${teamIndex + 1}Hand']?.toString() ?? "";
    TextEditingController overrideController = TextEditingController(
      text: existingHand.isNotEmpty
          ? existingHand
          : initialDisplayScore.toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void updateScore() {
              int basePoints = 0;
              int numericBid = 0;

              if (b1 == 'N' || b1 == 'NIL') {
                basePoints += n1Success ? 100 : -100;
              } else if (b1 == 'BN') {
                basePoints += n1Success ? 200 : -200;
              } else {
                numericBid += int.tryParse(b1) ?? 0;
              }

              if (b2 == 'N' || b2 == 'NIL') {
                basePoints += n2Success ? 100 : -100;
              } else if (b2 == 'BN') {
                basePoints += n2Success ? 200 : -200;
              } else {
                numericBid += int.tryParse(b2) ?? 0;
              }

              if (numericBid == 13) {
                if (isSet) {
                  basePoints -= 500;
                } else {
                  basePoints += 500;
                }
              } else if (numericBid == 10) {
                if (isSet) {
                  basePoints -= 200;
                } else {
                  basePoints += 200;
                }
              } else {
                if (isSet) {
                  basePoints -= (numericBid * 10);
                } else {
                  basePoints += (numericBid * 10);
                }
              }

              int displayScore = basePoints >= 0
                  ? (basePoints + bags)
                  : (basePoints - bags);
              overrideController.text = displayScore.toString();
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                "Round ${roundIndex + 1}: Team ${teamIndex + 1} Score",
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
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: const Color(0xFF00A2FF),
                      title: const Text(
                        "Did the team get set?",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      value: isSet,
                      onChanged: (val) {
                        setDialogState(() {
                          isSet = val;
                          if (isSet) bags = 0;
                          updateScore();
                        });
                      },
                    ),
                    if (!isSet) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "How many bags?",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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
                                  if (bags > 0) {
                                    setDialogState(() {
                                      bags--;
                                      updateScore();
                                    });
                                  }
                                },
                              ),
                              Text(
                                "$bags",
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
                                    bags++;
                                    updateScore();
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                    if (b1 == 'N' || b1 == 'NIL' || b1 == 'BN') ...[
                      const Divider(color: Colors.white12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeColor: const Color(0xFF00A2FF),
                        title: Text(
                          "Did ${playerNames[p1Idx]} make ${b1 == 'BN' ? 'Blind Nil' : 'Nil'}?",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        value: n1Success,
                        onChanged: (val) {
                          setDialogState(() {
                            n1Success = val;
                            updateScore();
                          });
                        },
                      ),
                    ],
                    if (b2 == 'N' || b2 == 'NIL' || b2 == 'BN') ...[
                      const Divider(color: Colors.white12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeColor: const Color(0xFF00A2FF),
                        title: Text(
                          "Did ${playerNames[p2Idx]} make ${b2 == 'BN' ? 'Blind Nil' : 'Nil'}?",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        value: n2Success,
                        onChanged: (val) {
                          setDialogState(() {
                            n2Success = val;
                            updateScore();
                          });
                        },
                      ),
                    ],
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
                        labelText: "Calculated Hand Score",
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
                    int finalNumericBid = 0;
                    if (b1 != 'N' && b1 != 'NIL' && b1 != 'BN') {
                      finalNumericBid += int.tryParse(b1) ?? 0;
                    }
                    if (b2 != 'N' && b2 != 'NIL' && b2 != 'BN') {
                      finalNumericBid += int.tryParse(b2) ?? 0;
                    }

                    if (isSet) {
                      rounds[roundIndex]['t${teamIndex + 1}Set'] = true;
                    } else {
                      rounds[roundIndex].remove('t${teamIndex + 1}Set');
                    }

                    rounds[roundIndex].remove('t${teamIndex + 1}Bags');

                    if (finalNumericBid == 10) {
                      rounds[roundIndex]['t${teamIndex + 1}TenForTwo'] = !isSet;
                    } else {
                      rounds[roundIndex].remove('t${teamIndex + 1}TenForTwo');
                    }

                    if (finalNumericBid == 13) {
                      rounds[roundIndex]['t${teamIndex + 1}ThirteenForFive'] =
                          !isSet;
                    } else {
                      rounds[roundIndex].remove(
                        't${teamIndex + 1}ThirteenForFive',
                      );
                    }

                    if (b1 == 'N' || b1 == 'NIL') {
                      rounds[roundIndex]['p${p1Idx + 1}NilSuccess'] = n1Success;
                      rounds[roundIndex].remove('p${p1Idx + 1}BlindNilSuccess');
                    } else if (b1 == 'BN') {
                      rounds[roundIndex]['p${p1Idx + 1}BlindNilSuccess'] =
                          n1Success;
                      rounds[roundIndex].remove('p${p1Idx + 1}NilSuccess');
                    } else {
                      rounds[roundIndex].remove('p${p1Idx + 1}NilSuccess');
                      rounds[roundIndex].remove('p${p1Idx + 1}BlindNilSuccess');
                    }

                    if (b2 == 'N' || b2 == 'NIL') {
                      rounds[roundIndex]['p${p2Idx + 1}NilSuccess'] = n2Success;
                      rounds[roundIndex].remove('p${p2Idx + 1}BlindNilSuccess');
                    } else if (b2 == 'BN') {
                      rounds[roundIndex]['p${p2Idx + 1}BlindNilSuccess'] =
                          n2Success;
                      rounds[roundIndex].remove('p${p2Idx + 1}NilSuccess');
                    } else {
                      rounds[roundIndex].remove('p${p2Idx + 1}NilSuccess');
                      rounds[roundIndex].remove('p${p2Idx + 1}BlindNilSuccess');
                    }

                    rounds[roundIndex]['t${teamIndex + 1}Hand'] =
                        overrideController.text;

                    recalculateTotals(rounds, 4);
                    onDataChanged();
                    Navigator.pop(context);

                    if (_isRoundComplete(rounds[roundIndex]) &&
                        !isRoundMathValid(rounds[roundIndex])) {
                      SleekNotificationBanner.show(
                        "Invalid Hand Scores",
                        "The total tricks don't add up to exactly 13. Please check your bags and sets. You cannot add a round until this is resolved.",
                        icon: Icons.calculate,
                        color: Colors.redAccent,
                      );
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
    double rndWidth = 40.0;
    double minCellWidth = 48.0;
    double minHandTotWidth = 55.0;
    double requiredWidth =
        rndWidth + (minCellWidth * 4) + (minHandTotWidth * 4);
    bool needsScroll = requiredWidth > constraints.maxWidth;
    double actualColWidth = needsScroll
        ? minCellWidth
        : (constraints.maxWidth - rndWidth - (minHandTotWidth * 4)) / 4;
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

    Map<int, TableColumnWidth> colWidths = {
      0: FixedColumnWidth(rndWidth),
      1: needsScroll
          ? FixedColumnWidth(minCellWidth)
          : const FlexColumnWidth(1),
      2: needsScroll
          ? FixedColumnWidth(minCellWidth)
          : const FlexColumnWidth(1),
      3: needsScroll
          ? FixedColumnWidth(minHandTotWidth)
          : const FlexColumnWidth(1.2),
      4: needsScroll
          ? FixedColumnWidth(minHandTotWidth)
          : const FlexColumnWidth(1.2),
      5: needsScroll
          ? FixedColumnWidth(minCellWidth)
          : const FlexColumnWidth(1),
      6: needsScroll
          ? FixedColumnWidth(minCellWidth)
          : const FlexColumnWidth(1),
      7: needsScroll
          ? FixedColumnWidth(minHandTotWidth)
          : const FlexColumnWidth(1.2),
      8: needsScroll
          ? FixedColumnWidth(minHandTotWidth)
          : const FlexColumnWidth(1.2),
    };

    List<TableRow> rows = [];
    rows.add(
      TableRow(
        children: [
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: _buildHeaderCell("RND", isCrowded),
          ),
          TableCell(
            verticalAlignment: isCrowded
                ? TableCellVerticalAlignment.bottom
                : TableCellVerticalAlignment.middle,
            child: _buildPlayerHeaderCell(0, isCrowded, playerNames),
          ),
          TableCell(
            verticalAlignment: isCrowded
                ? TableCellVerticalAlignment.bottom
                : TableCellVerticalAlignment.middle,
            child: _buildPlayerHeaderCell(1, isCrowded, playerNames),
          ),
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: _buildHeaderCell("T1 HND", isCrowded, isTeamTotal: true),
          ),
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.fill,
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: _buildHeaderCell("T1 TOT", isCrowded, isTeamTotal: true),
            ),
          ),
          TableCell(
            verticalAlignment: isCrowded
                ? TableCellVerticalAlignment.bottom
                : TableCellVerticalAlignment.middle,
            child: _buildPlayerHeaderCell(2, isCrowded, playerNames),
          ),
          TableCell(
            verticalAlignment: isCrowded
                ? TableCellVerticalAlignment.bottom
                : TableCellVerticalAlignment.middle,
            child: _buildPlayerHeaderCell(3, isCrowded, playerNames),
          ),
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: _buildHeaderCell("T2 HND", isCrowded, isTeamTotal: true),
          ),
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.fill,
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: _buildHeaderCell("T2 TOT", isCrowded, isTeamTotal: true),
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
            _buildBidCell(
              context,
              r,
              0,
              isCrowded,
              rounds,
              playerNames,
              isFinalized,
              onDataChanged,
              customSettings,
            ),
            _buildBidCell(
              context,
              r,
              1,
              isCrowded,
              rounds,
              playerNames,
              isFinalized,
              onDataChanged,
              customSettings,
            ),
            _buildHandCell(
              context,
              r,
              0,
              isCrowded,
              rounds,
              playerNames,
              isFinalized,
              onDataChanged,
            ),
            _buildTotalCell(
              rounds[r]['t1Total']?.toString() ?? "-",
              isBold: true,
              color: const Color(0xFF00A2FF),
              isCrowded: isCrowded,
            ),
            _buildBidCell(
              context,
              r,
              2,
              isCrowded,
              rounds,
              playerNames,
              isFinalized,
              onDataChanged,
              customSettings,
            ),
            _buildBidCell(
              context,
              r,
              3,
              isCrowded,
              rounds,
              playerNames,
              isFinalized,
              onDataChanged,
              customSettings,
            ),
            _buildHandCell(
              context,
              r,
              1,
              isCrowded,
              rounds,
              playerNames,
              isFinalized,
              onDataChanged,
            ),
            _buildTotalCell(
              rounds[r]['t2Total']?.toString() ?? "-",
              isBold: true,
              color: const Color(0xFF00A2FF),
              isCrowded: isCrowded,
            ),
          ],
        ),
      );
    }

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

  Widget _buildHeaderCell(
    String text,
    bool isCrowded, {
    bool isTeamTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 4.0),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isTeamTotal ? const Color(0xFF00A2FF) : Colors.white54,
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

  Widget _buildTotalCell(
    String text, {
    bool isBold = false,
    Color color = Colors.white,
    required bool isCrowded,
  }) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.fill,
      child: Container(
        color: Colors.black.withOpacity(0.3),
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
      ),
    );
  }

  // --- UPDATED: Re-wrapped the returned InkWell in _PulsingGlow if logic is met ---
  Widget _buildBidCell(
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
    final bid = rounds[roundIndex]['p${playerIndex + 1}Bid'];

    final bool isQuickBid = customSettings['quickBidEnabled'] == true;
    List<String> baseOrder = _getBiddingOrder(names, rounds);
    String expectedStartPlayer = baseOrder.isNotEmpty
        ? baseOrder[roundIndex % baseOrder.length]
        : "";

    bool shouldTriggerQuickBid = false;

    if (isQuickBid && !isFinalized && _isBidRoundEmpty(rounds[roundIndex])) {
      if (names[playerIndex] == expectedStartPlayer) {
        shouldTriggerQuickBid = true;
      }
    }

    Widget cellWidget = InkWell(
      onTap: isFinalized
          ? null
          : () {
              if (shouldTriggerQuickBid && names.length >= 4) {
                _showQuickBidDialog(
                  context,
                  roundIndex,
                  rounds,
                  names,
                  customSettings,
                  onChanged,
                );
              } else {
                _showBidDialog(
                  context,
                  roundIndex,
                  playerIndex,
                  rounds,
                  names,
                  onChanged,
                );
              }
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              bid != null && bid.toString().isNotEmpty ? "$bid" : "-",
              style: TextStyle(
                color: Colors.white,
                fontSize: _getDynamicFontSize(isCrowded) + 4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );

    if (shouldTriggerQuickBid) {
      return _PulsingGlow(color: const Color(0xFF00A2FF), child: cellWidget);
    }

    return cellWidget;
  }

  Widget _buildHandCell(
    BuildContext context,
    int roundIndex,
    int teamIndex,
    bool isCrowded,
    List<Map<String, dynamic>> rounds,
    List<String> names,
    bool isFinalized,
    VoidCallback onChanged,
  ) {
    final hand = rounds[roundIndex]['t${teamIndex + 1}Hand'];

    return InkWell(
      onTap: isFinalized
          ? null
          : () {
              int p1Idx = teamIndex == 0 ? 0 : 2;
              int p2Idx = teamIndex == 0 ? 1 : 3;
              String b1 =
                  rounds[roundIndex]['p${p1Idx + 1}Bid']?.toString().trim() ??
                  '';
              String b2 =
                  rounds[roundIndex]['p${p2Idx + 1}Bid']?.toString().trim() ??
                  '';

              if (b1.isEmpty || b2.isEmpty) {
                SleekNotificationBanner.show(
                  "Missing Bids",
                  "Please enter bids for both players before calculating the hand score.",
                  icon: Icons.warning_amber_rounded,
                  color: Colors.orangeAccent,
                );
                return;
              }
              _showTeamHandDialog(
                context,
                roundIndex,
                teamIndex,
                rounds,
                names,
                onChanged,
              );
            },
      child: Container(
        color: const Color(0xFF00A2FF).withOpacity(0.1),
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              hand != null && hand.toString().isNotEmpty ? "$hand" : "-",
              style: TextStyle(
                color: Colors.white,
                fontSize: _getDynamicFontSize(isCrowded) + 4,
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
