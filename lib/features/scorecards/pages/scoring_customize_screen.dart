import 'package:flutter/material.dart';
import '../../../core/shared_widgets/gradient_background.dart';
import '../../../core/shared_widgets/white_frost_tile.dart';
import '../../../core/layout/responsive.dart';
import 'package:scorecards_app/core/shared_widgets/top_bar_background.dart';

class ScoringCustomizeScreen extends StatefulWidget {
  final String gameType;
  final String scorecardId; // --- NEW: Added scorecardId ---
  final List<String> playerNames;
  final List<Map<String, dynamic>> rounds;
  final bool initialIsLive;
  final bool initialSplitScreen;
  final bool initialSwapPanes;
  final bool initialQuickBid;
  final bool isEmbedded;
  final bool initialQuickInfo;
  final bool isViewingMode;
  final bool initialShowHowToScore;
  final bool initialPokerNetColumn;

  const ScoringCustomizeScreen({
    super.key,
    required this.gameType,
    required this.scorecardId, // --- NEW ---
    required this.playerNames,
    required this.rounds,
    required this.initialIsLive,
    required this.initialSplitScreen,
    required this.initialSwapPanes,
    required this.initialQuickBid,
    this.isEmbedded = false,
    required this.initialQuickInfo,
    this.isViewingMode = false,
    this.initialShowHowToScore = true,
    this.initialPokerNetColumn = false,
  });

  @override
  State<ScoringCustomizeScreen> createState() => _ScoringCustomizeScreenState();
}

class _ScoringCustomizeScreenState extends State<ScoringCustomizeScreen> {
  late bool _isLive;
  late bool _splitScreenEnabled;
  late bool _swapPanes;
  late bool _quickBidEnabled;
  bool _canPop = false;
  late bool _quickInfoEnabled;
  late bool _showHowToScore;
  late bool _pokerNetColumn;

  @override
  void initState() {
    super.initState();
    _isLive = widget.initialIsLive;
    _splitScreenEnabled = widget.initialSplitScreen;
    _swapPanes = widget.initialSwapPanes;
    _quickBidEnabled = widget.initialQuickBid;
    _quickInfoEnabled = widget.initialQuickInfo;
    _showHowToScore = widget.initialShowHowToScore;
    _pokerNetColumn = widget.initialPokerNetColumn;
  }

  void _saveAndPop({bool reopen = false}) {
    if (_canPop) {
      return;
    }
    setState(() {
      _canPop = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.pop(context, {
          'isLive': _isLive,
          'splitScreenEnabled': _splitScreenEnabled,
          'swapPanes': _swapPanes,
          'quickBidEnabled': _quickBidEnabled,
          'quickInfoEnabled': _quickInfoEnabled,
          'showHowToScore': _showHowToScore,
          'pokerNetColumn': _pokerNetColumn,
          'reopen': reopen,
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _saveAndPop,
        ),
        titleSpacing: 20,
        title: const Text(
          "Customize Scorecard",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            fontSize: 24,
          ),
        ),
        flexibleSpace: const TopBarBackground(),
      ),
      body: ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + kToolbarHeight + 20,
          left: readableSide(context),
          right: readableSide(context),
          bottom: 40,
        ),
        physics: const ClampingScrollPhysics(),
        children: [
          // --- NEW: SCORECARD INFO SECTION ---
          WhiteFrostTile(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "SCORECARD INFO",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Scorecard ID",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Flexible(
                        child: SelectableText(
                          widget.scorecardId,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                            fontFamily:
                                'monospace', // Makes the ID easy to read
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (!widget.isViewingMode) ...[
            WhiteFrostTile(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "LIVE SCORECARDS",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                "Live Scorecard",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Switch(
                              value: _isLive,
                              activeColor: const Color(0xFF00A2FF),
                              activeTrackColor: const Color(
                                0xFF00A2FF,
                              ).withOpacity(0.3),
                              inactiveThumbColor: Colors.white54,
                              inactiveTrackColor: Colors.white10,
                              onChanged: (bool newValue) async {
                                if (newValue) {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: const Color(0xFF1E1E1E),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      title: const Text(
                                        "Enable Live Mode?",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      content: const Text(
                                        "Live Mode auto-syncs your scorecard to the cloud as you play, allowing others in your group to view the score in real-time. Do you want to continue?",
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text(
                                            "Cancel",
                                            style: TextStyle(
                                              color: Colors.white54,
                                            ),
                                          ),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF00A2FF,
                                            ),
                                          ),
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text(
                                            "Enable",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm != true) return;
                                }
                                setState(() {
                                  _isLive = newValue;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Auto-syncs to the cloud so other devices in the group can see the score as it is being played.",
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          WhiteFrostTile(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "DISPLAY OPTIONS",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              "Split Screen Metrics",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Switch(
                            value: _splitScreenEnabled,
                            activeColor: const Color(0xFF00A2FF),
                            activeTrackColor: const Color(
                              0xFF00A2FF,
                            ).withOpacity(0.3),
                            inactiveThumbColor: Colors.white54,
                            inactiveTrackColor: Colors.white10,
                            onChanged: (bool newValue) {
                              setState(() {
                                _splitScreenEnabled = newValue;
                                if (!_splitScreenEnabled) {
                                  _swapPanes = false;
                                }
                              });
                              _saveAndPop(reopen: true);
                            },
                          ),
                        ],
                      ),
                      if (_splitScreenEnabled) ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                "Flip Screens",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Switch(
                              value: _swapPanes,
                              activeColor: const Color(0xFF00A2FF),
                              activeTrackColor: const Color(
                                0xFF00A2FF,
                              ).withOpacity(0.3),
                              inactiveThumbColor: Colors.white54,
                              inactiveTrackColor: Colors.white10,
                              onChanged: (bool newValue) {
                                setState(() {
                                  _swapPanes = newValue;
                                });
                                _saveAndPop(reopen: true);
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(color: Colors.white24, height: 1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          "Quick Info Tile",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Switch(
                        value: _quickInfoEnabled,
                        activeColor: const Color(0xFF00A2FF),
                        activeTrackColor: const Color(
                          0xFF00A2FF,
                        ).withOpacity(0.3),
                        inactiveThumbColor: Colors.white54,
                        inactiveTrackColor: Colors.white10,
                        onChanged: (bool newValue) {
                          setState(() {
                            _quickInfoEnabled = newValue;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (widget.gameType.toLowerCase() == 'yahtzee') ...[
            const SizedBox(height: 24),
            WhiteFrostTile(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "YAHTZEE OPTIONS",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "How to Score Column",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Displays the scoring rules next to the category.",
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _showHowToScore,
                          activeColor: const Color(0xFF00A2FF),
                          activeTrackColor: const Color(
                            0xFF00A2FF,
                          ).withOpacity(0.3),
                          inactiveThumbColor: Colors.white54,
                          inactiveTrackColor: Colors.white10,
                          onChanged: (bool newValue) {
                            setState(() {
                              _showHowToScore = newValue;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (widget.gameType.toLowerCase() == 'poker') ...[
            const SizedBox(height: 24),
            WhiteFrostTile(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "POKER OPTIONS",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Show Round Net Column",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Adds a black-tinted column showing lost/gained per round.",
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _pokerNetColumn,
                          activeColor: const Color(0xFF00A2FF),
                          activeTrackColor: const Color(
                            0xFF00A2FF,
                          ).withOpacity(0.3),
                          inactiveThumbColor: Colors.white54,
                          inactiveTrackColor: Colors.white10,
                          onChanged: (bool newValue) {
                            setState(() {
                              _pokerNetColumn = newValue;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (widget.gameType.toLowerCase() == 'spades') ...[
            const SizedBox(height: 24),
            WhiteFrostTile(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "SPADES OPTIONS",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            "Quick Bid",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Switch(
                          value: _quickBidEnabled,
                          activeColor: const Color(0xFF00A2FF),
                          activeTrackColor: const Color(
                            0xFF00A2FF,
                          ).withOpacity(0.3),
                          inactiveThumbColor: Colors.white54,
                          inactiveTrackColor: Colors.white10,
                          onChanged: (bool newValue) {
                            setState(() {
                              _quickBidEnabled = newValue;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    Widget content = widget.isEmbedded
        ? scaffold
        : GradientBackground(child: scaffold);

    return PopScope(
      canPop: _canPop,
      onPopInvoked: (didPop) {
        if (didPop) {
          return;
        }
        _saveAndPop();
      },
      child: content,
    );
  }
}
