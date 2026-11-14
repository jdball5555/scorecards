import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/shared_widgets/glass_card.dart';
import '../../../core/shared_widgets/gradient_background.dart';
import '../../../core/shared_widgets/sleek_notification_banner.dart';
import 'package:scorecards_app/core/shared_widgets/top_bar_background.dart';

class AxisMigrationScreen extends StatefulWidget {
  const AxisMigrationScreen({super.key});

  @override
  State<AxisMigrationScreen> createState() => _AxisMigrationScreenState();
}

class _AxisMigrationScreenState extends State<AxisMigrationScreen> {
  final TextEditingController _jsonController = TextEditingController();
  bool _isMigrating = false;
  String? _validationMessage;
  bool _isValid = false;
  int _parsedGameCount = 0;

  // ---------------------------------------------------------------------------
  // Only the fields we actually want in each round. Everything else is stripped.
  // ---------------------------------------------------------------------------
  static const _roundKeepFields = {
    'roundNum',
    'p1Bid',
    'p2Bid',
    'p3Bid',
    'p4Bid',
    'p1NilSuccess',
    'p2NilSuccess',
    'p3NilSuccess',
    'p4NilSuccess',
    'p1BlindNilSuccess',
    'p2BlindNilSuccess',
    'p3BlindNilSuccess',
    'p4BlindNilSuccess',
    't1Hand',
    't1Total',
    't1Set',
    't1Bagged',
    't1TenForTwo',
    't2Hand',
    't2Total',
    't2Set',
    't2Bagged',
    't2TenForTwo',
  };

  // ---------------------------------------------------------------------------
  // Parse a date string that may be MM/dd/yyyy OR MM/dd/yy OR ISO-8601
  // ---------------------------------------------------------------------------
  DateTime _parseDate(String? axisId, String? dateStr, String? isoTimestamp) {
    if (axisId != null && axisId.isNotEmpty) {
      final idMatch = RegExp(r'^SPD-(\d{6})-').firstMatch(axisId);
      if (idMatch != null) {
        try {
          final raw = idMatch.group(1)!;
          final year = 2000 + int.parse(raw.substring(0, 2));
          final month = int.parse(raw.substring(2, 4));
          final day = int.parse(raw.substring(4, 6));
          return DateTime(year, month, day);
        } catch (_) {
          // ignore
        }
      }
    }

    if (dateStr != null && dateStr.isNotEmpty) {
      final parts = dateStr.split('/');
      if (parts.length == 3) {
        try {
          final month = int.parse(parts[0]);
          final day = int.parse(parts[1]);
          int year = int.parse(parts[2]);
          if (year < 100) {
            year += 2000;
          }
          return DateTime(year, month, day);
        } catch (_) {
          // ignore
        }
      }
    }

    if (isoTimestamp != null && isoTimestamp.isNotEmpty) {
      try {
        return DateTime.parse(isoTimestamp);
      } catch (_) {
        // ignore
      }
    }

    return DateTime.now();
  }

  // ---------------------------------------------------------------------------
  // Validate JSON and update the live status indicator
  // ---------------------------------------------------------------------------
  void _validateJson(String text) {
    text = text.trim();
    if (text.isEmpty) {
      setState(() {
        _validationMessage = null;
        _isValid = false;
        _parsedGameCount = 0;
      });
      return;
    }

    try {
      final decoded = jsonDecode(text);
      if (decoded is! List) {
        throw Exception('Root must be a JSON array [ ... ]');
      }
      setState(() {
        _parsedGameCount = decoded.length;
        _isValid = true;
        _validationMessage =
            '✓ Valid JSON — $_parsedGameCount game${_parsedGameCount == 1 ? '' : 's'} detected';
      });
    } catch (e) {
      String hint = e.toString();
      final offsetMatch = RegExp(r'position (\d+)').firstMatch(hint);
      if (offsetMatch != null) {
        final pos = int.tryParse(offsetMatch.group(1) ?? '') ?? 0;
        final snippet = text.length > pos + 20
            ? text.substring(pos, pos + 20)
            : text.substring(pos);
        hint = 'Parse error near position $pos: "$snippet..."';
      }
      setState(() {
        _isValid = false;
        _parsedGameCount = 0;
        _validationMessage = '✗ $hint';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // GROUP SELECTION DIALOG
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>?> _selectGroupDestination(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('game_groups')
        .where('members', arrayContains: uid)
        .get();

    final groups = snap.docs;

    if (!mounted) return null;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Select Destination',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text(
                  'Personal Scorecards',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'Do not sync with a group',
                  style: TextStyle(color: Colors.white54),
                ),
                leading: const Icon(Icons.person, color: Colors.white),
                onTap: () => Navigator.pop(ctx, {'type': 'person'}),
              ),
              const Divider(color: Colors.white24),
              if (groups.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "No game groups found.",
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              else
                ...groups.map((g) {
                  final data = g.data();
                  return ListTile(
                    title: Text(
                      data['name'] ?? 'Unnamed Group',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text(
                      "Sync to group dashboard",
                      style: TextStyle(color: Colors.white54),
                    ),
                    leading: const Icon(Icons.group, color: Color(0xFF00A2FF)),
                    onTap: () => Navigator.pop(ctx, {
                      'type': 'group',
                      'id': g.id,
                      'name': data['name'],
                    }),
                  );
                }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RECONCILE MISSING PLAYERS WITH SELECTED GROUP
  // ---------------------------------------------------------------------------
  Future<bool> _reconcileGroupPlayers(
    String groupId,
    List<String> importedNames,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final groupDoc = await FirebaseFirestore.instance
        .collection('game_groups')
        .doc(groupId)
        .get();
    List<String> knownNames = [];

    if (groupDoc.exists) {
      final data = groupDoc.data()!;

      void extractNames(List<dynamic> raw) {
        for (var e in raw) {
          if (e is Map) {
            String n = e['name']?.toString().trim() ?? '';
            if (n.isNotEmpty) knownNames.add(n);
          } else if (e is String) {
            knownNames.add(e.trim());
          }
        }
      }

      extractNames(data['localMembers'] ?? []);
      extractNames(data['guests'] ?? []);

      List<String> memberUids = List<String>.from(data['members'] ?? []);
      for (String mUid in memberUids) {
        final uDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(mUid)
            .get();
        if (uDoc.exists && uDoc.data()!.containsKey('displayName')) {
          knownNames.add(uDoc.data()!['displayName']);
        }
      }
    }

    if (mounted) Navigator.pop(context);

    List<String> missingNames = importedNames
        .where((n) => !knownNames.contains(n))
        .toList();

    if (missingNames.isEmpty) return true;

    Map<String, String> selections = {for (var n in missingNames) n: 'guest'};

    bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A2E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Unrecognized Players',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "The following players from your imported data are not in this group's roster. How should we add them?",
                        style: TextStyle(color: Colors.white70, height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      ...missingNames.map(
                        (name) => Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  color: Color(0xFF00A2FF),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: RadioListTile<String>(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text(
                                        "Guest",
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                      value: 'guest',
                                      groupValue: selections[name],
                                      onChanged: (val) => setDialogState(
                                        () => selections[name] = val!,
                                      ),
                                      activeColor: const Color(0xFF00A2FF),
                                    ),
                                  ),
                                  Expanded(
                                    child: RadioListTile<String>(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text(
                                        "Local Member",
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                      value: 'localMember',
                                      groupValue: selections[name],
                                      onChanged: (val) => setDialogState(
                                        () => selections[name] = val!,
                                      ),
                                      activeColor: const Color(0xFF00A2FF),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A2FF),
                  ),
                  child: const Text(
                    'Add & Continue',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return false;

    List<Map<String, String>> newGuests = [];
    List<Map<String, String>> newLocalMembers = [];
    selections.forEach((name, type) {
      String newId =
          'local_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(100000)}';
      if (type == 'guest') {
        newGuests.add({'id': newId, 'name': name});
      } else {
        newLocalMembers.add({'id': newId, 'name': name});
      }
    });

    if (newGuests.isNotEmpty || newLocalMembers.isNotEmpty) {
      final ref = FirebaseFirestore.instance
          .collection('game_groups')
          .doc(groupId);
      if (newGuests.isNotEmpty) {
        await ref.update({'guests': FieldValue.arrayUnion(newGuests)});
      }
      if (newLocalMembers.isNotEmpty) {
        await ref.update({
          'localMembers': FieldValue.arrayUnion(newLocalMembers),
        });
      }
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // MAIN MIGRATION
  // ---------------------------------------------------------------------------
  Future<void> _migrateData() async {
    final text = _jsonController.text.trim();
    if (text.isEmpty || !_isValid) return;

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      SleekNotificationBanner.show(
        "Error",
        "You must be logged in to migrate.",
        icon: Icons.error,
        color: Colors.redAccent,
      );
      return;
    }

    final List<dynamic> rawGames = jsonDecode(text);

    // 1. Harvest all unique names from the JSON payload
    Set<String> uniqueNames = {};
    for (var game in rawGames) {
      if (game['p1Name'] != null) {
        uniqueNames.add(game['p1Name'].toString().trim());
      }
      if (game['p2Name'] != null) {
        uniqueNames.add(game['p2Name'].toString().trim());
      }
      if (game['p3Name'] != null) {
        uniqueNames.add(game['p3Name'].toString().trim());
      }
      if (game['p4Name'] != null) {
        uniqueNames.add(game['p4Name'].toString().trim());
      }
    }
    uniqueNames.removeWhere((name) => name.isEmpty);

    // 2. Ask user for Destination (Personal vs Group)
    final destination = await _selectGroupDestination(uid);
    if (destination == null) return; // Cancelled

    String destType = destination['type'];
    String destId = destination['id'] ?? uid; // Defaults to UID if personal
    String? destGroupName = destination['name'];

    // 3. If Group, reconcile the names
    if (destType == 'group') {
      bool ready = await _reconcileGroupPlayers(destId, uniqueNames.toList());
      if (!ready) return; // User cancelled during reconciliation
    }

    setState(() => _isMigrating = true);

    try {
      final List<Map<String, dynamic>> allDocs = [];

      // --- 4. BUILD ID MAP FOR DESTINATION ---
      Map<String, String> nameToIdMap = {};

      if (destType == 'group') {
        final groupDoc = await FirebaseFirestore.instance
            .collection('game_groups')
            .doc(destId)
            .get();
        if (groupDoc.exists) {
          final data = groupDoc.data()!;
          List<String> memberUids = List<String>.from(data['members'] ?? []);

          for (String mUid in memberUids) {
            final uDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(mUid)
                .get();
            if (uDoc.exists && uDoc.data()!.containsKey('displayName')) {
              nameToIdMap[uDoc.data()!['displayName'].toString().trim()] = mUid;
            }
          }

          void mapLocals(List<dynamic> raw) {
            for (var e in raw) {
              if (e is Map) {
                String n = e['name']?.toString().trim() ?? '';
                String id = e['id']?.toString().trim() ?? '';
                if (n.isNotEmpty && id.isNotEmpty) nameToIdMap[n] = id;
              } else if (e is String) {
                nameToIdMap[e.trim()] = e
                    .trim(); // Fallback for legacy local strings
              }
            }
          }

          mapLocals(data['localMembers'] ?? []);
          mapLocals(data['guests'] ?? []);
        }
      } else {
        // Personal Scorecards Map
        final uDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(destId)
            .get();
        if (uDoc.exists && uDoc.data()!.containsKey('displayName')) {
          nameToIdMap[uDoc.data()!['displayName'].toString().trim()] = destId;
        }
      }

      String getId(String name) {
        if (nameToIdMap.containsKey(name) && nameToIdMap[name]!.isNotEmpty) {
          return nameToIdMap[name]!;
        }
        String newId =
            'local_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(100000)}';
        nameToIdMap[name] = newId;
        return newId;
      }

      // Track game counts per day to offset times for chronological sorting
      Map<String, int> dateCounters = {};

      // --- 5. PROCESS DOCUMENTS ---
      for (final axisGame in rawGames) {
        // We now generate a true Firestore Auto-ID so migrating old games doesn't lock us into the rigid Axis format.
        final String newDocId = FirebaseFirestore.instance
            .collection('scorecards')
            .doc()
            .id;

        // Player name mapping
        final String p1 = (axisGame['p1Name'] as String?)?.trim() ?? 'Player 1';
        final String p2 =
            (axisGame['p3Name'] as String?)?.trim() ??
            'Player 2'; // swapped Axis p3
        final String p3 =
            (axisGame['p2Name'] as String?)?.trim() ??
            'Player 3'; // swapped Axis p2
        final String p4 = (axisGame['p4Name'] as String?)?.trim() ?? 'Player 4';

        // Map to corresponding Player IDs
        List<String> pIds = [getId(p1), getId(p2), getId(p3), getId(p4)];

        // Round transformation
        final List<Map<String, dynamic>> newRounds = [];
        final List<dynamic> oldRounds = (axisGame['rounds'] as List?) ?? [];

        for (final r in oldRounds) {
          final Map<String, dynamic> nr = {};

          nr['roundNum'] = r['roundNum'];
          nr['p1Bid'] = r['p1Bid'];
          nr['p2Bid'] = r['p3Bid']; // swapped
          nr['p3Bid'] = r['p2Bid']; // swapped
          nr['p4Bid'] = r['p4Bid'];
          nr['t1Hand'] = r['t1Hand'];
          nr['t1Total'] = r['t1Total'];
          nr['t2Hand'] = r['t2Hand'];
          nr['t2Total'] = r['t2Total'];

          if (r['p1NilSuccess'] != null) {
            nr['p1NilSuccess'] = r['p1NilSuccess'];
          }
          if (r['p3NilSuccess'] != null) {
            nr['p2NilSuccess'] = r['p3NilSuccess']; // swapped
          }
          if (r['p2NilSuccess'] != null) {
            nr['p3NilSuccess'] = r['p2NilSuccess']; // swapped
          }
          if (r['p4NilSuccess'] != null) {
            nr['p4NilSuccess'] = r['p4NilSuccess'];
          }

          if (r['p1BlindNilSuccess'] != null) {
            nr['p1BlindNilSuccess'] = r['p1BlindNilSuccess'];
          }
          if (r['p3BlindNilSuccess'] != null) {
            nr['p2BlindNilSuccess'] = r['p3BlindNilSuccess']; // swapped
          }
          if (r['p2BlindNilSuccess'] != null) {
            nr['p3BlindNilSuccess'] = r['p2BlindNilSuccess']; // swapped
          }
          if (r['p4BlindNilSuccess'] != null) {
            nr['p4BlindNilSuccess'] = r['p4BlindNilSuccess'];
          }

          for (final key in [
            't1Set',
            't2Set',
            't1Bagged',
            't2Bagged',
            't1TenForTwo',
            't2TenForTwo',
          ]) {
            if (r[key] != null) {
              nr[key] = r[key];
            }
          }

          nr.removeWhere((k, v) => v == null || !_roundKeepFields.contains(k));
          newRounds.add(nr);
        }

        // Date / timestamp
        DateTime baseDate = _parseDate(
          axisGame['id'] as String?,
          axisGame['date'] as String?,
          axisGame['timestamp'] as String?,
        );

        // --- NEW: Chronological Spacing ---
        // Increment the minutes so games on the same date sort chronologically
        // properly in the final UI (e.g. 12:01 AM, 12:02 AM, etc.)
        String dateKey = "${baseDate.year}-${baseDate.month}-${baseDate.day}";
        int offset = dateCounters[dateKey] ?? 0;
        offset++;
        dateCounters[dateKey] = offset;

        DateTime finalCreatedDate = baseDate.add(Duration(minutes: offset));

        // Final document payload
        allDocs.add({
          'id': newDocId,
          'gameType': 'Spades',
          'ownerType': destType,
          'ownerId': destId,
          if (destGroupName != null) 'groupName': destGroupName,
          'createdDate': Timestamp.fromDate(finalCreatedDate),
          'lastUpdatedDate': Timestamp.fromDate(finalCreatedDate),
          'playerNames': [p1, p2, p3, p4],
          'playerIds': pIds,
          'rounds': newRounds,
          'isFinalized': true,
          'migratedFromAxis': true,
          'bagsCountAsPoints': false,
          'rules': {'bagsCountAsPoints': false, 'nilPartnerMinBid': 3},
        });
      }

      // ── Write in chunks of 500 (Firestore batch limit) ───────────────────
      const int chunkSize = 500;
      for (int i = 0; i < allDocs.length; i += chunkSize) {
        final chunk = allDocs.sublist(
          i,
          (i + chunkSize).clamp(0, allDocs.length),
        );
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in chunk) {
          final ref = FirebaseFirestore.instance
              .collection('scorecards')
              .doc(doc['id'] as String);
          batch.set(ref, doc);
        }
        await batch.commit();
      }

      _jsonController.clear();
      setState(() {
        _validationMessage = null;
        _isValid = false;
        _parsedGameCount = 0;
      });

      if (mounted) {
        SleekNotificationBanner.show(
          'Migration Complete',
          'Successfully migrated ${allDocs.length} games to ${destGroupName ?? 'Personal Scorecards'}!',
          icon: Icons.check_circle,
          color: Colors.green,
        );
      }
    } catch (e) {
      if (mounted) {
        SleekNotificationBanner.show(
          'Migration Failed',
          'Error: ${e.toString().replaceAll('Exception: ', '')}',
          icon: Icons.error_outline,
          color: Colors.redAccent,
        );
      }
    } finally {
      if (mounted) setState(() => _isMigrating = false);
    }
  }

  // ---------------------------------------------------------------------------
  // DELETE OLD SPADES GAMES
  // ---------------------------------------------------------------------------
  Future<void> _deleteOldSpadesScorecards() async {
    final step1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '⚠ Delete Old Spades Games?',
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'This will permanently delete all Spades scorecards created on or before June 8, 2026.\n\nThis cannot be undone.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Yes, continue',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (step1 != true) return;

    final step2 =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            String typed = '';
            return StatefulBuilder(
              builder: (ctx, setDialogState) => AlertDialog(
                backgroundColor: const Color(0xFF1A1A2E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text(
                  'Type DELETE to confirm',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Type the word DELETE in all caps to confirm permanent deletion:',
                      style: TextStyle(color: Colors.white70, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      autofocus: true,
                      onChanged: (val) => setDialogState(() => typed = val),
                      style: const TextStyle(
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                      decoration: InputDecoration(
                        hintText: 'DELETE',
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: typed.trim() == 'DELETE'
                          ? Colors.redAccent
                          : Colors.white12,
                    ),
                    onPressed: typed.trim() == 'DELETE'
                        ? () => Navigator.pop(ctx, true)
                        : null,
                    child: const Text(
                      'DELETE GAMES',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ) ??
        false;
    if (!step2) return;

    setState(() => _isMigrating = true);

    try {
      final cutoffDate = DateTime(2026, 6, 8, 23, 59, 59);

      final snap = await FirebaseFirestore.instance
          .collection('scorecards')
          .get();
      List<DocumentReference> toDelete = [];

      for (var doc in snap.docs) {
        final data = doc.data();
        final String gType = data['gameType']?.toString().toLowerCase() ?? '';

        if (gType == 'spades') {
          DateTime? docDate;
          if (data['createdDate'] is Timestamp) {
            docDate = (data['createdDate'] as Timestamp).toDate();
          } else if (data['createdDate'] is String) {
            docDate = DateTime.tryParse(data['createdDate']);
          }

          if (docDate != null &&
              docDate.isBefore(cutoffDate.add(const Duration(seconds: 1)))) {
            toDelete.add(doc.reference);
          }
        }
      }

      int totalDeleted = 0;
      const int chunkSize = 500;

      for (int i = 0; i < toDelete.length; i += chunkSize) {
        final batch = FirebaseFirestore.instance.batch();
        final chunk = toDelete.sublist(
          i,
          math.min(i + chunkSize, toDelete.length),
        );
        for (final ref in chunk) {
          batch.delete(ref);
        }
        await batch.commit();
        totalDeleted += chunk.length;
      }

      if (mounted) {
        SleekNotificationBanner.show(
          'Cleanup Complete',
          'Deleted $totalDeleted old Spades scorecards from Firestore.',
          icon: Icons.delete_sweep,
          color: Colors.redAccent,
        );
      }
    } catch (e) {
      if (mounted) {
        SleekNotificationBanner.show(
          'Delete Failed',
          'Error: ${e.toString().replaceAll('Exception: ', '')}',
          icon: Icons.error_outline,
          color: Colors.redAccent,
        );
      }
    } finally {
      if (mounted) setState(() => _isMigrating = false);
    }
  }

  // ---------------------------------------------------------------------------
  // MIGRATE SCORECARD IDS TO AUTO-IDS
  // ---------------------------------------------------------------------------
  Future<void> _migrateScorecardIds() async {
    final step1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '⚠ Standardize Scorecard IDs?',
          style: TextStyle(
            color: Colors.orangeAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'This will scan your entire database, find any scorecards using the old dashed ID format (e.g., SPD-260328-B001), create a new copy of them using a standard Firestore Auto-ID, and delete the old document.\n\nThis prevents scaling issues and write collisions. Are you sure you want to run this?',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Yes, continue',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (step1 != true) return;

    setState(() => _isMigrating = true);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('scorecards')
          .get();
      int updatedCount = 0;

      var batch = FirebaseFirestore.instance.batch();
      int currentOpCount = 0;

      for (var doc in snap.docs) {
        final oldId = doc.id;

        if (oldId.contains('-') || oldId.length < 20) {
          final newRef = FirebaseFirestore.instance
              .collection('scorecards')
              .doc();
          final newData = doc.data();
          newData['id'] = newRef.id;

          batch.set(newRef, newData);
          batch.delete(doc.reference);
          currentOpCount += 2;
          updatedCount++;

          if (currentOpCount >= 498) {
            await batch.commit();
            batch = FirebaseFirestore.instance.batch();
            currentOpCount = 0;
          }
        }
      }

      if (currentOpCount > 0) {
        await batch.commit();
      }

      if (mounted) {
        SleekNotificationBanner.show(
          'Migration Complete',
          'Successfully updated $updatedCount scorecards to the new Firestore Auto-ID format.',
          icon: Icons.check_circle,
          color: Colors.green,
        );
      }
    } catch (e) {
      if (mounted) {
        SleekNotificationBanner.show(
          'Migration Failed',
          'Error: ${e.toString()}',
          icon: Icons.error_outline,
          color: Colors.redAccent,
        );
      }
    } finally {
      if (mounted) setState(() => _isMigrating = false);
    }
  }

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color validationColor = Colors.white54;
    if (_validationMessage != null) {
      validationColor = _isValid ? Colors.greenAccent : Colors.redAccent;
    }

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          flexibleSpace: const TopBarBackground(),
          title: const Text(
            'Axis Data Migration',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste your Axis JSON export below. The migration will:\n'
                '  • Swap Players 2 & 3 to match Scorecards column order\n'
                '  • Strip internal Axis fields (bags tracking, etc.)\n'
                '  • Allow you to assign games to an existing Game Group\n'
                '  • Handle two-digit years (e.g. 01/31/23)',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 12),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _validationMessage != null
                    ? Container(
                        key: ValueKey(_validationMessage),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: (_isValid ? Colors.green : Colors.redAccent)
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                (_isValid
                                        ? Colors.greenAccent
                                        : Colors.redAccent)
                                    .withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          _validationMessage!,
                          style: TextStyle(
                            color: validationColor,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: 12),

              Expanded(
                child: GlassCard(
                  accentColor: const Color(0xFF7855C1),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _jsonController,
                      maxLines: null,
                      expands: true,
                      onChanged: _validateJson,
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            '[{"date":"08/07/2022","gameType":"spades","p1Name":"Jonathan",...}]',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.2),
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Align(
                alignment: Alignment.centerRight,
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _jsonController,
                  builder: (_, value, __) => Text(
                    '${value.text.length} characters',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isValid
                        ? const Color(0xFF00A2FF)
                        : Colors.white12,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: (_isMigrating || !_isValid) ? null : _migrateData,
                  child: _isMigrating
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Migrating...',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        )
                      : Text(
                          _isValid
                              ? 'MIGRATE $_parsedGameCount GAME${_parsedGameCount == 1 ? '' : 'S'}'
                              : 'PASTE VALID JSON TO CONTINUE',
                          style: TextStyle(
                            color: _isValid ? Colors.white : Colors.white38,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent, width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isMigrating ? null : _deleteOldSpadesScorecards,
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: const Text(
                    'DELETE OLD SPADES SCORECARDS',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orangeAccent,
                    side: const BorderSide(
                      color: Colors.orangeAccent,
                      width: 1,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isMigrating ? null : _migrateScorecardIds,
                  icon: const Icon(Icons.published_with_changes, size: 18),
                  label: const Text(
                    'TEMP: MIGRATE SCORECARD IDS',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
