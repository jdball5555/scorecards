import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;

class GroupService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
        'message': memberId == uid
            ? 'You deleted the group "$groupName".'
            : '$myName deleted the group "$groupName".',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
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

    final userQuery = await _db
        .collection('users')
        .where('email', isEqualTo: cleanEmail)
        .get();
    if (userQuery.docs.isEmpty) return "No account found with that email.";

    final targetUid = userQuery.docs.first.id;
    final targetName = userQuery.docs.first.data()['displayName'] ?? "A player";

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

  Future<void> acceptInvite(
    String inviteId,
    String groupId,
    String senderUid,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final myName =
        FirebaseAuth.instance.currentUser?.displayName ?? "A new player";

    final inviteDoc = await _db
        .collection('users')
        .doc(uid)
        .collection('mail')
        .doc(inviteId)
        .get();
    final localPlayerIdToReplace = inviteDoc.data()?['localPlayerIdToReplace'];
    final localPlayerNameToReplace = inviteDoc
        .data()?['localPlayerNameToReplace'];
    final groupName = inviteDoc.data()?['groupName'] ?? "a group";

    final groupDoc = await _db.collection('game_groups').doc(groupId).get();
    if (!groupDoc.exists) return;

    final batch = _db.batch();

    // Update ONLY the receiver's invite status to accepted
    batch.update(
      _db.collection('users').doc(uid).collection('mail').doc(inviteId),
      {'status': 'accepted'},
    );

    final members = List<String>.from(groupDoc.data()?['members'] ?? []);
    if (!members.contains(uid)) {
      members.add(uid);
    }

    final updateData = <String, dynamic>{'members': members};

    if (localPlayerIdToReplace != null) {
      final localMembers = List<dynamic>.from(
        groupDoc.data()?['localMembers'] ?? [],
      );
      localMembers.removeWhere(
        (p) =>
            (p is Map && p['id'] == localPlayerIdToReplace) ||
            p == localPlayerNameToReplace ||
            p == localPlayerIdToReplace,
      );
      updateData['localMembers'] = localMembers;

      final guests = List<dynamic>.from(groupDoc.data()?['guests'] ?? []);
      guests.removeWhere(
        (p) =>
            (p is Map && p['id'] == localPlayerIdToReplace) ||
            p == localPlayerNameToReplace ||
            p == localPlayerIdToReplace,
      );
      updateData['guests'] = guests;

      // Hidden in scorecard creation? Keep them hidden as their account.
      final hidden = List<String>.from(groupDoc.data()?['hiddenPlayers'] ?? []);
      if (hidden.remove(localPlayerIdToReplace)) {
        if (!hidden.contains(uid)) hidden.add(uid);
        updateData['hiddenPlayers'] = hidden;
      }
    }

    batch.update(_db.collection('game_groups').doc(groupId), updateData);

    // Notify everyone (including the specific message for the sender)
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

      final mailRef = _db
          .collection('users')
          .doc(memberId)
          .collection('mail')
          .doc();
      batch.set(mailRef, {
        'type': 'system_notice',
        'message': noticeMsg,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    // Now a member: the local player's past games in this group become theirs.
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
    final data = groupDoc.data()!;

    bool isLocal(dynamic p) =>
        (p is Map && p['id'] == localPlayerId) ||
        p == localPlayerId ||
        (localPlayerName.isNotEmpty && p == localPlayerName);

    final localMembers = List<dynamic>.from(data['localMembers'] ?? [])
      ..removeWhere(isLocal);
    final guests = List<dynamic>.from(data['guests'] ?? [])
      ..removeWhere(isLocal);
    final update = <String, dynamic>{
      'localMembers': localMembers,
      'guests': guests,
    };
    final hidden = List<String>.from(data['hiddenPlayers'] ?? []);
    if (hidden.remove(localPlayerId)) {
      if (!hidden.contains(memberUid)) hidden.add(memberUid);
      update['hiddenPlayers'] = hidden;
    }

    final batch = _db.batch();
    batch.update(groupRef, update);
    if (memberUid != myUid) {
      batch.set(
        _db.collection('users').doc(memberUid).collection('mail').doc(),
        {
          'type': 'system_notice',
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
  /// Returns the group and player names. Throws [InviteProblem]-style
  /// messages (as a String) when the link can't be used.
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

    final groupRef = _db.collection('game_groups').doc(groupId);
    final groupDoc = await groupRef.get();
    if (!groupDoc.exists) throw "That group doesn't exist anymore.";
    final data = groupDoc.data()!;

    bool isLocal(dynamic p) =>
        (p is Map && p['id'] == localId) ||
        p == localId ||
        (localName.isNotEmpty && p == localName);
    final localMembers = List<dynamic>.from(data['localMembers'] ?? []);
    final guests = List<dynamic>.from(data['guests'] ?? []);
    if (!localMembers.any(isLocal) && !guests.any(isLocal)) {
      throw "$localName isn't in $groupName anymore, so this link doesn't work.";
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

    final members = List<String>.from(data['members'] ?? []);
    if (members.contains(uid)) {
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

    localMembers.removeWhere(isLocal);
    guests.removeWhere(isLocal);
    final update = <String, dynamic>{
      'members': FieldValue.arrayUnion([uid]),
      'localMembers': localMembers,
      'guests': guests,
    };
    final hidden = List<String>.from(data['hiddenPlayers'] ?? []);
    if (hidden.remove(localId)) {
      if (!hidden.contains(uid)) hidden.add(uid);
      update['hiddenPlayers'] = hidden;
    }

    final batch = _db.batch();
    batch.update(groupRef, update);
    batch.update(inviteRef, {
      'usedBy': uid,
      'usedAt': FieldValue.serverTimestamp(),
    });
    final who = myName.isEmpty ? 'Someone' : myName;
    for (final memberId in members) {
      batch.set(_db.collection('users').doc(memberId).collection('mail').doc(), {
        'type': 'system_notice',
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
