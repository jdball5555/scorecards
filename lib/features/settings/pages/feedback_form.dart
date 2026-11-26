import 'package:flutter/material.dart';

import '../../../core/shared_widgets/gradient_background.dart';
import '../../../core/shared_widgets/white_frost_tile.dart';
import '../../../core/shared_widgets/sleek_notification_banner.dart';
import '../../../services/feedback_service.dart';
import '../../../core/layout/responsive.dart';
import 'package:scorecards_app/core/shared_widgets/top_bar_background.dart';
import 'package:scorecards_app/features/premium/premium_beta.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Feedback location for "please add this game" requests.
const kNewGameFeedbackLocation = 'New Game';

class FeedbackFormScreen extends ConsumerStatefulWidget {
  /// 'bug' or 'idea'.
  final String initialType;

  /// Pre-selects a "where" tile (e.g. [kNewGameFeedbackLocation]).
  final String? initialLocation;

  /// Pre-selects a template when the location is 'Scoring Template'.
  final String? initialTemplate;

  const FeedbackFormScreen({
    super.key,
    this.initialType = 'bug',
    this.initialLocation,
    this.initialTemplate,
  });

  /// Opens the form ready for someone to name a game they'd like added.
  static Future<void> openGameRequest(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/feedback'),
        builder: (_) => const FeedbackFormScreen(
          initialType: 'idea',
          initialLocation: kNewGameFeedbackLocation,
        ),
      ),
    );
  }

  @override
  ConsumerState<FeedbackFormScreen> createState() => _FeedbackFormScreenState();
}

class _FeedbackFormScreenState extends ConsumerState<FeedbackFormScreen> {
  final TextEditingController _feedbackController = TextEditingController();

  bool _isSubmitting = false;
  String _feedbackType = 'bug'; // 'bug' or 'idea'

  // Bug Report specific state
  String _bugLocation = 'Scoring Template';

  // Feature Idea specific state
  String _ideaLocation = 'New Page';

  String _selectedTemplate = 'Spades';

  final List<String> _locationOptions = [
    'Scoring Template',
    'Scoring Standard',
    'Custom Builder',
    'AI Rulebook Scan',
    'Group',
    'Metrics',
    'Settings',
    'Scorecard Screen',
    'Home',
    'Website',
  ];

  static const _featuredIdeas = [kNewGameFeedbackLocation, 'New Page'];

  // Template builder and rulebook scan are premium beta features.
  static const _premiumLocations = {'Custom Builder', 'AI Rulebook Scan'};

  List<String> get _visibleLocations => hasPremiumBeta(ref)
      ? _locationOptions
      : _locationOptions.where((l) => !_premiumLocations.contains(l)).toList();

  @override
  void initState() {
    super.initState();
    _feedbackType = widget.initialType == 'idea' ? 'idea' : 'bug';
    final loc = widget.initialLocation;
    if (loc != null) {
      if (_feedbackType == 'idea') {
        _ideaLocation = loc;
      } else if (_locationOptions.contains(loc)) {
        _bugLocation = loc;
      }
    }
    if (widget.initialTemplate != null &&
        _templateOptions.contains(widget.initialTemplate)) {
      _selectedTemplate = widget.initialTemplate!;
    }
  }

  String get _currentLocation =>
      _feedbackType == 'bug' ? _bugLocation : _ideaLocation;

  bool get _isGameRequest =>
      _feedbackType == 'idea' && _ideaLocation == kNewGameFeedbackLocation;

  String get _hintText {
    if (_isGameRequest) {
      return "Which game should we add? Tell us its name and, if you can, how it's scored (rounds, bids, target score...).";
    }
    return _feedbackType == 'bug'
        ? "Please describe the issue you encountered..."
        : "Please describe your idea or feature request...";
  }

  final List<String> _templateOptions = [
    'Spades',
    'Nines',
    'Nerts',
    'Wavelength',
    'Yahtzee',
    'Pit (Beta)',
    'Poker (Beta)',
  ];

  Future<void> _submitFeedback() async {
    final text = _feedbackController.text.trim();
    if (text.isEmpty) {
      SleekNotificationBanner.show(
        "Missing Info",
        "Please type your feedback before submitting.",
        icon: Icons.edit_note,
        color: Colors.orangeAccent,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final usesTemplate = _currentLocation == 'Scoring Template';
      final location = usesTemplate
          ? 'Scoring Template • ${_selectedTemplate.replaceAll(' (Beta)', '')}'
          : _currentLocation;

      await FeedbackService.submit(
        isBug: _feedbackType == 'bug',
        location: location,
        message: text,
        extra: {
          'isNewPageIdea':
              _feedbackType == 'idea' && _ideaLocation == 'New Page',
          'isGameRequest': _isGameRequest,
          if (usesTemplate) 'template': _selectedTemplate,
        },
      );

      if (mounted) {
        SleekNotificationBanner.show(
          _isGameRequest ? "Request Sent" : "Feedback Sent",
          _isGameRequest
              ? "Thanks! We read every game request."
              : "Thank you! Your feedback helps us improve Scorecards.",
          icon: Icons.check_circle,
          color: const Color(0xFF54A27E),
        );
        Navigator.pop(context);
      }
    } on FeedbackRateLimited {
      if (mounted) {
        SleekNotificationBanner.show(
          "Slow Down",
          "Please wait a few seconds before sending more feedback.",
          icon: Icons.timer_outlined,
          color: Colors.orangeAccent,
        );
      }
    } catch (e) {
      if (mounted) {
        SleekNotificationBanner.show(
          "Submission Failed",
          "Something went wrong. Please check your connection and try again.",
          icon: Icons.error_outline,
          color: Colors.redAccent,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Send Feedback",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            fontSize: 24,
          ),
        ),
        flexibleSpace: const TopBarBackground(),
      ),
      body: GradientBackground(
        child: ListView(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 20,
            left: readableSide(context),
            right: readableSide(context),
            bottom: 40,
          ),
          physics: const ClampingScrollPhysics(),
          children: [
            WhiteFrostTile(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "WHAT CAN WE HELP WITH?",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTypeButton(
                          id: 'bug',
                          label: "Fix a Problem",
                          icon: Icons.bug_report_outlined,
                          isSelected: _feedbackType == 'bug',
                          onTap: () => setState(() => _feedbackType = 'bug'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTypeButton(
                          id: 'idea',
                          label: "Suggest an Idea",
                          icon: Icons.lightbulb_outline,
                          isSelected: _feedbackType == 'idea',
                          onTap: () => setState(() => _feedbackType = 'idea'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            WhiteFrostTile(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _feedbackType == 'bug'
                        ? "WHERE IS THE PROBLEM?"
                        : "WHERE DOES THIS IDEA GO?",
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildTileGrid(
                    options: _feedbackType == 'idea'
                        ? [..._featuredIdeas, ..._visibleLocations]
                        : _visibleLocations,
                    selectedValue: _feedbackType == 'bug'
                        ? _bugLocation
                        : _ideaLocation,
                    onSelect: (val) {
                      setState(() {
                        if (_feedbackType == 'bug') {
                          _bugLocation = val;
                        } else {
                          _ideaLocation = val;
                        }
                      });
                    },
                  ),
                  if ((_feedbackType == 'bug' &&
                          _bugLocation == 'Scoring Template') ||
                      (_feedbackType == 'idea' &&
                          _ideaLocation == 'Scoring Template')) ...[
                    const SizedBox(height: 24),
                    const Text(
                      "WHICH TEMPLATE?",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTileGrid(
                      options: _templateOptions,
                      selectedValue: _selectedTemplate,
                      onSelect: (val) {
                        setState(() {
                          _selectedTemplate = val;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            WhiteFrostTile(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isGameRequest ? "WHAT GAME DO YOU WANT?" : "DETAILS",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _feedbackController,
                    maxLines: 6,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: _hintText,
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A2FF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSubmitting ? null : _submitFeedback,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "SUBMIT FEEDBACK",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton({
    required String id,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00A2FF).withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00A2FF)
                : Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF00A2FF) : Colors.white54,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTileGrid({
    required List<String> options,
    required String selectedValue,
    required ValueChanged<String> onSelect,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: options.map((option) {
            final isSelected = selectedValue == option;
            final isBig = _featuredIdeas.contains(option);
            // Two columns on phones, more on wide screens.
            final cols = constraints.maxWidth > 560 ? 3 : 2;
            final tileWidth = (constraints.maxWidth - 12 * (cols - 1)) / cols;

            return GestureDetector(
              onTap: () => onSelect(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: tileWidth,
                padding: EdgeInsets.symmetric(vertical: isBig ? 18 : 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF00A2FF).withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF00A2FF)
                        : Colors.white.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    option,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
