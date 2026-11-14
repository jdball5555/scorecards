import 'package:flutter/material.dart';
import '../../../core/shared_widgets/game_request_link.dart';

/// Names that already belong to a built-in scorecard. A custom template with
/// one of these names would be loaded as the built-in game instead.
const reservedTemplateNames = {
  'spades',
  'yahtzee',
  'wavelength',
  'pit',
  'poker',
  'nerts',
  'nines',
  'standard',
  'standard scorecard',
};

/// Lets a question page scroll when it doesn't fit (small phones, keyboard
/// open) while still centring it vertically when there is room.
class _QuestionScaffold extends StatelessWidget {
  final CrossAxisAlignment crossAxisAlignment;
  final List<Widget> children;

  const _QuestionScaffold({
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - 64).clamp(0, double.infinity),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: crossAxisAlignment,
            children: children,
          ),
        ),
      ),
    );
  }
}

Widget _errorText(String? error) {
  if (error == null) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(
      error,
      style: const TextStyle(color: Colors.redAccent, fontSize: 14),
    ),
  );
}

Widget _buildBlackButton(String label, VoidCallback? onPressed) {
  return ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF00A2FF), // Blue background
      foregroundColor: Colors.black, // Black text
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
  );
}

class IntroQuestion extends StatelessWidget {
  final String userName;
  final VoidCallback onNext;

  const IntroQuestion({
    super.key,
    required this.userName,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.style, size: 80, color: Colors.white),
        const SizedBox(height: 24),
        Text(
          "Let's Create Your Own Scorecard Template, $userName",
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "We'll ask a few quick questions to set up the rules.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        const SizedBox(height: 48),
        _buildBlackButton("Let's Go", onNext),
        const SizedBox(height: 24),
        const GameRequestLink(
          label: "Rather we build it? Request a game instead",
        ),
      ],
    );
  }
}

class GameNameQuestion extends StatefulWidget {
  final String initialName;
  final ValueChanged<String> onNext;

  const GameNameQuestion({
    super.key,
    required this.initialName,
    required this.onNext,
  });

  @override
  State<GameNameQuestion> createState() => _GameNameQuestionState();
}

class _GameNameQuestionState extends State<GameNameQuestion> {
  late TextEditingController _controller;
  String? _error;

  void _submit() {
    final val = _controller.text.trim();
    if (val.isEmpty) {
      setState(() => _error = "Please enter a name for your game.");
      return;
    }
    if (reservedTemplateNames.contains(val.toLowerCase())) {
      setState(
        () => _error =
            "\"$val\" is already a built-in scorecard. Try something like \"$val (House Rules)\".",
      );
      return;
    }
    setState(() => _error = null);
    widget.onNext(val);
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialName == 'Custom Scorecard' ? '' : widget.initialName,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      children: [
        const Text(
          "What is the name of this game?",
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _controller,
          style: const TextStyle(color: Colors.white, fontSize: 24),
          decoration: InputDecoration(
            hintText: "e.g., Oh Hell, Phase 10",
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white54),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF00A2FF), width: 2),
            ),
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _submit(),
        ),
        _errorText(_error),
        const SizedBox(height: 48),
        Align(
          alignment: Alignment.centerRight,
          child: _buildBlackButton("Next", _submit),
        ),
      ],
    );
  }
}

class GameModeQuestion extends StatefulWidget {
  final String initialMode;
  final ValueChanged<String> onNext;

  const GameModeQuestion({
    super.key,
    required this.initialMode,
    required this.onNext,
  });

  @override
  State<GameModeQuestion> createState() => _GameModeQuestionState();
}

class _GameModeQuestionState extends State<GameModeQuestion> {
  late String _selectedMode;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode;
  }

  @override
  Widget build(BuildContext context) {
    return _QuestionScaffold(
      children: [
        const Text(
          "Is it a player, team, or either/or game?",
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 32),
        _buildOption("Players Only", "player", Icons.person),
        const SizedBox(height: 16),
        _buildOption("Teams Only", "team", Icons.people),
        const SizedBox(height: 16),
        _buildOption("Either (Both Allowed)", "either", Icons.group_add),
        const SizedBox(height: 48),
        Align(
          alignment: Alignment.centerRight,
          child: _buildBlackButton("Next", () => widget.onNext(_selectedMode)),
        ),
      ],
    );
  }

  Widget _buildOption(String label, String value, IconData icon) {
    final isSelected = _selectedMode == value;
    return InkWell(
      onTap: () => setState(() => _selectedMode = value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00A2FF).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00A2FF)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF00A2FF) : Colors.white,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF00A2FF) : Colors.white,
                  fontSize: 20,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlayerCountQuestion extends StatefulWidget {
  final String gameMode;
  final int initialMin;
  final int initialMax;
  final Function(int min, int max) onNext;

  const PlayerCountQuestion({
    super.key,
    required this.gameMode,
    required this.initialMin,
    required this.initialMax,
    required this.onNext,
  });

  @override
  State<PlayerCountQuestion> createState() => _PlayerCountQuestionState();
}

class _PlayerCountQuestionState extends State<PlayerCountQuestion> {
  late int _min;
  late int _max;

  @override
  void initState() {
    super.initState();
    _min = widget.initialMin.clamp(1, 20);
    _max = widget.initialMax.clamp(_min, 20);
  }

  @override
  Widget build(BuildContext context) {
    String entityType = widget.gameMode == 'team' ? "teams" : "players";

    return _QuestionScaffold(
      children: [
        Text(
          "What is the minimum and maximum $entityType?",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 48),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text(
                "Minimum:",
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            _buildAdjuster(
              _min,
              (val) => setState(() {
                _min = val;
                if (_min > _max) _max = _min;
              }),
              minValue: 1,
              maxValue: 20,
            ),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text(
                "Maximum:",
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            _buildAdjuster(
              _max,
              (val) => setState(() => _max = val),
              minValue: _min,
              maxValue: 20,
            ),
          ],
        ),
        const SizedBox(height: 64),
        Align(
          alignment: Alignment.centerRight,
          child: _buildBlackButton("Next", () => widget.onNext(_min, _max)),
        ),
      ],
    );
  }

  Widget _buildAdjuster(
    int value,
    ValueChanged<int> onChanged, {
    int minValue = 1,
    int maxValue = 100,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
          onPressed: value > minValue ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 40,
          child: Text(
            "$value",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
          onPressed: value < maxValue ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class WinConditionQuestion extends StatefulWidget {
  final String initialCondition;
  final int initialValue;
  final Function(String condition, int value) onFinish;

  const WinConditionQuestion({
    super.key,
    required this.initialCondition,
    required this.initialValue,
    required this.onFinish,
  });

  @override
  State<WinConditionQuestion> createState() => _WinConditionQuestionState();
}

class _WinConditionQuestionState extends State<WinConditionQuestion> {
  late String _selectedCondition;
  late TextEditingController _targetController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedCondition = widget.initialCondition;
    _targetController = TextEditingController(
      text: widget.initialValue > 0 ? widget.initialValue.toString() : '',
    );
  }

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  bool _requiresTarget() {
    return _selectedCondition != 'highest_score' &&
        _selectedCondition != 'lowest_score';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "How is the winner determined?",
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                _buildOption("First to reach a score", "first_to_score"),
                const SizedBox(height: 12),
                _buildOption(
                  "Most points after locked amount of rounds",
                  "highest_after_rounds",
                ),
                const SizedBox(height: 12),
                _buildOption(
                  "Lowest score after locked amount of rounds",
                  "lowest_after_rounds",
                ),
                const SizedBox(height: 12),
                _buildOption(
                  "Lowest score when someone reaches a score",
                  "lowest_when_reached_score",
                ),
                const SizedBox(height: 12),
                _buildOption(
                  "Highest score (no locked limit)",
                  "highest_score",
                ),
                const SizedBox(height: 12),
                _buildOption("Lowest score (no locked limit)", "lowest_score"),

                if (_requiresTarget()) ...[
                  const SizedBox(height: 32),
                  _buildTargetInput(),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
          _errorText(_error),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: _buildBlackButton("Finish", () {
              final val = int.tryParse(_targetController.text.trim()) ?? 0;
              final isRounds = _selectedCondition.endsWith('_after_rounds');
              if (_requiresTarget() && val <= 0) {
                setState(
                  () => _error = isRounds
                      ? "Enter how many rounds the game lasts."
                      : "Enter the target score.",
                );
                return;
              }
              if (isRounds && val > 100) {
                setState(() => _error = "Please use 100 rounds or fewer.");
                return;
              }
              widget.onFinish(_selectedCondition, _requiresTarget() ? val : 0);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(String label, String value) {
    final isSelected = _selectedCondition == value;
    return InkWell(
      onTap: () => setState(() {
        _selectedCondition = value;
        _error = null;
      }),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00A2FF).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00A2FF)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF00A2FF) : Colors.white,
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildTargetInput() {
    String label = "What is the target score?";
    if (_selectedCondition == 'highest_after_rounds' ||
        _selectedCondition == 'lowest_after_rounds') {
      label = "How many rounds are locked?";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _targetController,
          keyboardType: TextInputType.number,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            hintText: _selectedCondition.endsWith('_after_rounds')
                ? "e.g., 10"
                : "e.g., 100",
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white54),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF00A2FF), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
