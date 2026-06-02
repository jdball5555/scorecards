import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/shared_widgets/white_frost_tile.dart';
import '../providers/mail_provider.dart';
import '../providers/notification_settings_provider.dart';
import 'mail_inbox_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _showEditNameDialog(User user) async {
    final TextEditingController nameController = TextEditingController(
      text: user.displayName,
    );
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Edit Display Name",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: nameController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: "New Name",
              labelStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF00A2FF)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A2FF),
              ),
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty && newName != user.displayName) {
                  await user.updateDisplayName(newName);
                  await user.reload();
                  setState(() {});

                  if (context.mounted) {
                    Navigator.pop(dialogContext);
                  }
                }
              },
              child: const Text(
                "Save",
                style: TextStyle(
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
    final user = FirebaseAuth.instance.currentUser;

    final notifState =
        ref.watch(mailNotificationProvider).value ?? {'unread': 0, 'action': 0};
    final actionCount = notifState['action'] ?? 0;
    final unreadCount = notifState['unread'] ?? 0;
    final totalCount = actionCount + unreadCount;
    final hasAction = actionCount > 0;

    final settingsState = ref.watch(notificationSettingsProvider).value ?? {};
    final inAppBannerEnabled = settingsState['in_app_banner'] ?? true;

    // --- OS PUSH NOTIFICATIONS MASTER LIST ---
    final List<Map<String, String>> notificationOptions = [
      {'key': 'invite_received', 'title': 'Invited to a Group'},
      {'key': 'removed_from_group', 'title': 'You Are Removed From a Group'},
      {'key': 'group_deleted', 'title': 'Group Gets Deleted'},
      {'key': 'new_player_added', 'title': 'Player Added to Group'},
      {'key': 'player_removed', 'title': 'Player Removed From Group'},
      {'key': 'player_left', 'title': 'Player Leaves Group'}, // NEW TOGGLE
      {'key': 'new_player_linked', 'title': 'New Player Linked in a Group'},
      {'key': 'invite_accepted', 'title': 'User Accepts Your Invite'},
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Settings",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ).copyWith(bottom: 120),
        physics: const BouncingScrollPhysics(),
        children: [
          WhiteFrostTile(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "ACCOUNT",
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
                  onTap: user != null ? () => _showEditNameDialog(user) : null,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          user?.displayName ?? "Set Display Name",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Icon(Icons.edit, color: Colors.white54, size: 20),
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Divider(color: Colors.white24, height: 1),
                ),

                Text(
                  user?.email ?? "No Email",
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Divider(color: Colors.white24, height: 1),
                ),

                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                  child: const Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Sign Out",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(Icons.logout, color: Colors.redAccent, size: 20),
                    ],
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
                  "PREFERENCES",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          "In-App Banner for New Mail",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Switch(
                        value: inAppBannerEnabled,
                        activeColor: const Color(0xFF00A2FF),
                        activeTrackColor: const Color(
                          0xFF00A2FF,
                        ).withOpacity(0.3),
                        inactiveThumbColor: Colors.white54,
                        inactiveTrackColor: Colors.white10,
                        onChanged: (bool newValue) {
                          NotificationSettingsController.toggleSetting(
                            'in_app_banner',
                            newValue,
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Divider(color: Colors.white24, height: 1),
                ),

                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings: const RouteSettings(name: '/mail_inbox'),
                        builder: (_) => MailInboxScreen(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Badge(
                          isLabelVisible: totalCount > 0,
                          backgroundColor: hasAction
                              ? const Color(0xFF00A2FF)
                              : Colors.white,
                          textColor: hasAction ? Colors.white : Colors.black,
                          child: const Icon(
                            Icons.mail_outline,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            "Mail Box",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (totalCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: hasAction
                                  ? const Color(0xFF00A2FF)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              totalCount.toString(),
                              style: TextStyle(
                                color: hasAction ? Colors.white : Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right, color: Colors.white54),
                      ],
                    ),
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
                  "PUSH NOTIFICATIONS",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),

                ...notificationOptions.map((option) {
                  final key = option['key']!;
                  final isToggled = settingsState[key] ?? true;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                option['title']!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Switch(
                              value: isToggled,
                              activeColor: const Color(0xFF00A2FF),
                              activeTrackColor: const Color(
                                0xFF00A2FF,
                              ).withOpacity(0.3),
                              inactiveThumbColor: Colors.white54,
                              inactiveTrackColor: Colors.white10,
                              onChanged: (bool newValue) {
                                NotificationSettingsController.toggleSetting(
                                  key,
                                  newValue,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      if (option != notificationOptions.last)
                        const Divider(color: Colors.white24, height: 1),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
