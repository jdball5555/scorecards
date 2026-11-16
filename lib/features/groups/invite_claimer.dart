import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_shell.dart' show bottomNavIndexProvider;
import '../../core/shared_widgets/sleek_notification_banner.dart';
import '../../core/web/url_cleaner.dart';
import '../../services/group_service.dart';
import 'player_invite.dart';

/// Once someone who opened an "Invite with a link" link is signed in, asks
/// them to join the group as that player (and does it).
class InviteClaimer extends ConsumerStatefulWidget {
  final Widget child;
  const InviteClaimer({super.key, required this.child});

  @override
  ConsumerState<InviteClaimer> createState() => _InviteClaimerState();
}

class _InviteClaimerState extends ConsumerState<InviteClaimer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _offer());
  }

  void _done() {
    ref.read(pendingInviteProvider.notifier).state = null;
    clearInviteFromUrl();
  }

  void _problem(String title, String message) {
    SleekNotificationBanner.show(
      title,
      message,
      icon: Icons.link_off,
      color: Colors.redAccent,
    );
  }

  Future<void> _offer() async {
    final invite = ref.read(pendingInviteProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (invite == null || uid == null || !mounted) return;

    // Check the link before asking (refreshing after joining shouldn't ask
    // again).
    Map<String, dynamic>? data;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('player_invites')
          .doc(invite.token)
          .get();
      data = doc.data();
    } catch (_) {
      // Couldn't check; let claiming report any problem.
    }
    if (!mounted) return;
    if (data != null && data['usedBy'] == uid) return _done();
    if (data != null && data['usedBy'] != null) {
      _done();
      return _problem(
        'Invite already used',
        'Someone already joined with that link. Ask for a new one.',
      );
    }

    final group = data?['groupName'] ?? invite.groupName ?? 'the group';
    final player = data?['localPlayerName'] ?? invite.playerName ?? 'a player';
    final join = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Join $group?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          "You were invited to join $group as $player. Your account takes "
          "$player's place in the group, along with their past games.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Not now',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A2FF),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Join',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    _done();
    if (join != true) return;

    try {
      final r = await GroupService().claimInviteLink(invite.token);
      SleekNotificationBanner.show(
        "You're in!",
        r.alreadyDone
            ? 'You already joined ${r.groupName} with this link.'
            : "You joined ${r.groupName} as ${r.playerName}. Their past games are yours now.",
        icon: Icons.group_add,
        color: const Color(0xFF00A2FF),
      );
      if (mounted) ref.read(bottomNavIndexProvider.notifier).state = 3;
    } catch (e) {
      _problem("Couldn't join", e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
