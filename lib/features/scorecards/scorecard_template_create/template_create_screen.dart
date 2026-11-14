import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/shared_widgets/gradient_background.dart';
import 'setup_questions.dart';
import 'template_scorecard_editor.dart';
import 'package:scorecards_app/core/shared_widgets/top_bar_background.dart';

class TemplateCreateScreen extends StatefulWidget {
  final bool isGroupGame;
  final String? selectedGroupId;
  final String? selectedGroupName;

  /// Pre-filled answers (e.g. from the rulebook scanner). When provided the
  /// intro page is skipped and the user reviews each answer.
  final Map<String, dynamic>? initialSettings;

  const TemplateCreateScreen({
    super.key,
    required this.isGroupGame,
    this.selectedGroupId,
    this.selectedGroupName,
    this.initialSettings,
  });

  @override
  State<TemplateCreateScreen> createState() => _TemplateCreateScreenState();
}

class _TemplateCreateScreenState extends State<TemplateCreateScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;

  final Map<String, dynamic> _customSettings = {
    'gameType': 'Custom Scorecard',
    'gameMode': 'player', // player, team, either
    'minPlayers': 2,
    'maxPlayers': 12,
    'winCondition':
        'highest_score', // first_to_score, highest_after_rounds, lowest_after_rounds, lowest_score
    'targetValue': 0, // Target score or rounds
  };

  late String _userName;

  bool get _isFromScan => widget.initialSettings != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialSettings != null) {
      _customSettings.addAll(widget.initialSettings!);
      _currentIndex = 1;
    }
    _pageController = PageController(initialPage: _currentIndex);
    String? displayName;
    try {
      displayName = FirebaseAuth.instance.currentUser?.displayName;
    } catch (_) {
      displayName = null;
    }
    final first = displayName?.trim().split(' ').first ?? '';
    _userName = first.isEmpty ? 'there' : first;
  }

  void _previousPage() {
    if (_currentIndex <= (_isFromScan ? 1 : 0)) {
      Navigator.pop(context);
      return;
    }
    setState(() => _currentIndex--);
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _nextPage() {
    // 5 total pages: Intro (0), Name (1), Mode (2), Count (3), Win/Target (4)
    if (_currentIndex < 4) {
      setState(() => _currentIndex++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finishSetup() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateScorecardEditor(
          customSettings: Map<String, dynamic>.from(_customSettings),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Exclude intro from progress calculation
    final totalProgressSteps = 4; // 1 to 4
    final currentProgressStep = _currentIndex > 0 ? _currentIndex : 0;
    final progress = totalProgressSteps > 0
        ? currentProgressStep / totalProgressSteps
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: Icon(
            _currentIndex <= (_isFromScan ? 1 : 0)
                ? Icons.close
                : Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: _previousPage,
        ),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            _isFromScan ? "Review Scan" : "Setup Questions",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              fontSize: 24,
            ),
          ),
        ),
        actions: [
          if (_currentIndex > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 20.0),
                child: Text(
                  "Step $currentProgressStep of $totalProgressSteps",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
        flexibleSpace: const TopBarBackground(),
        bottom: _currentIndex > 0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF00A2FF),
                  ),
                  minHeight: 4,
                ),
              )
            : null,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              if (_isFromScan && _currentIndex > 0)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7855C1).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF7855C1).withValues(alpha: 0.6),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFFB79CFF),
                        size: 18,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Pre-filled from your scan. Check each answer and fix anything that's off.",
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              // Form Content
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: PageView(
                      controller: _pageController,
                      physics:
                          const NeverScrollableScrollPhysics(), // Force using the buttons to advance
                      children: [
                        IntroQuestion(userName: _userName, onNext: _nextPage),
                        GameNameQuestion(
                          initialName: _customSettings['gameType'],
                          onNext: (val) {
                            _customSettings['gameType'] = val;
                            _nextPage();
                          },
                        ),
                        GameModeQuestion(
                          initialMode: _customSettings['gameMode'],
                          onNext: (val) {
                            setState(() => _customSettings['gameMode'] = val);
                            _nextPage();
                          },
                        ),
                        PlayerCountQuestion(
                          gameMode: _customSettings['gameMode'],
                          initialMin: _customSettings['minPlayers'],
                          initialMax: _customSettings['maxPlayers'],
                          onNext: (minP, maxP) {
                            _customSettings['minPlayers'] = minP;
                            _customSettings['maxPlayers'] = maxP;
                            _nextPage();
                          },
                        ),
                        WinConditionQuestion(
                          initialCondition: _customSettings['winCondition'],
                          initialValue: _customSettings['targetValue'],
                          onFinish: (condition, val) {
                            _customSettings['winCondition'] = condition;
                            _customSettings['targetValue'] = val;
                            _finishSetup();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
