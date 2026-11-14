import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/app_version.dart' as v;

const kAppVersion = v.appVersion;

/// Sends feedback to the Axis Optic inbox.
///
/// Optic lives in the Axis Team Firebase project, so tickets go through the
/// `submitAppFeedback` Cloud Function there (axis-team/functions/index.js),
/// which checks the person's Scorecards sign-in and files the ticket where
/// Optic and the developer push notifications pick it up.
///
/// A copy is also kept in this project's `feedback` collection so nothing is
/// lost if Optic can't be reached.
class OpticFeedbackService {
  static const endpoint =
      'https://us-central1-project-attendance-app.cloudfunctions.net/submitAppFeedback';
  static const appVersion = kAppVersion;

  static String get _platform {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name; // android, iOS, macOS...
  }

  /// Returns normally when the ticket reached Optic or was saved locally.
  /// Throws only if both failed.
  static Future<void> submit({
    required bool isBug,
    required String location,
    required String message,
    Map<String, dynamic> extra = const {},
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final name = (user?.displayName ?? '').trim();

    bool sentToOptic = false;
    String? opticError;
    try {
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
              'type': isBug ? 'Bug' : 'Improvement',
              'location': location,
              'message': message,
              'submitter_name': name,
              'platform': _platform,
              'app_version': appVersion,
            }),
          )
          .timeout(const Duration(seconds: 15));
      sentToOptic = res.statusCode == 200;
      if (!sentToOptic) opticError = 'HTTP ${res.statusCode}: ${res.body}';
      if (res.statusCode == 429) {
        throw const FeedbackRateLimited();
      }
    } on FeedbackRateLimited {
      rethrow;
    } catch (e) {
      opticError = e.toString();
    }
    if (opticError != null) debugPrint('Optic feedback not sent: $opticError');

    try {
      await FirebaseFirestore.instance.collection('feedback').add({
        'uid': user?.uid ?? 'anonymous',
        'email': user?.email ?? 'none',
        'displayName': name.isEmpty ? 'none' : name,
        'type': isBug ? 'bug' : 'idea',
        'location': location,
        'text': message,
        'platform': _platform,
        'appVersion': 'v$appVersion',
        'sentToOptic': sentToOptic,
        if (opticError != null) 'opticError': opticError,
        ...extra,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (!sentToOptic) rethrow;
    }
  }
}

class FeedbackRateLimited implements Exception {
  const FeedbackRateLimited();
}
