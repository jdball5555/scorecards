import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/shared_widgets/gradient_background.dart';
import '../../../core/shared_widgets/glass_card.dart';
import '../../../core/shared_widgets/sleek_notification_banner.dart';
import 'template_create_customize.dart';
import 'data_entry_builder_dialog.dart';
import 'package:scorecards_app/core/shared_widgets/top_bar_background.dart';

class TemplateScorecardEditor extends StatefulWidget {
  final Map<String, dynamic> customSettings;
  final String? templateId;

  const TemplateScorecardEditor({
    super.key,
    required this.customSettings,
    this.templateId,
  });

  @override
  State<TemplateScorecardEditor> createState() =>
      _TemplateScorecardEditorState();
}

class _TemplateScorecardEditorState extends State<TemplateScorecardEditor> {
  late Map<String, dynamic> _settings;
  String? _templateId;
  bool _isSaving = false;

  int _inputsPerPlayer = 1;
  List<String> _blueprintColumns = ['player_core'];
  List<String> _lockedLeftColumns = [];
  List<String> _lockedRightColumns = [];
  List<String> _layoutRows = [];

  Map<String, String> _customNames = {};
  Map<String, Map<String, dynamic>> _cellConfigs = {};
  bool _showTotalRow = true;
  int _numRounds = 1;
  Map<String, int> _configGroupIndices = {};
  bool _hasMultipleConfigGroups = false;

  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _settings = Map<String, dynamic>.from(widget.customSettings);
    _templateId = widget.templateId;
    // A brand-new template has never been saved, so leaving should prompt.
    _hasUnsavedChanges = widget.templateId == null;
    _initializeRounds();

    if (_settings['layoutSettings'] != null) {
      final layout = Map<String, dynamic>.from(_settings['layoutSettings']);
      _inputsPerPlayer = layout['inputsPerPlayer'] ?? 1;
      _showTotalRow = layout['showTotalRow'] ?? true;

      if (layout['blueprintColumns'] != null) {
        _blueprintColumns = List<String>.from(layout['blueprintColumns']);
        _lockedLeftColumns = List<String>.from(
          layout['lockedLeftColumns'] ?? [],
        );
        _lockedRightColumns = List<String>.from(
          layout['lockedRightColumns'] ?? [],
        );
      } else {
        // Legacy migration
        _blueprintColumns = ['player_core'];
      }

      if (layout['layoutRows'] != null) {
        _layoutRows = List<String>.from(layout['layoutRows']);
      } else {
        _layoutRows = List.generate(_numRounds, (i) => 'round_$i');
      }
      _syncRoundRowsWithSettings();

      if (layout['customNames'] != null) {
        _customNames = Map<String, String>.from(layout['customNames']);
      }
    } else {
      _layoutRows = List.generate(_numRounds, (i) => 'round_$i');
    }

    if (_settings['cellConfigs'] != null) {
      final raw = Map<String, dynamic>.from(_settings['cellConfigs']);
      _cellConfigs = raw.map(
        (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
      );
    }

    _updateConfigGroups();
  }

  String _getConfigSignature(Map<String, dynamic> config) {
    final inputs = config['inputs'] as List? ?? [];
    final inputsStr = inputs
        .map((i) {
          var type = i['type'] ?? '';
          var header = i['header'] ?? '';
          var desc = i['description'] ?? '';
          var wp = i['worthPoints'] ?? false;
          var pts = i['points'] ?? 0;
          var opt = (i['options'] as List?)?.join(',') ?? '';
          return "$type|$header|$desc|$wp|$pts|$opt";
        })
        .join("||");

    return "${inputsStr}_${config['showCalcScore']}_${config['calcScoreAdjustable']}_${config['isTextOnly']}";
  }

  void _updateConfigGroups() {
    List<String> uniqueSignatures = [];
    _configGroupIndices.clear();

    final allColumns = [
      ..._lockedLeftColumns,
      ..._blueprintColumns,
      ..._lockedRightColumns,
    ];

    for (String row in _layoutRows) {
      if (row.startsWith('round_')) {
        for (String col in allColumns) {
          if (col == 'player_core') {
            if (_inputsPerPlayer > 1) {
              for (int i = 0; i < _inputsPerPlayer; i++) {
                String k = '${row}_${col}_$i';
                if (_cellConfigs[k] != null) {
                  String sig = _getConfigSignature(_cellConfigs[k]!);
                  if (!uniqueSignatures.contains(sig)) {
                    uniqueSignatures.add(sig);
                  }
                  _configGroupIndices[k] = uniqueSignatures.indexOf(sig) + 1;
                }
              }
            } else {
              String k = '${row}_$col';
              if (_cellConfigs[k] != null) {
                String sig = _getConfigSignature(_cellConfigs[k]!);
                if (!uniqueSignatures.contains(sig)) {
                  uniqueSignatures.add(sig);
                }
                _configGroupIndices[k] = uniqueSignatures.indexOf(sig) + 1;
              }
            }
          } else {
            String k = '${row}_$col';
            if (_cellConfigs[k] != null) {
              String sig = _getConfigSignature(_cellConfigs[k]!);
              if (!uniqueSignatures.contains(sig)) {
                uniqueSignatures.add(sig);
              }
              _configGroupIndices[k] = uniqueSignatures.indexOf(sig) + 1;
            }
          }
        }
      }
    }
    _hasMultipleConfigGroups = uniqueSignatures.length > 1;
  }

  String _getCellDisplayString(String configKey, bool isCustom) {
    if (_cellConfigs[configKey] == null) return "";
    if (isCustom) return "✓";
    if (!_hasMultipleConfigGroups) return "✓";

    int index = _configGroupIndices[configKey] ?? 1;
    const subscripts = ['₀', '₁', '₂', '₃', '₄', '₅', '₆', '₇', '₈', '₉'];
    String subscriptStr = index
        .toString()
        .split('')
        .map((char) => subscripts[int.parse(char)])
        .join('');
    return "✓$subscriptStr";
  }

  bool get _isFixedRounds {
    final winCond = _settings['winCondition'];
    return winCond == 'highest_after_rounds' ||
        winCond == 'lowest_after_rounds';
  }

  void _initializeRounds() {
    final target = _settings['targetValue'];
    _numRounds = 1;
    if (_isFixedRounds && target != null) {
      _numRounds = (int.tryParse(target.toString()) ?? 1).clamp(1, 100);
    }
  }

  /// Keeps the number of `round_*` rows in sync with a fixed-round win
  /// condition (e.g. "most points after 10 rounds"), preserving custom rows.
  void _syncRoundRowsWithSettings() {
    if (!_isFixedRounds) {
      if (!_layoutRows.any((r) => r.startsWith('round_'))) {
        _layoutRows.insert(0, 'round_0');
      }
      return;
    }
    final roundRows = _layoutRows.where((r) => r.startsWith('round_')).length;
    if (roundRows < _numRounds) {
      int nextIdx = 0;
      for (final r in _layoutRows) {
        final i = int.tryParse(r.split('_').last) ?? -1;
        if (r.startsWith('round_') && i >= nextIdx) nextIdx = i + 1;
      }
      for (int i = roundRows; i < _numRounds; i++) {
        _layoutRows.add('round_${nextIdx++}');
      }
    } else if (roundRows > _numRounds) {
      int toRemove = roundRows - _numRounds;
      for (int i = _layoutRows.length - 1; i >= 0 && toRemove > 0; i--) {
        if (_layoutRows[i].startsWith('round_')) {
          _layoutRows.removeAt(i);
          toRemove--;
        }
      }
    }
  }

  /// Sequential, human-friendly label for a row ("1", "2", … or custom name).
  String _rowLabel(String rowId) {
    if (!rowId.startsWith('round_')) return _customNames[rowId] ?? "Cust";
    int n = 0;
    for (final r in _layoutRows) {
      if (r.startsWith('round_')) n++;
      if (r == rowId) break;
    }
    return "$n";
  }

  Map<String, dynamic> _currentSettings() {
    return {
      'gameType': _settings['gameType'] ?? 'Custom Scorecard',
      'gameMode': _settings['gameMode'],
      'minPlayers': _settings['minPlayers'],
      'maxPlayers': _settings['maxPlayers'],
      'winCondition': _settings['winCondition'],
      'targetValue': _settings['targetValue'],
      'layoutSettings': {
        'inputsPerPlayer': _inputsPerPlayer,
        'showTotalRow': _showTotalRow,
        'blueprintColumns': _blueprintColumns,
        'lockedLeftColumns': _lockedLeftColumns,
        'lockedRightColumns': _lockedRightColumns,
        'layoutRows': _layoutRows,
        'customNames': _customNames,
      },
      'cellConfigs': _cellConfigs,
    };
  }

  Future<bool> _handleBackButton() async {
    if (!_hasUnsavedChanges) return true;

    final isFirstTime = _templateId == null;
    final discardText = isFirstTime
        ? "Delete Scorecard Template"
        : "Discard Changes";

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Save Changes?",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isFirstTime
              ? "Do you want to save this new template, or delete it?"
              : "You have unsaved changes. Do you want to save them before leaving?",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: Text(
              discardText,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A2FF),
            ),
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text(
              "SAVE",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == 'discard') {
      return true;
    } else if (result == 'save') {
      return await _saveTemplateToFirestore();
    }
    return false;
  }

  /// Saves the draft (and optionally publishes it). Returns true on success.
  Future<bool> _saveTemplateToFirestore({bool isPublishing = false}) async {
    if (_isSaving) return false;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      SleekNotificationBanner.show(
        "Not Signed In",
        "Please sign in again to save your template.",
        icon: Icons.error_outline,
        color: Colors.redAccent,
      );
      return false;
    }

    _isSaving = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF00A2FF)),
      ),
    );

    try {
      final currentSettings = _currentSettings();

      final templateData = <String, dynamic>{
        'templateName': _settings['gameType'] ?? 'Custom Scorecard',
        'creatorId': uid,
        'draftSettings': currentSettings,
        // Top-level summary fields so the template list can show them for
        // drafts as well as published templates.
        'gameMode': currentSettings['gameMode'],
        'minPlayers': currentSettings['minPlayers'],
        'maxPlayers': currentSettings['maxPlayers'],
        'lastEditedAt': FieldValue.serverTimestamp(),
      };

      if (isPublishing) {
        templateData['isPublished'] = true;
        templateData['publishedSettings'] = currentSettings;
        templateData.addAll(currentSettings);
      }

      final collection = FirebaseFirestore.instance.collection(
        'scorecard_templates',
      );
      if (_templateId != null) {
        await collection
            .doc(_templateId)
            .set(templateData, SetOptions(merge: true));
      } else {
        templateData['createdAt'] = FieldValue.serverTimestamp();
        if (!isPublishing) {
          templateData['isPublished'] = false;
        }
        // Remember the new id so later saves update this document instead of
        // creating duplicates.
        final ref = await collection.add(templateData);
        _templateId = ref.id;
      }

      if (mounted) {
        Navigator.pop(context);
        setState(() {
          _hasUnsavedChanges = false;
        });
        SleekNotificationBanner.show(
          isPublishing ? "Template Published" : "Draft Saved",
          isPublishing
              ? "It's now available when you create a new scorecard."
              : "Publish it from Settings when you're ready to play.",
          icon: isPublishing ? Icons.cloud_done_rounded : Icons.save_rounded,
          color: Colors.green,
        );
      }
      return true;
    } catch (e) {
      debugPrint("Error saving template: $e");
      if (mounted) {
        Navigator.pop(context);
        SleekNotificationBanner.show(
          "Save Failed",
          "Couldn't save your template. Check your connection and try again.",
          icon: Icons.error_outline,
          color: Colors.redAccent,
        );
      }
      return false;
    } finally {
      _isSaving = false;
    }
  }

  void _showRenameGameDialog() {
    final controller = TextEditingController(
      text: _settings['gameType']?.toString() ?? '',
    );
    void apply(BuildContext ctx) {
      final val = controller.text.trim();
      if (val.isNotEmpty) {
        setState(() {
          _settings['gameType'] = val;
          _hasUnsavedChanges = true;
        });
      }
      Navigator.pop(ctx);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          "Rename Game",
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Game name",
            hintStyle: TextStyle(color: Colors.white54),
          ),
          onSubmitted: (_) => apply(ctx),
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
            onPressed: () => apply(ctx),
            child: const Text(
              "SAVE",
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

  void _showRenameDialog(String id, String defaultName) {
    String newName = _customNames[id] ?? defaultName;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Rename", style: TextStyle(color: Colors.white)),
        content: TextField(
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Enter name",
            hintStyle: TextStyle(color: Colors.white54),
          ),
          onChanged: (val) => newName = val,
          onSubmitted: (val) {
            setState(() {
              _customNames[id] = val;
              _hasUnsavedChanges = true;
            });
            Navigator.pop(ctx);
          },
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
              setState(() {
                _customNames[id] = newName;
                _hasUnsavedChanges = true;
              });
              Navigator.pop(ctx);
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
      ),
    );
  }

  Future<void> _promptAddCustomColumn(
    String sourceColId,
    String position,
  ) async {
    final isLockedEligible =
        _blueprintColumns.length == 1 &&
        _blueprintColumns.first == 'player_core';

    String? colType = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          "Add Custom Column",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text(
                "Repeat for each Player/Team",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                "This column will automatically duplicate next to every player's score during the game (e.g., a Bid column).",
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: () => Navigator.pop(ctx, 'blueprint'),
            ),
            const Divider(color: Colors.white12),
            ListTile(
              title: Text(
                "Lock to Edge",
                style: TextStyle(
                  color: isLockedEligible ? Colors.white : Colors.white38,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                "This column will only appear once on the edge of the scorecard (e.g., Global Notes).",
                style: TextStyle(
                  color: isLockedEligible ? Colors.white54 : Colors.white24,
                  fontSize: 12,
                ),
              ),
              onTap: isLockedEligible
                  ? () => Navigator.pop(ctx, 'locked')
                  : null,
            ),
          ],
        ),
      ),
    );

    if (colType == null) return;

    final newColId = 'custom_col_${DateTime.now().millisecondsSinceEpoch}';

    setState(() {
      if (colType == 'blueprint') {
        int idx = _blueprintColumns.indexOf(sourceColId);
        if (idx == -1) idx = _blueprintColumns.length - 1; // Fallback
        _blueprintColumns.insert(position == 'left' ? idx : idx + 1, newColId);
      } else if (colType == 'locked') {
        if (position == 'left' || _lockedLeftColumns.contains(sourceColId)) {
          _lockedLeftColumns.add(newColId);
        } else {
          _lockedRightColumns.add(newColId);
        }
      }
      _hasUnsavedChanges = true;
    });
  }

  void _showPlayerContextMenu(
    BuildContext context,
    String colId,
    Offset position,
  ) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        const PopupMenuItem(
          value: 'add_input',
          child: ListTile(
            leading: Icon(Icons.add, color: Colors.white),
            title: Text(
              "Add internal input",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
        if (_inputsPerPlayer > 1)
          const PopupMenuItem(
            value: 'remove_input',
            child: ListTile(
              leading: Icon(Icons.remove, color: Colors.white),
              title: Text(
                "Remove internal input",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        const PopupMenuItem(
          value: 'add_left',
          child: ListTile(
            leading: Icon(Icons.keyboard_arrow_left, color: Colors.white),
            title: Text(
              "Add custom column left",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
        const PopupMenuItem(
          value: 'add_right',
          child: ListTile(
            leading: Icon(Icons.keyboard_arrow_right, color: Colors.white),
            title: Text(
              "Add custom column right",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    ).then((value) {
      if (value == 'add_input') {
        setState(() {
          _inputsPerPlayer++;
          _updateConfigGroups();
          _hasUnsavedChanges = true;
        });
      }
      if (value == 'remove_input') {
        setState(() {
          final removedIdx = _inputsPerPlayer - 1;
          _inputsPerPlayer--;
          _cellConfigs.removeWhere(
            (k, _) => k.endsWith('_player_core_$removedIdx'),
          );
          _updateConfigGroups();
          _hasUnsavedChanges = true;
        });
      }
      if (value == 'add_left') _promptAddCustomColumn(colId, 'left');
      if (value == 'add_right') _promptAddCustomColumn(colId, 'right');
    });
  }

  void _showCustomColumnMenu(
    BuildContext context,
    String colId,
    Offset position,
    String colType,
  ) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        const PopupMenuItem(
          value: 'rename',
          child: ListTile(
            leading: Icon(Icons.edit, color: Colors.white),
            title: Text("Rename", style: TextStyle(color: Colors.white)),
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete, color: Colors.redAccent),
            title: Text(
              "Delete column",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ),
      ],
    ).then((value) {
      if (value == 'rename') {
        _showRenameDialog(colId, "Custom");
      }
      if (value == 'delete') {
        setState(() {
          if (colType == 'blueprint') _blueprintColumns.remove(colId);
          if (colType == 'locked_left') _lockedLeftColumns.remove(colId);
          if (colType == 'locked_right') _lockedRightColumns.remove(colId);
          _cellConfigs.removeWhere((k, _) => k.endsWith('_$colId'));
          _customNames.remove(colId);
          _updateConfigGroups();
          _hasUnsavedChanges = true;
        });
      }
    });
  }

  void _showRoundContextMenu(
    BuildContext context,
    String rowId,
    Offset position,
  ) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        if (rowId.startsWith('custom_row_'))
          const PopupMenuItem(
            value: 'rename',
            child: ListTile(
              leading: Icon(Icons.edit, color: Colors.white),
              title: Text("Rename", style: TextStyle(color: Colors.white)),
            ),
          ),
        const PopupMenuItem(
          value: 'add_up',
          child: ListTile(
            leading: Icon(Icons.arrow_upward, color: Colors.white),
            title: Text(
              "Add custom row above",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
        const PopupMenuItem(
          value: 'add_down',
          child: ListTile(
            leading: Icon(Icons.arrow_downward, color: Colors.white),
            title: Text(
              "Add custom row below",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
        if (rowId.startsWith('custom_row_'))
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete, color: Colors.redAccent),
              title: Text(
                "Delete custom row",
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ),
        if (!_showTotalRow)
          const PopupMenuItem(
            value: 'add_tot',
            child: ListTile(
              leading: Icon(Icons.functions, color: Colors.white),
              title: Text(
                "Add TOT row below",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
      ],
    ).then((value) {
      if (value == 'rename') _showRenameDialog(rowId, "Cust");
      if (value == 'add_up') {
        setState(() {
          int idx = _layoutRows.indexOf(rowId);
          _layoutRows.insert(
            idx,
            'custom_row_${DateTime.now().millisecondsSinceEpoch}',
          );
          _hasUnsavedChanges = true;
        });
      }
      if (value == 'add_down') {
        setState(() {
          int idx = _layoutRows.indexOf(rowId);
          _layoutRows.insert(
            idx + 1,
            'custom_row_${DateTime.now().millisecondsSinceEpoch}',
          );
          _hasUnsavedChanges = true;
        });
      }
      if (value == 'delete') {
        setState(() {
          _layoutRows.remove(rowId);
          _cellConfigs.removeWhere((k, _) => k.startsWith('${rowId}_'));
          _customNames.remove(rowId);
          _updateConfigGroups();
          _hasUnsavedChanges = true;
        });
      }
      if (value == 'add_tot') {
        setState(() {
          _showTotalRow = true;
          _hasUnsavedChanges = true;
        });
      }
    });
  }

  void _showTotContextMenu(BuildContext context, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        const PopupMenuItem(
          value: 'remove_tot',
          child: ListTile(
            leading: Icon(Icons.delete, color: Colors.redAccent),
            title: Text(
              "Remove TOT row",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ),
      ],
    ).then((value) {
      if (value == 'remove_tot') {
        setState(() {
          _showTotalRow = false;
          _hasUnsavedChanges = true;
        });
      }
    });
  }

  void _showCellConfigBuilder(
    BuildContext context,
    String configKey,
    int roundIndex,
    String columnId,
    bool isCustomCell, {
    int? inputIndex,
  }) async {
    final rowId = _layoutRows[roundIndex];
    final rowName = rowId.startsWith('round_')
        ? "Round ${_rowLabel(rowId)}"
        : _rowLabel(rowId);
    String defaultTitle = "$rowName: Score";
    if (inputIndex != null) {
      defaultTitle = "$rowName: Score ${inputIndex + 1}";
    }

    Map<String, dynamic> config = _cellConfigs[configKey] != null
        ? Map<String, dynamic>.from(_cellConfigs[configKey]!)
        : {
            'inputs': [
              {'type': 'standard', 'name': '', 'header': ''},
            ],
            'modalTitle': defaultTitle,
            'showCalcScore': null,
            'calcScoreAdjustable': false,
            'isTextOnly': false,
          };

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => DataEntryBuilderDialog(
        initialConfig: config,
        defaultTitle: defaultTitle,
        isCustomCell: isCustomCell,
      ),
    );

    if (result != null) {
      if (!mounted) return;

      bool shouldApplyToAll = result['applyToAllNonCustom'] == true;
      result.remove('applyToAllNonCustom');

      setState(() {
        _hasUnsavedChanges = true;
        if (shouldApplyToAll) {
          final allColumns = [
            ..._lockedLeftColumns,
            ..._blueprintColumns,
            ..._lockedRightColumns,
          ];
          for (String row in _layoutRows) {
            if (row.startsWith('round_')) {
              for (String col in allColumns) {
                if (col == 'player_core') {
                  if (_inputsPerPlayer > 1) {
                    for (int i = 0; i < _inputsPerPlayer; i++) {
                      var newResult = Map<String, dynamic>.from(result);
                      newResult['modalTitle'] =
                          "Round ${_rowLabel(row)}: Player/Team Score ${i + 1}";
                      _cellConfigs['${row}_${col}_$i'] = newResult;
                    }
                  } else {
                    var newResult = Map<String, dynamic>.from(result);
                    newResult['modalTitle'] =
                        "Round ${_rowLabel(row)}: Player/Team Score";
                    _cellConfigs['${row}_$col'] = newResult;
                  }
                }
              }
            }
          }
        } else {
          _cellConfigs[configKey] = result;
        }
        _updateConfigGroups();
      });
    }
  }

  double _getDynamicFontSize(double baseSize, bool isCrowded) =>
      isCrowded ? baseSize * 0.9 : baseSize;

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
    BuildContext context,
    String colId,
    String text,
    bool isCrowded,
    Function(Offset) onTap, {
    bool isBlueprint = false,
  }) {
    final textStyle = TextStyle(
      color: isBlueprint ? const Color(0xFF00A2FF) : Colors.white,
      fontWeight: FontWeight.w900,
      fontSize: _getDynamicFontSize(14, isCrowded),
      letterSpacing: 1.0,
    );

    Widget cellContent = isCrowded
        ? ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 75),
            child: RotatedBox(
              quarterTurns: 3,
              child: Text(
                text,
                style: textStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
        : Text(
            text,
            textAlign: TextAlign.center,
            style: textStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );

    return GestureDetector(
      onTapUp: (details) => onTap(details.globalPosition),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 4.0),
        child: Center(child: cellContent),
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
              fontSize: _getDynamicFontSize(16, isCrowded),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveGrid(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    double rndWidth = 52.0;
    double baseInputWidth = 60.0;

    int totalFlex = 0;
    final allColumns = [
      ..._lockedLeftColumns,
      ..._blueprintColumns,
      ..._lockedRightColumns,
    ];
    for (String col in allColumns) {
      if (col == 'player_core') {
        totalFlex += _inputsPerPlayer;
      } else {
        totalFlex += 1;
      }
    }

    double calculatedInputWidth = (constraints.maxWidth - rndWidth) / totalFlex;
    bool needsScroll = calculatedInputWidth < baseInputWidth;
    double actualInputWidth = needsScroll
        ? baseInputWidth
        : calculatedInputWidth;
    double usableTextWidth = actualInputWidth * _inputsPerPlayer - 8.0;

    bool isCrowded = false;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (String col in allColumns) {
      String label = col == 'player_core'
          ? "Blueprint Core\n(Player/Team)"
          : (_customNames[col] ?? "Custom");
      textPainter.text = TextSpan(
        text: label,
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
    int colIndex = 1;
    for (String col in allColumns) {
      if (col == 'player_core') {
        colWidths[colIndex] = needsScroll
            ? FixedColumnWidth(baseInputWidth * _inputsPerPlayer)
            : FlexColumnWidth(_inputsPerPlayer.toDouble());
      } else {
        colWidths[colIndex] = needsScroll
            ? FixedColumnWidth(baseInputWidth)
            : const FlexColumnWidth(1.0);
      }
      colIndex++;
    }

    List<TableRow> rows = [];

    // Header Row
    List<Widget> headerCells = [
      TableCell(
        verticalAlignment: TableCellVerticalAlignment.middle,
        child: _buildHeaderCell("RND", isCrowded),
      ),
    ];

    for (String col in allColumns) {
      if (col == 'player_core') {
        headerCells.add(
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: _buildPlayerHeaderCell(
              context,
              col,
              "BLUEPRINT\n(Player/Team)",
              isCrowded,
              (pos) => _showPlayerContextMenu(context, col, pos),
              isBlueprint: true,
            ),
          ),
        );
      } else {
        String type = _lockedLeftColumns.contains(col)
            ? 'locked_left'
            : (_lockedRightColumns.contains(col)
                  ? 'locked_right'
                  : 'blueprint');
        headerCells.add(
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: _buildPlayerHeaderCell(
              context,
              col,
              _customNames[col] ?? "Custom",
              isCrowded,
              (pos) => _showCustomColumnMenu(context, col, pos, type),
              isBlueprint: type == 'blueprint',
            ),
          ),
        );
      }
    }
    rows.add(TableRow(children: headerCells));

    // Data Rows
    for (int r = 0; r < _layoutRows.length; r++) {
      String rowId = _layoutRows[r];
      String rLabel = _rowLabel(rowId);

      List<Widget> rowCells = [
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: GestureDetector(
            onTapUp: (details) =>
                _showRoundContextMenu(context, rowId, details.globalPosition),
            behavior: HitTestBehavior.opaque,
            child: _buildCell(
              rLabel,
              isBold: true,
              color: Colors.white54,
              isCrowded: isCrowded,
            ),
          ),
        ),
      ];

      for (int c = 0; c < allColumns.length; c++) {
        String col = allColumns[c];
        String configKey = '${rowId}_$col';
        if (col == 'player_core' && _inputsPerPlayer > 1) {
          rowCells.add(
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: Row(
                children: List.generate(
                  _inputsPerPlayer,
                  (i) => Expanded(
                    child: GestureDetector(
                      onTap: () => _showCellConfigBuilder(
                        context,
                        '${configKey}_$i',
                        r,
                        col,
                        col.startsWith('custom_'),
                        inputIndex: i,
                      ),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        decoration: i < _inputsPerPlayer - 1
                            ? BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                              )
                            : null,
                        child: _buildCell(
                          _getCellDisplayString(
                            '${configKey}_$i',
                            col.startsWith('custom_'),
                          ),
                          isCrowded: isCrowded,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          rowCells.add(
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: GestureDetector(
                onTap: () => _showCellConfigBuilder(
                  context,
                  configKey,
                  r,
                  col,
                  col.startsWith('custom_') || rowId.startsWith('custom_'),
                ),
                behavior: HitTestBehavior.opaque,
                child: _buildCell(
                  _getCellDisplayString(
                    configKey,
                    col.startsWith('custom_') || rowId.startsWith('custom_'),
                  ),
                  isCrowded: isCrowded,
                ),
              ),
            ),
          );
        }
      }
      rows.add(TableRow(children: rowCells));
    }

    if (_showTotalRow) {
      List<Widget> totalCells = [
        TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: GestureDetector(
            onTapUp: (details) =>
                _showTotContextMenu(context, details.globalPosition),
            behavior: HitTestBehavior.opaque,
            child: _buildCell(
              "TOT",
              isBold: true,
              color: Colors.white,
              isCrowded: isCrowded,
            ),
          ),
        ),
      ];
      for (String col in allColumns) {
        if (col == 'player_core' && _inputsPerPlayer > 1) {
          totalCells.add(
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: Row(
                children: List.generate(
                  _inputsPerPlayer,
                  (i) => Expanded(
                    child: Container(
                      decoration: i < _inputsPerPlayer - 1
                          ? BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                            )
                          : null,
                      child: _buildCell(
                        "0",
                        isBold: true,
                        color: Colors.white,
                        isCrowded: isCrowded,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          totalCells.add(
            _buildCell(
              "0",
              isBold: true,
              color: Colors.white,
              isCrowded: isCrowded,
            ),
          );
        }
      }
      rows.add(
        TableRow(
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3)),
          children: totalCells,
        ),
      );
    }

    Widget tableGrid = Table(
      columnWidths: colWidths,
      border: TableBorder(
        horizontalInside: BorderSide(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
        verticalInside: BorderSide(
          color: Colors.white.withValues(alpha: 0.2),
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

  Future<void> _openCustomize() async {
    final updatedSettings = _currentSettings();
    updatedSettings['isPublished'] = _settings['isPublished'] ?? false;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateCreateCustomize(customSettings: updatedSettings),
      ),
    );

    if (!mounted) return;
    if (result != null && result is Map<String, dynamic>) {
      if (result['action'] == 'publish') {
        final ok = await _saveTemplateToFirestore(isPublishing: true);
        if (ok && mounted) setState(() => _settings['isPublished'] = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameName = _settings['gameType'] as String? ?? 'Custom Scorecard';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleBackButton();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        extendBody: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleSpacing: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _templateId == null ? "Create Template" : "Edit Template",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontSize: 24,
              ),
            ),
          ),
          flexibleSpace: const TopBarBackground(),
          actions: [
            IconButton(
              icon: Icon(
                Icons.save_rounded,
                color: _hasUnsavedChanges ? Colors.white : Colors.white38,
              ),
              tooltip: 'Save Draft',
              onPressed: () => _saveTemplateToFirestore(),
            ),
            IconButton(
              icon: const Icon(Icons.tune_rounded, color: Colors.white70),
              tooltip: 'Publish & Test',
              onPressed: _openCustomize,
            ),
            const SizedBox(width: 8),
          ],
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final shouldPop = await _handleBackButton();
              if (shouldPop && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: GradientBackground(
          child: SizedBox.expand(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              // This context is inside the Scaffold body, so its top padding
              // already includes the (transparent) app bar height.
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 12,
                left: 16,
                right: 16,
                bottom: 40,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF00A2FF).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.touch_app,
                          color: Color(0xFF00A2FF),
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Design a 1-player blueprint. Tap a cell to choose how it's scored, tap a header or round number for more options. During a game the blueprint repeats for every player/team.",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GlassCard(
                    accentColor: const Color(0xFF00A2FF),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 4.0,
                            right: 4.0,
                            bottom: 16.0,
                          ),
                          child: InkWell(
                            onTap: _showRenameGameDialog,
                            borderRadius: BorderRadius.circular(8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    gameName.toUpperCase(),
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
                                const SizedBox(width: 12),
                                const Icon(
                                  Icons.edit,
                                  color: Colors.white54,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Measure the real width available inside the card
                        // so the grid decides correctly when to scroll.
                        LayoutBuilder(
                          builder: (context, constraints) =>
                              _buildInteractiveGrid(context, constraints),
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
    );
  }
}
