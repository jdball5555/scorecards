import 'package:scorecards_app/core/shared_widgets/sleek_notification_banner.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/shared_widgets/gradient_background.dart';
import '../../../core/shared_widgets/white_frost_tile.dart';
import '../../../services/group_service.dart';
import '../../../core/layout/responsive.dart';
import 'package:scorecards_app/core/shared_widgets/top_bar_background.dart';

class GroupsCustomizeScreen extends StatefulWidget {
  const GroupsCustomizeScreen({super.key});

  @override
  State<GroupsCustomizeScreen> createState() => _GroupsCustomizeScreenState();
}

class _GroupsCustomizeScreenState extends State<GroupsCustomizeScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final GroupService _groupService = GroupService();

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

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
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
            "Customize Groups",
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
                    "ACTIONS",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _showTextInputDialog(
                        title: "New Game Group",
                        label: "Group Name",
                        buttonText: "Create",
                        onSubmit: (name) async {
                          if (currentUser == null) return;
                          try {
                            await _groupService.createGroup(
                              name,
                              currentUser!.uid,
                            );
                            SleekNotificationBanner.show(
                              'Group Created',
                              '$name is ready. Add your players to it.',
                              icon: Icons.check_circle,
                              color: const Color(0xFF00A2FF),
                            );
                          } catch (e) {
                            SleekNotificationBanner.show(
                              "Couldn't create group",
                              e.toString(),
                              icon: Icons.error_outline,
                              color: Colors.redAccent,
                            );
                          }
                        },
                      );
                    },
                    child: const Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Create New Group",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Icon(Icons.add, color: Colors.white54),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
