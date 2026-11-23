import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'scorecard_create.dart';
import 'scoring.dart';
import '../templates/game_template.dart';
import '../providers/local_scorecard_provider.dart';
import '../../../services/group_service.dart';
import '../../../core/shared_widgets/sleek_notification_banner.dart';

class ScorecardSetupDialog extends StatefulWidget {
  final String gameType;
  final String ownerType;
  final String ownerId;
  final String? groupName;
  final String customId;
  final Map<String, dynamic>? customSettings;

  const ScorecardSetupDialog({
    super.key,
    required this.gameType,
    required this.ownerType,
    required this.ownerId,
    this.groupName,
    required this.customId,
    this.customSettings,
  });

  @override
  State<ScorecardSetupDialog> createState() => _ScorecardSetupDialogState();
}

class _ScorecardSetupDialogState extends State<ScorecardSetupDialog> {
  late GameTemplate _template;
  List<String> _playerNames = [];
  List<String> _playerIds = [];
  int _activeIndex = 0;

  final Map<String, dynamic> _templateSettings = {};
  final TextEditingController _manualNameController = TextEditingController();
  final GroupService _groupService = GroupService();
  final Map<String, Map<String, dynamic>> _userCache = {};

  final Color primaryBlue = const Color(0xFF00A2FF);
  final Color customPurple = const Color(0xFF7855C1);

  @override
  void initState() {
    super.initState();
    _template = TemplateFactory.getTemplate(widget.gameType);

    if (widget.customSettings != null) {
      int minP = widget.customSettings!['minPlayers'] ?? 2;
      String pLabel = widget.customSettings!['gameMode'] == 'team'
          ? "Team"
          : "Player";
      _playerNames = List.generate(minP, (i) => "$pLabel ${i + 1}");
      _templateSettings.addAll(widget.customSettings!);
    } else {
      _playerNames = _template.generateInitialPlayerNames();
    }

    _playerIds = List<String>.filled(_playerNames.length, '', growable: true);
    _updateManualController();
  }

  @override
  void dispose() {
    _manualNameController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _getCachedUserData(String uid) async {
    if (_userCache.containsKey(uid)) {
      return _userCache[uid]!;
    }
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (doc.exists && doc.data() != null) {
      _userCache[uid] = doc.data()!;
      return doc.data()!;
    }
    return {'displayName': 'Unknown Player'};
  }

  void _updateManualController() {
    if (_playerNames.isNotEmpty && _activeIndex < _playerNames.length) {
      _manualNameController.text =
          _playerNames[_activeIndex].startsWith('Player ') ||
              _playerNames[_activeIndex].startsWith('Team ')
          ? ''
          : _playerNames[_activeIndex];
    }
  }

  void _updatePlayer(int index, String newName, String newId) {
    setState(() {
      String defaultPrefix = "Player";
      if (widget.customSettings != null &&
          widget.customSettings!['gameMode'] == 'team') {
        defaultPrefix = "Team";
      }

      _playerNames[index] = newName.trim().isEmpty
          ? "$defaultPrefix ${index + 1}"
          : newName;
      _playerIds[index] = newId;

      // Auto-advance to next empty slot
      int nextEmpty = _playerNames.indexWhere(
        (n) => n.startsWith('Player ') || n.startsWith('Team '),
      );
      if (nextEmpty != -1) {
        _activeIndex = nextEmpty;
        _updateManualController();
      }
    });
  }

  Future<void> _showTextInputDialog({
    required String title,
    required String label,
    required String buttonText,
    required Function(String) onSubmit,
  }) async {
    final TextEditingController controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(color: Colors.white54),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF00A2FF)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
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
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(context);
                  onSubmit(controller.text.trim());
                }
              },
              child: Text(
                buttonText,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSlot(int index) {
    bool isCurrent = index == _activeIndex;
    bool isAssigned =
        !_playerNames[index].startsWith('Player ') &&
        !_playerNames[index].startsWith('Team ');
    String name = _playerNames[index];

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeIndex = index;
            _updateManualController();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: isCurrent
                ? primaryBlue.withOpacity(0.15)
                : Colors.white.withOpacity(0.05),
            border: Border.all(
              color: isCurrent ? primaryBlue : Colors.white.withOpacity(0.1),
              width: isCurrent ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCurrent
                    ? "EDITING"
                    : (isAssigned ? "ASSIGNED" : "EMPTY SEAT"),
                style: TextStyle(
                  color: isCurrent ? primaryBlue : Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isAssigned ? name : "---",
                style: TextStyle(
                  color: isCurrent
                      ? primaryBlue
                      : (isAssigned ? Colors.white : Colors.white38),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlotsVisual() {
    // Only use the paired visual grouping for hardcoded templates like Spades or Wavelength
    bool isPairedTeamGame =
        widget.gameType.toLowerCase() == 'spades' ||
        widget.gameType.toLowerCase() == 'wavelength';

    List<Widget> rows = [];

    if (isPairedTeamGame && _playerNames.length % 2 == 0) {
      int numTeams = _playerNames.length ~/ 2;
      for (int t = 0; t < numTeams; t++) {
        int idx1 = t * 2;
        int idx2 = idx1 + 1;
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "TEAM ${t + 1}",
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildSlot(idx1),
                    const SizedBox(width: 12),
                    _buildSlot(idx2),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    } else {
      for (int i = 0; i < _playerNames.length; i += 2) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                _buildSlot(i),
                const SizedBox(width: 12),
                if (i + 1 < _playerNames.length)
                  _buildSlot(i + 1)
                else
                  const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
        );
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  Widget _buildGroupSelectionPool() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('game_groups')
          .doc(widget.ownerId)
          .snapshots(),
      builder: (ctx, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final members = List<String>.from(data['members'] ?? []);
        final hiddenPlayers = List<String>.from(data['hiddenPlayers'] ?? []);
        final currentUser = FirebaseAuth.instance.currentUser;
        final ownerUid = data['owner'] ?? "";

        members.sort((a, b) {
          if (a == currentUser?.uid) return -1;
          if (b == currentUser?.uid) return 1;
          if (a == ownerUid) return -1;
          if (b == ownerUid) return 1;
          return 0;
        });

        List<Map<String, String>> parseLocal(List<dynamic> raw) {
          return raw.map<Map<String, String>>((e) {
            if (e is String) return {'id': e, 'name': e};
            if (e is Map) {
              return {
                'id': e['id']?.toString() ?? '',
                'name': e['name']?.toString() ?? '',
              };
            }
            return {'id': '', 'name': ''};
          }).toList();
        }

        final localMembers = parseLocal(
          (data['localMembers'] as List<dynamic>?) ?? [],
        );
        final guests = parseLocal((data['guests'] as List<dynamic>?) ?? []);

        bool isNameSelected(String name) {
          for (int i = 0; i < _playerNames.length; i++) {
            if (i != _activeIndex && _playerNames[i] == name) return true;
          }
          return false;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "GROUP MEMBERS",
              style: TextStyle(
                color: primaryBlue,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ...members.map((uid) {
                  if (hiddenPlayers.contains(uid)) {
                    return const SizedBox.shrink();
                  }
                  if (uid == currentUser?.uid) {
                    final myName = currentUser?.displayName ?? "You";
                    if (isNameSelected(myName) || isNameSelected("You")) {
                      return const SizedBox.shrink();
                    }
                    return _buildChip(
                      "You",
                      Icons.person,
                      primaryBlue,
                      () => _updatePlayer(_activeIndex, myName, uid),
                    );
                  }
                  return FutureBuilder<Map<String, dynamic>>(
                    future: _getCachedUserData(uid),
                    builder: (c, snap) {
                      if (!snap.hasData) return const SizedBox.shrink();
                      final name = snap.data!['displayName'] ?? "Player";
                      if (isNameSelected(name)) return const SizedBox.shrink();
                      return _buildChip(
                        name,
                        Icons.person,
                        primaryBlue,
                        () => _updatePlayer(_activeIndex, name, uid),
                      );
                    },
                  );
                }),
                ...localMembers
                    .where(
                      (p) =>
                          !isNameSelected(p['name']!) &&
                          !hiddenPlayers.contains(p['id']),
                    )
                    .map(
                      (p) => _buildChip(
                        p['name']!,
                        Icons.person,
                        customPurple,
                        () => _updatePlayer(_activeIndex, p['name']!, p['id']!),
                      ),
                    ),
                _buildAddButton("Add Member", primaryBlue, () {
                  _showTextInputDialog(
                    title: "Add Member",
                    label: "Player Name",
                    buttonText: "Add",
                    onSubmit: (name) async => await _groupService.addPlayer(
                      widget.ownerId,
                      name,
                      false,
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              "GUESTS",
              style: TextStyle(
                color: customPurple,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ...guests
                    .where(
                      (p) =>
                          !isNameSelected(p['name']!) &&
                          !hiddenPlayers.contains(p['id']),
                    )
                    .map(
                      (p) => _buildChip(
                        p['name']!,
                        Icons.person_outline,
                        customPurple,
                        () => _updatePlayer(_activeIndex, p['name']!, p['id']!),
                      ),
                    ),
                _buildAddButton("Add Guest", customPurple, () {
                  _showTextInputDialog(
                    title: "Add Guest",
                    label: "Guest Name",
                    buttonText: "Add",
                    onSubmit: (name) async => await _groupService.addPlayer(
                      widget.ownerId,
                      name,
                      true,
                    ),
                  );
                }),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildManualSelectionPool() {
    String defaultPrefix = "Player";
    if (widget.customSettings != null &&
        widget.customSettings!['gameMode'] == 'team') {
      defaultPrefix = "Team";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "ENTER ${defaultPrefix.toUpperCase()} NAME",
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: TextField(
            controller: _manualNameController,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textCapitalization: TextCapitalization.words,
            onChanged: (val) {
              setState(() {
                _playerNames[_activeIndex] = val.trim().isEmpty
                    ? "$defaultPrefix ${_activeIndex + 1}"
                    : val;
              });
            },
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: "Type name here...",
              hintStyle: TextStyle(
                color: Colors.white54,
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChip(
    String name,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, style: BorderStyle.solid),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmAndStartScoring() {
    bool allSeatsFilled = !_playerNames.any(
      (n) => n.startsWith('Player ') || n.startsWith('Team '),
    );
    if (!allSeatsFilled) {
      SleekNotificationBanner.show(
        "Missing Names",
        "Please fill all the seats before starting.",
        icon: Icons.person_add_alt_1,
        color: Colors.orangeAccent,
      );
      return;
    }

    if (widget.gameType.toLowerCase() == 'wavelength') {
      int numTeams = _playerNames.length ~/ 2;
      for (int t = 1; t <= numTeams; t++) {
        int p1Idx = (t - 1) * 2;
        int p2Idx = p1Idx + 1;
        if (p2Idx < _playerNames.length) {
          if (_templateSettings['team_${t}_clueGiver'] == null) {
            setState(() {
              _templateSettings['showValidationError'] = true;
            });
            SleekNotificationBanner.show(
              "Missing Team Roles",
              "Please assign a First Clue Giver for all teams before starting.",
              icon: Icons.warning_amber_rounded,
              color: Colors.orangeAccent,
            );
            return;
          }
        }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Start Game?",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Are you ready to start scoring? You cannot add, remove, or modify players once the game begins.",
          style: TextStyle(color: Colors.white70),
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
              Navigator.pop(ctx);
              _executeStartScoring();
            },
            child: const Text(
              "START",
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

  void _executeStartScoring() {
    var initialRound = _template.createNewRound(1, _playerNames.length);
    if (widget.gameType.toLowerCase() == 'poker') {
      initialRound['buyIn'] = 2;
    }

    // Spades reads the bidding order from round 1 (also what rematches copy),
    // so carry the 1st/2nd bidder chosen in setup into it.
    if (widget.gameType.toLowerCase() == 'spades') {
      for (final key in ['firstBidder', 'secondBidder']) {
        final value = _templateSettings[key];
        if (value != null && _playerNames.contains(value)) {
          initialRound[key] = value;
        }
      }
    }

    if (widget.gameType.toLowerCase() == 'wavelength') {
      int numTeams = _playerNames.length ~/ 2;
      for (int t = 1; t <= numTeams; t++) {
        if (_templateSettings.containsKey('team_${t}_clueGiver')) {
          _templateSettings.remove('team_${t}_clueGiver');
        }
        if (_templateSettings.containsKey('team_${t}_guesser')) {
          initialRound['t${t}Guesser'] = _templateSettings['team_${t}_guesser'];
          _templateSettings.remove('team_${t}_guesser');
        }
      }
    }

    final scorecard = LocalScorecard(
      id: widget.customId,
      gameType: widget.gameType,
      groupName: widget.groupName,
      ownerType: widget.ownerType,
      ownerId: widget.ownerId,
      createdDate: DateTime.now(),
      lastUpdatedDate: DateTime.now(),
      playerNames: _playerNames,
      playerIds: _playerIds,
      rounds: [initialRound],
      isSynced: false,
      isFinalized: false,
      isLive: false,
      customSettings: _templateSettings,
    );

    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScoringScreen(
          gameType: widget.gameType,
          ownerType: widget.ownerType,
          ownerId: widget.ownerId,
          groupName: widget.groupName,
          existingCard: scorecard,
          customId: widget.customId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isVariablePlayers;
    bool canAddMore;
    bool canRemove;
    String entityLabel;
    String pLabel;

    if (widget.customSettings != null) {
      int minEntities = widget.customSettings!['minPlayers'] ?? 2;
      int maxEntities = widget.customSettings!['maxPlayers'] ?? 12;
      String mode = widget.customSettings!['gameMode'] ?? 'player';

      pLabel = mode == 'team' ? "Team" : "Player";
      entityLabel = mode == 'team' ? "Team" : "Seat";
      isVariablePlayers = minEntities < maxEntities;
      canAddMore = _playerNames.length < maxEntities;
      canRemove = _playerNames.length > minEntities;
    } else {
      isVariablePlayers =
          _template.canAddPlayer(_template.initialPlayerCount, []) ||
          _playerNames.length > _template.initialPlayerCount;
      canAddMore = _template.canAddPlayer(_playerNames.length, []);
      canRemove = _playerNames.length > _template.initialPlayerCount;
      bool isPairedTeamGame =
          widget.gameType.toLowerCase() == 'spades' ||
          widget.gameType.toLowerCase() == 'wavelength';
      entityLabel = isPairedTeamGame ? "Team" : "Seat";
      pLabel = "Player";
    }

    Widget? extraUI = _template.buildExtraAssignmentUI(
      context: context,
      setModalState: setState,
      playerNames: _playerNames,
      activePlayerIndex: _activeIndex,
      customSettings: _templateSettings,
      onSettingsChanged: (key, value) {
        setState(() => _templateSettings[key] = value);
      },
    );

    return Dialog(
      // Keeps the dialog a sensible size on desktop browsers.
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 560),
      backgroundColor: const Color(0xFF1E1E1E).withOpacity(0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
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
                    onPressed: () {
                      Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (context) => const ScorecardCreateDialog(),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      "Setup ${widget.gameType} Scorecard",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _buildSlotsVisual(),

              if (isVariablePlayers) ...[
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: canRemove
                          ? () {
                              setState(() {
                                _playerNames.removeLast();
                                _playerIds.removeLast();
                                if (widget.gameType.toLowerCase() ==
                                    'wavelength') {
                                  _playerNames.removeLast();
                                  _playerIds.removeLast();
                                }
                                if (_activeIndex >= _playerNames.length) {
                                  _activeIndex = _playerNames.length - 1;
                                  if (_activeIndex < 0) _activeIndex = 0;
                                  _updateManualController();
                                }
                              });
                            }
                          : null,
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: canRemove ? Colors.redAccent : Colors.white24,
                        size: 18,
                      ),
                      label: Text(
                        "Remove $entityLabel",
                        style: TextStyle(
                          color: canRemove ? Colors.redAccent : Colors.white24,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: canAddMore
                          ? () {
                              setState(() {
                                _playerNames.add(
                                  "$pLabel ${_playerNames.length + 1}",
                                );
                                _playerIds.add("");
                                if (widget.gameType.toLowerCase() ==
                                    'wavelength') {
                                  _playerNames.add(
                                    "$pLabel ${_playerNames.length + 1}",
                                  );
                                  _playerIds.add("");
                                }
                              });
                            }
                          : null,
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: canAddMore
                            ? const Color(0xFF00A2FF)
                            : Colors.white24,
                        size: 18,
                      ),
                      label: Text(
                        "Add $entityLabel",
                        style: TextStyle(
                          color: canAddMore
                              ? const Color(0xFF00A2FF)
                              : Colors.white24,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const Divider(color: Colors.white12, height: 40),

              if (widget.ownerType == 'group')
                _buildGroupSelectionPool()
              else
                _buildManualSelectionPool(),

              const SizedBox(height: 32),

              if (extraUI != null) ...[extraUI, const SizedBox(height: 16)],

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
                  onPressed: _confirmAndStartScoring,
                  child: const Text(
                    "START SCORING",
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
      ),
    );
  }
}
