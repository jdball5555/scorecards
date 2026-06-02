import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 1. SMART NOTIFICATION COUNTER
final mailNotificationProvider = StreamProvider<Map<String, int>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value({'unread': 0, 'action': 0});

  // CHANGED: Removed the strict .where() query.
  // We now fetch all mail and sort it in memory so we don't miss documents missing a status field!
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('mail')
      .snapshots()
      .map((snapshot) {
        int unread = 0;
        int action = 0;

        for (var doc in snapshot.docs) {
          final data = doc.data();
          // Uses the exact same fallback logic as your UI!
          final status = data['status'] as String? ?? 'unread';

          if (status == 'unread') {
            unread++;
          } else if (status == 'pending' || status == 'pending_action') {
            action++;
          }
        }
        return {'unread': unread, 'action': action};
      });
});

// 2. THE MAIL DATA STREAM
final mailStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('mail')
      .snapshots()
      .map((snapshot) {
        final list = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();

        // FLIPPED SORTING: Ascending order (Oldest at index 0, Newest at the end)
        list.sort((a, b) {
          final aTime = a['timestamp'] ?? a['createdAt'];
          final bTime = b['timestamp'] ?? b['createdAt'];
          if (aTime is Timestamp && bTime is Timestamp) {
            return aTime.compareTo(bTime);
          }
          return 0;
        });

        return list;
      });
});
