import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/group_service.dart';
import '../../../core/shared_widgets/sleek_notification_banner.dart';
import 'groups_customize_screen.dart';
import '../../../core/layout/responsive.dart';
import 'package:scorecards_app/core/shared_widgets/top_bar_background.dart';
import 'package:flutter/services.dart';
import '../player_invite.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final GroupService _groupService = GroupService();

  final Map<String, Map<String, dynamic>> _userCache = {};

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
    return {'displayName': 'Unknown Player', 'email': 'No email'};
  }

  /// Runs a group action and shows what happened. Failures (no connection,
  /// no permission...) used to be silent, which looked like dead buttons.
  Future<void> _run(
    Future<void> Function() action, {
    String? successTitle,
    String? successMessage,
  }) async {
    try {
      await action();
      if (successTitle != null) {
        SleekNotificationBanner.show(
          successTitle,
          successMessage ?? '',
          icon: Icons.check_circle,
          color: const Color(0xFF00A2FF),
        );
      }
    } catch (e) {
      debugPrint('Group action failed: $e');
      SleekNotificationBanner.show(
        "Couldn't do that",
        _friendlyError(e),
        icon: Icons.error_outline,
        color: Colors.redAccent,
      );
    }
  }

  String _friendlyError(Object e) {
    final text = e.toString();
    if (text.contains('permission-denied')) {
      return "You don't have permission to change this group.";
    }
    if (text.contains('unavailable') || text.contains('network')) {
      return 'No connection. Check your internet and try again.';
    }
    return text.replaceFirst(RegExp(r'^\[[^\]]*\]\s*'), '');
  }

  /// A player's options: a bottom sheet on phones, a centered dialog on the
  /// website (a sheet at the bottom of a big window is easy to miss).
  void _showPlayerOptions(Widget Function(BuildContext ctx) builder) {
    if (isWideLayout(context)) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            // Scrolls in short windows instead of overflowing.
            child: SingleChildScrollView(child: builder(ctx)),
          ),
        ),
      );
      return;
    }
    // Sheets are capped at about half the screen unless they ask for more;
    // with all the options it overflowed (yellow/black stripes) on phones.
    // Let it grow, and scroll if it still doesn't fit.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SingleChildScrollView(child: builder(ctx)),
    );
  }

  Future<void> _showTextInputDialog({
    required String title,
    required String label,
    required String buttonText,
    String initialValue = "",
    required Function(String) onSubmit,
  }) async {
    final TextEditingController controller = TextEditingController(
      text: initialValue,
    );
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

  Future<void> _showEmailInputDialog({
    required String groupId,
    required String groupName,
    String? localPlayerIdToReplace,
    String? localPlayerNameToReplace,
  }) async {
    final TextEditingController controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Link Account",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (localPlayerNameToReplace != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    "Enter the email of their Scorecards account. "
                    "Once linked, $localPlayerNameToReplace becomes that "
                    "account and their past games in $groupName move to it.",
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Player's Email Address",
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF00A2FF)),
                  ),
                ),
              ),
            ],
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
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(dialogContext);

                  String result;
                  try {
                    result = await _groupService.sendInvite(
                      groupId,
                      groupName,
                      controller.text,
                      currentUser?.displayName ?? "A player",
                      localPlayerIdToReplace: localPlayerIdToReplace,
                      localPlayerNameToReplace: localPlayerNameToReplace,
                    );
                  } catch (e) {
                    result = _friendlyError(e);
                  }

                  final ok = result == "Success" || result == "Linked";
                  final who = localPlayerNameToReplace;
                  SleekNotificationBanner.show(
                    result == "Linked"
                        ? "Linked!"
                        : ok
                        ? "Invite Sent!"
                        : "Couldn't send invite",
                    result == "Linked"
                        ? "${who ?? 'That player'} is now that account, games and all."
                        : ok
                        ? (who != null
                              ? "When they accept, $who becomes their account and $who's games move to them."
                              : "Your invite was sent successfully.")
                        : result,
                    icon: ok ? Icons.check_circle : Icons.error_outline,
                    color: ok ? const Color(0xFF00A2FF) : Colors.redAccent,
                  );
                }
              },
              child: const Text(
                "Send Invite",
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

  /// "Invite with a link": shows a link for this local player to send to
  /// the real person. Opening it lets them make an account (or sign in) and
  /// take the player's place in the group, past games included.
  void _showInviteLinkDialog({
    required String groupId,
    required String groupName,
    required String playerId,
    required String playerName,
  }) {
    final link = _groupService
        .createInviteLink(
          groupId: groupId,
          groupName: groupName,
          playerId: playerId,
          playerName: playerName,
        )
        .then(
          (token) => PendingInvite.buildUrl(
            token: token,
            groupName: groupName,
            playerName: playerName,
          ).toString(),
        );
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<String>(
        future: link,
        builder: (ctx, snap) {
          final url = snap.data;
          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              "Invite $playerName",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Send this link to $playerName. When they open it and "
                    "make an account (or sign in), they take $playerName's "
                    "place in $groupName, past games included.",
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  if (snap.hasError)
                    Text(
                      "Couldn't make the link: ${_friendlyError(snap.error!)}",
                      style: const TextStyle(color: Colors.redAccent),
                    )
                  else if (url == null)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          color: Color(0xFF7855C1),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: SelectableText(
                        url,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  const Text(
                    "Works once. Anyone with the link can use it, so only send it to them.",
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  "Close",
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7855C1),
                ),
                onPressed: url == null
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: url));
                        if (ctx.mounted) Navigator.pop(ctx);
                        SleekNotificationBanner.show(
                          "Link Copied",
                          "Send it to $playerName.",
                          icon: Icons.check_circle,
                          color: const Color(0xFF00A2FF),
                        );
                      },
                icon: const Icon(Icons.copy, size: 16, color: Colors.white),
                label: const Text(
                  "Copy link",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmLeaveGroup(
    String groupId,
    String groupName,
    bool isOwner,
    List<String> members,
  ) {
    if (isOwner) {
      if (members.length > 1) {
        _showTransferOwnershipDialog(groupId, groupName, members);
        return;
      } else {
        _confirmDeleteGroup(groupId, groupName);
        return;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Leave Group?",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Are you sure you want to leave $groupName?",
          style: const TextStyle(color: Colors.white70),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await _run(() => _groupService.leaveGroup(groupId, groupName));
            },
            child: const Text(
              "Leave Group",
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

  void _confirmDeleteGroup(String groupId, String groupName) {
    showDialog(
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
              "Delete Group?",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          "This action is permanent for EVERYONE in '$groupName'.",
          style: const TextStyle(color: Colors.white70),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await _run(() => _groupService.deleteGroup(groupId, groupName));
            },
            child: const Text(
              "DELETE PERMANENTLY",
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

  void _showTransferOwnershipDialog(
    String groupId,
    String groupName,
    List<String> memberUids,
  ) {
    List<String> eligibleMembers = memberUids
        .where((uid) => uid != currentUser?.uid)
        .toList();
    if (eligibleMembers.isEmpty) {
      _showErrorDialog(
        "Cannot Transfer",
        "There are no other synced members to transfer ownership to.",
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Transfer Ownership",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: eligibleMembers
                .map(
                  (uid) => FutureBuilder<Map<String, dynamic>>(
                    future: _getCachedUserData(uid),
                    builder: (context, snapshot) {
                      String name = "Loading...";
                      if (snapshot.hasData)
                        name =
                            snapshot.data!['displayName'] ?? "Unknown Member";
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00A2FF),
                          ),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _run(
                              () => _groupService.transferOwnership(
                                groupId,
                                groupName,
                                uid,
                                name,
                              ),
                              successTitle: 'Ownership Transferred',
                              successMessage: '$name now owns $groupName.',
                            );
                          },
                          child: const Text(
                            "Make Owner",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Got it",
              style: TextStyle(color: Color(0xFF00A2FF)),
            ),
          ),
        ],
      ),
    );
  }

  void _showLocalPlayerOptions(
    String groupId,
    String groupName,
    String playerName,
    String playerId,
    bool isGuest,
    bool amIOwner,
    bool isHidden,
  ) {
    final Color iconColor = const Color(0xFF7855C1);

    _showPlayerOptions((ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: iconColor.withOpacity(0.2),
                    child: Text(
                      playerName.isNotEmpty ? playerName[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: iconColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    playerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    isGuest ? "Local Guest" : "Local Member",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      playerId,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: Colors.white.withOpacity(0.1)),
            ListTile(
              leading: Icon(
                isHidden ? Icons.visibility : Icons.visibility_off,
                color: iconColor,
              ),
              title: Text(
                isHidden ? "Unhide Player" : "Hide Player",
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                "Toggles visibility in scorecard creation",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await _run(
                  () => _groupService.togglePlayerVisibility(
                    groupId,
                    playerId,
                    !isHidden,
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.edit, color: iconColor),
              title: const Text(
                "Change Name",
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showTextInputDialog(
                  title: "Change Name",
                  label: "New Name",
                  initialValue: playerName,
                  buttonText: "Save",
                  onSubmit: (newName) => _run(
                    () => _groupService.renamePlayer(
                      groupId,
                      playerId,
                      newName,
                      isGuest,
                    ),
                    successTitle: 'Name Changed',
                    successMessage: '$playerName is now $newName.',
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.share_outlined, color: iconColor),
              title: const Text(
                "Invite with a link",
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                "They make an account and become $playerName",
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showInviteLinkDialog(
                  groupId: groupId,
                  groupName: groupName,
                  playerId: playerId,
                  playerName: playerName,
                );
              },
            ),
            if (isGuest || playerName != currentUser?.displayName)
              ListTile(
                leading: Icon(Icons.link, color: iconColor),
                title: const Text(
                  "Link Account",
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  "Already has an account? Link it by email",
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEmailInputDialog(
                    groupId: groupId,
                    groupName: groupName,
                    localPlayerIdToReplace: playerId,
                    localPlayerNameToReplace: playerName,
                  );
                },
              ),
            if (amIOwner)
              ListTile(
                leading: const Icon(
                  Icons.person_remove,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  "Remove",
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _run(
                    () => _groupService.removePlayer(
                      groupId,
                      playerId,
                      playerName,
                      isGuest,
                    ),
                    successTitle: 'Removed',
                    successMessage: '$playerName was removed.',
                  );
                },
              ),
            const SizedBox(height: 10),
          ],
        ),
      );
    });
  }

  void _showSyncedPlayerOptions(
    String name,
    String email,
    bool isOwner,
    bool amIOwner,
    String groupId,
    String groupName,
    String targetUid,
    bool isHidden,
  ) {
    _showPlayerOptions((ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF00A2FF).withOpacity(0.2),
                    child: Icon(
                      isOwner ? Icons.workspace_premium : Icons.person,
                      color: const Color(0xFF00A2FF),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      email,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    targetUid,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: Colors.white.withOpacity(0.1)),
            ListTile(
              leading: Icon(
                isHidden ? Icons.visibility : Icons.visibility_off,
                color: const Color(0xFF00A2FF),
              ),
              title: Text(
                isHidden ? "Unhide Player" : "Hide Player",
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                "Toggles visibility in scorecard creation",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await _run(
                  () => _groupService.togglePlayerVisibility(
                    groupId,
                    targetUid,
                    !isHidden,
                  ),
                );
              },
            ),
            if (amIOwner && !isOwner) ...[
              ListTile(
                leading: const Icon(
                  Icons.person_remove,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  "Remove Player",
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _run(
                    () => _groupService.kickMember(
                      groupId,
                      groupName,
                      targetUid,
                      name,
                    ),
                    successTitle: 'Removed',
                    successMessage: '$name was removed from $groupName.',
                  );
                },
              ),
            ],
            const SizedBox(height: 10),
          ],
        ),
      );
    });
  }

  Widget _buildPlayerChip(
    String name,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isHidden = false,
  }) {
    final double opacity = isHidden ? 0.3 : 1.0;

    return Material(
      color: color.withOpacity(0.15 * opacity),
      shape: StadiumBorder(
        side: BorderSide(color: color.withOpacity(0.5 * opacity)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: color.withOpacity(0.12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color.withOpacity(opacity)),
              const SizedBox(width: 6),
              Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color.withOpacity(opacity),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton(String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: color)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: color.withOpacity(0.12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) return const SizedBox();

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        title: const Text(
          'Manage Groups',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white70),
            tooltip: 'Customize Groups',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GroupsCustomizeScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        flexibleSpace: const TopBarBackground(),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('game_groups')
            .where('members', arrayContains: currentUser!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00A2FF)),
            );
          }
          final groups = snapshot.data?.docs ?? [];
          if (groups.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.groups_outlined,
                      size: 56,
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "No game groups yet",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Create one with the settings button (top right), or ask a friend to invite you, to share scorecards and stats.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            edgeOffset:
                MediaQuery.of(context).padding.top + kToolbarHeight - 32,
            color: const Color(0xFF00A2FF),
            backgroundColor: const Color(0xFF1E1E1E),
            onRefresh: () async {
              // Delay gives user visual feedback; StreamBuilder handles the actual syncing.
              await Future.delayed(const Duration(milliseconds: 500));
              if (mounted) setState(() {});
            },
            child: ListView.builder(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + kToolbarHeight - 32,
                left: readableSide(context, maxWidth: 920),
                right: readableSide(context, maxWidth: 920),
                bottom: 100,
              ),
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final groupData = groups[index].data() as Map<String, dynamic>;
                final groupId = groups[index].id;
                final groupName = groupData['name'] ?? "Unknown Group";
                final ownerUid = groupData['owner'] ?? "";
                final amIOwner = ownerUid == currentUser!.uid;

                final members = List<String>.from(groupData['members'] ?? []);

                List<Map<String, String>> parseLocalPlayers(List<dynamic> raw) {
                  return raw.map<Map<String, String>>((e) {
                    if (e is String) {
                      return <String, String>{'id': e, 'name': e};
                    }
                    if (e is Map) {
                      return <String, String>{
                        'id': e['id']?.toString() ?? '',
                        'name': e['name']?.toString() ?? '',
                      };
                    }
                    return <String, String>{'id': '', 'name': ''};
                  }).toList();
                }

                final localMembers = parseLocalPlayers(
                  (groupData['localMembers'] as List<dynamic>?) ?? [],
                );
                final guests = parseLocalPlayers(
                  (groupData['guests'] as List<dynamic>?) ?? [],
                );
                final hiddenPlayers = List<String>.from(
                  groupData['hiddenPlayers'] ?? [],
                );

                members.sort((a, b) {
                  if (a == currentUser!.uid) return -1;
                  if (b == currentUser!.uid) return 1;
                  if (a == ownerUid) return -1;
                  if (b == ownerUid) return 1;
                  return 0;
                });

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF00A2FF).withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              groupName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.white54,
                            ),
                            color: const Color(0xFF2C2C2C),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            onSelected: (value) {
                              if (value == 'leave') {
                                _confirmLeaveGroup(
                                  groupId,
                                  groupName,
                                  amIOwner,
                                  members,
                                );
                              } else if (value == 'delete') {
                                _confirmDeleteGroup(groupId, groupName);
                              } else if (value == 'transfer') {
                                _showTransferOwnershipDialog(
                                  groupId,
                                  groupName,
                                  members,
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              if (amIOwner)
                                const PopupMenuItem(
                                  value: 'transfer',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.swap_horiz,
                                        color: Color(0xFF00A2FF),
                                        size: 20,
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        "Transfer Ownership",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              const PopupMenuItem(
                                value: 'leave',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.exit_to_app,
                                      color: Colors.white54,
                                      size: 20,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      "Leave Group",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                              if (amIOwner)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete_forever,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        "Delete Group",
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        "MEMBERS",
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF00A2FF),
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ...members.map((uid) {
                            final isOwner = uid == ownerUid;
                            final icon = isOwner
                                ? Icons.workspace_premium
                                : Icons.person;
                            final isHidden = hiddenPlayers.contains(uid);
                            if (uid == currentUser!.uid) {
                              return _buildPlayerChip(
                                "You",
                                icon,
                                const Color(0xFF00A2FF),
                                () => _showSyncedPlayerOptions(
                                  "You",
                                  currentUser!.email ?? "",
                                  isOwner,
                                  amIOwner,
                                  groupId,
                                  groupName,
                                  uid,
                                  isHidden,
                                ),
                                isHidden: isHidden,
                              );
                            }

                            return FutureBuilder<Map<String, dynamic>>(
                              future: _getCachedUserData(uid),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const SizedBox();
                                }
                                final data = snapshot.data!;
                                final name = data['displayName'] ?? "Player";
                                final email = data['email'] ?? "Unknown Email";

                                return _buildPlayerChip(
                                  name,
                                  icon,
                                  const Color(0xFF00A2FF),
                                  () => _showSyncedPlayerOptions(
                                    name,
                                    email,
                                    isOwner,
                                    amIOwner,
                                    groupId,
                                    groupName,
                                    uid,
                                    isHidden,
                                  ),
                                  isHidden: isHidden,
                                );
                              },
                            );
                          }),

                          ...localMembers.map(
                            (player) => _buildPlayerChip(
                              player['name']!,
                              Icons.person,
                              const Color(0xFF7855C1),
                              () => _showLocalPlayerOptions(
                                groupId,
                                groupName,
                                player['name']!,
                                player['id']!,
                                false,
                                amIOwner,
                                hiddenPlayers.contains(player['id']),
                              ),
                              isHidden: hiddenPlayers.contains(player['id']),
                            ),
                          ),

                          _buildAddButton(
                            "Add Member",
                            const Color(0xFF00A2FF),
                            () {
                              _showTextInputDialog(
                                title: "Add Member",
                                label: "Player Name",
                                buttonText: "Add",
                                onSubmit: (name) => _run(
                                  () => _groupService.addPlayer(
                                    groupId,
                                    name,
                                    false,
                                  ),
                                  successTitle: 'Member Added',
                                  successMessage:
                                      '$name was added to $groupName.',
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      const Text(
                        "GUESTS",
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF7855C1),
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ...guests.map(
                            (player) => _buildPlayerChip(
                              player['name']!,
                              Icons.person_outline,
                              const Color(0xFF7855C1),
                              () => _showLocalPlayerOptions(
                                groupId,
                                groupName,
                                player['name']!,
                                player['id']!,
                                true,
                                amIOwner,
                                hiddenPlayers.contains(player['id']),
                              ),
                              isHidden: hiddenPlayers.contains(player['id']),
                            ),
                          ),

                          _buildAddButton(
                            "Add Guest",
                            const Color(0xFF7855C1),
                            () {
                              _showTextInputDialog(
                                title: "Add Guest",
                                label: "Guest Name",
                                buttonText: "Add",
                                onSubmit: (name) => _run(
                                  () => _groupService.addPlayer(
                                    groupId,
                                    name,
                                    true,
                                  ),
                                  successTitle: 'Guest Added',
                                  successMessage:
                                      '$name was added to $groupName.',
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
