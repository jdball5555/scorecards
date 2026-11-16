import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/shared_widgets/gradient_background.dart';
import 'metrics_customize_screen.dart';
import 'specific_metrics_screen.dart';
import '../registry/metrics_registry.dart'; // --- NEW IMPORT ---
import '../models/metrics_models.dart';
import 'package:scorecards_app/core/shared_widgets/top_bar_background.dart';

class MetricsScreen extends StatefulWidget {
  final bool isEmbedded;
  final bool isLiveGame;

  const MetricsScreen({
    super.key,
    this.isEmbedded = false,
    this.isLiveGame = false,
  });

  @override
  State<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen> {
  static const Color _themeBlue = Color(0xFF00A2FF);

  bool _isLoading = true;
  bool _hasAppliedDefault = false;
  List<Map<String, dynamic>> _rawFetchedGames = [];
  List<Map<String, dynamic>> _allGames = [];
  List<Map<String, dynamic>> _userGroups = [];
  DateTime? _lastUpdatedAt;

  String _selectedScope = 'All';
  String _selectedPlayer = '';
  String _selectedGameType = 'Spades';
  List<String> _availableGameTypes = ['Spades', 'Yahtzee', 'Nerts', 'Nines'];
  String _compareMode = 'none';
  String _comparePlayer = '';
  int _trendNumber = 1;
  String _trendUnit = 'months';

  // Base setup, but now dynamically auto-filled by the Builder below!
  List<String> _tileOrder = ['gamesPlayed', 'winRate'];

  List<String> _hiddenTiles = [];
  List<String> _availablePlayers = [];
  List<Map<String, dynamic>> _globalGames = [];
  Timer? _liveTimer;

  @override
  void initState() {
    super.initState();
    _selectedPlayer =
        FirebaseAuth.instance.currentUser?.displayName ?? 'Player 1';
    _fetchData();

    if (widget.isEmbedded && widget.isLiveGame) {
      _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _fetchData(showLoading: false);
      });
    }
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData({bool showLoading = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (showLoading && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      Map<String, dynamic>? metricsDefault;
      if (!_hasAppliedDefault) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final userData = userDoc.data();
        if (userData != null && userData['metricsDefault'] is Map) {
          metricsDefault = Map<String, dynamic>.from(
            userData['metricsDefault'] as Map,
          );
        }
      }

      final groupSnap = await FirebaseFirestore.instance
          .collection('game_groups')
          .where('members', arrayContains: user.uid)
          .get();

      _userGroups = groupSnap.docs.map((d) {
        final data = d.data();
        return <String, dynamic>{'id': d.id, ...data};
      }).toList();

      final groupIds = _userGroups.map((g) => g['id'] as String).toList();

      if (!_hasAppliedDefault) {
        _applyMetricsDefault(metricsDefault);
        _hasAppliedDefault = true;
      }

      List<Map<String, dynamic>> fetchedGames = [];

      final personalSnap = await FirebaseFirestore.instance
          .collection('scorecards')
          .where('ownerType', isEqualTo: 'person')
          .where('ownerId', isEqualTo: user.uid)
          .get();

      fetchedGames.addAll(personalSnap.docs.map((d) => d.data()));

      if (groupIds.isNotEmpty) {
        for (var i = 0; i < groupIds.length; i += 10) {
          final chunk = groupIds.sublist(
            i,
            i + 10 > groupIds.length ? groupIds.length : i + 10,
          );
          final groupGamesSnap = await FirebaseFirestore.instance
              .collection('scorecards')
              .where('ownerType', isEqualTo: 'group')
              .where('ownerId', whereIn: chunk)
              .get();
          fetchedGames.addAll(groupGamesSnap.docs.map((d) => d.data()));
        }
      }

      Set<String> uniqueTypes = {'Spades', 'Yahtzee', 'Nerts', 'Nines'};
      for (var g in fetchedGames) {
        String gt = g['gameType']?.toString() ?? '';
        if (gt.isNotEmpty && gt != 'All') {
          uniqueTypes.add(gt);
        }
      }
      _availableGameTypes = uniqueTypes.toList()..sort();

      if (_selectedGameType == 'All' ||
          !_availableGameTypes.contains(_selectedGameType)) {
        _selectedGameType = _availableGameTypes.contains('Spades')
            ? 'Spades'
            : _availableGameTypes.first;
      }

      _rawFetchedGames = fetchedGames;
      _rawFetchedGames.sort((a, b) => _gameDate(b).compareTo(_gameDate(a)));

      _applyLocalFilters();
      _lastUpdatedAt = DateTime.now();
    } catch (e) {
      debugPrint("Error fetching metrics: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshMetrics() => _fetchData(showLoading: false);

  void _applyLocalFilters() {
    _globalGames = _rawFetchedGames
        .where((g) => g['isFinalized'] == true)
        .toList();

    _allGames = _rawFetchedGames.where((game) {
      bool isTargetGame = true;
      if (_selectedGameType != 'All') {
        final gameTypeStr = game['gameType']?.toString().toLowerCase() ?? '';
        if (gameTypeStr != _selectedGameType.toLowerCase()) {
          isTargetGame = false;
        }
      }

      if (widget.isEmbedded) {
        final isFinal = game['isFinalized'] == true;
        final isLiveGame = game['isLive'] == true;
        return isTargetGame && (isFinal || isLiveGame);
      } else {
        return isTargetGame && game['isFinalized'] == true;
      }
    }).toList();

    _updateAvailablePlayers();
  }

  void _applyMetricsDefault(Map<String, dynamic>? metricsDefault) {
    if (metricsDefault == null) return;

    final scope = metricsDefault['scope']?.toString();
    final groupIds = _userGroups.map((g) => g['id']?.toString()).toSet();
    if (scope == 'All' || scope == 'Personal' || groupIds.contains(scope)) {
      _selectedScope = scope!;
    }

    final player = metricsDefault['player']?.toString();
    if (player != null && player.trim().isNotEmpty) {
      _selectedPlayer = player.trim();
    }
    if (metricsDefault['gameType'] != null) {
      _selectedGameType = metricsDefault['gameType'].toString();
    }
    if (metricsDefault['compareMode'] != null) {
      _compareMode = metricsDefault['compareMode'].toString();
    }
    if (metricsDefault['comparePlayer'] != null) {
      _comparePlayer = metricsDefault['comparePlayer'].toString();
    }
    if (metricsDefault['trendNumber'] != null) {
      _trendNumber = metricsDefault['trendNumber'] as int;
    }
    if (metricsDefault['trendUnit'] != null) {
      _trendUnit = metricsDefault['trendUnit'].toString();
    }
    if (metricsDefault['tileOrder'] != null) {
      _tileOrder = List<String>.from(metricsDefault['tileOrder']);
    } else if (metricsDefault['visibleTiles'] != null) {
      _tileOrder = List<String>.from(metricsDefault['visibleTiles']);
      if (metricsDefault['hiddenTiles'] != null) {
        for (String hidden in List<String>.from(
          metricsDefault['hiddenTiles'],
        )) {
          if (!_tileOrder.contains(hidden)) {
            _tileOrder.add(hidden);
          }
        }
      }
    }
    if (metricsDefault['hiddenTiles'] != null) {
      _hiddenTiles = List<String>.from(metricsDefault['hiddenTiles']);
    }
  }

  Future<void> _saveMetricsDefault() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'metricsDefault': {
          'scope': _selectedScope,
          'player': _selectedPlayer,
          'gameType': _selectedGameType,
          'compareMode': _compareMode,
          'comparePlayer': _comparePlayer,
          'trendNumber': _trendNumber,
          'trendUnit': _trendUnit,
          'tileOrder': _tileOrder,
          'hiddenTiles': _hiddenTiles,
        },
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error saving metrics default: $e");
    }
  }

  void _updateAvailablePlayers() {
    Set<String> players = {};
    for (var game in _allGames) {
      if (_selectedScope != 'All') {
        if (_selectedScope == 'Personal' && game['ownerType'] != 'person') {
          continue;
        }
        if (_selectedScope != 'Personal' && game['ownerId'] != _selectedScope) {
          continue;
        }
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
        players.add("${t1[0]} & ${t1[1]}");
        players.add("${t2[0]} & ${t2[1]}");
      }
    }

    _availablePlayers = players.toList()..sort();
    if (!_availablePlayers.contains(_selectedPlayer) &&
        _selectedPlayer != 'Group Metrics' &&
        _selectedPlayer != 'Group Records' &&
        _availablePlayers.isNotEmpty) {
      _selectedPlayer = _availablePlayers.first;
    }
    if ((!_availablePlayers.contains(_comparePlayer) ||
            _comparePlayer == _selectedPlayer) &&
        _availablePlayers.length > 1) {
      _comparePlayer = _availablePlayers.firstWhere(
        (p) => p != _selectedPlayer,
        orElse: () => '',
      );
    }
  }

  List<String> _getPlayersToCompare() {
    if (_compareMode == 'none') {
      return [_selectedPlayer];
    }
    if (_compareMode == 'two') {
      List<String> players = [_selectedPlayer];
      if (_comparePlayer.isNotEmpty && _comparePlayer != _selectedPlayer) {
        players.add(_comparePlayer);
      }
      return players;
    }
    if (_compareMode == 'group') {
      bool isTeam = _selectedPlayer.contains(' & ');
      return _availablePlayers
          .where((p) => p.contains(' & ') == isTeam)
          .take(10)
          .toList();
    }
    return [_selectedPlayer];
  }

  List<Map<String, dynamic>> _getBaseFilteredGames(String playerName) {
    if (playerName == 'Group Metrics' || playerName == 'Group Records') {
      final filtered = _allGames.where((game) {
        if (_selectedScope != 'All') {
          if (_selectedScope == 'Personal' && game['ownerType'] != 'person') {
            return false;
          }
          if (_selectedScope != 'Personal' &&
              game['ownerId'] != _selectedScope) {
            return false;
          }
        }
        return true;
      }).toList();
      filtered.sort((a, b) => _gameDate(b).compareTo(_gameDate(a)));
      return filtered;
    }

    final filtered = _allGames.where((game) {
      if (_selectedScope != 'All') {
        if (_selectedScope == 'Personal' && game['ownerType'] != 'person')
          return false;
        if (_selectedScope != 'Personal' && game['ownerId'] != _selectedScope)
          return false;
      }
      List<String> pNames = List<String>.from(game['playerNames'] ?? []);
      if (playerName.contains(' & ')) {
        List<String> teamNames = playerName.split(' & ');
        if (teamNames.length == 2) {
          int p1Idx = pNames.indexOf(teamNames[0]);
          int p2Idx = pNames.indexOf(teamNames[1]);
          if (p1Idx != -1 && p2Idx != -1) {
            bool sameTeam =
                (p1Idx == 0 || p1Idx == 1) && (p2Idx == 0 || p2Idx == 1) ||
                (p1Idx == 2 || p1Idx == 3) && (p2Idx == 2 || p2Idx == 3);
            if (!sameTeam) return false;
          } else {
            return false;
          }
        } else {
          if (pNames.indexOf(playerName) == -1) return false;
        }
      } else {
        if (pNames.indexOf(playerName) == -1) return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) => _gameDate(b).compareTo(_gameDate(a)));
    return filtered;
  }

  // Each player's game lists, shared by every tile until the games or the
  // filters change (filtering + sorting all games once per tile, several
  // times over, was what made this page freeze).
  final Map<String, _PlayerGames> _playerGamesCache = {};
  Object? _playerGamesKey;

  _PlayerGames _gamesFor(String player) {
    final key = (
      _allGames,
      _globalGames,
      _selectedScope,
      _trendNumber,
      _trendUnit,
    );
    if (key != _playerGamesKey) {
      _playerGamesCache.clear();
      _playerGamesKey = key;
    }
    return _playerGamesCache.putIfAbsent(player, () {
      final base = _getBaseFilteredGames(player);
      return _PlayerGames(
        lifetime: base,
        current: _getGamesForPeriod(
          previous: false,
          player: player,
          base: base,
        ),
        previous: _getGamesForPeriod(
          previous: true,
          player: player,
          base: base,
        ),
      );
    });
  }

  List<Map<String, dynamic>> _getGamesForPeriod({
    required bool previous,
    required String player,
    List<Map<String, dynamic>>? base,
  }) {
    base ??= _getBaseFilteredGames(player);
    if (_trendUnit == 'games') {
      if (!previous) {
        return base.take(_trendNumber).toList();
      } else {
        return base.skip(_trendNumber).take(_trendNumber).toList();
      }
    } else {
      final now = DateTime.now();
      final start = _subtractUnit(now, _trendNumber, _trendUnit);
      if (!previous) {
        return base.where((g) => !_gameDate(g).isBefore(start)).toList();
      } else {
        final previousStart = _subtractUnit(start, _trendNumber, _trendUnit);
        return base
            .where(
              (g) =>
                  _gameDate(g).isBefore(start) &&
                  !_gameDate(g).isBefore(previousStart),
            )
            .toList();
      }
    }
  }

  DateTime _subtractUnit(DateTime date, int amount, String unit) {
    switch (unit) {
      case 'days':
        return date.subtract(Duration(days: amount));
      case 'months':
        return DateTime(
          date.year,
          date.month - amount,
          date.day,
          date.hour,
          date.minute,
          date.second,
        );
      case 'years':
        return DateTime(
          date.year - amount,
          date.month,
          date.day,
          date.hour,
          date.minute,
          date.second,
        );
      default:
        return date;
    }
  }

  DateTime _gameDate(Map<String, dynamic> game) {
    return _parseDate(game['createdDate'] ?? game['date']);
  }

  DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  String _formatUpdatedAt() {
    final updatedAt = _lastUpdatedAt;
    if (updatedAt == null) return "Not updated yet";
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = updatedAt.hour % 12 == 0 ? 12 : updatedAt.hour % 12;
    final minute = updatedAt.minute.toString().padLeft(2, '0');
    final period = updatedAt.hour >= 12 ? 'PM' : 'AM';
    return "Updated ${months[updatedAt.month - 1]} ${updatedAt.day}, $hour:$minute $period";
  }

  String _scopeDisplay() {
    if (_selectedScope == 'All') return 'All Groups';
    if (_selectedScope == 'Personal') return 'Personal';
    for (var g in _userGroups) {
      if (g['id'] == _selectedScope)
        return g['name']?.toString() ?? 'Unknown Group';
    }
    return 'Unknown Group';
  }

  Future<void> _openCustomizeScreen() async {
    final route = PageRouteBuilder<Map<String, dynamic>>(
      // Opaque so the page underneath isn't painted through this one
      // (on the website, the shared background shows instead).
      opaque: true,
      pageBuilder: (ctx, animation, secondaryAnimation) =>
          MetricsCustomizeScreen(
            scope: _selectedScope,
            player: _selectedPlayer,
            gameType: _selectedGameType,
            compareMode: _compareMode,
            comparePlayer: _comparePlayer,
            trendNumber: _trendNumber,
            trendUnit: _trendUnit,
            tileOrder: _tileOrder,
            hiddenTiles: _hiddenTiles,
            availablePlayers: _availablePlayers,
            userGroups: _userGroups,
            availableGameTypes: _availableGameTypes,
            isEmbedded: widget.isEmbedded,
            rawFetchedGames: _rawFetchedGames,
          ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return child;
      },
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );

    final result = await Navigator.push<Map<String, dynamic>>(context, route);

    if (result != null) {
      setState(() => _isLoading = true);

      setState(() {
        if (result.containsKey('scope')) _selectedScope = result['scope'];
        if (result.containsKey('player')) _selectedPlayer = result['player'];
        if (result.containsKey('gameType')) {
          _selectedGameType = result['gameType'];
        }
        if (result.containsKey('compareMode')) {
          _compareMode = result['compareMode'];
        }
        if (result.containsKey('comparePlayer')) {
          _comparePlayer = result['comparePlayer'];
        }
        if (result.containsKey('trendNumber')) {
          _trendNumber = result['trendNumber'];
        }
        if (result.containsKey('trendUnit')) _trendUnit = result['trendUnit'];
        if (result.containsKey('tileOrder')) {
          _tileOrder = List<String>.from(result['tileOrder']);
        }
        if (result.containsKey('hiddenTiles')) {
          _hiddenTiles = List<String>.from(result['hiddenTiles']);
        }
        _applyLocalFilters();
      });
      await _saveMetricsDefault();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildMetricCard({
    required String title,
    required List<PlayerMetricData> playersData,
    bool showInteractiveChevron = false,
    VoidCallback? onInfoTap,
    VoidCallback? onTap,
  }) {
    if (playersData.isEmpty) return const SizedBox.shrink();

    if (_compareMode == 'none' || playersData.length == 1) {
      final pd = playersData.first;
      return GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withOpacity(0.05),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 12,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 3,
                      height: 20,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: pd.benchmarkColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (onInfoTap != null) ...[
                                  const SizedBox(width: 2),
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: onInfoTap,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                        vertical: 4.0,
                                      ),
                                      child: Icon(
                                        Icons.info_outline,
                                        color: Colors.white.withOpacity(0.38),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (showInteractiveChevron) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white.withOpacity(0.38),
                              size: 20,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (pd.isGroupRecord) ...[
                      const Icon(
                        Icons.star,
                        color: Color(0xFF00A2FF),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: pd.benchmarkColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: pd.benchmarkColor.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        pd.primaryValue,
                        style: TextStyle(
                          color: pd.benchmarkColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 260;
                    Widget subtitles = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                pd.subtitle1,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.55),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (pd.subtitleInfo != null &&
                                pd.subtitleInfo!.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: const Color(0xFF1E1E1E),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      title: const Text(
                                        "Record Details",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      content: SingleChildScrollView(
                                        child: Text(
                                          pd.subtitleInfo!,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text(
                                            "Close",
                                            style: TextStyle(
                                              color: Color(0xFF00A2FF),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(6.0),
                                  child: Icon(
                                    Icons.info_outline,
                                    color: Colors.white.withOpacity(0.55),
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (pd.subtitle2 != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            pd.subtitle2!,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    );
                    Widget trends = Column(
                      crossAxisAlignment: isNarrow
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.end,
                      children: [
                        Text(
                          pd.trendText,
                          style: TextStyle(
                            color: pd.trendColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (!widget.isEmbedded) ...[
                          Text(
                            _allGames.isEmpty ? "No Data" : _formatUpdatedAt(),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.25),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    );
                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          subtitles,
                          const SizedBox(height: 8),
                          trends,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: subtitles),
                        const SizedBox(width: 12),
                        trends,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.05),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (onInfoTap != null) ...[
                    const SizedBox(width: 2),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onInfoTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        child: Icon(
                          Icons.info_outline,
                          color: Colors.white.withOpacity(0.38),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                  if (showInteractiveChevron) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withOpacity(0.38),
                      size: 20,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: IntrinsicHeight(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: playersData.asMap().entries.map((entry) {
                      int idx = entry.key;
                      PlayerMetricData pd = entry.value;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (idx > 0)
                            VerticalDivider(
                              width: 32,
                              thickness: 1,
                              color: Colors.white.withOpacity(0.06),
                            ),
                          Container(
                            constraints: const BoxConstraints(
                              minWidth: 100,
                              maxWidth: 150,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  pd.playerName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (pd.isGroupRecord) ...[
                                      const Icon(
                                        Icons.star,
                                        color: Color(0xFF00A2FF),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: pd.benchmarkColor.withOpacity(
                                          0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: pd.benchmarkColor.withOpacity(
                                            0.4,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        pd.primaryValue,
                                        style: TextStyle(
                                          color: pd.benchmarkColor,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  pd.trendText,
                                  style: TextStyle(
                                    color: pd.trendColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        pd.subtitle2 != null
                                            ? "${pd.subtitle1}\n${pd.subtitle2}"
                                            : pd.subtitle1,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.55),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          height: 1.3,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    if (pd.subtitleInfo != null &&
                                        pd.subtitleInfo!.isNotEmpty) ...[
                                      const SizedBox(width: 4),
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              backgroundColor: const Color(
                                                0xFF1E1E1E,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              title: const Text(
                                                "Record Details",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              content: SingleChildScrollView(
                                                child: Text(
                                                  pd.subtitleInfo!,
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    height: 1.5,
                                                  ),
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx),
                                                  child: const Text(
                                                    "Close",
                                                    style: TextStyle(
                                                      color: Color(0xFF00A2FF),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(6.0),
                                          child: Icon(
                                            Icons.info_outline,
                                            color: Colors.white.withOpacity(
                                              0.55,
                                            ),
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTileById(String tileId) {
    final provider = MetricsRegistry.getProvider(_selectedGameType);
    if (provider == null) return const SizedBox.shrink();

    final players = _getPlayersToCompare();
    List<PlayerMetricData> playersData = [];

    for (var p in players) {
      final games = _gamesFor(p);
      final lifetimeGames = games.lifetime;
      final currentTrendGames = games.current;
      final previousTrendGames = games.previous;

      playersData.add(
        provider.buildMetricData(
          context: context,
          tileId: tileId,
          playerName: p,
          lifetimeGames: lifetimeGames,
          currentTrendGames: currentTrendGames,
          previousTrendGames: previousTrendGames,
          globalGames: _globalGames,
          trendNumber: _trendNumber,
          trendUnit: _trendUnit,
        ),
      );
    }

    String compareSubtitle = "";
    if (_compareMode == 'none') {
      compareSubtitle = _selectedPlayer;
    } else if (_compareMode == 'two') {
      compareSubtitle = "$_selectedPlayer vs $_comparePlayer";
    } else if (_compareMode == 'group') {
      compareSubtitle = "Comparing Group";
    }

    final onTapCallback = _compareMode == 'none'
        ? provider.getOnTapCallback(
            context,
            tileId,
            _selectedPlayer,
            _gamesFor(_selectedPlayer).lifetime,
            _scopeDisplay(),
            _selectedGameType,
            compareSubtitle,
          )
        : null;

    return _buildMetricCard(
      title: provider.getTileTitle(tileId),
      playersData: playersData,
      showInteractiveChevron: onTapCallback != null,
      onInfoTap: provider.getInfoCallback(context, tileId),
      onTap: onTapCallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    String compareSubtitle = "";
    if (_compareMode == 'none') {
      compareSubtitle = _selectedPlayer;
    } else if (_compareMode == 'two') {
      compareSubtitle = "$_selectedPlayer vs $_comparePlayer";
    } else if (_compareMode == 'group') {
      compareSubtitle = "Comparing Group";
    }

    final provider = MetricsRegistry.getProvider(_selectedGameType);
    List<String> relevantTiles =
        provider?.getAvailableTileIds(_selectedPlayer) ?? [];

    // --- DYNAMICALLY INJECT MISSING TILES ---
    for (String id in relevantTiles) {
      if (!_tileOrder.contains(id)) {
        _tileOrder.add(id);
      }
    }

    List<String> tilesToDisplay = _tileOrder
        .where((t) => relevantTiles.contains(t) && !_hiddenTiles.contains(t))
        .toList();

    Widget bodyContent = _isLoading
        ? const Center(child: CircularProgressIndicator(color: _themeBlue))
        : RefreshIndicator(
            edgeOffset:
                MediaQuery.of(context).padding.top + kToolbarHeight + 40,
            color: _themeBlue,
            backgroundColor: const Color(0xFF1E1E1E),
            onRefresh: _refreshMetrics,
            child: ListView(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + kToolbarHeight + 60,
                left: 20,
                right: 20,
                bottom: 16,
              ),
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              children: [
                if (_allGames.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.query_stats,
                            size: 64,
                            color: Colors.white.withOpacity(0.2),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "No Finalized Games Found",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  ...tilesToDisplay.map((tileId) => _buildTileById(tileId)),
                ],
                const SizedBox(height: 100),
              ],
            ),
          );

    Widget scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: false,
        titleSpacing: 20,
        title: Row(
          children: [
            const Text(
              "Metrics",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontSize: 24,
              ),
            ),
            if (widget.isEmbedded && widget.isLiveGame) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.redAccent, width: 1),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.sensors, color: Colors.redAccent, size: 12),
                    SizedBox(width: 4),
                    Text(
                      "LIVE",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white70),
            tooltip: 'Customize Metrics',
            onPressed: _openCustomizeScreen,
          ),
          const SizedBox(width: 8),
        ],
        flexibleSpace: const TopBarBackground(),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openCustomizeScreen,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Text(
                  "${_scopeDisplay()}  •  $_selectedGameType  •  $compareSubtitle",
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: bodyContent,
    );

    Widget animatedScaffold = scaffold;
    final route = ModalRoute.of(context);
    final secondaryAnimation = route?.secondaryAnimation;
    if (secondaryAnimation != null) {
      animatedScaffold = AnimatedBuilder(
        animation: secondaryAnimation,
        builder: (context, child) => Opacity(
          opacity: (1.0 - secondaryAnimation.value).clamp(0.0, 1.0),
          child: child,
        ),
        child: scaffold,
      );
    }

    return widget.isEmbedded
        ? animatedScaffold
        : GradientBackground(child: animatedScaffold);
  }
}

class _PlayerGames {
  final List<Map<String, dynamic>> lifetime;
  final List<Map<String, dynamic>> current;
  final List<Map<String, dynamic>> previous;
  const _PlayerGames({
    required this.lifetime,
    required this.current,
    required this.previous,
  });
}
