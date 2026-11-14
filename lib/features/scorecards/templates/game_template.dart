import 'package:flutter/material.dart';
import 'standard_template.dart';
import 'spades_template.dart';
import 'yahtzee_template.dart';
import 'wavelength_template.dart';
import 'poker_template.dart';
import 'pit_template.dart';
import 'nerts_template.dart';
import 'nines_template.dart';
import 'custom_template.dart';

abstract class GameTemplate {
  String get gameType;
  int get initialPlayerCount;

  bool canAddPlayer(int currentPlayerCount, List<Map<String, dynamic>> rounds);
  List<String> generateInitialPlayerNames();
  Map<String, dynamic> createNewRound(int roundNum, int playerCount);

  bool get autoManagesRounds => false;

  bool canAddRound(List<Map<String, dynamic>> rounds, int playerCount, {Map<String, dynamic> customSettings = const {}});
  bool isReadyToFinalize(List<Map<String, dynamic>> rounds, int playerCount, {Map<String, dynamic> customSettings = const {}});
  void onRoundRemoved(List<Map<String, dynamic>> rounds);

  /// Called after any data change. Templates can use this to auto-add rounds.
  /// Returns true if the rounds list was modified (so the caller should setState).
  bool onDataUpdated(List<Map<String, dynamic>> rounds, int playerCount, {Map<String, dynamic> customSettings = const {}}) {
    return false;
  }

  // Added customSettings here
  void recalculateTotals(
    List<Map<String, dynamic>> rounds,
    int playerCount, {
    Map<String, dynamic> customSettings = const {},
  });

  // Added customSettings here
  String getWinnerDeclaration(
    List<String> playerNames,
    List<Map<String, dynamic>> rounds, {
    Map<String, dynamic> customSettings = const {},
  });

  Widget buildGrid({
    required BuildContext context,
    required BoxConstraints constraints,
    required List<String> playerNames,
    required List<Map<String, dynamic>> rounds,
    required bool isFinalized,
    required VoidCallback onDataChanged,
    required Function(int) onPlayerTap,
    Map<String, dynamic> customSettings = const {},
  });

  Widget? buildExtraAssignmentUI({
    required BuildContext context,
    required void Function(VoidCallback fn) setModalState,
    required List<String> playerNames,
    int? activePlayerIndex,
    required Map<String, dynamic> customSettings,
    required void Function(String key, dynamic value) onSettingsChanged,
  });
}

class TemplateFactory {
  static GameTemplate getTemplate(String type) {
    if (type.toLowerCase() == 'spades') {
      return SpadesTemplate();
    }
    if (type.toLowerCase() == 'yahtzee') {
      return YahtzeeTemplate();
    }
    if (type.toLowerCase() == 'wavelength') {
      return WavelengthTemplate();
    }
    if (type.toLowerCase() == 'pit') {
      return PitTemplate();
    }
    if (type.toLowerCase() == 'poker') {
      return PokerTemplate();
    }
    if (type.toLowerCase() == 'nerts') {
      return NertsTemplate();
    }
    if (type.toLowerCase() == 'nines') {
      return NinesTemplate();
    }
    if (type.toLowerCase() == 'standard') {
      return StandardTemplate();
    }
    return CustomTemplate();
  }

  static bool isOfficialTemplate(String type) {
    final t = getTemplate(type);
    return t.runtimeType.toString() != 'StandardTemplate' && t.runtimeType.toString() != 'CustomTemplate';
  }
}
