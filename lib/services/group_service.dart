import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    batch.update(groupRef, {
      arrayName: FieldValue.arrayUnion([playerName.trim()]),
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
    String playerName,
    bool isGuest,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final myName = FirebaseAuth.instance.currentUser?.displayName ?? "A member";

    String arrayName = isGuest ? 'guests' : 'localMembers';
    final batch = _db.batch();
    final groupRef = _db.collection('game_groups').doc(groupId);

    batch.update(groupRef, {
      arrayName: FieldValue.arrayRemove([playerName.trim()]),
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
              '$myName removed local player "$playerName" from "$groupName".',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
    await batch.commit();
  }

  Future<void> renamePlayer(
    String groupId,
    String oldName,
    String newName,
    bool isGuest,
  ) async {
    if (oldName == newName || newName.trim().isEmpty) return;
    String arrayName = isGuest ? 'guests' : 'localMembers';
    final docRef = _db.collection('game_groups').doc(groupId);
    WriteBatch batch = _db.batch();
    batch.update(docRef, {
      arrayName: FieldValue.arrayRemove([oldName.trim()]),
    });
    batch.update(docRef, {
      arrayName: FieldValue.arrayUnion([newName.trim()]),
    });
    await batch.commit();
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
    String? localPlayerToReplace,
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
      if (members.contains(targetUid))
        return "User is already a synced member of this group.";
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
      'localPlayerToReplace': localPlayerToReplace,
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
    final batch = _db.batch();

    final inviteDoc = await _db
        .collection('users')
        .doc(uid)
        .collection('mail')
        .doc(inviteId)
        .get();
    final localPlayerToReplace = inviteDoc.data()?['localPlayerToReplace'];
    final groupName = inviteDoc.data()?['groupName'] ?? "a group";

    // Update ONLY the receiver's invite status to accepted
    batch.update(
      _db.collection('users').doc(uid).collection('mail').doc(inviteId),
      {'status': 'accepted'},
    );

    final groupUpdate = <String, dynamic>{
      'members': FieldValue.arrayUnion([uid]),
    };

    if (localPlayerToReplace != null) {
      groupUpdate['localMembers'] = FieldValue.arrayRemove([
        localPlayerToReplace,
      ]);
      groupUpdate['guests'] = FieldValue.arrayRemove([localPlayerToReplace]);
    }

    batch.update(_db.collection('game_groups').doc(groupId), groupUpdate);

    // Notify everyone (including the specific message for the sender)
    final groupDoc = await _db.collection('game_groups').doc(groupId).get();
    if (groupDoc.exists) {
      final members = List<String>.from(groupDoc.data()?['members'] ?? []);
      for (String memberId in members) {
        if (memberId == uid) continue;

        String noticeMsg;
        if (memberId == senderUid) {
          noticeMsg = '$myName accepted your invite to "$groupName"!';
        } else {
          noticeMsg = localPlayerToReplace != null
              ? '$myName has linked to the local profile "$localPlayerToReplace" in "$groupName"!'
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
    }

    await batch.commit();
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
}
