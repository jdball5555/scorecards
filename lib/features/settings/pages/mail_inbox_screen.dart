import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/shared_widgets/gradient_background.dart';
import '../../../core/shared_widgets/glass_card.dart';
import '../../../core/shared_widgets/sleek_notification_banner.dart';
import '../../../services/group_service.dart';
import '../providers/mail_provider.dart';
import '../../scorecards/providers/local_scorecard_provider.dart';
import '../../scorecards/pages/scoring.dart';
import 'package:scorecards_app/core/shared_widgets/top_bar_background.dart';

class MailInboxScreen extends ConsumerWidget {
  MailInboxScreen({super.key});

  final GroupService _groupService = GroupService();

  Future<void> _markAsRead(BuildContext context, String mailId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('mail')
          .doc(mailId)
          .update({'status': 'read'});
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _markAllAsRead(
    BuildContext context,
    List<Map<String, dynamic>> mailList,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // CHANGED: Added the fallback here so it actually grabs messages with a missing status!
      final unreadMails = mailList.where((m) {
        final status = m['status'] as String? ?? 'unread';
        return status == 'unread';
      }).toList();

      if (unreadMails.isEmpty) return;

      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      for (var mail in unreadMails) {
        batch.update(
          db
              .collection('users')
              .doc(user.uid)
              .collection('mail')
              .doc(mail['id']),
          {'status': 'read'},
        );
      }
      await batch.commit();
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark all as read: $e')),
        );
    }
  }

  Future<void> _handleMailAction(
    BuildContext context,
    Map<String, dynamic> mail,
    String decision,
  ) async {
    try {
      final mailId = mail['id'];
      final groupId = mail['groupId'] ?? "";
      final senderUid = mail['senderUid'] ?? "";
      final groupName = mail['groupName'] ?? "the group";

      if (decision == 'Accepted') {
        await _groupService.acceptInvite(mailId, groupId, senderUid);

        if (context.mounted) {
          SleekNotificationBanner.show(
            "Group Joined!",
            "You are now a member of $groupName.",
            icon: Icons.group_add,
            color: const Color(0xFF00A2FF),
          );
        }
      } else if (decision == 'Denied') {
        await _groupService.denyInvite(mailId, senderUid);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Action failed: $e'),
          ),
        );
      }
    }
  }

  Future<void> _openScorecard(BuildContext context, String scorecardId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF00A2FF)),
      ),
    );

    try {
      final doc = await FirebaseFirestore.instance
          .collection('scorecards')
          .doc(scorecardId)
          .get();
      if (context.mounted) {
        Navigator.pop(context); // close loading
      }

      if (doc.exists && doc.data() != null) {
        final card = LocalScorecard.fromMap(doc.data()!);
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ScoringScreen(
                gameType: card.gameType,
                ownerType: card.ownerType,
                ownerId: card.ownerId,
                groupName: card.groupName,
                existingCard: card,
              ),
            ),
          );
        }
      } else {
        if (context.mounted) {
          SleekNotificationBanner.show(
            "Scorecard Not Found",
            "This scorecard may have been deleted.",
            icon: Icons.error_outline,
            color: Colors.redAccent,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close loading
        SleekNotificationBanner.show(
          "Error",
          "Could not load scorecard: $e",
          icon: Icons.error_outline,
          color: Colors.redAccent,
        );
      }
    }
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      final now = DateTime.now();

      int hour = date.hour == 0
          ? 12
          : (date.hour > 12 ? date.hour - 12 : date.hour);
      String minute = date.minute.toString().padLeft(2, '0');
      String amPm = date.hour >= 12 ? 'PM' : 'AM';
      String timeString = '$hour:$minute $amPm';

      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        return 'Today • $timeString';
      } else if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day - 1) {
        return 'Yesterday • $timeString';
      } else {
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
        return '${months[date.month - 1]} ${date.day} • $timeString';
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mailStream = ref.watch(mailStreamProvider);

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          flexibleSpace: const TopBarBackground(),
          title: const Text(
            'Mail Inbox',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: mailStream.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF00A2FF)),
              ),
              error: (err, stack) => Center(
                child: Text(
                  'Error: $err',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
              data: (mailList) {
                if (mailList.isEmpty) {
                  return const Center(
                    child: Text(
                      "No mail yet.",
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                // CHANGED: Added the fallback here so the button correctly activates!
                final hasUnread = mailList.any((m) {
                  final status = m['status'] as String? ?? 'unread';
                  return status == 'unread';
                });

                final displayList = mailList.reversed.toList();

                return Column(
                  children: [
                    Expanded(
                      child: ShaderMask(
                        shaderCallback: (Rect rect) {
                          return const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.transparent, Colors.black],
                            stops: [0.0, 0.05],
                          ).createShader(rect);
                        },
                        blendMode: BlendMode.dstIn,
                        child: ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 20,
                          ).copyWith(bottom: 20),
                          itemCount: displayList.length,
                          itemBuilder: (context, index) {
                            return _buildMailTile(
                              context: context,
                              mail: displayList[index],
                            );
                          },
                        ),
                      ),
                    ),

                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 20,
                          right: 20,
                          bottom: 32,
                          top: 10,
                        ),
                        child: InkWell(
                          onTap: hasUnread
                              ? () => _markAllAsRead(context, mailList)
                              : null,
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: hasUnread
                                  ? Colors.white.withOpacity(0.08)
                                  : Colors.white.withOpacity(0.02),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: hasUnread
                                    ? Colors.white.withOpacity(0.15)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                hasUnread ? "Mark All as Read" : "No new mail",
                                style: TextStyle(
                                  color: hasUnread
                                      ? Colors.white
                                      : Colors.white38,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // --- THE TILE ROUTER ---
  Widget _buildMailTile({
    required BuildContext context,
    required Map<String, dynamic> mail,
  }) {
    final status = mail['status'] as String? ?? 'unread';
    final type = mail['type'] as String? ?? '';
    final timeString = _formatTime(mail['timestamp'] ?? mail['createdAt']);
    final actionResult = mail['actionResult'] as String?;

    String title = mail['title'] ?? 'Notification';
    String body = mail['body'] ?? mail['message'] ?? 'No content available.';

    if (type == 'invite_received') {
      final groupName = mail['groupName'] ?? 'a group';
      final senderName = mail['senderName'] ?? 'Someone';
      title = 'Group Invite';
      body = '$senderName invited you to join "$groupName".';
    }

    // ==========================================
    // 1. PENDING ACTION (Blue Glass Card + Buttons)
    // ==========================================
    if (status == 'pending' || status == 'pending_action') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: GlassCard(
          accentColor: const Color(0xFF00A2FF),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.touch_app,
                    color: Color(0xFF00A2FF),
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              timeString,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          body,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _handleMailAction(context, mail, 'Denied'),
                    child: const Text(
                      'Deny',
                      style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A2FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () =>
                        _handleMailAction(context, mail, 'Accepted'),
                    child: const Text(
                      'Accept',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    // ==========================================
    // 2. UNREAD (White Frosted)
    // ==========================================
    else if (status == 'unread') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _markAsRead(context, mail['id']),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.mark_email_unread,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  timeString,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              body,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (type == 'new_scorecard' &&
                                mail['scorecardId'] != null) ...[
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00A2FF),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: () {
                                    _markAsRead(context, mail['id']);
                                    _openScorecard(
                                      context,
                                      mail['scorecardId'],
                                    );
                                  },
                                  icon: const Icon(Icons.analytics, size: 16),
                                  label: const Text(
                                    "View Scorecard",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    // ==========================================
    // 3. READ / ARCHIVED (Gray & Dull)
    // ==========================================
    else {
      String actionText = "";
      Color actionColor = Colors.transparent;

      if (status == 'accepted' || actionResult == 'Accepted') {
        actionText = "ACCEPTED";
        actionColor = Colors.greenAccent.withOpacity(0.6);
      } else if (status == 'denied' || actionResult == 'Denied') {
        actionText = "DENIED";
        actionColor = Colors.redAccent.withOpacity(0.6);
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.05),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.drafts, color: Colors.white38, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Text(
                                  timeString,
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              body,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (actionText.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        actionText,
                        style: TextStyle(
                          color: actionColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                  if (type == 'new_scorecard' &&
                      mail['scorecardId'] != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF00A2FF),
                        ),
                        onPressed: () =>
                            _openScorecard(context, mail['scorecardId']),
                        icon: const Icon(Icons.analytics, size: 16),
                        label: const Text(
                          "View Scorecard",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }
  }
}
