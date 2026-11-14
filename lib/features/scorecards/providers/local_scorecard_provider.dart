import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocalScorecard {
  final String id;
  final String gameType;
  final String? groupName;
  final String ownerType;
  final String ownerId;
  final DateTime createdDate;
  final DateTime lastUpdatedDate;
  final List<String> playerNames;
  final List<String> playerIds;
  final List<Map<String, dynamic>> rounds;
  final bool isSynced;
  final bool isFinalized; // Locks the scorecard from future edits
  final bool isLive; // Determines if the game auto-syncs per change

  // NEW: Holds root-level rules and settings (like exactly100bonus)
  final Map<String, dynamic> customSettings;

  LocalScorecard({
    required this.id,
    required this.gameType,
    this.groupName,
    required this.ownerType,
    required this.ownerId,
    required this.createdDate,
    required this.lastUpdatedDate,
    required this.playerNames,
    required this.playerIds,
    required this.rounds,
    this.isSynced = false,
    this.isFinalized = false,
    this.isLive = false,
    this.customSettings = const {}, // Added to constructor
  });

  // --- UPDATED: Native Firestore Auto-ID Generator ---
  static Future<String> generateCustomId(String gameType) async {
    // Generates a robust 20-character random ID to completely avoid write collisions
    return FirebaseFirestore.instance.collection('scorecards').doc().id;
  }

  factory LocalScorecard.fromMap(Map<String, dynamic> map) {
    List<String> players = List<String>.from(map['playerNames'] ?? []);
    List<String> ids = List<String>.from(map['playerIds'] ?? []);
    if (ids.isEmpty || ids.length != players.length) {
      ids = List<String>.filled(players.length, '', growable: true);
    }

    List<Map<String, dynamic>> parsedRounds = List<Map<String, dynamic>>.from(
      map['rounds'] ?? [],
    );

    DateTime parseDate(dynamic dateField) {
      if (dateField is Timestamp) return dateField.toDate();
      if (dateField is String) {
        return DateTime.tryParse(dateField) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return LocalScorecard(
      id: map['id'],
      gameType: map['gameType'] ?? 'Standard Scorecard',
      groupName: map['groupName'],
      ownerType: map['ownerType'] ?? 'person',
      ownerId: map['ownerId'] ?? '',
      createdDate: parseDate(map['createdDate'] ?? map['date']),
      lastUpdatedDate: parseDate(map['lastUpdatedDate'] ?? map['date']),
      playerNames: players,
      playerIds: ids,
      rounds: parsedRounds,
      isSynced: true,
      isFinalized: map['isFinalized'] ?? false,
      isLive: map['isLive'] ?? false,
      // Pulls custom settings from the root of the Firestore document
      customSettings: map['customSettings'] != null
          ? Map<String, dynamic>.from(map['customSettings'])
          : {},
    );
  }

  List<Map<String, String>> get summaryTotals {
    if (gameType.toLowerCase() == 'spades') {
      if (rounds.isEmpty) {
        return [
          {'name': 'Team 1', 'score': '0'},
          {'name': 'Team 2', 'score': '0'},
        ];
      }
      final last = rounds.last;
      return [
        {'name': 'Team 1', 'score': last['t1Total']?.toString() ?? '0'},
        {'name': 'Team 2', 'score': last['t2Total']?.toString() ?? '0'},
      ];
    } else if (gameType.toLowerCase() == 'wavelength') {
      List<Map<String, String>> results = [];
      int teams = playerNames.length ~/ 2;
      for (int t = 0; t < teams; t++) {
        int tot = 0;
        for (var r in rounds) {
          tot += int.tryParse(r['t${t + 1}Score']?.toString() ?? '') ?? 0;
        }
        String teamName = "";
        if (t * 2 + 1 < playerNames.length) {
          teamName = "${playerNames[t * 2]} & ${playerNames[t * 2 + 1]}";
        } else if (t * 2 < playerNames.length) {
          teamName = playerNames[t * 2];
        }
        results.add({'name': teamName, 'score': tot.toString()});
      }
      return results;
    } else {
      List<Map<String, String>> results = [];
      for (int i = 0; i < playerNames.length; i++) {
        int t = 0;
        for (var r in rounds) {
          t += (int.tryParse(r['p${i + 1}Score']?.toString() ?? '') ?? 0);
        }
        results.add({'name': playerNames[i], 'score': t.toString()});
      }
      return results;
    }
  }
}

class LocalScorecardsNotifier extends StateNotifier<List<LocalScorecard>> {
  LocalScorecardsNotifier() : super([]);

  void saveScorecard(LocalScorecard scorecard) {
    final index = state.indexWhere((s) => s.id == scorecard.id);
    if (index != -1) {
      state = [
        ...state.sublist(0, index),
        scorecard,
        ...state.sublist(index + 1),
      ];
    } else {
      state = [scorecard, ...state];
    }
  }

  void deleteScorecard(String id) {
    state = state.where((s) => s.id != id).toList();
  }
}

final localScorecardsProvider =
    StateNotifierProvider<LocalScorecardsNotifier, List<LocalScorecard>>((ref) {
      return LocalScorecardsNotifier();
    });
