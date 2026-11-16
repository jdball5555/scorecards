import 'package:flutter/material.dart';
import '../../../core/shared_widgets/gradient_background.dart';
import '../../../core/shared_widgets/white_frost_tile.dart';
import '../registry/metrics_registry.dart';
import '../../../core/layout/responsive.dart';
import 'package:scorecards_app/core/shared_widgets/top_bar_background.dart';

class MetricsCustomizeScreen extends StatefulWidget {
  final String scope;
  final String player;
  final String gameType;
  final String compareMode;
  final String comparePlayer;
  final int trendNumber;
  final String trendUnit;
  final List<String> tileOrder;
  final List<String> hiddenTiles;
  final List<String> availablePlayers;
  final List<Map<String, dynamic>> userGroups;
  final List<String> availableGameTypes;
  final List<Map<String, dynamic>> rawFetchedGames;
  final bool isEmbedded;

  const MetricsCustomizeScreen({
    super.key,
    required this.scope,
    required this.player,
    required this.gameType,
    required this.compareMode,
    required this.comparePlayer,
    required this.trendNumber,
    required this.trendUnit,
    required this.tileOrder,
    required this.hiddenTiles,
    required this.availablePlayers,
    required this.userGroups,
    required this.availableGameTypes,
    required this.rawFetchedGames,
    this.isEmbedded = false,
  });

  @override
  State<MetricsCustomizeScreen> createState() => _MetricsCustomizeScreenState();
}

class _MetricsCustomizeScreenState extends State<MetricsCustomizeScreen> {
  late String _tempScope;
  late String _tempPlayer;
  late String _tempGameType;
  late String _tempCompareMode;
  late String _tempComparePlayer;
  late int _tempTrendNumber;
  late String _tempTrendUnit;
  late List<String> _allTiles;
  late Map<String, bool> _tileVisibility;

  late List<String> _tempAvailablePlayers;
  late List<String> _tempAvailableTeams;

  late bool _isInit = false;
  bool _canPop = false;
  bool _isSaving = false;

  late String _targetCategory;

  @override
  void initState() {
    super.initState();
    _tempScope = widget.scope;
    _tempPlayer = widget.player;
    _tempGameType = widget.gameType;
    _tempCompareMode = widget.compareMode;
    _tempComparePlayer = widget.comparePlayer;
    _tempTrendNumber = widget.trendNumber.clamp(1, 100);

    _tempTrendUnit = widget.trendUnit.isNotEmpty
        ? widget.trendUnit[0].toUpperCase() +
              widget.trendUnit.substring(1).toLowerCase()
        : 'Games';

    _allTiles = List.from(widget.tileOrder);
    _tileVisibility = {
      for (var id in _allTiles) id: !widget.hiddenTiles.contains(id),
    };

    _tempAvailablePlayers = [];
    _tempAvailableTeams = [];
    _updateTempAvailablePlayers(init: true);
  }

  bool _hasDataForScope(String scope) {
    return widget.rawFetchedGames.any((game) {
      if (scope == 'All') return true;
      if (scope == 'Personal') return game['ownerType'] == 'person';
      return game['ownerId'] == scope;
    });
  }

  void _updateTempAvailablePlayers({bool init = false}) {
    Set<String> players = {};
    Set<String> teams = {};

    final filteredGames = widget.rawFetchedGames.where((game) {
      if (_tempGameType == 'All') return true;
      return (game['gameType']?.toString().toLowerCase() ?? '') ==
          _tempGameType.toLowerCase();
    });

    for (var game in filteredGames) {
      if (_tempScope != 'All') {
        if (_tempScope == 'Personal' && game['ownerType'] != 'person') continue;
        if (_tempScope != 'Personal' && game['ownerId'] != _tempScope) continue;
      }

      List<dynamic> pNames = game['playerNames'] ?? [];
      for (var name in pNames) {
        players.add(name.toString().trim());
      }

      if ((game['gameType']?.toString().toLowerCase() ?? '') == 'spades' &&
          pNames.length >= 4) {
        List<String> t1 = [
          pNames[0].toString().trim(),
          pNames[1].toString().trim(),
        ]..sort();
        List<String> t2 = [
          pNames[2].toString().trim(),
          pNames[3].toString().trim(),
        ]..sort();
        teams.add("${t1[0]} & ${t1[1]}");
        teams.add("${t2[0]} & ${t2[1]}");
      }
    }

    setState(() {
      _tempAvailablePlayers = players.toList()..sort();
      _tempAvailableTeams = teams.toList()..sort();

      if (init) {
        if (_tempPlayer == 'Group Metrics') {
          _targetCategory = 'General';
        } else if (_tempPlayer == 'Group Records') {
          _targetCategory = 'Records';
        } else if (_tempPlayer.contains(' & ') &&
            _tempAvailableTeams.contains(_tempPlayer)) {
          _targetCategory = 'Teams';
        } else {
          _targetCategory = 'Players';
        }
      } else {
        if (_targetCategory == 'Players' &&
            !_tempAvailablePlayers.contains(_tempPlayer)) {
          _tempPlayer = _tempAvailablePlayers.isNotEmpty
              ? _tempAvailablePlayers.first
              : '';
        } else if (_targetCategory == 'Teams' &&
            !_tempAvailableTeams.contains(_tempPlayer)) {
          _tempPlayer = _tempAvailableTeams.isNotEmpty
              ? _tempAvailableTeams.first
              : '';
        }
      }
    });
  }

  bool _hasUnsavedChanges() {
    if (_tempScope != widget.scope) return true;
    if (_tempPlayer != widget.player) return true;
    if (_tempGameType != widget.gameType) return true;
    if (_tempCompareMode != widget.compareMode) return true;
    if (_tempComparePlayer != widget.comparePlayer) return true;
    if (_tempTrendNumber != widget.trendNumber) return true;
    if (_tempTrendUnit.toLowerCase() != widget.trendUnit.toLowerCase())
      return true;

    final newHidden = _allTiles
        .where((id) => _tileVisibility[id] == false)
        .toList();
    if (newHidden.length != widget.hiddenTiles.length) return true;
    for (var h in newHidden) {
      if (!widget.hiddenTiles.contains(h)) return true;
    }

    if (_allTiles.length != widget.tileOrder.length) return true;
    for (int i = 0; i < _allTiles.length; i++) {
      if (_allTiles[i] != widget.tileOrder[i]) return true;
    }

    return false;
  }

  Future<void> _handlePop() async {
    if (!_hasUnsavedChanges()) {
      setState(() => _canPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Unsaved Changes",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "You have unsaved changes. Do you want to save them?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text(
              "Discard",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A2FF),
            ),
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text(
              "Save",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == 'save') {
      _saveAndPop();
    } else if (result == 'discard') {
      setState(() => _canPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  void _saveAndPop() {
    if (_canPop) return;
    setState(() {
      _canPop = true;
      _isSaving = true;
    });

    final newHidden = _allTiles
        .where((id) => _tileVisibility[id] == false)
        .toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.pop(context, {
          'scope': _tempScope,
          'player': _tempPlayer,
          'gameType': _tempGameType,
          'compareMode': _tempCompareMode,
          'comparePlayer': _tempComparePlayer,
          'trendNumber': _tempTrendNumber > 0 ? _tempTrendNumber : 1,
          'trendUnit': _tempTrendUnit.toLowerCase(),
          'tileOrder': _allTiles,
          'hiddenTiles': newHidden,
        });
      }
    });
  }

  List<String> _getRelevantTiles(String gameType, String playerName) {
    final provider = MetricsRegistry.getProvider(gameType);
    return provider?.getAvailableTileIds(playerName) ?? [];
  }

  Widget _buildSelectionChip(
    String label,
    bool isSelected,
    VoidCallback onTap, {
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00A2FF).withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00A2FF)
                : Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? const Color(0xFF00A2FF) : Colors.white54,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF00A2FF) : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final headerStyle = const TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w500,
    );

    bool hasData = _hasDataForScope(_tempScope);

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
          onPressed: _handlePop,
        ),
        title: const Text(
          "Customize Metrics",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            fontSize: 24,
          ),
        ),
        flexibleSpace: const TopBarBackground(),
      ),
      body: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
        child: ListView(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 20,
            left: readableSide(context),
            right: readableSide(context),
            bottom: 40,
          ),
          children: [
            WhiteFrostTile(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "CONFIGURATION",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text("Data Source", style: headerStyle),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildSelectionChip("All Games", _tempScope == 'All', () {
                        setState(() {
                          _tempScope = 'All';
                          _updateTempAvailablePlayers();
                        });
                      }, icon: Icons.public),
                      _buildSelectionChip(
                        "Personal Only",
                        _tempScope == 'Personal',
                        () {
                          setState(() {
                            _tempScope = 'Personal';
                            _updateTempAvailablePlayers();
                          });
                        },
                        icon: Icons.person,
                      ),
                      ...widget.userGroups.map(
                        (g) => _buildSelectionChip(
                          g['name'] ?? 'Unnamed Group',
                          _tempScope == g['id'],
                          () {
                            setState(() {
                              _tempScope = g['id']!;
                              _updateTempAvailablePlayers();
                            });
                          },
                          icon: Icons.group,
                        ),
                      ),
                    ],
                  ),

                  if (!hasData) ...[
                    const SizedBox(height: 40),
                    Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.folder_off_outlined,
                            color: Colors.white24,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "No data available for this source.",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ] else ...[
                    const SizedBox(height: 24),

                    Text("Game Type", style: headerStyle),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.availableGameTypes
                          .map(
                            (type) => _buildSelectionChip(
                              type,
                              _tempGameType == type,
                              () {
                                setState(() {
                                  _tempGameType = type;
                                  _updateTempAvailablePlayers();
                                });
                              },
                              icon: Icons.casino_outlined,
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 24),

                    Text("Target View", style: headerStyle),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildSelectionChip(
                          "General",
                          _targetCategory == 'General',
                          () {
                            setState(() {
                              _targetCategory = 'General';
                              _tempPlayer = 'Group Metrics';
                              _tempCompareMode = 'none';
                            });
                          },
                          icon: Icons.analytics,
                        ),
                        _buildSelectionChip(
                          "Records",
                          _targetCategory == 'Records',
                          () {
                            setState(() {
                              _targetCategory = 'Records';
                              _tempPlayer = 'Group Records';
                              _tempCompareMode = 'none';
                            });
                          },
                          icon: Icons.emoji_events,
                        ),
                        _buildSelectionChip(
                          "Players",
                          _targetCategory == 'Players',
                          () {
                            setState(() {
                              _targetCategory = 'Players';
                              _tempPlayer = _tempAvailablePlayers.isNotEmpty
                                  ? _tempAvailablePlayers.first
                                  : '';
                            });
                          },
                          icon: Icons.person_pin_outlined,
                        ),
                        if (_tempAvailableTeams.isNotEmpty)
                          _buildSelectionChip(
                            "Teams",
                            _targetCategory == 'Teams',
                            () {
                              setState(() {
                                _targetCategory = 'Teams';
                                _tempPlayer = _tempAvailableTeams.isNotEmpty
                                    ? _tempAvailableTeams.first
                                    : '';
                              });
                            },
                            icon: Icons.groups,
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    if (_targetCategory == 'Players' ||
                        _targetCategory == 'Teams') ...[
                      Row(
                        children: [
                          Text("Compare Mode", style: headerStyle),
                          const SizedBox(width: 12),
                          Switch(
                            value: _tempCompareMode != 'none',
                            activeColor: const Color(0xFF00A2FF),
                            activeTrackColor: const Color(
                              0xFF00A2FF,
                            ).withOpacity(0.3),
                            inactiveThumbColor: Colors.white54,
                            inactiveTrackColor: Colors.white10,
                            onChanged: (val) {
                              setState(() {
                                if (val) {
                                  _tempCompareMode = 'two';
                                } else {
                                  _tempCompareMode = 'none';
                                }
                              });
                            },
                          ),
                        ],
                      ),

                      if (_tempCompareMode != 'none') ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildSelectionChip(
                              _targetCategory == 'Teams'
                                  ? "Vs. Team"
                                  : "Vs. Player",
                              _tempCompareMode == 'two',
                              () => setState(() => _tempCompareMode = 'two'),
                              icon: Icons.swap_horiz_rounded,
                            ),
                            _buildSelectionChip(
                              "Vs. Entire Group",
                              _tempCompareMode == 'group',
                              () => setState(() => _tempCompareMode = 'group'),
                              icon: Icons.all_inclusive_rounded,
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),

                      if (_tempCompareMode == 'none') ...[
                        Text(
                          _targetCategory == 'Teams'
                              ? "Select Team"
                              : "Select Player",
                          style: headerStyle,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              (_targetCategory == 'Teams'
                                      ? _tempAvailableTeams
                                      : _tempAvailablePlayers)
                                  .map(
                                    (p) => _buildSelectionChip(
                                      p,
                                      _tempPlayer == p,
                                      () => setState(() => _tempPlayer = p),
                                    ),
                                  )
                                  .toList(),
                        ),
                        const SizedBox(height: 24),
                      ] else if (_tempCompareMode == 'two') ...[
                        Text(
                          _targetCategory == 'Teams'
                              ? "Select Base Team"
                              : "Select Base Player",
                          style: headerStyle,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              (_targetCategory == 'Teams'
                                      ? _tempAvailableTeams
                                      : _tempAvailablePlayers)
                                  .map(
                                    (p) => _buildSelectionChip(
                                      p,
                                      _tempPlayer == p,
                                      () => setState(() => _tempPlayer = p),
                                    ),
                                  )
                                  .toList(),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _targetCategory == 'Teams'
                              ? "Select Compare Team"
                              : "Select Compare Player",
                          style: headerStyle,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              (_targetCategory == 'Teams'
                                      ? _tempAvailableTeams
                                      : _tempAvailablePlayers)
                                  .map(
                                    (p) => _buildSelectionChip(
                                      p,
                                      _tempComparePlayer == p,
                                      () => setState(
                                        () => _tempComparePlayer = p,
                                      ),
                                      icon: _targetCategory == 'Teams'
                                          ? Icons.groups
                                          : Icons.person_outline,
                                    ),
                                  )
                                  .toList(),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ],

                    Text("Trend Calculation Window", style: headerStyle),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.15),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: _tempTrendNumber > 1
                                    ? () => setState(() => _tempTrendNumber--)
                                    : null,
                                child: const Icon(
                                  Icons.remove,
                                  color: Colors.white54,
                                  size: 20,
                                ),
                              ),
                              Container(
                                constraints: const BoxConstraints(minWidth: 44),
                                child: Text(
                                  "$_tempTrendNumber",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              GestureDetector(
                                onTap: _tempTrendNumber < 100
                                    ? () => setState(() => _tempTrendNumber++)
                                    : null,
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),

                        ...['Days', 'Months', 'Years', 'Games'].map((unit) {
                          return _buildSelectionChip(
                            unit,
                            _tempTrendUnit == unit,
                            () => setState(() => _tempTrendUnit = unit),
                          );
                        }).toList(),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            if (hasData) ...[
              const SizedBox(height: 24),
              WhiteFrostTile(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "METRIC TILES",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        final relevantTiles = _getRelevantTiles(
                          _tempGameType,
                          _tempPlayer,
                        );

                        for (var id in relevantTiles) {
                          if (!_allTiles.contains(id)) {
                            _allTiles.add(id);
                            _tileVisibility[id] = !widget.hiddenTiles.contains(
                              id,
                            );
                          }
                        }

                        final displayTiles = _allTiles
                            .where((id) => relevantTiles.contains(id))
                            .toList();

                        final provider = MetricsRegistry.getProvider(
                          _tempGameType,
                        );

                        return Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(canvasColor: Colors.transparent),
                          child: ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            buildDefaultDragHandles: false,
                            itemCount: displayTiles.length,
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                if (newIndex > oldIndex) newIndex -= 1;
                                final item = displayTiles[oldIndex];
                                _allTiles.remove(item);
                                final insertIndex =
                                    newIndex < displayTiles.length
                                    ? _allTiles.indexOf(displayTiles[newIndex])
                                    : _allTiles.length;
                                _allTiles.insert(insertIndex, item);
                              });
                            },
                            itemBuilder: (ctx, i) {
                              final id = displayTiles[i];
                              final isVisible = _tileVisibility[id] ?? false;

                              final titleText =
                                  provider?.getTileTitle(id) ?? id;

                              return Container(
                                key: ValueKey("tile_$id"),
                                decoration: BoxDecoration(
                                  border: i < displayTiles.length - 1
                                      ? const Border(
                                          bottom: BorderSide(
                                            color: Colors.white24,
                                            width: 1,
                                          ),
                                        )
                                      : null,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4.0,
                                  ),
                                  child: Row(
                                    children: [
                                      ReorderableDragStartListener(
                                        index: i,
                                        child: const Padding(
                                          padding: EdgeInsets.only(
                                            right: 16.0,
                                            top: 8.0,
                                            bottom: 8.0,
                                          ),
                                          child: Icon(
                                            Icons.drag_handle,
                                            color: Colors.white54,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          titleText,
                                          style: headerStyle,
                                        ),
                                      ),
                                      Switch(
                                        value: isVisible,
                                        activeColor: const Color(0xFF00A2FF),
                                        activeTrackColor: const Color(
                                          0xFF00A2FF,
                                        ).withOpacity(0.3),
                                        inactiveThumbColor: Colors.white54,
                                        inactiveTrackColor: Colors.white10,
                                        onChanged: (bool newValue) => setState(
                                          () => _tileVisibility[id] = newValue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: (_hasUnsavedChanges() && !_isSaving)
                  ? _saveAndPop
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A2FF),
                disabledBackgroundColor: Colors.white.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      "Save Changes",
                      style: TextStyle(
                        color: _hasUnsavedChanges()
                            ? Colors.white
                            : Colors.white54,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );

    return PopScope(
      canPop: _canPop,
      onPopInvoked: (didPop) {
        if (!didPop) _handlePop();
      },
      child: widget.isEmbedded ? scaffold : GradientBackground(child: scaffold),
    );
  }
}
