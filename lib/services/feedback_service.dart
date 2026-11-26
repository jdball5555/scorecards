import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/app_version.dart' as v;

const kAppVersion = v.appVersion;

/// Sends feedback to the Axis Optic inbox.
///
/// Tickets live in Axis Optic (axis-optic-ce4f2), not in this project. They
/// go through its `feedback` Cloud Function, which checks the person's
/// Scorecards sign-in and files the ticket where Console (Axis Optic's
/// developer app) and the developer push notifications pick it up.
class FeedbackService {
  static const endpoint =
      'https://us-central1-axis-optic-ce4f2.cloudfunctions.net/feedback';
  static const appVersion = kAppVersion;

  static String get _platform {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name; // android, iOS, macOS...
  }

  /// Returns normally once the ticket reached Axis Optic.
  /// Throws [FeedbackRateLimited] if they sent one a few seconds ago.
  static Future<void> submit({
    required bool isBug,
    required String location,
    required String message,
    Map<String, Object> extra = const {},
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    if (token == null) throw Exception('Not signed in');
    final res = await http
        .post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'action': 'submit',
            'type': isBug ? 'Bug' : 'Improvement',
            'location': location,
            'message': message,
            'submitter_name': (user?.displayName ?? '').trim(),
            'platform': _platform,
            'app_version': appVersion,
            'extra': extra,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 429) throw const FeedbackRateLimited();
    if (res.statusCode != 200) {
      debugPrint('Feedback not sent: HTTP ${res.statusCode}: ${res.body}');
      throw Exception('HTTP ${res.statusCode}');
    }
  }
}

class FeedbackRateLimited implements Exception {
  const FeedbackRateLimited();
}
