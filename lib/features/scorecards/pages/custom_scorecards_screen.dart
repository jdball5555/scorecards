import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/shared_widgets/glass_card.dart';
import '../../../core/shared_widgets/gradient_background.dart';
import '../../../core/shared_widgets/sleek_notification_banner.dart';
import '../../../core/shared_widgets/game_request_link.dart';
import '../scorecard_template_create/template_create_screen.dart';
import '../scorecard_template_create/template_scorecard_editor.dart';
import '../pages/ai_template_scan_screen.dart';
import '../../../core/layout/responsive.dart';
import 'package:scorecards_app/core/shared_widgets/top_bar_background.dart';

class CustomScorecardsScreen extends StatefulWidget {
  const CustomScorecardsScreen({super.key});

  @override
  State<CustomScorecardsScreen> createState() => _CustomScorecardsScreenState();
}

class _CustomScorecardsScreenState extends State<CustomScorecardsScreen> {
  String _formatDateOnly(DateTime dt) {
    return "${dt.month}/${dt.day}/${dt.year}";
  }

  void _onTemplateTapped(Map<String, dynamic> templateData, String templateId) {
    final sourceData = templateData['draftSettings'] != null
        ? Map<String, dynamic>.from(templateData['draftSettings'])
        : Map<String, dynamic>.from(templateData);

    final customSettings = Map<String, dynamic>.from(sourceData);
    if (sourceData['layoutSettings'] != null) {
      customSettings.addAll(
        Map<String, dynamic>.from(sourceData['layoutSettings']),
      );
    }

    customSettings['gameType'] =
        templateData['templateName'] ??
        sourceData['gameType'] ??
        'Custom Scorecard';
    customSettings['isPublished'] = templateData['isPublished'] ?? false;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateScorecardEditor(
          customSettings: customSettings,
          templateId: templateId,
        ),
      ),
    );
  }

  void _showCreateOptionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Create Custom Scorecard",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Choose how you want to build your template",
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 20),
                GlassCard(
                  accentColor: const Color(0xFF00A2FF),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const TemplateCreateScreen(isGroupGame: false),
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_note_rounded,
                          color: Color(0xFF00A2FF),
                          size: 32,
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Manual Builder",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "Answer step-by-step setup questions",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white24,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GlassCard(
                  accentColor: const Color(0xFF7855C1),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AiTemplateScanScreen(),
                      ),
                    );
                  },
                  // REMOVED 'const' from the Padding below so the inner Container doesn't crash
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: Color(0xFF7855C1),
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    "Scan with AI",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF7855C1),
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(4),
                                      ),
                                    ),
                                    child: const Text(
                                      "NEW",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isRulebookScanSupported
                                    ? "Snap a picture of a rulebook or box"
                                    : "Available in the iPhone & Android app",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white24,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GameRequestLink(
                  label: "Rather we add a game for you? Request it",
                  onBeforeOpen: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteTemplate(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text(
              "Delete Template?",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          "This will permanently delete your custom template. Games using this template will not be affected. Are you sure?",
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "DELETE",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('scorecard_templates')
            .doc(id)
            .delete();
      } catch (e) {
        debugPrint("Error deleting template: $e");
        SleekNotificationBanner.show(
          "Delete Failed",
          "Couldn't delete that template. Please try again.",
          icon: Icons.error_outline,
          color: Colors.redAccent,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          title: const Text(
            "Custom Scorecards",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              fontSize: 24,
            ),
          ),
          flexibleSpace: const TopBarBackground(),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showCreateOptionsModal,
          backgroundColor: const Color(0xFF00A2FF),
          elevation: 4,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            "CREATE TEMPLATE",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: uid == null
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('scorecard_templates')
                      .where('creatorId', isEqualTo: uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          "Error loading templates.",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      );
                    }

                    final docs = List.of(snapshot.data?.docs ?? []);

                    docs.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aTime =
                          (aData['createdAt'] as Timestamp?)?.toDate() ??
                          DateTime(2000);
                      final bTime =
                          (bData['createdAt'] as Timestamp?)?.toDate() ??
                          DateTime(2000);
                      return bTime.compareTo(aTime);
                    });

                    if (docs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.style_outlined,
                                size: 64,
                                color: Colors.white38,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No Custom Scorecards Yet",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Tap 'CREATE TEMPLATE' in the bottom right to build manually or scan a rulebook with AI.",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        readableSide(context),
                        16,
                        readableSide(context),
                        100,
                      ),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final date =
                            (data['createdAt'] as Timestamp?)?.toDate() ??
                            DateTime.now();
                        final isPublished = data['isPublished'] == true;
                        // Older drafts only stored these inside draftSettings.
                        final summary = <String, dynamic>{
                          ...Map<String, dynamic>.from(
                            data['draftSettings'] ?? const {},
                          ),
                          ...data,
                        };
                        final mode = (summary['gameMode'] ?? 'player')
                            .toString()
                            .toUpperCase();
                        final minP = summary['minPlayers'] ?? 2;
                        final maxP = summary['maxPlayers'] ?? minP;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: GlassCard(
                            onTap: () => _onTemplateTapped(data, doc.id),
                            onLongPress: () => _deleteTemplate(doc.id),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Template Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                data['templateName'] ??
                                                    'Custom Template',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isPublished
                                                    ? Colors.green.withValues(
                                                        alpha: 0.2,
                                                      )
                                                    : Colors.orangeAccent
                                                          .withValues(
                                                            alpha: 0.2,
                                                          ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: isPublished
                                                      ? Colors.green
                                                      : Colors.orangeAccent,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                isPublished
                                                    ? "PUBLISHED"
                                                    : "DRAFT",
                                                style: TextStyle(
                                                  color: isPublished
                                                      ? Colors.green
                                                      : Colors.orangeAccent,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.0,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                "Mode: $mode",
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          minP == maxP
                                              ? "${mode == 'TEAM' ? 'Teams' : 'Players'}: $minP"
                                              : "${mode == 'TEAM' ? 'Teams' : 'Players'}: $minP - $maxP",
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Trailing Date + actions
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _formatDateOnly(date),
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 32,
                                        height: 32,
                                        child: PopupMenuButton<String>(
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(
                                            Icons.more_horiz,
                                            color: Colors.white54,
                                            size: 20,
                                          ),
                                          color: const Color(0xFF2C2C2C),
                                          onSelected: (v) {
                                            if (v == 'edit') {
                                              _onTemplateTapped(data, doc.id);
                                            } else if (v == 'delete') {
                                              _deleteTemplate(doc.id);
                                            }
                                          },
                                          itemBuilder: (_) => const [
                                            PopupMenuItem(
                                              value: 'edit',
                                              child: Text(
                                                "Edit",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Text(
                                                "Delete",
                                                style: TextStyle(
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }
}
