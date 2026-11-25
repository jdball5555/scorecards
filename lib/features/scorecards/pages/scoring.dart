import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/shared_widgets/glass_card.dart';
import '../../../core/shared_widgets/gradient_background.dart';
import '../../../core/shared_widgets/sleek_notification_banner.dart';
import '../providers/local_scorecard_provider.dart';
import '../templates/game_template.dart';
import '../templates/spades_template.dart';
import '../../metrics/pages/metrics_screen.dart';
import '../../../services/group_service.dart';
import 'scoring_customize_screen.dart';
import 'split_screen.dart';
import 'package:scorecards_app/core/shared_widgets/top_bar_background.dart';

class ScoringScreen extends ConsumerStatefulWidget {
  final String gameType;
  final String ownerType;
  final String ownerId;
  final String? groupName;
  final LocalScorecard? existingCard;
  final String? customId;

  const ScoringScreen({
    super.key,
    required this.gameType,
    required this.ownerType,
    required this.ownerId,
    this.groupName,
    this.existingCard,
    this.customId,
  });

  @override
  ConsumerState<ScoringScreen> createState() => _ScoringScreenState();
}

class _ScoringScreenState extends ConsumerState<ScoringScreen> {
  late DateTime _createdDate;
  late DateTime _lastUpdatedDate;

  List<String> _playerNames = [];
  List<String> _playerIds = [];
  List<Map<String, dynamic>> _rounds = [];
  Map<String, dynamic> _customSettings = {}; // ADDED to hold root rules

  bool _isSynced = false;
  bool _isUploading = false;
  bool _isFinalized = false;
  bool _isLive = false;
  bool _isViewingMode = false;

  final GroupService _groupService = GroupService();
  final Map<String, Map<String, dynamic>> _userCache = {};
  final User? currentUser = FirebaseAuth.instance.currentUser;
  late GameTemplate _template;

  bool _splitScreenEnabled = false;
  bool _swapPanes = false;
  bool _quickBidEnabled = true;
  bool _quickInfoEnabled = false;
  bool _showHowToScore = true;
  bool _pokerNetColumn = false;
  Offset? _quickInfoOffset;

  final GlobalKey<NavigatorState> _scoringNavKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _metricsNavKey = GlobalKey<NavigatorState>();

  final Color primaryBlue = const Color(0xFF00A2FF);
  final Color customPurple = const Color(0xFF7855C1);

  @override
  void initState() {
    super.initState();
    _template = TemplateFactory.getTemplate(widget.gameType);

    final card = widget.existingCard;
    _createdDate = card?.createdDate ?? DateTime.now();
    _lastUpdatedDate = card?.lastUpdatedDate ?? DateTime.now();
    _isSynced = card?.isSynced ?? false;
    _isFinalized = card?.isFinalized ?? false;
    _isLive = card?.isLive ?? false;

    if (card != null) {
      if (_isFinalized) {
        _isViewingMode = true;
      } else if (_isLive) {
        _isViewingMode = true;
      }
    }

    if (card != null) {
      _playerNames = List.from(card.playerNames);
      _playerIds = List.from(card.playerIds);
      _rounds = List.from(card.rounds.map((r) => Map<String, dynamic>.from(r)));
      _customSettings = Map<String, dynamic>.from(
        card.customSettings,
      ); // PULLS SETTINGS
    } else {
      _playerNames = _template.generateInitialPlayerNames();
      _playerIds = List<String>.filled(_playerNames.length, '', growable: true);
      _rounds = [_template.createNewRound(1, _playerNames.length)];
      if (widget.gameType.toLowerCase() == 'poker') {
        int defaultBuyIn = 2;
        try {
          final localCards = ref.read(localScorecardsProvider);
          final pokerCards = localCards
              .where((c) => c.gameType.toLowerCase() == 'poker')
              .toList();
          if (pokerCards.isNotEmpty) {
            pokerCards.sort((a, b) => a.createdDate.compareTo(b.createdDate));
            final lastCard = pokerCards.last;
            if (lastCard.rounds.isNotEmpty) {
              defaultBuyIn =
                  int.tryParse(
                    lastCard.rounds.last['buyIn']?.toString() ?? '2',
                  ) ??
                  2;
            }
          }
        } catch (e) {
          debugPrint("Error fetching default buy in: $e");
        }
        _rounds[0]['buyIn'] = defaultBuyIn;
      }
    }
  }

  Future<void> _openCustomizeScreen() async {
    final bool isSplit = _splitScreenEnabled;

    final String currentScorecardId =
        widget.existingCard?.id ?? widget.customId ?? 'Unknown ID';

    final navigator = isSplit
        ? (_scoringNavKey.currentState ?? Navigator.of(context))
        : Navigator.of(context);

    final route = isSplit
        ? PageRouteBuilder<Map<String, dynamic>>(
            opaque: false,
            pageBuilder: (ctx, animation, secondaryAnimation) =>
                ScoringCustomizeScreen(
                  gameType: widget.gameType,
                  scorecardId: currentScorecardId,
                  playerNames: _playerNames,
                  rounds: _rounds,
                  initialIsLive: _isLive,
                  initialSplitScreen: _splitScreenEnabled,
                  initialSwapPanes: _swapPanes,
                  initialQuickBid: _quickBidEnabled,
                  isEmbedded: true,
                  initialQuickInfo: _quickInfoEnabled,
                  isViewingMode: _isViewingMode,
                  initialShowHowToScore: _showHowToScore,
                  initialPokerNetColumn: _pokerNetColumn,
                ),
            transitionsBuilder:
                (transitionCtx, animation, secondaryAnimation, child) {
                  const begin = Offset(1.0, 0.0);
                  const end = Offset.zero;
                  const curve = Curves.easeOutCubic;
                  final tween = Tween(
                    begin: begin,
                    end: end,
                  ).chain(CurveTween(curve: curve));
                  return SlideTransition(
                    position: animation.drive(tween),
                    child: child,
                  );
                },
          )
        : MaterialPageRoute<Map<String, dynamic>>(
            builder: (ctx) => ScoringCustomizeScreen(
              gameType: widget.gameType,
              scorecardId: currentScorecardId,
              playerNames: _playerNames,
              rounds: _rounds,
              initialIsLive: _isLive,
              initialSplitScreen: _splitScreenEnabled,
              initialSwapPanes: _swapPanes,
              initialQuickBid: _quickBidEnabled,
              isEmbedded: false,
              initialQuickInfo: _quickInfoEnabled,
              isViewingMode: _isViewingMode,
              initialShowHowToScore: _showHowToScore,
              initialPokerNetColumn: _pokerNetColumn,
            ),
          );

    final result = await navigator.push<Map<String, dynamic>>(route);

    if (result != null) {
      if (!mounted) return;

      final bool newlyLive = result['isLive'] ?? false;
      final bool shouldUpload = newlyLive != _isLive;
      final bool reopen = result['reopen'] ?? false;

      setState(() {
        _isLive = newlyLive;
        _splitScreenEnabled = result['splitScreenEnabled'] ?? false;
        _swapPanes = result['swapPanes'] ?? false;
        _quickBidEnabled = result['quickBidEnabled'] ?? false;
        _quickInfoEnabled = result['quickInfoEnabled'] ?? _quickInfoEnabled;
        _showHowToScore = result['showHowToScore'] ?? _showHowToScore;
        _pokerNetColumn = result['pokerNetColumn'] ?? _pokerNetColumn;
      });

      if (shouldUpload) {
        _uploadToCloud(silent: true);
      }

      if (reopen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openCustomizeScreen();
        });
      }
    }
  }

  Future<void> _handlePop(bool didPop) async {
    if (didPop) return;

    if (_splitScreenEnabled) {
      if (_scoringNavKey.currentState?.canPop() ?? false) {
        _scoringNavKey.currentState!.pop();
        return;
      }
      if (_metricsNavKey.currentState?.canPop() ?? false) {
        _metricsNavKey.currentState!.pop();
        return;
      }
    }

    if (_isLive && !_isViewingMode) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "End Live Scorecard?",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Leaving this page will end the live scorecard session. Continue?",
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                "End Live & Leave",
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
        setState(() {
          _isLive = false;
          _splitScreenEnabled = false;
        });
        await _uploadToCloud(silent: true);
        _saveData();
        if (mounted) Navigator.pop(context);
      }
    } else {
      _saveData();
      Navigator.pop(context);
    }
  }

  void _onTemplateDataChanged() {
    // Pass custom settings into recalculateTotals so it knows exactly100bonus is true
    _template.recalculateTotals(
      _rounds,
      _playerNames.length,
      customSettings: _customSettings,
    );
    // Let template auto-manage rounds (e.g. custom scorecards)
    bool roundsChanged = _template.onDataUpdated(
      _rounds,
      _playerNames.length,
      customSettings: _customSettings,
    );
    if (roundsChanged) {
      _template.recalculateTotals(
        _rounds,
        _playerNames.length,
        customSettings: _customSettings,
      );
    }
    setState(() => _isSynced = false);
    _saveData();
    if (_isLive && !_isFinalized) {
      _uploadToCloud(silent: true);
    }
  }

  Future<void> _finishGame() async {
    if (widget.customId == 'test_mode') {
      Navigator.pop(context);
      return;
    }

    if (_isViewingMode && _isFinalized) {
      _uploadToCloud(silent: true);
    }
  }

  Future<void> _uploadToCloud({bool silent = false}) async {
    if (widget.customId == 'test_mode') return; // Do not upload test mode data
    if (currentUser == null) return;
    if (mounted) setState(() => _isUploading = true);

    try {
      final scorecardId =
          widget.existingCard?.id ??
          widget.customId ??
          DateTime.now().millisecondsSinceEpoch.toString();

      final docData = {
        'id': scorecardId,
        'ownerType': widget.ownerType,
        'ownerId': widget.ownerId,
        'gameType': widget.gameType,
        'groupName': widget.groupName,
        'createdDate': Timestamp.fromDate(_createdDate),
        'lastUpdatedDate': Timestamp.fromDate(DateTime.now()),
        'playerNames': _playerNames,
        'playerIds': _playerIds,
        'rounds': _rounds,
        'isFinalized': _isFinalized,
        'isLive': _isLive,
        'submittedBy': currentUser?.uid,
        'customSettings': _customSettings, // ADDED: Uploads rule to Firebase
      };

      await FirebaseFirestore.instance
          .collection('scorecards')
          .doc(scorecardId)
          .set(docData);

      if (mounted) {
        setState(() {
          _isSynced = true;
          _lastUpdatedDate = DateTime.now();
        });
      }
      _saveData();

      if (!silent) {
        SleekNotificationBanner.show(
          "Uploaded to Cloud",
          "Your scorecard has been securely saved.",
          icon: Icons.cloud_done_rounded,
          color: Colors.green,
        );
      }
    } catch (e) {
      if (!silent) {
        SleekNotificationBanner.show(
          "Upload Failed",
          "Please check your connection and try again.",
          icon: Icons.error_outline,
          color: Colors.redAccent,
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _saveData() async {
    if (widget.customId == 'test_mode') return; // Do not save test mode data

    final scorecard = LocalScorecard(
      id:
          widget.existingCard?.id ??
          widget.customId ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      gameType: widget.gameType,
      groupName: widget.groupName,
      ownerType: widget.ownerType,
      ownerId: widget.ownerId,
      createdDate: _createdDate,
      lastUpdatedDate: DateTime.now(),
      playerNames: List.from(_playerNames),
      playerIds: List.from(_playerIds),
      rounds: List.from(_rounds.map((r) => Map<String, dynamic>.from(r))),
      isSynced: _isSynced,
      isFinalized: _isFinalized,
      isLive: _isLive,
      customSettings: Map<String, dynamic>.from(
        _customSettings,
      ), // ADDED: Saves locally
    );
    ref.read(localScorecardsProvider.notifier).saveScorecard(scorecard);
  }

  String _getFormattedDate() {
    return "${_createdDate.month}/${_createdDate.day}/${_createdDate.year}";
  }

  bool _isRoundEmpty(Map<String, dynamic> round) {
    for (var entry in round.entries) {
      if (entry.key == 'roundNum') continue;
      if (entry.key == 'id') continue;
      // Custom scorecards store derived running totals / raw dialog inputs.
      if (entry.key.endsWith('_Total')) continue;
      if (entry.key.endsWith('_Raw')) continue;
      if (entry.key == 'category') continue;
      if (entry.key == 'currentYahtzeeRound') continue;
      if (entry.key == 'roundFinalized') continue;
      if (entry.key.endsWith('Category')) continue;
      if (entry.key.endsWith('YahtzeeBonus')) continue;
      if (entry.value != null && entry.value.toString().trim().isNotEmpty) {
        return false;
      }
    }
    return true;
  }

  void _handleFinalizeGame() {
    // For auto-managed templates, strip trailing empty round before checking
    if (_template.autoManagesRounds && _rounds.length > 1) {
      if (_isRoundEmpty(_rounds.last)) {
        _rounds.removeLast();
      }
    }

    if (!_template.isReadyToFinalize(
      _rounds,
      _playerNames.length,
      customSettings: _customSettings,
    )) {
      if (_template is SpadesTemplate && _rounds.isNotEmpty) {
        final spades = _template as SpadesTemplate;
        bool hasInvalidMath = _rounds.any((r) => !spades.isRoundMathValid(r));
        if (hasInvalidMath) {
          SleekNotificationBanner.show(
            "Invalid Hand Scores",
            "One or more rounds have tricks that don't add up to exactly 13. Please fix them before finalizing.",
            icon: Icons.calculate,
            color: Colors.redAccent,
          );
          return;
        }
      }

      SleekNotificationBanner.show(
        "Incomplete Game",
        "All active rounds and cells must be completely filled out before finalizing the game.",
        icon: Icons.warning_amber_rounded,
        color: Colors.orangeAccent,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Finalize Game",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _template.getWinnerDeclaration(
                _playerNames,
                _rounds,
                customSettings: _customSettings,
              ),
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text(
              "This will be permanently updated to the cloud. You will be unable to alter the score after it is finalized.",
              style: TextStyle(
                color: customPurple,
                fontSize: 12,
                fontWeight: FontWeight.bold,
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: customPurple),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _isFinalized = true;
                _isViewingMode = true;
                _isSynced = false;
              });
              _uploadToCloud();
            },
            child: const Text(
              "FINALIZE",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInfoTile(
    BuildContext context,
    double initialTop,
    BoxConstraints paneConstraints,
  ) {
    bool isSpades = widget.gameType.toLowerCase() == 'spades';
    bool isWavelength = widget.gameType.toLowerCase() == 'wavelength';
    bool isPoker = widget.gameType.toLowerCase() == 'poker';
    Widget content;

    if (isSpades && _rounds.isNotEmpty) {
      var r = _rounds.last;
      bool b1 = r['p1Bid']?.toString().isNotEmpty == true;
      bool b2 = r['p2Bid']?.toString().isNotEmpty == true;
      bool b3 = r['p3Bid']?.toString().isNotEmpty == true;
      bool b4 = r['p4Bid']?.toString().isNotEmpty == true;
      bool biddingComplete = b1 && b2 && b3 && b4;

      int t1Tot = 0;
      int t2Tot = 0;
      for (var rnd in _rounds) {
        if (rnd['t1Total'] != null) {
          t1Tot = int.tryParse(rnd['t1Total'].toString()) ?? t1Tot;
        }
        if (rnd['t2Total'] != null) {
          t2Tot = int.tryParse(rnd['t2Total'].toString()) ?? t2Tot;
        }
      }

      int t1Bid = 0;
      String p1b = (r['p1Bid']?.toString() ?? '').toUpperCase();
      if (p1b != 'N' && p1b != 'NIL' && p1b != 'BN') {
        t1Bid += int.tryParse(p1b) ?? 0;
      }

      String p2b = (r['p2Bid']?.toString() ?? '').toUpperCase();
      if (p2b != 'N' && p2b != 'NIL' && p2b != 'BN') {
        t1Bid += int.tryParse(p2b) ?? 0;
      }

      int t2Bid = 0;
      String p3b = (r['p3Bid']?.toString() ?? '').toUpperCase();
      if (p3b != 'N' && p3b != 'NIL' && p3b != 'BN') {
        t2Bid += int.tryParse(p3b) ?? 0;
      }

      String p4b = (r['p4Bid']?.toString() ?? '').toUpperCase();
      if (p4b != 'N' && p4b != 'NIL' && p4b != 'BN') {
        t2Bid += int.tryParse(p4b) ?? 0;
      }

      content = IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${_playerNames[0]} & ${_playerNames[1]}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
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
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (biddingComplete)
                    Text(
                      "Bid: $t1Bid",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    Column(
                      children: [
                        Text(
                          "${_playerNames[0]}: ${r['p1Bid']?.toString().isEmpty == false ? r['p1Bid'] : '-'}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "${_playerNames[1]}: ${r['p2Bid']?.toString().isEmpty == false ? r['p2Bid'] : '-'}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const VerticalDivider(
              color: Colors.white24,
              thickness: 1,
              width: 24,
            ),
            SizedBox(
              width: 150,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${_playerNames[2]} & ${_playerNames[3]}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
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
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (biddingComplete)
                    Text(
                      "Bid: $t2Bid",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    Column(
                      children: [
                        Text(
                          "${_playerNames[2]}: ${r['p3Bid']?.toString().isEmpty == false ? r['p3Bid'] : '-'}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "${_playerNames[3]}: ${r['p4Bid']?.toString().isEmpty == false ? r['p4Bid'] : '-'}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (isWavelength) {
      int teams = _playerNames.length ~/ 2;
      List<int> totals = List.filled(teams, 0);
      for (var rnd in _rounds) {
        for (int t = 0; t < teams; t++) {
          totals[t] +=
              int.tryParse(rnd['t${t + 1}Score']?.toString() ?? '') ?? 0;
        }
      }

      List<Widget> teamWidgets = [];
      for (int t = 0; t < teams; t++) {
        int p1Idx = t * 2;
        int p2Idx = t * 2 + 1;
        String teamName = "";
        if (p2Idx < _playerNames.length) {
          teamName = "${_playerNames[p1Idx]} & ${_playerNames[p2Idx]}";
        } else {
          teamName = _playerNames[p1Idx];
        }

        teamWidgets.add(
          SizedBox(
            width: teams == 1 ? 200 : 150,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  teamName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  "${totals[t]}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        );

        if (t < teams - 1) {
          teamWidgets.add(
            const VerticalDivider(
              color: Colors.white24,
              thickness: 1,
              width: 24,
            ),
          );
        }
      }

      content = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: teamWidgets,
          ),
        ),
      );
    } else if (isPoker) {
      List<Widget> scores = [];
      for (int i = 0; i < _playerNames.length; i++) {
        int net = 0;
        if (_rounds.isNotEmpty) {
          net =
              int.tryParse(_rounds.last['p${i + 1}Total']?.toString() ?? '0') ??
              0;
        }
        String netStr = net > 0 ? "+$net" : net.toString();
        Color netColor = net > 0
            ? Colors.greenAccent
            : (net < 0 ? Colors.redAccent : Colors.white);
        scores.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${_playerNames[i]}:",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  netStr,
                  style: TextStyle(
                    color: netColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "NET PROFIT / LOSS",
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          ...scores,
        ],
      );
    } else {
      List<Widget> scores = [];
      for (int i = 0; i < _playerNames.length; i++) {
        int tot = 0;
        if (widget.gameType.toLowerCase() == 'yahtzee') {
          List<String> upperCats = [
            'Aces',
            'Twos',
            'Threes',
            'Fours',
            'Fives',
            'Sixes',
          ];
          int upper = 0;
          int lower = 0;
          for (var r in _rounds) {
            String? cat = r['p${i + 1}Category'] ?? r['category'];
            int score =
                int.tryParse(r['p${i + 1}Score']?.toString() ?? '') ?? 0;
            if (cat != null && cat != 'YAHTZEE BONUS') {
              if (upperCats.contains(cat)) {
                upper += score;
              } else {
                lower += score;
              }
            }
          }
          int bonus = upper >= 63 ? 35 : 0;
          int yBonus = 0;
          for (var r in _rounds) {
            var yb = r['p${i + 1}YahtzeeBonus'];
            if (yb == true) {
              yBonus += 100;
            } else if (yb != null) {
              yBonus += int.tryParse(yb.toString()) ?? 0;
            }
            var cat = r['category'] ?? r['p${i + 1}Category'];
            if (cat == 'YAHTZEE BONUS') {
              yBonus +=
                  int.tryParse(r['p${i + 1}Score']?.toString() ?? '0') ?? 0;
            }
          }
          tot = upper + lower + bonus + yBonus;
        } else {
          for (var rnd in _rounds) {
            tot += int.tryParse(rnd['p${i + 1}Score']?.toString() ?? '') ?? 0;
          }
        }
        scores.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${_playerNames[i]}:",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  "$tot",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "SCORES",
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          ...scores,
        ],
      );
    }

    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          double currentX = _quickInfoOffset?.dx ?? 20;
          double currentY = _quickInfoOffset?.dy ?? initialTop;

          final maxDx = paneConstraints.maxWidth - 370;
          final maxDy = paneConstraints.maxHeight - 180;
          double newX = (currentX + details.delta.dx).clamp(
            0.0,
            maxDx < 0 ? 0.0 : maxDx,
          );
          double newY = (currentY + details.delta.dy).clamp(
            0.0,
            maxDy < 0 ? 0.0 : maxDy,
          );

          _quickInfoOffset = Offset(newX, newY);
        });
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(24),
          ),
          child: GlassCard(
            accentColor: customPurple,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainScoringUI(BuildContext context) {
    Widget scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Scorecard",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontSize: 24,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _isViewingMode
                    ? Colors.white.withOpacity(0.1)
                    : customPurple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _isViewingMode ? Colors.white38 : customPurple,
                  width: 1,
                ),
              ),
              child: Text(
                _isViewingMode ? "VIEWING" : "EDITING",
                style: TextStyle(
                  color: _isViewingMode ? Colors.white70 : customPurple,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
        flexibleSpace: const TopBarBackground(),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white70),
            tooltip: 'Customize Scorecard',
            onPressed: _openCustomizeScreen,
          ),
          const SizedBox(width: 8),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _handlePop(false),
        ),
      ),

      // DYNAMIC NAVIGATION BAR
      bottomNavigationBar: _isViewingMode
          ? const SizedBox.shrink()
          // The website frame's left border runs down through this bar.
          : SiteLeftEdgeLine(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      child: SizedBox(
                        height: 70,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            if (widget.gameType.toLowerCase() == 'yahtzee') ...[
                              Builder(
                                builder: (context) {
                                  int currentRound = _rounds.length;

                                  bool allFilled = true;
                                  for (
                                    int p = 0;
                                    p < _playerNames.length;
                                    p++
                                  ) {
                                    int count = 0;
                                    for (var r in _rounds) {
                                      String? cat =
                                          r['p${p + 1}Category'] ??
                                          r['category'];
                                      if (cat != null &&
                                          cat != 'YAHTZEE BONUS') {
                                        count++;
                                      }
                                    }
                                    if (count < currentRound) {
                                      allFilled = false;
                                      break;
                                    }
                                  }

                                  int displayRound = currentRound > 13
                                      ? 13
                                      : currentRound;

                                  bool isLastRound = currentRound >= 13;

                                  return Expanded(
                                    child: TextButton.icon(
                                      icon: Icon(
                                        isLastRound
                                            ? Icons.check_circle
                                            : Icons.check_circle_outline,
                                        color: allFilled
                                            ? (isLastRound
                                                  ? customPurple
                                                  : primaryBlue)
                                            : Colors.white24,
                                        size: 18,
                                      ),
                                      label: FittedBox(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              isLastRound
                                                  ? "FINALIZE GAME"
                                                  : "FINALIZE RND",
                                              style: TextStyle(
                                                color: allFilled
                                                    ? (isLastRound
                                                          ? customPurple
                                                          : primaryBlue)
                                                    : Colors.white24,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (!isLastRound)
                                              Text(
                                                "$displayRound/13",
                                                style: TextStyle(
                                                  color: allFilled
                                                      ? primaryBlue.withOpacity(
                                                          0.8,
                                                        )
                                                      : Colors.white24,
                                                  fontSize: 10,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      onPressed: allFilled
                                          ? () {
                                              if (isLastRound) {
                                                _handleFinalizeGame();
                                              } else {
                                                setState(() {
                                                  if (_rounds.isEmpty) {
                                                    _rounds.add({
                                                      'roundNum': 1,
                                                    });
                                                  }
                                                  if (_rounds[0].containsKey(
                                                    'currentYahtzeeRound',
                                                  )) {
                                                    _rounds[0].remove(
                                                      'currentYahtzeeRound',
                                                    );
                                                  }
                                                  _rounds.add({
                                                    'roundNum':
                                                        currentRound + 1,
                                                  });
                                                  _isSynced = false;
                                                });
                                                _onTemplateDataChanged();
                                              }
                                            }
                                          : null,
                                    ),
                                  );
                                },
                              ),
                            ] else ...[
                              if (!_template.autoManagesRounds) ...[
                                // --- REMOVE ROUND ---
                                Expanded(
                                  child: TextButton.icon(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                      color: Colors.redAccent,
                                      size: 18,
                                    ),
                                    label: const FittedBox(
                                      child: Text(
                                        "REMOVE ROUND",
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    onPressed: () async {
                                      if (_rounds.length > 1) {
                                        final roundToRemove = _rounds.last;
                                        bool shouldRemove = true;

                                        if (!_isRoundEmpty(roundToRemove)) {
                                          shouldRemove =
                                              await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  backgroundColor: const Color(
                                                    0xFF1E1E1E,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                  ),
                                                  title: const Text(
                                                    "Remove Round?",
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  content: const Text(
                                                    "This round already contains data. Are you sure you want to remove it?",
                                                    style: TextStyle(
                                                      color: Colors.white70,
                                                    ),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            ctx,
                                                            false,
                                                          ),
                                                      child: const Text(
                                                        "Cancel",
                                                        style: TextStyle(
                                                          color: Colors.white54,
                                                        ),
                                                      ),
                                                    ),
                                                    ElevatedButton(
                                                      style:
                                                          ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                Colors
                                                                    .redAccent,
                                                          ),
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            ctx,
                                                            true,
                                                          ),
                                                      child: const Text(
                                                        "REMOVE",
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ) ??
                                              false;
                                        }

                                        if (shouldRemove) {
                                          setState(() {
                                            _rounds.removeLast();
                                            _template.onRoundRemoved(_rounds);
                                            _isSynced = false;
                                          });
                                          _saveData();
                                        }
                                      }
                                    },
                                  ),
                                ),
                                // --- ADD ROUND ---
                                Expanded(
                                  child: TextButton.icon(
                                    icon: const Icon(
                                      Icons.add_circle_outline,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    label: const FittedBox(
                                      child: Text(
                                        "ADD ROUND",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    onPressed: () {
                                      if (!_template.canAddRound(
                                        _rounds,
                                        _playerNames.length,
                                        customSettings: _customSettings,
                                      )) {
                                        if (_template is SpadesTemplate &&
                                            _rounds.isNotEmpty) {
                                          final spades =
                                              _template as SpadesTemplate;
                                          if (!spades.isRoundMathValid(
                                            _rounds.last,
                                          )) {
                                            SleekNotificationBanner.show(
                                              "Invalid Hand Scores",
                                              "The total tricks don't add up to exactly 13. Please check your bags and sets before adding a round.",
                                              icon: Icons.calculate,
                                              color: Colors.redAccent,
                                            );
                                            return;
                                          }
                                        }

                                        SleekNotificationBanner.show(
                                          "Incomplete Round",
                                          "Please completely fill out the previous round before adding a new one.",
                                          icon: Icons.warning_amber_rounded,
                                          color: Colors.orangeAccent,
                                        );
                                        return;
                                      }
                                      setState(() {
                                        _rounds.add(
                                          _template.createNewRound(
                                            _rounds.length + 1,
                                            _playerNames.length,
                                          ),
                                        );
                                        if (widget.gameType.toLowerCase() ==
                                            'poker') {
                                          int prevBuyIn = 2;
                                          if (_rounds.length > 1) {
                                            prevBuyIn =
                                                int.tryParse(
                                                  _rounds[_rounds.length -
                                                              2]['buyIn']
                                                          ?.toString() ??
                                                      '2',
                                                ) ??
                                                2;
                                          }
                                          _rounds.last['buyIn'] = prevBuyIn;
                                        }
                                        _template.recalculateTotals(
                                          _rounds,
                                          _playerNames.length,
                                          customSettings: _customSettings,
                                        );
                                        _isSynced = false;
                                      });
                                      _saveData();
                                    },
                                  ),
                                ),
                              ],
                              // --- FINALIZE GAME ---
                              Expanded(
                                child: Builder(
                                  builder: (context) {
                                    bool canFinalize = _template
                                        .isReadyToFinalize(
                                          _rounds,
                                          _playerNames.length,
                                          customSettings: _customSettings,
                                        );
                                    return TextButton.icon(
                                      icon: Icon(
                                        Icons.check_circle,
                                        color: canFinalize
                                            ? customPurple
                                            : Colors.white24,
                                        size: 18,
                                      ),
                                      label: FittedBox(
                                        child: Text(
                                          "FINALIZE",
                                          style: TextStyle(
                                            color: canFinalize
                                                ? customPurple
                                                : Colors.white24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      onPressed: _handleFinalizeGame,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          double initialTop =
              MediaQuery.of(context).padding.top + kToolbarHeight + 300;
          if (initialTop > constraints.maxHeight - 180) {
            initialTop = constraints.maxHeight - 180;
          }
          if (initialTop < 0) {
            initialTop = 0;
          }

          return Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.only(
                    top:
                        MediaQuery.of(context).padding.top +
                        kToolbarHeight +
                        20,
                    left: 20,
                    right: 20,
                    bottom: _isViewingMode ? 40 : 120,
                  ),
                  child: GlassCard(
                    accentColor: primaryBlue,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 16.0,
                            right: 16.0,
                            top: 20.0,
                            bottom: 16.0,
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
                                            widget.gameType.toUpperCase(),
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
                                          widget.gameType,
                                        )) ...[
                                          const SizedBox(width: 6),
                                          const Icon(
                                            Icons.verified,
                                            color: Color(0xFF00A2FF),
                                            size: 18,
                                          ),
                                        ],
                                        if (_isLive && !_isFinalized) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.redAccent
                                                  .withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(4),
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
                                  Icon(
                                    _isFinalized
                                        ? Icons.check_circle_rounded
                                        : (_isViewingMode
                                              ? Icons.visibility
                                              : Icons.edit_document),
                                    color: _isFinalized
                                        ? const Color(0xFF00A2FF)
                                        : (_isViewingMode
                                              ? Colors.white54
                                              : const Color(0xFF7855C1)),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  if (_isUploading)
                                    const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF00A2FF),
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else if (_isSynced)
                                    const Icon(
                                      Icons.cloud_done_rounded,
                                      color: Color(0xFF00A2FF),
                                      size: 20,
                                    )
                                  else
                                    GestureDetector(
                                      onTap: _isViewingMode
                                          ? null
                                          : _uploadToCloud,
                                      child: Icon(
                                        Icons.cloud_upload_rounded,
                                        color: _isViewingMode
                                            ? Colors.white54
                                            : const Color(0xFF7855C1),
                                        size: 20,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (widget.ownerType == 'group' &&
                                      widget.groupName != null) ...[
                                    Text(
                                      widget.groupName!.toUpperCase(),
                                      style: TextStyle(
                                        color: primaryBlue,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      "•",
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    _getFormattedDate(),
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return _template.buildGrid(
                              context: context,
                              constraints: constraints,
                              playerNames: _playerNames,
                              rounds: _rounds,
                              isFinalized: _isViewingMode,
                              onDataChanged: _onTemplateDataChanged,
                              onPlayerTap: (idx) {},
                              // ADDED: Merged root rules with UI states
                              customSettings: {
                                ..._customSettings,
                                'quickBidEnabled': _quickBidEnabled,
                                'isGroupGame': widget.ownerType == 'group',
                                'showHowToScore': _showHowToScore,
                                'showNetColumn': _pokerNetColumn,
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_quickInfoEnabled)
                Positioned(
                  left: _quickInfoOffset?.dx ?? 20,
                  top: _quickInfoOffset?.dy ?? initialTop,
                  child: _buildQuickInfoTile(context, initialTop, constraints),
                ),
            ],
          );
        },
      ),
    );

    final route = ModalRoute.of(context);
    final secondaryAnimation = route?.secondaryAnimation;
    if (secondaryAnimation != null) {
      return AnimatedBuilder(
        animation: secondaryAnimation,
        builder: (animCtx, child) {
          return Opacity(
            opacity: (1.0 - secondaryAnimation.value).clamp(0.0, 1.0),
            child: child,
          );
        },
        child: scaffold,
      );
    }

    return scaffold;
  }

  @override
  Widget build(BuildContext context) {
    Widget finalUI;

    if (_splitScreenEnabled) {
      Widget scoringPane = Navigator(
        key: _scoringNavKey,
        onGenerateRoute: (settings) => PageRouteBuilder(
          opaque: false,
          pageBuilder: (ctx, _, __) => _buildMainScoringUI(ctx),
        ),
      );

      Widget metricsPane = Navigator(
        key: _metricsNavKey,
        onGenerateRoute: (settings) => PageRouteBuilder(
          opaque: false,
          pageBuilder: (ctx, _, __) =>
              MetricsScreen(isEmbedded: true, isLiveGame: _isLive),
        ),
      );

      finalUI = SplitScreen(
        mainPane: scoringPane,
        secondaryPane: metricsPane,
        swapPanes: _swapPanes,
      );
    } else {
      finalUI = _buildMainScoringUI(context);
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        _handlePop(didPop);
      },
      child: GradientBackground(child: finalUI),
    );
  }
}
