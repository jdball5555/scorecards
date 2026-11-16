import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'scorecard_setup.dart';
import '../../../core/shared_widgets/game_request_link.dart';
import '../scorecard_template_create/template_create_screen.dart';
import 'package:scorecards_app/features/premium/premium_beta.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ScorecardCreateDialog extends ConsumerStatefulWidget {
  final bool isTestMode;
  final Map<String, dynamic>? prelockedCustomSettings;

  /// Opens with this built-in template already chosen (e.g. 'Spades').
  final String? initialTemplate;

  const ScorecardCreateDialog({
    super.key,
    this.isTestMode = false,
    this.prelockedCustomSettings,
    this.initialTemplate,
  });

  @override
  ConsumerState<ScorecardCreateDialog> createState() =>
      _ScorecardCreateDialogState();
}

class _ScorecardCreateDialogState extends ConsumerState<ScorecardCreateDialog> {
  bool _isGroupGame = false;
  String? _selectedGroupId;
  String? _selectedGroupName;

  String _selectedType = 'standard';
  String? _selectedTemplate = 'Spades';

  List<String> _templates = [
    'Spades',
    'Nines',
    'Nerts',
    'Wavelength',
    'Yahtzee',
    'Pit (Beta)',
    'Poker (Beta)',
  ];

  bool _isLoadingSettings = true;

  final TextEditingController _customGameController = TextEditingController();
  List<String> _previousCustomGames = [];
  List<String> _groupCustomGames = [];

  Stream<QuerySnapshot>? _groupsStream;

  // ADDED: Cache to hold downloaded template settings
  Map<String, Map<String, dynamic>> _customTemplatesData = {};

  @override
  void dispose() {
    _customGameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _groupsStream = FirebaseFirestore.instance
          .collection('game_groups')
          .where('members', arrayContains: uid)
          .snapshots();
    }

    if (widget.initialTemplate != null) {
      _selectedType = 'template';
      _selectedTemplate = widget.initialTemplate;
    }
    if (widget.isTestMode) {
      _selectedType = 'template';
      _selectedTemplate =
          widget.prelockedCustomSettings?['gameType'] ?? 'Custom Scorecard';
    }
    _loadLastSettings();
  }

  Future<void> _loadLastSettings() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        // Your own published templates (a premium beta feature): fill the
        // dropdown and cache their settings.
        final premium = await ref
            .read(premiumBetaProvider.future)
            .timeout(const Duration(seconds: 5), onTimeout: () => false)
            .catchError((Object _) => false);
        final templateDocs = premium
            ? (await FirebaseFirestore.instance
                      .collection('scorecard_templates')
                      .where('creatorId', isEqualTo: uid)
                      .where('isPublished', isEqualTo: true)
                      .get())
                  .docs
            : const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        for (var tDoc in templateDocs) {
          final data = tDoc.data();
          final name = data['templateName'] as String?;
          if (name != null && !_templates.contains(name)) {
            _templates.add(name);
            _customTemplatesData[name] = data;
          }
        }

        if (doc.exists) {
          if (doc.data()?.containsKey('lastScorecardSettings') == true) {
            final settings = doc.data()!['lastScorecardSettings'];
            _isGroupGame = settings['isGroupGame'] ?? false;
            _selectedGroupId = settings['selectedGroupId'];
            _selectedGroupName = settings['selectedGroupName'];
            if (!widget.isTestMode && widget.initialTemplate == null) {
              _selectedType = settings['selectedType'] ?? 'standard';
              _selectedTemplate = settings['selectedTemplate'] ?? 'Spades';
              // "Create" (the template builder) needs premium beta.
              if (_selectedType == 'custom' && !premium) {
                _selectedType = 'standard';
              }
            }
          }
          if (doc.data()?.containsKey('customGameNames') == true) {
            _previousCustomGames = List<String>.from(
              doc.data()!['customGameNames'],
            );
          }
        }
        if (_isGroupGame && _selectedGroupId != null) {
          await _fetchGroupCustomGames(_selectedGroupId!);
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _isLoadingSettings = false;
      });
    }
  }

  Future<String> _generateCustomId(String gameType) async {
    return FirebaseFirestore.instance.collection('scorecards').doc().id;
  }

  Future<void> _fetchGroupCustomGames(String groupId) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('scorecards')
          .where('groupId', isEqualTo: groupId)
          .get();

      final Set<String> groupGames = {};
      for (var doc in query.docs) {
        final gt = doc.data()['gameType'] as String?;
        if (gt != null &&
            !_templates.contains(gt) &&
            gt.toLowerCase() != 'standard') {
          groupGames.add(gt);
        }
      }

      if (mounted) {
        setState(() {
          _groupCustomGames = groupGames.toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching group games: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final premium = hasPremiumBeta(ref);

    if (_isLoadingSettings) {
      return Dialog(
        backgroundColor: const Color(0xFF1E1E1E).withOpacity(0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: const Padding(
          padding: EdgeInsets.all(40.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [CircularProgressIndicator(color: Color(0xFF00A2FF))],
          ),
        ),
      );
    }

    return Dialog(
      // Keeps the dialog a sensible size on desktop browsers.
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 560),
      backgroundColor: const Color(0xFF1E1E1E).withOpacity(0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    "Create Scorecard",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_selectedType != 'custom') ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    "Part of a Group?",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    "Syncs scores with others",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  activeColor: const Color(0xFF00A2FF),
                  value: _isGroupGame,
                  onChanged: (val) {
                    setState(() {
                      _isGroupGame = val;
                      if (!_isGroupGame) {
                        _selectedGroupId = null;
                        _selectedGroupName = null;
                      }
                    });
                  },
                ),

                if (_isGroupGame && uid != null && _groupsStream != null) ...[
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot>(
                    stream: _groupsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Text(
                          "You aren't in any groups yet. Create one in the Groups tab!",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        );
                      }
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value:
                                snapshot.data!.docs.any(
                                  (d) => d.id == _selectedGroupId,
                                )
                                ? _selectedGroupId
                                : null,
                            hint: const Text(
                              "Choose your group...",
                              style: TextStyle(color: Colors.white54),
                            ),
                            dropdownColor: const Color(0xFF2C2C2C),
                            isExpanded: true,
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.white54,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            items: snapshot.data!.docs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return DropdownMenuItem(
                                value: doc.id,
                                child: Text(data['name'] ?? 'Unnamed Group'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedGroupId = val;
                                  final selectedDoc = snapshot.data!.docs
                                      .firstWhere((doc) => doc.id == val);
                                  _selectedGroupName =
                                      (selectedDoc.data()
                                          as Map<String, dynamic>)['name'];
                                });
                                _fetchGroupCustomGames(val);
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ],
                const Divider(color: Colors.white12, height: 32),
              ],

              if (!widget.isTestMode) ...[
                const Text(
                  "Scorecard Type:",
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildToggleOption('Standard', 'standard', Icons.grid_on),
                    const SizedBox(width: 8),
                    _buildToggleOption('Template', 'template', Icons.style),
                    // Building templates is a premium beta feature.
                    if (premium) ...[
                      const SizedBox(width: 8),
                      _buildToggleOption('Create', 'custom', Icons.edit),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
              ] else ...[
                const Text(
                  "Scorecard Type:",
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildToggleOption('Template', 'template', Icons.style),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              if (_selectedType == 'standard') ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: TextField(
                    controller: _customGameController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "Game Name (e.g. Hearts, Rummy)",
                      hintStyle: TextStyle(
                        color: Colors.white54,
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ),
                Builder(
                  builder: (context) {
                    final allGamesSet = <String>{};
                    allGamesSet.addAll(_previousCustomGames);
                    if (_isGroupGame && _selectedGroupId != null) {
                      allGamesSet.addAll(_groupCustomGames);
                    }
                    final allGames = allGamesSet.toList()..sort();

                    if (allGames.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        const Text(
                          "Recent Games:",
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: allGames.map((game) {
                            return GestureDetector(
                              onTap: () => setState(
                                () => _customGameController.text = game,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                child: Text(
                                  game,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
              ] else if (_selectedType == 'template') ...[
                if (widget.isTestMode)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Text(
                      _selectedTemplate ?? 'Custom Template',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: (_templates.contains(_selectedTemplate)
                            ? _selectedTemplate
                            : _templates.first),
                        dropdownColor: const Color(0xFF2C2C2C),
                        isExpanded: true,
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.white54,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        items: _templates.map((game) {
                          return DropdownMenuItem(
                            value: game,
                            child: Text(game),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _selectedTemplate = val),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
              ] else if (_selectedType == 'custom') ...[
                const Text(
                  "Custom Template:",
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A2FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF00A2FF).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit, color: Color(0xFF00A2FF)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "Create a Template",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "Design your own reusable scorecard.",
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (widget.isTestMode) ...[
                const Divider(color: Colors.white12, height: 32),
                const Text(
                  "Test Mode:",
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A2FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF00A2FF).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.science, color: Color(0xFF00A2FF)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "Testing Template",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "Data will not be saved.",
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A2FF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _handleSubmit,
                  child: Text(
                    _selectedType == 'custom'
                        ? "Create Custom Template"
                        : "Next (Setup Players)",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (!widget.isTestMode)
                const GameRequestLink(
                  label: "Don't see your game? Request it",
                  padding: EdgeInsets.only(top: 8),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleOption(String label, String value, IconData icon) {
    final isSelected = _selectedType == value;
    return Expanded(
      child: GestureDetector(
        onTap: widget.isTestMode
            ? null
            : () => setState(() => _selectedType = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF00A2FF).withOpacity(0.2)
                : Colors.white.withOpacity(0.05),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF00A2FF)
                  : Colors.white.withOpacity(0.1),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF00A2FF) : Colors.white54,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSubmit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (_isGroupGame && _selectedGroupId == null && _selectedType != 'custom') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a group first.")),
      );
      return;
    }

    String finalGameName;
    if (_selectedType == 'standard') {
      finalGameName = _customGameController.text.trim();
      if (finalGameName.isEmpty) {
        finalGameName = 'Standard Scorecard';
      }
      if (finalGameName != 'Standard Scorecard') {
        _previousCustomGames.remove(finalGameName);
        _previousCustomGames.insert(0, finalGameName);
        if (_previousCustomGames.length > 8) {
          _previousCustomGames = _previousCustomGames.sublist(0, 8);
        }
      }
    } else if (_selectedType == 'custom') {
      finalGameName = 'Custom Scorecard';
    } else {
      // The remembered template may have been deleted/unpublished since; fall
      // back to what the dropdown is actually showing.
      final shown = widget.isTestMode || _templates.contains(_selectedTemplate)
          ? _selectedTemplate
          : _templates.first;
      finalGameName = (shown ?? 'Spades').replaceAll(' (Beta)', '');
    }

    final String ownerType =
        (_isGroupGame && _selectedGroupId != null && _selectedType != 'custom')
        ? 'group'
        : 'person';
    final String ownerId =
        (_isGroupGame && _selectedGroupId != null && _selectedType != 'custom')
        ? _selectedGroupId!
        : uid;

    if (uid.isNotEmpty && !widget.isTestMode) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({
            'lastScorecardSettings': {
              'isGroupGame': _isGroupGame,
              'selectedGroupId': _selectedGroupId,
              'selectedGroupName': _selectedGroupName,
              'selectedType': _selectedType,
              'selectedTemplate': _selectedTemplate,
            },
            'customGameNames': _previousCustomGames,
          }, SetOptions(merge: true))
          .catchError((_) {});
    }

    if (_selectedType == 'custom' && !widget.isTestMode) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TemplateCreateScreen(
              isGroupGame: _isGroupGame,
              selectedGroupId: _selectedGroupId,
              selectedGroupName: _selectedGroupName,
            ),
          ),
        );
      }
      return;
    }

    Map<String, dynamic>? customSettingsToPass = widget.prelockedCustomSettings;

    // ADDED: Inject downloaded configuration data into custom templates
    // In test mode always use the editor's live draft, never a stale
    // published copy that happens to share the same name.
    if (!widget.isTestMode &&
        _selectedType == 'template' &&
        _customTemplatesData.containsKey(finalGameName)) {
      final templateData = _customTemplatesData[finalGameName]!;
      final sourceData = templateData['publishedSettings'] != null
          ? Map<String, dynamic>.from(templateData['publishedSettings'])
          : Map<String, dynamic>.from(templateData);

      customSettingsToPass = Map<String, dynamic>.from(sourceData);
      if (sourceData['layoutSettings'] != null) {
        customSettingsToPass.addAll(
          Map<String, dynamic>.from(sourceData['layoutSettings']),
        );
      }
      customSettingsToPass['gameType'] = finalGameName;
      customSettingsToPass['isPublished'] =
          templateData['isPublished'] ?? false;
      if (templateData['cellConfigs'] != null) {
        customSettingsToPass['cellConfigs'] = templateData['cellConfigs'];
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final customId = widget.isTestMode
        ? 'test_mode'
        : await _generateCustomId(finalGameName);

    if (mounted) Navigator.pop(context);
    if (mounted) Navigator.pop(context);

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => ScorecardSetupDialog(
          gameType: finalGameName,
          ownerType: ownerType,
          ownerId: ownerId,
          groupName: _selectedGroupName,
          customId: customId,
          customSettings: customSettingsToPass,
        ),
      );
    }
  }
}
