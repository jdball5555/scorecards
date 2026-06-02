import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 1. STREAM: Listens to the user's preferences in real-time
final notificationSettingsProvider = StreamProvider<Map<String, dynamic>>((
  ref,
) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return Stream.value({});

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((snapshot) {
        final data = snapshot.data();
        // If they have settings saved, return them. Otherwise, return an empty map.
        if (data != null && data.containsKey('notificationSettings')) {
          return data['notificationSettings'] as Map<String, dynamic>;
        }
        return {};
      });
});

// 2. ACTION: Toggles a setting and saves it to Firestore instantly
class NotificationSettingsController {
  static Future<void> toggleSetting(String key, bool newValue) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {
          'notificationSettings': {key: newValue},
        },
        SetOptions(merge: true),
      ); // Merge ensures we don't overwrite their other settings!
    } catch (e) {
      // Handle silently or print to debug
    }
  }
}
