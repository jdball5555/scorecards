import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Looks up an account by email. The database doesn't let the app search
/// profiles, so this goes through a Cloud Function (functions/index.js).
const _findUserByEmailUrl =
    'https://us-central1-scorecards-app.cloudfunctions.net/findUserByEmail';

class GroupService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> createGroup(String name, String creatorUid) async {
    final docRef = _db.collection('game_groups').doc();
    await docRef.set({
      'name': name,
      'owner': creatorUid,
      'createdAt': FieldValue.serverTimestamp(),
      'id': docRef.id,
      'members': [creatorUid],
      'localMembers': [],
      'guests': [],
    });
  }

  Future<void> addPlayer(
    String groupId,
    String playerName,
    bool isGuest,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final myName = FirebaseAuth.instance.currentUser?.displayName ?? "A member";

    String arrayName = isGuest ? 'guests' : 'localMembers';
    final batch = _db.batch();

    final groupRef = _db.collection('game_groups').doc(groupId);
    final newId =
        'local_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(1000)}';
    batch.update(groupRef, {
      arrayName: FieldValue.arrayUnion([
        {'id': newId, 'name': playerName.trim()},
      ]),
    });

    final doc = await groupRef.get();
    if (doc.exists) {
      final groupName = doc.data()?['name'] ?? "a group";
      final members = List<String>.from(doc.data()?['members'] ?? []);

      for (String memberId in members) {
        if (memberId == uid) continue;

        final mailRef = _db
            .collection('users')
            .doc(memberId)
            .collection('mail')
            .doc();
        batch.set(mailRef, {
          'type': 'system_notice',
          'groupId': groupId,
          'senderUid': _myUid,
          'message':
              '$myName added local player "$playerName" to "$groupName".',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  }

  Future<void> removePlayer(
    String groupId,
    String playerId,
    String playerName,
    bool isGuest,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final myName = FirebaseAuth.instance.currentUser?.displayName ?? "A member";

    String arrayName = isGuest ? 'guests' : 'localMembers';
    final groupRef = _db.collection('game_groups').doc(groupId);

    final doc = await groupRef.get();
    if (doc.exists) {
      final list = List<dynamic>.from(doc.data()?[arrayName] ?? []);
      list.removeWhere(
        (p) =>
            (p is Map && p['id'] == playerId) ||
            p == playerName ||
            p == playerId,
      );

      final batch = _db.batch();
      batch.update(groupRef, {arrayName: list});

      final groupName = doc.data()?['name'] ?? "a group";
      final members = List<String>.from(doc.data()?['members'] ?? []);

      for (String memberId in members) {
        if (memberId == uid) continue;

        final mailRef = _db
            .collection('users')
            .doc(memberId)
            .collection('mail')
            .doc();
        batch.set(mailRef, {
          'type': 'system_notice',
          'groupId': groupId,
          'senderUid': _myUid,
          'message':
              '$myName removed local player "$playerName" from "$groupName".',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  Future<void> renamePlayer(
    String groupId,
    String playerId,
    String newName,
    bool isGuest,
  ) async {
    if (newName.trim().isEmpty) return;
    String arrayName = isGuest ? 'guests' : 'localMembers';
    final docRef = _db.collection('game_groups').doc(groupId);
    final doc = await docRef.get();

    if (doc.exists) {
      final list = List<dynamic>.from(doc.data()?[arrayName] ?? []);
      final index = list.indexWhere(
        (p) => (p is Map && p['id'] == playerId) || p == playerId,
      );

      if (index != -1) {
        if (list[index] is String) {
          list[index] = {'id': playerId, 'name': newName.trim()};
        } else {
          list[index]['name'] = newName.trim();
        }
        await docRef.update({arrayName: list});
      }
    }
  }

  Future<void> kickMember(
    String groupId,
    String groupName,
    String targetUid,
    String targetName,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final myName =
        FirebaseAuth.instance.currentUser?.displayName ?? "The owner";
    final batch = _db.batch();

    batch.update(_db.collection('game_groups').doc(groupId), {
      'members': FieldValue.arrayRemove([targetUid]),
    });

    final targetMailRef = _db
        .collection('users')
        .doc(targetUid)
        .collection('mail')
        .doc();
    batch.set(targetMailRef, {
      'type': 'system_notice',
          'groupId': groupId,
          'senderUid': _myUid,
      'message': 'You got kicked out of "$groupName" by $myName.',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final doc = await _db.collection('game_groups').doc(groupId).get();
    if (doc.exists) {
      final members = List<String>.from(doc.data()?['members'] ?? []);
      for (String memberId in members) {
        if (memberId == targetUid) continue;

        final mailRef = _db
            .collection('users')
            .doc(memberId)
            .collection('mail')
            .doc();
        String noticeMessage;
        if (memberId == uid) {
          noticeMessage = 'You kicked $targetName out of "$groupName".';
        } else {
          noticeMessage = '$myName kicked $targetName out of "$groupName".';
        }

        batch.set(mailRef, {
          'type': 'system_notice',
          'groupId': groupId,
          'senderUid': _myUid,
          'message': noticeMessage,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  }

  Future<void> leaveGroup(String groupId, String groupName) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final myName = FirebaseAuth.instance.currentUser?.displayName ?? "A member";

    final doc = await _db.collection('game_groups').doc(groupId).get();
    if (!doc.exists) return;

    final members = List<String>.from(doc.data()?['members'] ?? []);
    final batch = _db.batch();

    batch.update(_db.collection('game_groups').doc(groupId), {
      'members': FieldValue.arrayRemove([uid]),
    });

    for (String memberId in members) {
      final mailRef = _db
          .collection('users')
          .doc(memberId)
          .collection('mail')
          .doc();
      batch.set(mailRef, {
        'type': 'system_notice',
          'groupId': groupId,
          'senderUid': _myUid,
        'message': memberId == uid
            ? 'You left the group "$groupName".'
            : '$myName left the group "$groupName".',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> transferOwnership(
    String groupId,
    String groupName,
    String newOwnerUid,
    String newOwnerName,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final myName =
        FirebaseAuth.instance.currentUser?.displayName ?? "The owner";
    final batch = _db.batch();

    batch.update(_db.collection('game_groups').doc(groupId), {
      'owner': newOwnerUid,
    });

    final doc = await _db.collection('game_groups').doc(groupId).get();
    if (doc.exists) {
      final members = List<String>.from(doc.data()?['members'] ?? []);
      for (String memberId in members) {
        final mailRef = _db
            .collection('users')
            .doc(memberId)
            .collection('mail')
            .doc();

        String noticeMessage;
        if (memberId == uid) {
          noticeMessage =
              'You transferred ownership of "$groupName" to $newOwnerName.';
        } else if (memberId == newOwnerUid) {
          noticeMessage = '$myName made you the new owner of "$groupName".';
        } else {
          noticeMessage =
              '$myName transferred ownership of "$groupName" to $newOwnerName.';
        }

        batch.set(mailRef, {
          'type': 'system_notice',
          'groupId': groupId,
          'senderUid': _myUid,
          'message': noticeMessage,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  }

  Future<void> deleteGroup(String groupId, String groupName) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final myName =
        FirebaseAuth.instance.currentUser?.displayName ?? "The owner";

    final doc = await _db.collection('game_groups').doc(groupId).get();
    if (!doc.exists) return;

    final members = List<String>.from(doc.data()?['members'] ?? []);
    final batch = _db.batch();

    batch.delete(_db.collection('game_groups').doc(groupId));

    for (String memberId in members) {
      final mailRef = _db
          .collection('users')
          .doc(memberId)
          .collection('mail')
          .doc();
      batch.set(mailRef, {
        'type': 'system_notice',
          'groupId': groupId,
          'senderUid': _myUid,
        'message': memberId == uid
            ? 'You deleted the group "$groupName".'
            : '$myName deleted the group "$groupName".',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// The account with this email, or null if there isn't one.
  Future<({String uid, String name})?> _findUserByEmail(String email) async {
    final idToken = await FirebaseAuth.instance.currentUser!.getIdToken();
    final res = await http
        .post(
          Uri.parse(_findUserByEmailUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({
            'data': {'email': email},
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('findUserByEmail: ${res.statusCode}');
    }
    final result = (jsonDecode(res.body) as Map)['result'] as Map?;
    final uid = result?['uid'] as String?;
    if (uid == null) return null;
    return (uid: uid, name: (result?['displayName'] as String?) ?? 'A player');
  }

  Future<String> sendInvite(
    String groupId,
    String groupName,
    String targetEmail,
    String senderName, {
    String? localPlayerIdToReplace,
    String? localPlayerNameToReplace,
  }) async {
    final cleanEmail = targetEmail.trim().toLowerCase();
    final senderUid = FirebaseAuth.instance.currentUser!.uid;

    final ({String uid, String name})? target;
    try {
      target = await _findUserByEmail(cleanEmail);
    } catch (_) {
      return "Couldn't look up that email. Check your connection and try again.";
    }
    if (target == null) return "No account found with that email.";

    final targetUid = target.uid;
    final targetName = target.name;

    final groupDoc = await _db.collection('game_groups').doc(groupId).get();
    if (groupDoc.exists) {
      final members = List<String>.from(groupDoc.data()?['members'] ?? []);
      if (members.contains(targetUid)) {
        // Linking a local player to someone already in the group: no invite
        // needed, the local player just becomes them.
        if (localPlayerIdToReplace != null) {
          await linkLocalPlayerToMember(
            groupId: groupId,
            groupName: groupName,
            localPlayerId: localPlayerIdToReplace,
            localPlayerName: localPlayerNameToReplace ?? '',
            memberUid: targetUid,
            memberName: targetName,
          );
          return "Linked";
        }
        return "User is already a synced member of this group.";
      }
    }

    final customMailId = _db.collection('users').doc().id;
    final batch = _db.batch();

    final baseData = {
      'groupId': groupId,
      'groupName': groupName,
      'targetUid': targetUid,
      'targetEmail': cleanEmail,
      'targetName': targetName,
      'senderName': senderName,
      'senderUid': senderUid,
      'status': 'pending',
      'localPlayerIdToReplace': localPlayerIdToReplace,
      'localPlayerNameToReplace': localPlayerNameToReplace,
      'createdAt': FieldValue.serverTimestamp(),
    };

    // ONLY write to the target's database. No more useless "sent" receipts!
    batch.set(
      _db
          .collection('users')
          .doc(targetUid)
          .collection('mail')
          .doc(customMailId),
      {...baseData, 'type': 'invite_received'},
    );

    await batch.commit();
    return "Success";
  }

  /// The group, or null if you can't see it (you're not a member, or it's
  /// gone): only members can read a group.
  Future<DocumentSnapshot<Map<String, dynamic>>?> _groupIfMember(
    String groupId,
  ) async {
    try {
      final doc = await _db.collection('game_groups').doc(groupId).get();
      return doc.exists ? doc : null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  /// Takes a local player out of a group's player lists (the account taking
  /// their place is already a member). Returns the changes to save.
  Map<String, dynamic> _withoutLocalPlayer(
    Map<String, dynamic> group,
    String localPlayerId,
    String localPlayerName,
    String uid,
  ) {
    bool isLocal(dynamic p) =>
        (p is Map && p['id'] == localPlayerId) ||
        p == localPlayerId ||
        (localPlayerName.isNotEmpty && p == localPlayerName);

    final update = <String, dynamic>{
      'localMembers': List<dynamic>.from(group['localMembers'] ?? [])
        ..removeWhere(isLocal),
      'guests': List<dynamic>.from(group['guests'] ?? [])..removeWhere(isLocal),
    };
    // Hidden in scorecard creation? Keep them hidden as their account.
    final hidden = List<String>.from(group['hiddenPlayers'] ?? []);
    if (hidden.remove(localPlayerId)) {
      if (!hidden.contains(uid)) hidden.add(uid);
      update['hiddenPlayers'] = hidden;
    }
    return update;
  }

  Future<void> acceptInvite(
    String inviteId,
    String groupId,
    String senderUid,
  ) async {
    final uid = _myUid;
    final myName =
        FirebaseAuth.instance.currentUser?.displayName ?? "A new player";

    final inviteRef = _db
        .collection('users')
        .doc(uid)
        .collection('mail')
        .doc(inviteId);
    final inviteDoc = await inviteRef.get();
    final localPlayerIdToReplace =
        inviteDoc.data()?['localPlayerIdToReplace'] as String?;
    final localPlayerNameToReplace =
        inviteDoc.data()?['localPlayerNameToReplace'] as String?;
    final groupName = inviteDoc.data()?['groupName'] ?? "a group";
    final groupRef = _db.collection('game_groups').doc(groupId);

    // 1. Join. The database rules let you add yourself to a group only in
    // the same write that accepts a pending invite to it.
    var group = await _groupIfMember(groupId);
    if (group == null) {
      final join = _db.batch();
      join.update(inviteRef, {'status': 'accepted'});
      join.update(groupRef, {
        'members': FieldValue.arrayUnion([uid]),
        'joinedVia': {'type': 'mail', 'id': inviteId},
      });
      await join.commit();
      group = await _groupIfMember(groupId);
      if (group == null) return;
    } else {
      await inviteRef.update({'status': 'accepted'});
    }

    // 2. Now a member: take the local player's place and tell the group.
    final data = group.data()!;
    final batch = _db.batch();
    if (localPlayerIdToReplace != null) {
      batch.update(
        groupRef,
        _withoutLocalPlayer(
          data,
          localPlayerIdToReplace,
          localPlayerNameToReplace ?? '',
          uid,
        ),
      );
    }

    final members = List<String>.from(data['members'] ?? []);
    for (String memberId in members) {
      if (memberId == uid) continue;

      String noticeMsg;
      if (memberId == senderUid) {
        noticeMsg = '$myName accepted your invite to "$groupName"!';
      } else {
        noticeMsg = localPlayerNameToReplace != null
            ? '$myName has linked to the local profile "$localPlayerNameToReplace" in "$groupName"!'
            : '$myName has joined the group "$groupName"!';
      }

      batch.set(_db.collection('users').doc(memberId).collection('mail').doc(), {
        'type': 'system_notice',
        'groupId': groupId,
        'senderUid': uid,
        'message': noticeMsg,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    // The local player's past games in this group become theirs.
    if (localPlayerIdToReplace != null) {
      await moveLocalHistoryToAccount(
        groupId: groupId,
        localPlayerId: localPlayerIdToReplace,
        localPlayerName: localPlayerNameToReplace ?? '',
        uid: uid,
        accountName: myName,
      );
    }
  }

  /// Merges a local player (member or guest) into someone who is already a
  /// synced member: the local profile goes away and its games become theirs.
  Future<void> linkLocalPlayerToMember({
    required String groupId,
    required String groupName,
    required String localPlayerId,
    required String localPlayerName,
    required String memberUid,
    required String memberName,
  }) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final myName = FirebaseAuth.instance.currentUser?.displayName ?? "A member";
    final groupRef = _db.collection('game_groups').doc(groupId);
    final groupDoc = await groupRef.get();
    if (!groupDoc.exists) return;
    final update = _withoutLocalPlayer(
      groupDoc.data()!,
      localPlayerId,
      localPlayerName,
      memberUid,
    );

    final batch = _db.batch();
    batch.update(groupRef, update);
    if (memberUid != myUid) {
      batch.set(
        _db.collection('users').doc(memberUid).collection('mail').doc(),
        {
          'type': 'system_notice',
          'groupId': groupId,
          'senderUid': _myUid,
          'message':
              '$myName linked the local player "$localPlayerName" in "$groupName" to your account. Their games are now yours.',
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
    }
    await batch.commit();

    await moveLocalHistoryToAccount(
      groupId: groupId,
      localPlayerId: localPlayerId,
      localPlayerName: localPlayerName,
      uid: memberUid,
      accountName: memberName,
    );
  }

  /// The token for an "Invite with a link" link that turns this local player
  /// into whoever opens it. Reuses the player's unused link if there is one.
  Future<String> createInviteLink({
    required String groupId,
    required String groupName,
    required String playerId,
    required String playerName,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final invites = _db.collection('player_invites');
    final existing = await invites
        .where('groupId', isEqualTo: groupId)
        .where('localPlayerId', isEqualTo: playerId)
        .get();
    for (final d in existing.docs) {
      if (d.data()['usedBy'] == null) {
        // Keep the name on it current in case the player was renamed.
        if (d.data()['localPlayerName'] != playerName ||
            d.data()['groupName'] != groupName) {
          await d.reference.update({
            'localPlayerName': playerName,
            'groupName': groupName,
          });
        }
        return d.id;
      }
    }
    final ref = invites.doc(); // random id: the link can't be guessed
    await ref.set({
      'groupId': groupId,
      'groupName': groupName,
      'localPlayerId': playerId,
      'localPlayerName': playerName,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'usedBy': null,
    });
    return ref.id;
  }

  /// Accepts an invite link for the signed-in account: they join the group
  /// in the local player's place and the player's past games become theirs.
  /// Returns the group and player names. Throws a message (as a String)
  /// when the link can't be used.
  Future<({String groupName, String playerName, bool alreadyDone})>
  claimInviteLink(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw "Sign in first.";
    try {
      await user.reload();
    } catch (_) {}
    final me = FirebaseAuth.instance.currentUser ?? user;
    final uid = me.uid;

    final inviteRef = _db.collection('player_invites').doc(token);
    final invite = await inviteRef.get();
    if (!invite.exists) {
      throw "This invite link doesn't work anymore. Ask for a new one.";
    }
    final inv = invite.data()!;
    final groupId = inv['groupId'] as String;
    final localId = inv['localPlayerId'] as String;
    final localName = (inv['localPlayerName'] ?? '') as String;
    final groupName = (inv['groupName'] ?? 'the group') as String;
    if (inv['usedBy'] != null) {
      if (inv['usedBy'] == uid) {
        return (groupName: groupName, playerName: localName, alreadyDone: true);
      }
      throw "This invite link has already been used.";
    }

    // No name yet (new account)? Take the player's.
    var myName = (me.displayName ?? '').trim();
    if (myName.isEmpty && localName.isNotEmpty) {
      myName = localName;
      try {
        await me.updateDisplayName(localName);
        await _db.collection('users').doc(uid).set({
          'displayName': localName,
          'email': me.email,
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    final groupRef = _db.collection('game_groups').doc(groupId);
    final existing = await _groupIfMember(groupId);
    if (existing != null) {
      // Already in the group: merge the local player into them.
      await linkLocalPlayerToMember(
        groupId: groupId,
        groupName: groupName,
        localPlayerId: localId,
        localPlayerName: localName,
        memberUid: uid,
        memberName: myName,
      );
      await inviteRef.update({
        'usedBy': uid,
        'usedAt': FieldValue.serverTimestamp(),
      });
      return (groupName: groupName, playerName: localName, alreadyDone: false);
    }

    // 1. Join. The database rules let you add yourself to a group only in
    // the same write that uses up an invite link to it.
    final join = _db.batch();
    join.update(groupRef, {
      'members': FieldValue.arrayUnion([uid]),
      'joinedVia': {'type': 'link', 'id': token},
    });
    join.update(inviteRef, {
      'usedBy': uid,
      'usedAt': FieldValue.serverTimestamp(),
    });
    try {
      await join.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' || e.code == 'not-found') {
        throw "That group doesn't exist anymore, so this link doesn't work.";
      }
      rethrow;
    }

    // 2. Now a member: take the player's place and tell the group.
    final group = await _groupIfMember(groupId);
    if (group == null) {
      return (groupName: groupName, playerName: localName, alreadyDone: false);
    }
    final data = group.data()!;
    final batch = _db.batch();
    batch.update(groupRef, _withoutLocalPlayer(data, localId, localName, uid));
    final who = myName.isEmpty ? 'Someone' : myName;
    for (final memberId in List<String>.from(data['members'] ?? [])) {
      if (memberId == uid) continue;
      batch.set(_db.collection('users').doc(memberId).collection('mail').doc(), {
        'type': 'system_notice',
        'groupId': groupId,
        'senderUid': uid,
        'message':
            '$who joined "$groupName" with an invite link and is now "$localName". Their past games came with them.',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    await moveLocalHistoryToAccount(
      groupId: groupId,
      localPlayerId: localId,
      localPlayerName: localName,
      uid: uid,
      accountName: myName,
    );
    return (groupName: groupName, playerName: localName, alreadyDone: false);
  }

  /// Rewrites a group's scorecards so a local player's seats belong to an
  /// account: the player id becomes the account's uid and the name becomes
  /// the account's name (metrics group players by name). Seats are matched
  /// by the local player's id, or by name where a game stored no id.
  /// Returns how many scorecards changed.
  Future<int> moveLocalHistoryToAccount({
    required String groupId,
    required String localPlayerId,
    required String localPlayerName,
    required String uid,
    required String accountName,
  }) async {
    final snap = await _db
        .collection('scorecards')
        .where('ownerType', isEqualTo: 'group')
        .where('ownerId', isEqualTo: groupId)
        .get();

    final newName = accountName.trim().isEmpty
        ? localPlayerName
        : accountName.trim();
    var changed = 0;
    WriteBatch batch = _db.batch();
    var inBatch = 0;

    for (final doc in snap.docs) {
      final data = doc.data();
      final names = List<dynamic>.from(data['playerNames'] ?? []);
      final ids = List<dynamic>.from(data['playerIds'] ?? []);
      while (ids.length < names.length) {
        ids.add('');
      }
      var touched = false;
      for (var i = 0; i < names.length; i++) {
        final id = (ids[i] ?? '').toString();
        final byId = id == localPlayerId;
        final byName =
            id.isEmpty &&
            localPlayerName.isNotEmpty &&
            names[i].toString().trim().toLowerCase() ==
                localPlayerName.trim().toLowerCase();
        if (byId || byName) {
          ids[i] = uid;
          names[i] = newName;
          touched = true;
        }
      }
      if (!touched) continue;
      batch.update(doc.reference, {'playerIds': ids, 'playerNames': names});
      changed++;
      if (++inBatch == 400) {
        await batch.commit();
        batch = _db.batch();
        inBatch = 0;
      }
    }
    if (inBatch > 0) await batch.commit();
    return changed;
  }

  Future<void> denyInvite(String inviteId, String senderUid) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final batch = _db.batch();

    // Update ONLY the receiver's invite status to denied
    batch.update(
      _db.collection('users').doc(uid).collection('mail').doc(inviteId),
      {'status': 'denied'},
    );

    await batch.commit();
  }

  Stream<QuerySnapshot> getMyInvitesStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    return _db
        .collection('users')
        .doc(uid)
        .collection('mail')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> togglePlayerVisibility(
    String groupId,
    String playerId,
    bool isHidden,
  ) async {
    final groupRef = _db.collection('game_groups').doc(groupId);
    if (isHidden) {
      await groupRef.update({
        'hiddenPlayers': FieldValue.arrayUnion([playerId]),
      });
    } else {
      await groupRef.update({
        'hiddenPlayers': FieldValue.arrayRemove([playerId]),
      });
    }
  }
}
