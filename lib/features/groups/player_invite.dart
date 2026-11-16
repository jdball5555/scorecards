import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where invite links point (the website).
const kWebAppUrl = 'https://scorecards.axisoptic.com';

/// "Invite with a link": a link someone opens to make (or sign in to) an
/// account and take a local player's place in a group, past games included.
///
/// The link is `kWebAppUrl/?join=TOKEN&g=GROUP_NAME&p=PLAYER_NAME`.
/// The token is the id of a player_invites/{token} document (random, so it
/// can't be guessed); g and p are only there so the sign-in page can say
/// what the invite is before they're signed in.
class PendingInvite {
  final String token;
  final String? groupName;
  final String? playerName;

  const PendingInvite(this.token, {this.groupName, this.playerName});

  /// The invite in the address bar, if the website was opened from one.
  static PendingInvite? fromUrl() {
    if (!kIsWeb) return null;
    final q = Uri.base.queryParameters;
    final token = q['join'];
    if (token == null || !RegExp(r'^[A-Za-z0-9]{12,40}$').hasMatch(token)) {
      return null;
    }
    String? clean(String? s) {
      final t = s?.trim();
      return (t == null || t.isEmpty)
          ? null
          : t.substring(0, t.length.clamp(0, 60));
    }

    return PendingInvite(
      token,
      groupName: clean(q['g']),
      playerName: clean(q['p']),
    );
  }

  static Uri buildUrl({
    required String token,
    required String groupName,
    required String playerName,
  }) {
    return Uri.parse(kWebAppUrl).replace(
      queryParameters: {'join': token, 'g': groupName, 'p': playerName},
    );
  }
}

/// The invite this visit was opened with, until it's accepted or dismissed.
final pendingInviteProvider = StateProvider<PendingInvite?>(
  (ref) => PendingInvite.fromUrl(),
);
