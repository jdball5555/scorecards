import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/shared_widgets/gradient_background.dart';
import '../../../core/shared_widgets/white_frost_tile.dart';
import '../providers/scorecard_filter_provider.dart';
import '../../../core/layout/responsive.dart';
import 'package:scorecards_app/core/shared_widgets/top_bar_background.dart';

class ScorecardCustomizeScreen extends ConsumerStatefulWidget {
  final List<String> availableGameTypes;
  final List<Map<String, dynamic>> userGroups;

  const ScorecardCustomizeScreen({
    super.key,
    required this.availableGameTypes,
    required this.userGroups,
  });

  @override
  ConsumerState<ScorecardCustomizeScreen> createState() =>
      _ScorecardCustomizeScreenState();
}

class _ScorecardCustomizeScreenState
    extends ConsumerState<ScorecardCustomizeScreen> {
  late String _tempScope;
  late int _tempTrendNumber;
  late String _tempTrendUnit;
  String? _tempGameType;
  bool _canPop = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final filterState = ref.read(scorecardFilterProvider);
    _tempScope = filterState.scope;
    _tempGameType = filterState.gameType;

    final tp = filterState.timePeriod;
    if (tp == 'All Time') {
      _tempTrendUnit = 'All Time';
      _tempTrendNumber = 30;
    } else if (tp == 'This Year') {
      _tempTrendUnit = 'Years';
      _tempTrendNumber = 1;
    } else if (tp.startsWith('Last ')) {
      final parts = tp.split(' ');
      if (parts.length >= 3) {
        _tempTrendNumber = int.tryParse(parts[1]) ?? 30;
        _tempTrendUnit = parts[2];
      } else {
        _tempTrendUnit = 'Days';
        _tempTrendNumber = 30;
      }
    } else {
      _tempTrendUnit = 'All Time';
      _tempTrendNumber = 30;
    }
  }

  String get _computedTimePeriod {
    if (_tempTrendUnit == 'All Time') return 'All Time';
    return 'Last $_tempTrendNumber $_tempTrendUnit';
  }

  bool _hasUnsavedChanges() {
    final filterState = ref.read(scorecardFilterProvider);
    return _tempScope != filterState.scope ||
        _computedTimePeriod != filterState.timePeriod ||
        _tempGameType != filterState.gameType;
  }

  Future<void> _saveAndPop() async {
    setState(() => _isSaving = true);

    // Simulate a brief delay to show the saving spinner for feedback
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      setState(() => _canPop = true);
      final filterNotifier = ref.read(scorecardFilterProvider.notifier);
      filterNotifier.setScope(_tempScope);
      filterNotifier.setTimePeriod(_computedTimePeriod);
      filterNotifier.setGameType(_tempGameType);
      Navigator.of(context).pop();
    }
  }

  Future<bool> _onWillPop() async {
    if (_canPop) return true;
    if (!_hasUnsavedChanges()) return true;

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
      return false; // already popped by _saveAndPop
    } else if (result == 'discard') {
      return true;
    }
    return false;
  }

  Widget _buildChip(
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
    return WillPopScope(
      onWillPop: _onWillPop,
      child: GradientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text(
              "Customize Filter",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontSize: 24,
              ),
            ),
            flexibleSpace: const TopBarBackground(),
          ),
          body: ListView(
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
                      "DATA SOURCE",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 12,
                      children: [
                        _buildChip(
                          "All Games",
                          _tempScope == 'All',
                          () => setState(() => _tempScope = 'All'),
                          icon: Icons.public,
                        ),
                        _buildChip(
                          "Personal Only",
                          _tempScope == 'Personal',
                          () => setState(() => _tempScope = 'Personal'),
                          icon: Icons.person,
                        ),
                        ...widget.userGroups.map((g) {
                          return _buildChip(
                            g['name'] ?? 'Unnamed Group',
                            _tempScope == g['id'],
                            () => setState(() => _tempScope = g['id']!),
                            icon: Icons.group,
                          );
                        }).toList(),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      "GAME TYPE",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 12,
                      children: [
                        _buildChip(
                          "All Games",
                          _tempGameType == null,
                          () => setState(() => _tempGameType = null),
                          icon: Icons.casino_outlined,
                        ),
                        ...widget.availableGameTypes.map((gt) {
                          return _buildChip(
                            gt,
                            _tempGameType == gt,
                            () => setState(() => _tempGameType = gt),
                            icon: Icons.casino_outlined,
                          );
                        }).toList(),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      "TIME PERIOD",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildChip(
                          'All Time',
                          _tempTrendUnit == 'All Time',
                          () => setState(() => _tempTrendUnit = 'All Time'),
                        ),
                        if (_tempTrendUnit != 'All Time')
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
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
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
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
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ...['Days', 'Months', 'Years'].map((unit) {
                          return _buildChip(
                            unit,
                            _tempTrendUnit == unit,
                            () => setState(() => _tempTrendUnit = unit),
                          );
                        }).toList(),
                      ],
                    ),
                  ],
                ),
              ),
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
      ),
    );
  }
}
