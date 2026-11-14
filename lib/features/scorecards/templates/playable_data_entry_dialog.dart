import 'package:flutter/material.dart';

class PlayableDataEntryDialog extends StatefulWidget {
  final Map<String, dynamic> config;
  final String defaultTitle;

  /// Values previously entered for this cell (`input_0`, `input_1`, ...), so
  /// re-opening a cell edits it instead of starting from scratch.
  final Map<String, dynamic>? initialRawInputs;

  /// The cell's previously saved score / text.
  final dynamic initialScore;

  const PlayableDataEntryDialog({
    super.key,
    required this.config,
    required this.defaultTitle,
    this.initialRawInputs,
    this.initialScore,
  });

  @override
  State<PlayableDataEntryDialog> createState() =>
      _PlayableDataEntryDialogState();
}

class _PlayableDataEntryDialogState extends State<PlayableDataEntryDialog> {
  late String _modalTitle;
  late List<Map<String, dynamic>> _inputs;
  late bool _showCalcScore;
  late bool _calcScoreAdjustable;
  late bool _isTextOnly;

  // State to track inputs
  final Map<int, TextEditingController> _textControllers = {};
  final Map<int, String?> _selectedTiles = {};
  final Map<int, int> _numberValues = {};
  final Map<int, bool> _toggleValues = {};

  TextEditingController? _calcScoreController;
  int _currentCalculatedScore = 0;

  @override
  void initState() {
    super.initState();
    // Use the dynamic runtime title (e.g., "Round 1: Dave's Score") instead of the hardcoded builder title
    _modalTitle = widget.defaultTitle;
    _calcScoreAdjustable = widget.config['calcScoreAdjustable'] ?? false;
    _isTextOnly = widget.config['isTextOnly'] ?? false;

    final configured = widget.config['inputs'] as List?;
    final initialInputs = (configured == null || configured.isEmpty)
        ? [
            {'type': 'standard', 'name': '', 'header': ''},
          ]
        : configured;

    _inputs = initialInputs
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    if (widget.config['showCalcScore'] == null) {
      bool hasPointsToggle = _inputs.any(
        (i) => i['type'] == 'toggle' && (i['worthPoints'] == true),
      );
      _showCalcScore = _inputs.length > 1 || hasPointsToggle;
    } else {
      _showCalcScore = widget.config['showCalcScore'];
    }

    final raw = widget.initialRawInputs ?? const {};
    for (int i = 0; i < _inputs.length; i++) {
      final prev = raw['input_$i'];
      if (_inputs[i]['type'] == 'standard') {
        _textControllers[i] = TextEditingController(
          text: prev?.toString() ?? '',
        );
      } else if (_inputs[i]['type'] == 'number_stepper') {
        _numberValues[i] = int.tryParse('$prev') ?? 0;
      } else if (_inputs[i]['type'] == 'toggle') {
        _toggleValues[i] = prev == true;
      } else if (_inputs[i]['type'] == 'tiles' && prev != null) {
        _selectedTiles[i] = prev.toString();
      }
    }

    if (_isTextOnly) {
      _textControllers[0] = TextEditingController(
        text: widget.initialScore?.toString() ?? '',
      );
    }

    _recalculateScore(notify: false);

    // One controller for the total field. When adjustable, it follows the
    // inputs but the user can still override it before saving.
    _calcScoreController = TextEditingController(
      text: (_calcScoreAdjustable && widget.initialScore != null)
          ? widget.initialScore.toString()
          : _currentCalculatedScore.toString(),
    );
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    _calcScoreController?.dispose();
    super.dispose();
  }

  /// Always keeps the computed total up to date. Whether it is *shown* is a
  /// display choice only (it used to be skipped when hidden, which made every
  /// multi-input cell score 0).
  void _recalculateScore({bool notify = true}) {

    int total = 0;
    for (int i = 0; i < _inputs.length; i++) {
      final input = _inputs[i];
      if (input['type'] == 'standard') {
        total += int.tryParse(_textControllers[i]?.text ?? '0') ?? 0;
      } else if (input['type'] == 'number_stepper') {
        total += _numberValues[i] ?? 0;
      } else if (input['type'] == 'tiles') {
        total += int.tryParse(_selectedTiles[i] ?? '0') ?? 0;
      } else if (input['type'] == 'toggle') {
        if (_toggleValues[i] == true && input['worthPoints'] == true) {
          total += (input['points'] as int? ?? 0);
        }
      }
    }
    _currentCalculatedScore = total;
    if (notify) {
      _calcScoreController?.text = total.toString();
      setState(() {});
    }
  }

  void _handleSave() {
    Map<String, dynamic> rawInputs = {};
    for (int i = 0; i < _inputs.length; i++) {
      if (_inputs[i]['type'] == 'standard') {
        rawInputs['input_$i'] = _textControllers[i]?.text;
      } else if (_inputs[i]['type'] == 'number_stepper') {
        rawInputs['input_$i'] = _numberValues[i];
      } else if (_inputs[i]['type'] == 'tiles') {
        rawInputs['input_$i'] = _selectedTiles[i];
      } else if (_inputs[i]['type'] == 'toggle') {
        rawInputs['input_$i'] = _toggleValues[i];
      }
    }

    int finalScore = _currentCalculatedScore;
    if (_calcScoreAdjustable && _showCalcScore) {
      finalScore =
          int.tryParse(_calcScoreController?.text.trim() ?? '') ??
          _currentCalculatedScore;
    }

    Navigator.pop(context, {
      'score': _isTextOnly ? _textControllers[0]?.text.trim() : finalScore,
      'rawInputs': rawInputs,
    });
  }

  Widget _buildStandardInput(int index, Map<String, dynamic> input) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (input['header'] != null && input['header'].toString().isNotEmpty)
          Text(
            input['header'],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        if (input['description'] != null &&
            input['description'].toString().isNotEmpty)
          Text(
            input['description'],
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _textControllers[index],
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          autofocus: index == 0,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
          textAlign: TextAlign.center,
          onChanged: (_) => _recalculateScore(),
          decoration: InputDecoration(
            hintText: "0",
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 24),
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTilesInput(int index, Map<String, dynamic> input) {
    final options = (input['options'] as List?) ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (input['header'] != null && input['header'].toString().isNotEmpty)
          Text(
            input['header'],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        if (input['description'] != null &&
            input['description'].toString().isNotEmpty)
          Text(
            input['description'],
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        const SizedBox(height: 12),
        Center(
          // ENFORCES ALIGNMENT IN PLAY MODE
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: options.map((opt) {
              String tile = opt.toString();
              bool isSelected = _selectedTiles[index] == tile;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTiles[index] = tile;
                  });
                  _recalculateScore();
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF00A2FF)
                        : Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF00A2FF)
                          : Colors.white.withValues(alpha: 0.1),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      tile,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: tile.length > 1 ? 16 : 20,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberStepper(int index, Map<String, dynamic> input) {
    final steps =
        (input['options'] as List?)
            ?.map((e) => int.tryParse(e.toString()) ?? 0)
            .toList() ??
        [1, 5];
    int currentVal = _numberValues[index] ?? 0;

    Widget buildAdjustButton(int amount) {
      return GestureDetector(
        onTap: () {
          setState(() {
            _numberValues[index] = currentVal + amount;
          });
          _recalculateScore();
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF00A2FF).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF00A2FF), width: 1.5),
          ),
          child: Center(
            child: Text(
              amount > 0 ? "+$amount" : "$amount",
              style: const TextStyle(
                color: Color(0xFF00A2FF),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (input['header'] != null && input['header'].toString().isNotEmpty)
          Text(
            input['header'],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        if (input['description'] != null &&
            input['description'].toString().isNotEmpty)
          Text(
            input['description'],
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (steps.isNotEmpty) ...[
              buildAdjustButton(-steps.last),
              const SizedBox(width: 8),
              buildAdjustButton(-steps.first),
            ] else ...[
              buildAdjustButton(-1),
            ],
            Container(
              width: 65,
              alignment: Alignment.center,
              child: Text(
                "$currentVal",
                style: const TextStyle(
                  color: Color(0xFF00A2FF),
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (steps.isNotEmpty) ...[
              buildAdjustButton(steps.first),
              const SizedBox(width: 8),
              buildAdjustButton(steps.last),
            ] else ...[
              buildAdjustButton(1),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildToggleInput(int index, Map<String, dynamic> input) {
    bool val = _toggleValues[index] ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (input['header'] != null && input['header'].toString().isNotEmpty)
          Text(
            input['header'],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        if (input['description'] != null &&
            input['description'].toString().isNotEmpty)
          Text(
            input['description'],
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: const Color(0xFF00A2FF),
          title: Text(
            (input['name']?.toString().isNotEmpty ?? false)
                ? input['name'].toString()
                : 'Question?',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          value: val,
          onChanged: (v) {
            setState(() => _toggleValues[index] = v);
            _recalculateScore();
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        _modalTitle,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isTextOnly)
                  TextField(
                    controller: _textControllers[0],
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    decoration: InputDecoration(
                      hintText: "Enter text...",
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  )
                else ...[
                  ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: _inputs.length,
                    separatorBuilder: (context, index) => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Divider(color: Colors.white12),
                    ),
                    itemBuilder: (context, index) {
                      final input = _inputs[index];
                      switch (input['type']) {
                        case 'standard':
                          return _buildStandardInput(index, input);
                        case 'tiles':
                          return _buildTilesInput(index, input);
                        case 'number_stepper':
                          return _buildNumberStepper(index, input);
                        case 'toggle':
                          return _buildToggleInput(index, input);
                        default:
                          return const SizedBox.shrink();
                      }
                    },
                  ),
                  if (_showCalcScore) ...[
                    const Divider(color: Colors.white12, height: 32),
                    TextField(
                      controller: _calcScoreController,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                      ),
                      readOnly: !_calcScoreAdjustable,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: _calcScoreAdjustable
                            ? "Adjustable Calc Score"
                            : "Total Calculated Score",
                        labelStyle: const TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00A2FF),
          ),
          onPressed: _handleSave,
          child: const Text(
            "SAVE",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
