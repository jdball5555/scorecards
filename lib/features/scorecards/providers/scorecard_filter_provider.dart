import 'package:flutter_riverpod/flutter_riverpod.dart';

class ScorecardFilterState {
  final String scope;
  final String? gameType;
  final String timePeriod;

  ScorecardFilterState({
    this.scope = 'All',
    this.gameType,
    this.timePeriod = 'All Time',
  });

  ScorecardFilterState copyWith({
    String? scope,
    String? gameType,
    bool clearGameType = false,
    String? timePeriod,
  }) {
    return ScorecardFilterState(
      scope: scope ?? this.scope,
      gameType: clearGameType ? null : (gameType ?? this.gameType),
      timePeriod: timePeriod ?? this.timePeriod,
    );
  }
}

class ScorecardFilterNotifier extends StateNotifier<ScorecardFilterState> {
  ScorecardFilterNotifier() : super(ScorecardFilterState());

  void setScope(String scope) {
    state = state.copyWith(scope: scope);
  }

  void setGameType(String? gameType) {
    state = state.copyWith(gameType: gameType, clearGameType: gameType == null);
  }

  void setTimePeriod(String timePeriod) {
    state = state.copyWith(timePeriod: timePeriod);
  }

  void reset() {
    state = ScorecardFilterState();
  }
}

final scorecardFilterProvider =
    StateNotifierProvider<ScorecardFilterNotifier, ScorecardFilterState>((ref) {
      return ScorecardFilterNotifier();
    });
