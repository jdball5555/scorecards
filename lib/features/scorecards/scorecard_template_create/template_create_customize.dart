import 'package:flutter/material.dart';
import '../../../core/shared_widgets/gradient_background.dart';
import '../../../core/shared_widgets/white_frost_tile.dart';
import '../pages/scorecard_create.dart';
import '../../../core/layout/responsive.dart';
import 'package:scorecards_app/core/shared_widgets/top_bar_background.dart';

class TemplateCreateCustomize extends StatelessWidget {
  final Map<String, dynamic> customSettings;

  const TemplateCreateCustomize({super.key, required this.customSettings});

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context, {
            'action': 'update',
            'settings': customSettings,
          }),
        ),
        titleSpacing: 20,
        title: const Text(
          "Customize Template",
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
                    "VERSION CONTROL",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (customSettings['isPublished'] == true) ...[
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                        SizedBox(width: 6),
                        Text(
                          "A version of this template is published",
                          style: TextStyle(color: Colors.green, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text(
                    "Publishing will update the live version of this template available in your Create Scorecard menu. Your ongoing draft edits are safe until you decide to publish them.",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A2FF),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.cloud_upload, color: Colors.white),
                      label: const Text(
                        "PUBLISH CURRENT DRAFT",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF1E1E1E),
                            title: const Text(
                              "Publish Current Version?",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: const Text(
                              "This will immediately save and publish your current template draft to your Templates library. This version will be used for all future games until you publish again.",
                              style: TextStyle(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text(
                                  "Cancel",
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00A2FF),
                                ),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text(
                                  "PUBLISH",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true && context.mounted) {
                          Navigator.pop(context, {
                            'action': 'publish',
                            'settings': customSettings,
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            WhiteFrostTile(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "TEMPLATE INFO",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildRow(
                    "Game Name",
                    customSettings['gameType']?.toString() ?? "N/A",
                  ),
                  _buildRow(
                    "Game Mode",
                    customSettings['gameMode']?.toString().toUpperCase() ??
                        "N/A",
                  ),
                  _buildRow(
                    "Min Entities",
                    customSettings['minPlayers']?.toString() ?? "N/A",
                  ),
                  _buildRow(
                    "Max Entities",
                    customSettings['maxPlayers']?.toString() ?? "N/A",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            WhiteFrostTile(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "WIN CONDITIONS",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildRow(
                    "Condition",
                    _formatWinCondition(customSettings['winCondition']),
                  ),
                  if ((int.tryParse('${customSettings['targetValue']}') ?? 0) >
                      0)
                    _buildRow(
                      (customSettings['winCondition'] ?? '')
                              .toString()
                              .endsWith('_after_rounds')
                          ? "Rounds"
                          : "Target Score",
                      customSettings['targetValue'].toString(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            WhiteFrostTile(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "LAYOUT SETTINGS",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildRow(
                    "Inputs per Player",
                    (_layout['inputsPerPlayer'] ?? 1).toString(),
                  ),
                  _buildRow("Custom Columns", _countCustomColumns().toString()),
                  _buildRow("Custom Rows", _countCustomRows().toString()),
                  _buildRow(
                    "Total Row",
                    (_layout['showTotalRow'] ?? true) ? "Shown" : "Hidden",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.science, color: Colors.white),
                label: const Text(
                  "TEST MODE",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => ScorecardCreateDialog(
                      isTestMode: true,
                      prelockedCustomSettings: customSettings,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> get _layout =>
      Map<String, dynamic>.from(customSettings['layoutSettings'] ?? {});

  int _countCustomColumns() {
    final layout = _layout;
    final cols = [
      ...(layout['lockedLeftColumns'] as List? ?? []),
      ...(layout['blueprintColumns'] as List? ?? []),
      ...(layout['lockedRightColumns'] as List? ?? []),
    ];
    return cols.where((col) => col.toString() != 'player_core').length;
  }

  int _countCustomRows() {
    final rows = _layout['layoutRows'] as List? ?? [];
    return rows.where((r) => r.toString().startsWith('custom_row_')).length;
  }

  String _formatWinCondition(String? condition) {
    switch (condition) {
      case 'first_to_score':
        return 'First to reach a score';
      case 'highest_after_rounds':
        return 'Most points after locked rounds';
      case 'lowest_after_rounds':
        return 'Lowest score after locked rounds';
      case 'lowest_when_reached_score':
        return 'Lowest score when target reached';
      case 'highest_score':
        return 'Highest score (no limit)';
      case 'lowest_score':
        return 'Lowest score (no limit)';
      default:
        return condition ?? "Unknown";
    }
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white54, fontSize: 16),
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}
