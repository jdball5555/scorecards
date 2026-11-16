import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../core/shared_widgets/sleek_notification_banner.dart';

class DataEntryBuilderDialog extends StatefulWidget {
  final Map<String, dynamic> initialConfig;
  final String defaultTitle;
  final bool isCustomCell;

  const DataEntryBuilderDialog({
    super.key,
    required this.initialConfig,
    required this.defaultTitle,
    this.isCustomCell = false,
  });

  @override
  State<DataEntryBuilderDialog> createState() => _DataEntryBuilderDialogState();
}

class _DataEntryBuilderDialogState extends State<DataEntryBuilderDialog> {
  late List<Map<String, dynamic>> _inputs;
  late String _modalTitle;
  late bool _showCalcScore;
  late bool _calcScoreAdjustable;
  late bool _isTextOnly;

  @override
  void initState() {
    super.initState();
    _modalTitle = widget.initialConfig['modalTitle'] ?? widget.defaultTitle;
    _calcScoreAdjustable = widget.initialConfig['calcScoreAdjustable'] ?? false;
    _isTextOnly = widget.initialConfig['isTextOnly'] ?? false;

    final initialInputs = widget.initialConfig['inputs'] as List? ?? [];

    _inputs = initialInputs.map((e) {
      final map = Map<String, dynamic>.from(e);
      if (map['options'] != null) {
        map['options'] = List<dynamic>.from(map['options']);
      }
      return map;
    }).toList();

    if (widget.initialConfig['showCalcScore'] == null) {
      bool hasPointsToggle = _inputs.any(
        (i) => i['type'] == 'toggle' && (i['worthPoints'] ?? false),
      );
      _showCalcScore = _inputs.length > 1 || hasPointsToggle;
    } else {
      _showCalcScore = widget.initialConfig['showCalcScore'];
    }
  }

  void _editModalTitle() {
    String newTitle = _modalTitle;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          "Edit Modal Title",
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          controller: TextEditingController(text: newTitle),
          onChanged: (val) => newTitle = val,
          onSubmitted: (val) {
            setState(() => _modalTitle = val);
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A2FF),
            ),
            onPressed: () {
              setState(() => _modalTitle = newTitle);
              Navigator.pop(ctx);
            },
            child: const Text("SAVE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddInputMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Add Input Type",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.keyboard, color: Colors.white54),
                title: const Text(
                  "Standard input",
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  setState(() {
                    _inputs.add({'type': 'standard', 'name': '', 'header': ''});
                    if (_inputs.length > 1) _showCalcScore = true;
                  });
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.white54,
                ),
                title: const Text(
                  "Number input (+/-)",
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  setState(() {
                    _inputs.add({
                      'type': 'number_stepper',
                      'name': '',
                      'header': '',
                      'options': [1, 5],
                    });
                    if (_inputs.length > 1) _showCalcScore = true;
                  });
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.grid_view, color: Colors.white54),
                title: const Text(
                  "Select from tiles",
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  setState(() {
                    _inputs.add({
                      'type': 'tiles',
                      'name': '',
                      'header': '',
                      'options': ['1', '2', '3', '4'],
                    });
                    if (_inputs.length > 1) _showCalcScore = true;
                  });
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.toggle_on, color: Colors.white54),
                title: const Text(
                  "True/False toggle",
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  setState(() {
                    _inputs.add({
                      'type': 'toggle',
                      'name': '',
                      'header': '',
                      'worthPoints': false,
                      'points': 0,
                    });
                    if (_inputs.length > 1) _showCalcScore = true;
                  });
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTextInputDialog(
    String title,
    String hintText,
    String initialVal,
    Function(String) onSave,
  ) {
    String temp = initialVal;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Colors.white38),
          ),
          controller: TextEditingController(text: temp)
            ..selection = TextSelection.collapsed(offset: temp.length),
          onChanged: (val) => temp = val,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () {
              onSave("");
              Navigator.pop(ctx);
            },
            child: const Text(
              "Clear",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A2FF),
            ),
            onPressed: () {
              onSave(temp);
              Navigator.pop(ctx);
            },
            child: const Text("SAVE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleMenuSelection(
    String value,
    int index,
    Map<String, dynamic> input,
  ) {
    if (value == 'delete') {
      setState(() => _inputs.removeAt(index));
    } else if (value == 'header') {
      _showTextInputDialog(
        "Header",
        "Optional Header (e.g. Bid)",
        input['header'] ?? '',
        (newVal) => setState(() => input['header'] = newVal),
      );
    } else if (value == 'description') {
      _showTextInputDialog(
        "Description",
        "Optional Description (e.g. enter your bid)",
        input['description'] ?? '',
        (newVal) => setState(() => input['description'] = newVal),
      );
    } else if (value == 'worth_points') {
      setState(() {
        input['worthPoints'] = !(input['worthPoints'] ?? false);
        if (input['worthPoints'] == true && !_showCalcScore) {
          _showCalcScore = true;
        }
      });
    }
  }

  Widget _buildInputWrapper(
    int index,
    String defaultTypeName,
    Map<String, dynamic> input,
    Widget child, {
    List<PopupMenuEntry<String>> extraMenu = const [],
  }) {
    bool isDefaultHeader =
        (input['header'] == null || input['header'].toString().trim().isEmpty);
    String headerText = isDefaultHeader
        ? defaultTypeName.toUpperCase()
        : input['header'].toString().toUpperCase();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headerText,
                        style: TextStyle(
                          color: isDefaultHeader
                              ? Colors.white54
                              : Colors.white,
                          fontSize: isDefaultHeader ? 10 : 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          fontStyle: isDefaultHeader
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                      if (input['description'] != null &&
                          input['description'].toString().trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            input['description'],
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 32,
                width: 32,
                child: PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: Colors.white54,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  color: const Color(0xFF2C2C2C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (val) => _handleMenuSelection(val, index, input),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'header',
                      child: ListTile(
                        leading: const Icon(
                          Icons.text_fields,
                          color: Colors.white,
                        ),
                        title: Text(
                          isDefaultHeader ? "Add Header" : "Edit Header",
                          style: const TextStyle(color: Colors.white),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'description',
                      child: ListTile(
                        leading: const Icon(
                          Icons.description,
                          color: Colors.white,
                        ),
                        title: Text(
                          (input['description'] == null ||
                                  input['description']
                                      .toString()
                                      .trim()
                                      .isEmpty)
                              ? "Add Description"
                              : "Edit Description",
                          style: const TextStyle(color: Colors.white),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (extraMenu.isNotEmpty) const PopupMenuDivider(),
                    ...extraMenu,
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.redAccent),
                        title: Text(
                          "Delete Input",
                          style: TextStyle(color: Colors.redAccent),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildStandardInput(int index, Map<String, dynamic> input) {
    return _buildInputWrapper(
      index,
      "Standard Input",
      input,
      TextField(
        readOnly: true,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w900,
        ),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: "Tap to enter score",
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 18),
          filled: true,
          fillColor: Colors.black.withValues(alpha: 0.3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildTilesInput(int index, Map<String, dynamic> input) {
    final options = (input['options'] as List?) ?? [];
    return _buildInputWrapper(
      index,
      "Tile Input",
      input,
      Center(
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            ...options.asMap().entries.map((entry) {
              int optIdx = entry.key;
              String tile = entry.value.toString();
              return GestureDetector(
                onTap: () {
                  String newName = tile;
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF1E1E1E),
                      title: const Text(
                        "Edit Tile",
                        style: TextStyle(color: Colors.white),
                      ),
                      content: TextField(
                        autofocus: true,
                        style: const TextStyle(color: Colors.white),
                        controller: TextEditingController(text: newName),
                        onChanged: (val) => newName = val,
                        onSubmitted: (val) {
                          setState(() => options[optIdx] = val);
                          Navigator.pop(ctx);
                        },
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            setState(() => options.removeAt(optIdx));
                            Navigator.pop(ctx);
                          },
                          child: const Text(
                            "Delete",
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00A2FF),
                          ),
                          onPressed: () {
                            setState(() => options[optIdx] = newName);
                            Navigator.pop(ctx);
                          },
                          child: const Text(
                            "SAVE",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      tile,
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: tile.length > 1 ? 16 : 20,
                      ),
                    ),
                  ),
                ),
              );
            }),
            GestureDetector(
              onTap: () {
                String newTile = "";
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF1E1E1E),
                    title: const Text(
                      "Add Tile",
                      style: TextStyle(color: Colors.white),
                    ),
                    content: TextField(
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (val) => newTile = val,
                      onSubmitted: (val) {
                        if (val.isNotEmpty) setState(() => options.add(val));
                        Navigator.pop(ctx);
                      },
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          if (newTile.isNotEmpty)
                            setState(() => options.add(newTile));
                          Navigator.pop(ctx);
                        },
                        child: const Text("ADD"),
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF00A2FF).withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.add, color: Color(0xFF00A2FF)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberStepper(int index, Map<String, dynamic> input) {
    final steps = (input['options'] as List?) ?? [];
    // Firestore can hand numbers back as num/String; normalise to int.
    for (int i = 0; i < steps.length; i++) {
      if (steps[i] is! int) steps[i] = int.tryParse('${steps[i]}') ?? 1;
    }

    Widget buildAdjustButton(int amount) {
      return Container(
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
      );
    }

    return _buildInputWrapper(
      index,
      "Number Input",
      input,
      Column(
        children: [
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
                child: const Text(
                  "0",
                  style: TextStyle(
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
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ...steps.asMap().entries.map((entry) {
                int stepIdx = entry.key;
                int stepVal = entry.value;
                return InkWell(
                  onTap: () {
                    setState(() => steps.removeAt(stepIdx));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00A2FF).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF00A2FF)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "±$stepVal",
                          style: const TextStyle(
                            color: Color(0xFF00A2FF),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.close,
                          color: Color(0xFF00A2FF),
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                );
              }),
              InkWell(
                onTap: () {
                  String newStep = "";
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF1E1E1E),
                      title: const Text(
                        "Add Increment",
                        style: TextStyle(color: Colors.white),
                      ),
                      content: TextField(
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        onChanged: (val) => newStep = val,
                        onSubmitted: (val) {
                          final v = int.tryParse(val);
                          if (v != null) setState(() => steps.add(v));
                          Navigator.pop(ctx);
                        },
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("Cancel"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            final v = int.tryParse(newStep);
                            if (v != null) setState(() => steps.add(v));
                            Navigator.pop(ctx);
                          },
                          child: const Text("ADD"),
                        ),
                      ],
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white38),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    "+ Add Button",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleInput(int index, Map<String, dynamic> input) {
    bool worthPoints = input['worthPoints'] ?? false;
    int points = int.tryParse('${input['points']}') ?? 0;

    return _buildInputWrapper(
      index,
      "Toggle Input",
      input,
      extraMenu: [
        CheckedPopupMenuItem(
          value: 'worth_points',
          checked: worthPoints,
          child: const ListTile(
            leading: Icon(Icons.calculate, color: Colors.white),
            title: Text("Worth Points", style: TextStyle(color: Colors.white)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: "Enter question (e.g. Won the trick?)",
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                    ),
                    controller:
                        TextEditingController(
                            text: input['name']?.toString() ?? '',
                          )
                          ..selection = TextSelection.collapsed(
                            offset: (input['name']?.toString() ?? '').length,
                          ),
                    onChanged: (val) => input['name'] = val,
                  ),
                ),
                const Switch(value: false, onChanged: null),
              ],
            ),
            if (worthPoints) ...[
              const Divider(color: Colors.white24, height: 24),
              Row(
                children: [
                  const Text(
                    "Points Value:",
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: "e.g. 10 or -10",
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                      ),
                      onChanged: (val) {
                        input['points'] = int.tryParse(val) ?? 0;
                      },
                      controller: TextEditingController(text: points.toString())
                        ..selection = TextSelection.collapsed(
                          offset: points.toString().length,
                        ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextOnlyMockup() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: const Center(
        child: Text(
          "Text Only Mode\n\nDuring scoring, tapping this cell will simply allow the user to type a text label (e.g. Yahtzee categories or text notes). No math is performed.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: EdgeInsets.zero,
      contentPadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.only(left: 20, right: 8, top: 12, bottom: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _editModalTitle,
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        _modalTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.edit, color: Colors.white38, size: 16),
                  ],
                ),
              ),
            ),
            if (!_isTextOnly)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                color: const Color(0xFF2C2C2C),
                onSelected: (val) {
                  if (val == 'calc') {
                    setState(() => _showCalcScore = !_showCalcScore);
                  } else if (val == 'adj') {
                    setState(
                      () => _calcScoreAdjustable = !_calcScoreAdjustable,
                    );
                  }
                },
                itemBuilder: (context) => [
                  CheckedPopupMenuItem(
                    value: 'calc',
                    checked: _showCalcScore,
                    child: const Text(
                      "Show Calculated Score",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  if (_showCalcScore)
                    CheckedPopupMenuItem(
                      value: 'adj',
                      checked: _calcScoreAdjustable,
                      child: const Text(
                        "Adjustable Calc Score",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                ],
              ),
          ],
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
                if (widget.isCustomCell)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "Text Only Cell (No Math Input)",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        CupertinoSwitch(
                          value: _isTextOnly,
                          activeTrackColor: const Color(0xFF00A2FF),
                          onChanged: (val) => setState(() => _isTextOnly = val),
                        ),
                      ],
                    ),
                  ),

                if (_isTextOnly)
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: _buildTextOnlyMockup(),
                  )
                else ...[
                  ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(20),
                    itemCount: _inputs.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
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
                    const Divider(color: Colors.white12),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: TextField(
                        readOnly: true,
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
                          suffixIcon: _calcScoreAdjustable
                              ? const Icon(Icons.edit, color: Colors.white38)
                              : null,
                        ),
                      ),
                    ),
                  ],

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF00A2FF),
                            side: const BorderSide(color: Color(0xFF00A2FF)),
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text(
                            "ADD INPUT",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: _showAddInputMenu,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.all(12),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text("CANCEL", style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00A2FF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () async {
            if (!_isTextOnly && _inputs.isEmpty) {
              SleekNotificationBanner.show(
                "Add an Input",
                "Tap ADD INPUT so players have something to fill in for this cell.",
                icon: Icons.warning_amber_rounded,
                color: Colors.orangeAccent,
              );
              return;
            }
            for (var input in _inputs) {
              if (input['type'] == 'toggle' &&
                  (input['name'] == null ||
                      input['name'].toString().trim().isEmpty)) {
                SleekNotificationBanner.show(
                  "Missing Question",
                  "Please enter a question for all True/False toggles.",
                  icon: Icons.warning_amber_rounded,
                  color: Colors.orangeAccent,
                );
                return;
              }
            }

            bool applyToAll = false;
            if (!widget.isCustomCell) {
              final promptResult = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E1E),
                  title: const Text(
                    "Apply to all?",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: const Text(
                    "Use this same setup for every player score cell in every round?",
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text(
                        "No, just this cell",
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A2FF),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        "Yes",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
              if (promptResult == null) return;
              applyToAll = promptResult;
            }

            Navigator.pop(context, {
              'inputs': _inputs,
              'modalTitle': _modalTitle,
              'showCalcScore': _showCalcScore,
              'calcScoreAdjustable': _calcScoreAdjustable,
              'isTextOnly': _isTextOnly,
              'applyToAllNonCustom': applyToAll,
            });
          },
          child: const Text(
            "SAVE",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
