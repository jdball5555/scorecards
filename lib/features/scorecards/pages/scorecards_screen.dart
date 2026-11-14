import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/shared_widgets/glass_card.dart';
import '../providers/local_scorecard_provider.dart';
import '../templates/game_template.dart';
import 'scoring.dart';
import '../providers/scorecard_filter_provider.dart';
import 'scorecard_customize_screen.dart';
import 'scorecard_create.dart';
import 'package:scorecards_app/core/shared_widgets/top_bar_background.dart';

// --- UPGRADED: Non-Paginating StateNotifier for Client-Side Filtering ---
class CloudScorecardsNotifier
    extends StateNotifier<AsyncValue<List<LocalScorecard>>> {
  CloudScorecardsNotifier() : super(const AsyncValue.loading()) {
    loadInitial();
  }

  List<LocalScorecard> _allScorecards = [];
  List<Map<String, dynamic>> userGroups = [];

  Future<void> loadInitial() async {
    try {
      state = const AsyncValue.loading();

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        state = const AsyncValue.data([]);
        return;
      }

      // Prepare group chunks
      final groupsQuery = await FirebaseFirestore.instance
          .collection('game_groups')
          .where('members', arrayContains: user.uid)
          .get();

      userGroups = groupsQuery.docs.map((d) {
        final data = d.data();
        return <String, dynamic>{'id': d.id, ...data};
      }).toList();

      final groupIds = groupsQuery.docs.map((d) => d.id).toList();
      List<List<String>> groupChunks = [];
      for (var i = 0; i < groupIds.length; i += 10) {
        groupChunks.add(
          groupIds.sublist(
            i,
            i + 10 > groupIds.length ? groupIds.length : i + 10,
          ),
        );
      }

      List<LocalScorecard> newCards = [];

      // 1. Fetch Personal (All)
      final personalQ = await FirebaseFirestore.instance
          .collection('scorecards')
          .where('ownerType', isEqualTo: 'person')
          .where('ownerId', isEqualTo: user.uid)
          .get();

      for (var doc in personalQ.docs) {
        newCards.add(
          LocalScorecard.fromMap(doc.data() as Map<String, dynamic>),
        );
      }

      // 2. Fetch Group Chunks (All)
      for (int i = 0; i < groupChunks.length; i++) {
        final groupQ = await FirebaseFirestore.instance
            .collection('scorecards')
            .where('ownerType', isEqualTo: 'group')
            .where('ownerId', whereIn: groupChunks[i])
            .get();

        for (var doc in groupQ.docs) {
          newCards.add(
            LocalScorecard.fromMap(doc.data() as Map<String, dynamic>),
          );
        }
      }

      // Ensure uniqueness and sort globally by date
      final uniqueCards = <String, LocalScorecard>{};
      for (var c in newCards) {
        uniqueCards[c.id] = c;
      }

      _allScorecards = uniqueCards.values.toList();
      _allScorecards.sort((a, b) => b.createdDate.compareTo(a.createdDate));

      state = AsyncValue.data(_allScorecards);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void removeCardLocally(String id) {
    _allScorecards.removeWhere((c) => c.id == id);
    if (state.value != null) {
      state = AsyncValue.data(state.value!.where((c) => c.id != id).toList());
    }
  }
}

final cloudScorecardsProvider =
    StateNotifierProvider.autoDispose<
      CloudScorecardsNotifier,
      AsyncValue<List<LocalScorecard>>
    >((ref) {
      return CloudScorecardsNotifier();
    });

class ScorecardsScreen extends ConsumerStatefulWidget {
  const ScorecardsScreen({super.key});

  @override
  ConsumerState<ScorecardsScreen> createState() => _ScorecardsScreenState();
}

class _ScorecardsScreenState extends ConsumerState<ScorecardsScreen> {
  bool _isLoadingMore = false;
  int _visibleLimit = 20;

  // Strictly Date Only
  String _formatDateOnly(DateTime dt) {
    return "${dt.month}/${dt.day}/${dt.year}";
  }

  Future<void> _deleteScorecard(
    BuildContext context,
    WidgetRef ref,
    LocalScorecard card,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text(
              "Delete Scorecard?",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          "This action is permanent and will delete the scorecard for everyone. Are you sure?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "DELETE PERMANENTLY",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('scorecards')
            .doc(card.id)
            .delete();
      } catch (e) {
        debugPrint("Error deleting scorecard: $e");
      }
      ref.read(localScorecardsProvider.notifier).deleteScorecard(card.id);

      // Remove it smoothly from pagination list without forcing a full refresh
      ref.read(cloudScorecardsProvider.notifier).removeCardLocally(card.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filterState = ref.watch(scorecardFilterProvider);

    List<LocalScorecard> applyFilter(List<LocalScorecard> cards) {
      return cards.where((c) {
        if (filterState.scope != 'All') {
          if (filterState.scope == 'Personal' && c.ownerType != 'person') {
            return false;
          } else if (filterState.scope != 'Personal' &&
              c.ownerId != filterState.scope) {
            return false;
          }
        }
        if (filterState.gameType != null &&
            c.gameType != filterState.gameType) {
          return false;
        }
        if (filterState.timePeriod != 'All Time') {
          final now = DateTime.now();
          if (filterState.timePeriod.startsWith('Last ')) {
            final parts = filterState.timePeriod.split(' ');
            if (parts.length >= 3) {
              final num = int.tryParse(parts[1]) ?? 0;
              final unit = parts[2];
              if (unit == 'Days') {
                if (now.difference(c.createdDate).inDays > num) return false;
              } else if (unit == 'Months') {
                final diffMonths =
                    (now.year - c.createdDate.year) * 12 +
                    now.month -
                    c.createdDate.month;
                if (diffMonths > num) return false;
              } else if (unit == 'Years') {
                if (now.year - c.createdDate.year > num) return false;
              }
            }
          } else if (filterState.timePeriod == 'This Year') {
            if (c.createdDate.year != now.year) return false;
          }
        }
        return true;
      }).toList();
    }

    final localCardsRaw = ref
        .watch(localScorecardsProvider)
        .where((c) => !c.isSynced)
        .toList();
    final localCards = applyFilter(localCardsRaw);

    final cloudCardsAsync = ref.watch(cloudScorecardsProvider);
    final filteredCloudCardsAsync = cloudCardsAsync.whenData(
      (cards) => applyFilter(cards),
    );

    final Set<String> playedGames = {};
    if (cloudCardsAsync.hasValue && cloudCardsAsync.value != null) {
      for (var card in cloudCardsAsync.value!) {
        playedGames.add(card.gameType);
      }
    }
    for (var card in localCardsRaw) {
      playedGames.add(card.gameType);
    }
    final availableGameTypes = playedGames.toList()..sort();

    int totalScorecards =
        localCards.length + (filteredCloudCardsAsync.value?.length ?? 0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const Text(
          "Scorecards",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white70),
            tooltip: 'Customize Scorecards',
            onPressed: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  // Opaque so the page underneath isn't painted through this one
                  // (on the website, the shared background shows instead).
                  opaque: true,
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      ScorecardCustomizeScreen(
                        availableGameTypes: availableGameTypes,
                        userGroups: ref
                            .read(cloudScorecardsProvider.notifier)
                            .userGroups,
                      ),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return child;
                      },
                  transitionDuration: Duration.zero,
                  reverseTransitionDuration: Duration.zero,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        flexibleSpace: const TopBarBackground(),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    // Opaque so the page underneath isn't painted through this one
                    // (on the website, the shared background shows instead).
                    opaque: true,
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        ScorecardCustomizeScreen(
                          availableGameTypes: availableGameTypes,
                          userGroups: ref
                              .read(cloudScorecardsProvider.notifier)
                              .userGroups,
                        ),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                          return child;
                        },
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Consumer(
                  builder: (context, ref, child) {
                    final userGroups = ref
                        .read(cloudScorecardsProvider.notifier)
                        .userGroups;
                    String scopeDisplay = "";
                    if (filterState.scope == 'Personal') {
                      scopeDisplay = "Personal Only  •  ";
                    } else if (filterState.scope != 'All') {
                      final match = userGroups.where(
                        (g) => g['id'] == filterState.scope,
                      );
                      if (match.isNotEmpty) {
                        scopeDisplay = "${match.first['name']}  •  ";
                      }
                    }
                    return Text(
                      "$scopeDisplay${filterState.gameType ?? 'All Games'}  •  ${filterState.timePeriod}  •  $totalScorecards Scorecard${totalScorecards == 1 ? '' : 's'}",
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
      body: (cloudCardsAsync.isLoading && !cloudCardsAsync.hasValue)
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00A2FF)),
            )
          : RefreshIndicator(
              edgeOffset:
                  MediaQuery.of(context).padding.top + kToolbarHeight + 40,
              color: const Color(0xFF00A2FF),
              backgroundColor: const Color(0xFF1E1E1E),
              onRefresh: () async {
                setState(() => _visibleLimit = 20);
                return ref.refresh(cloudScorecardsProvider);
              },
              child: ListView(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + kToolbarHeight + 60,
                  left: 20,
                  right: 20,
                  bottom: 20,
                ),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
                children: [
                  // --- 1. LOCAL DRAFTS ---
                  if (localCards.isNotEmpty) ...[
                    Text(
                      "LOCAL DRAFTS",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _TileGrid(
                      children: [
                        for (final card in localCards)
                          _buildScorecardTile(context, ref, card),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  filteredCloudCardsAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (err, stack) {
                      // This prints the exact error (and the Firebase link) to your debug console!
                      debugPrint("CLOUD SCORECARDS ERROR: $err");

                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          "Database Error:\n$err",
                          style: TextStyle(
                            color: Colors.redAccent.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                    data: (cloudCards) {
                      if (cloudCards.isEmpty && localCards.isEmpty) {
                        return const _EmptyScorecards();
                      }

                      final visibleCloudCards = cloudCards
                          .take(_visibleLimit)
                          .toList();
                      final bool hasMoreLocally =
                          cloudCards.length > _visibleLimit;

                      // Filter into Active and Submitted
                      final activeCloudCards = visibleCloudCards
                          .where((c) => !c.isFinalized)
                          .toList();
                      final submittedCloudCards = visibleCloudCards
                          .where((c) => c.isFinalized)
                          .toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- 2. ACTIVE / UNSUBMITTED CLOUD CARDS ---
                          if (activeCloudCards.isNotEmpty) ...[
                            Text(
                              "ACTIVE SCORECARDS",
                              style: TextStyle(
                                color: const Color(0xFF00A2FF).withOpacity(0.8),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _TileGrid(
                              children: [
                                for (final card in activeCloudCards)
                                  _buildScorecardTile(context, ref, card),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],

                          // --- 3. SUBMITTED CLOUD CARDS ---
                          if (submittedCloudCards.isNotEmpty) ...[
                            Text(
                              "SUBMITTED SCORECARDS",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _TileGrid(
                              children: [
                                for (final card in submittedCloudCards)
                                  _buildScorecardTile(context, ref, card),
                              ],
                            ),
                          ],

                          if (hasMoreLocally)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 24.0,
                              ),
                              child: Center(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(
                                      0.1,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.expand_more_rounded,
                                    color: Colors.white70,
                                  ),
                                  label: const Text(
                                    "Load More",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _visibleLimit += 20;
                                    });
                                  },
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }

  Widget _buildScorecardTile(
    BuildContext context,
    WidgetRef ref,
    LocalScorecard card,
  ) {
    bool isFinalized = false;
    List<String> playerNames = [];
    List<dynamic> rounds = [];

    isFinalized = card.isFinalized;
    playerNames = List<String>.from(card.playerNames);
    rounds = List<dynamic>.from(card.rounds);

    final String gameType = card.gameType.toLowerCase();
    List<Map<String, String>> entities = [];

    if (gameType == 'spades') {
      int t1Tot = 0;
      int t2Tot = 0;
      if (rounds.isNotEmpty) {
        t1Tot = int.tryParse(rounds.last['t1Total']?.toString() ?? '0') ?? 0;
        t2Tot = int.tryParse(rounds.last['t2Total']?.toString() ?? '0') ?? 0;
      }
      String t1Name = playerNames.length >= 2
          ? "${playerNames[0]} & ${playerNames[1]}"
          : "Team 1";
      String t2Name = playerNames.length >= 4
          ? "${playerNames[2]} & ${playerNames[3]}"
          : "Team 2";
      entities.add({'name': t1Name, 'score': t1Tot.toString()});
      entities.add({'name': t2Name, 'score': t2Tot.toString()});
    } else if (gameType == 'wavelength') {
      int teams = playerNames.length ~/ 2;
      List<int> totals = List.filled(teams, 0);
      for (var rnd in rounds) {
        for (int t = 0; t < teams; t++) {
          totals[t] +=
              int.tryParse(rnd['t${t + 1}Score']?.toString() ?? '') ?? 0;
        }
      }
      for (int t = 0; t < teams; t++) {
        int p1Idx = t * 2;
        int p2Idx = t * 2 + 1;
        String teamName = "";
        if (p2Idx < playerNames.length) {
          teamName = "${playerNames[p1Idx]} & ${playerNames[p2Idx]}";
        } else {
          teamName = playerNames[p1Idx];
        }
        entities.add({'name': teamName, 'score': totals[t].toString()});
      }
    } else if (gameType == 'yahtzee') {
      List<String> upperCats = [
        'Aces',
        'Twos',
        'Threes',
        'Fours',
        'Fives',
        'Sixes',
      ];
      for (int i = 0; i < playerNames.length; i++) {
        int upper = 0;
        int lower = 0;
        int yBonus = 0;
        for (var r in rounds) {
          String? cat = r['p${i + 1}Category'] ?? r['category'];
          int score = int.tryParse(r['p${i + 1}Score']?.toString() ?? '') ?? 0;
          if (cat != null && cat != 'YAHTZEE BONUS') {
            if (upperCats.contains(cat)) {
              upper += score;
            } else {
              lower += score;
            }
          }
          var yb = r['p${i + 1}YahtzeeBonus'];
          if (yb == true || yb == 'true') {
            yBonus += 100;
          } else if (yb != null) {
            yBonus += int.tryParse(yb.toString()) ?? 0;
          }
          if (cat == 'YAHTZEE BONUS') {
            yBonus += int.tryParse(r['p${i + 1}Score']?.toString() ?? '0') ?? 0;
          }
        }
        int bonus = upper >= 63 ? 35 : 0;
        int tot = upper + lower + bonus + yBonus;
        entities.add({'name': playerNames[i], 'score': tot.toString()});
      }
    } else if (gameType == 'poker') {
      for (int i = 0; i < playerNames.length; i++) {
        int net = 0;
        if (rounds.isNotEmpty) {
          net =
              int.tryParse(rounds.last['p${i + 1}Total']?.toString() ?? '0') ??
              0;
        }
        String scoreStr = net > 0 ? "+$net" : net.toString();
        entities.add({'name': playerNames[i], 'score': scoreStr});
      }
    } else {
      for (int i = 0; i < playerNames.length; i++) {
        int tot = 0;
        for (var rnd in rounds) {
          tot += int.tryParse(rnd['p${i + 1}Score']?.toString() ?? '') ?? 0;
        }
        entities.add({'name': playerNames[i], 'score': tot.toString()});
      }
    }

    if ((entities.isEmpty || entities.every((e) => e['score'] == '0')) &&
        card.summaryTotals.isNotEmpty) {
      entities = card.summaryTotals
          .map<Map<String, String>>(
            (e) => <String, String>{
              'name': e['name']?.toString() ?? 'Unknown',
              'score': e['score']?.toString() ?? '0',
            },
          )
          .toList();
    }

    if (entities.isEmpty) {
      entities.add({'name': 'Player 1', 'score': '0'});
    }

    Widget scoresWidget;
    if (entities.length == 1) {
      scoresWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entities[0]['name']!,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            entities[0]['score']!,
            style: const TextStyle(
              color: Color(0xFF00A2FF),
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );
    } else if (entities.length == 2) {
      scoresWidget = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entities[0]['name']!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  entities[0]['score']!,
                  style: const TextStyle(
                    color: Color(0xFF00A2FF),
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "VS",
              style: TextStyle(
                color: Colors.white.withOpacity(0.15),
                fontSize: 16,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  entities[1]['name']!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 4),
                Text(
                  entities[1]['score']!,
                  style: const TextStyle(
                    color: Color(0xFF00A2FF),
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      List<Widget> children = [];
      for (int i = 0; i < entities.length; i++) {
        children.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                entities[i]['name']!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                entities[i]['score']!,
                style: const TextStyle(
                  color: Color(0xFF00A2FF),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );

        if (i < entities.length - 1) {
          children.add(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "VS",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.15),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          );
        }
      }

      scoresWidget = LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: children,
              ),
            ),
          );
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: GestureDetector(
        onLongPress: () => _deleteScorecard(context, ref, card),
        child: GlassCard(
          accentColor: const Color(0xFF00A2FF),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ScoringScreen(
                  gameType: card.gameType,
                  ownerType: card.ownerType,
                  ownerId: card.ownerId,
                  groupName: card.groupName,
                  existingCard: card,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 20.0,
              bottom: 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              card.gameType.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                letterSpacing: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (TemplateFactory.isOfficialTemplate(
                            card.gameType,
                          )) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified,
                              color: Color(0xFF00A2FF),
                              size: 18,
                            ),
                          ],
                          if (card.isLive && !isFinalized) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.redAccent,
                                  width: 1,
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.sensors,
                                    color: Colors.redAccent,
                                    size: 12,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    "LIVE",
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Checked = Blue, Edit = Purple
                    Icon(
                      isFinalized
                          ? Icons.check_circle_rounded
                          : Icons.edit_document,
                      color: isFinalized
                          ? const Color(0xFF00A2FF)
                          : const Color(0xFF7855C1),
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    // Cloud Done = Blue, Cloud Off = Purple
                    Icon(
                      card.isSynced
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_off_rounded,
                      color: card.isSynced
                          ? const Color(0xFF00A2FF)
                          : const Color(0xFF7855C1),
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                Row(
                  children: [
                    if (card.ownerType == 'group' &&
                        card.groupName != null) ...[
                      Flexible(
                        child: Text(
                          card.groupName!.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF00A2FF),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "•",
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      _formatDateOnly(card.createdDate), // Strictly Date Only
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Divider(color: Colors.white12, height: 1),
                ),

                scoresWidget,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyScorecards extends StatelessWidget {
  const _EmptyScorecards();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          Icon(
            Icons.style_outlined,
            size: 56,
            color: Colors.white.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 16),
          const Text(
            "No scorecards yet",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Games you score show up here, ready to sync with your groups.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A2FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const ScorecardCreateDialog(),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text(
              "START SCORING",
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lays scorecard tiles out in as many columns as fit (one on phones).
class _TileGrid extends StatelessWidget {
  final List<Widget> children;
  const _TileGrid({required this.children});

  static const double _minTileWidth = 360;
  static const double _gap = 16;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = ((c.maxWidth + _gap) ~/ (_minTileWidth + _gap)).clamp(
          1,
          4,
        );
        if (cols == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );
        }
        final w = (c.maxWidth - _gap * (cols - 1)) / cols;
        return Wrap(
          spacing: _gap,
          children: [for (final t in children) SizedBox(width: w, child: t)],
        );
      },
    );
  }
}
