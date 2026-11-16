import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/providers/auth_provider.dart';

/// Premium beta: early features for accounts switched on in Axis Optic.
/// For now that's custom templates (the builder, saved templates, the AI
/// rulebook scan).
///
/// The switch is a sign-in claim, `premiumBeta`, that only the server can set
/// (Optic → functions/optic.js), so it can't be turned on from the app.
/// Optic also writes `users/{uid}.premiumBeta` as a copy; when that copy
/// changes we refresh the sign-in so the switch takes effect right away
/// instead of within the hour. The claim is what counts, never the copy.
final premiumBetaProvider = StreamProvider<bool>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(false);
  return _premiumBetaFor(user);
});

/// Whether this account has premium beta (false while loading, or if it
/// can't be checked; `.value` would rethrow the error and break the page).
bool hasPremiumBeta(WidgetRef ref) =>
    ref.watch(premiumBetaProvider).valueOrNull ?? false;

Stream<bool> _premiumBetaFor(User user) async* {
  Future<bool> readClaim({required bool refresh}) async {
    try {
      final result = await user.getIdTokenResult(refresh);
      return result.claims?['premiumBeta'] == true;
    } catch (_) {
      return false;
    }
  }

  var claim = await readClaim(refresh: false);
  yield claim;

  bool? lastCopy;
  final docs = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .handleError((Object _) {});
  await for (final doc in docs) {
    final copy = doc.data()?['premiumBeta'] == true;
    // Only when the copy changes (and disagrees), not on every profile save.
    if (copy == lastCopy) continue;
    lastCopy = copy;
    if (copy == claim) continue;
    final fresh = await readClaim(refresh: true);
    if (fresh != claim) {
      claim = fresh;
      yield claim;
    }
  }
}

/// The small "Premium beta" note shown in Settings for accounts that have it.
class PremiumBetaBadge extends StatelessWidget {
  const PremiumBetaBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.auto_awesome,
          size: 14,
          color: Colors.white.withValues(alpha: 0.45),
        ),
        const SizedBox(width: 6),
        Text(
          'Premium beta',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
