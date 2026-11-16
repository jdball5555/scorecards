import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// The signed-in user, updated when their profile changes too (e.g. the name
/// set right after making an account), not just on sign-in/out.
final userProfileProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.userChanges();
});
