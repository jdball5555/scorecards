/// Turns OCR text from a rulebook / box photo into a best-guess template setup.
///
/// Pure Dart (no Flutter / ML Kit) so it can be unit tested. The scanner
/// screen feeds it the recognised text and pre-fills the setup questions with
/// the result for the user to review.
class RulebookParseResult {
  final String? gameName;
  final String gameMode; // player | team | either
  final int? minPlayers;
  final int? maxPlayers;
  final String winCondition;
  final int targetValue;

  /// Human-readable list of what was detected, for display.
  final List<String> findings;

  const RulebookParseResult({
    required this.gameName,
    required this.gameMode,
    required this.minPlayers,
    required this.maxPlayers,
    required this.winCondition,
    required this.targetValue,
    required this.findings,
  });

  bool get foundAnything => findings.isNotEmpty;

  /// Settings in the shape TemplateCreateScreen / the editor expect.
  Map<String, dynamic> toSettings() => {
    'gameType': gameName ?? 'Custom Scorecard',
    'gameMode': gameMode,
    'minPlayers': minPlayers ?? 2,
    'maxPlayers': maxPlayers ?? 8,
    'winCondition': winCondition,
    'targetValue': targetValue,
  };
}

class RulebookParser {
  static const _numberWords = {
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
    'twenty': 20,
  };

  // Lines that are clearly not a game title.
  static final _notTitle = RegExp(
    r'\b(contents?|components?|players?|ages?|object(ive)?|setup|set up|'
    r'how to|overview|introduction|table of|page|copyright|www\.|\.com|'
    r'minutes?|includes?|game ?play|scoring|rules? summary|the game|'
    r'each player|you will|winner|wins?)\b',
    caseSensitive: false,
  );

  static RulebookParseResult parse(String rawText) {
    final findings = <String>[];
    final text = _normalise(rawText);
    final lower = text.toLowerCase();

    // --- Game name -----------------------------------------------------------
    final name = _detectName(rawText);
    if (name != null) findings.add('Game name: $name');

    // --- Player counts -------------------------------------------------------
    int? minP;
    int? maxP;
    final range = RegExp(
      r'(\d{1,2})\s*(?:-|–|—|to|or)\s*(\d{1,2})\s*players?',
    ).firstMatch(lower);
    final labelledRange = RegExp(
      r'players?\s*[:=]?\s*(\d{1,2})\s*(?:-|–|—|to)\s*(\d{1,2})',
    ).firstMatch(lower);
    final orMore = RegExp(
      r'(\d{1,2})\s*(?:\+|or more)\s*players?',
    ).firstMatch(lower);
    final exact = RegExp(r'\bfor\s+(\d{1,2})\s+players?\b').firstMatch(lower);
    final upTo = RegExp(r'up to\s+(\d{1,2})\s+players?').firstMatch(lower);
    if (range != null || labelledRange != null) {
      final m = (range ?? labelledRange)!;
      final a = int.parse(m.group(1)!);
      final b = int.parse(m.group(2)!);
      minP = a < b ? a : b;
      maxP = a < b ? b : a;
    } else if (orMore != null) {
      minP = int.parse(orMore.group(1)!);
      maxP = 12;
    } else if (exact != null) {
      minP = int.parse(exact.group(1)!);
      maxP = minP;
    } else if (upTo != null) {
      maxP = int.parse(upTo.group(1)!);
      minP = maxP < 2 ? maxP : 2;
    }
    if (minP != null && maxP != null) {
      minP = minP.clamp(1, 20);
      maxP = maxP.clamp(minP, 20);
      findings.add(minP == maxP ? 'Players: $minP' : 'Players: $minP–$maxP');
    }

    // --- Team / player mode --------------------------------------------------
    String mode = 'player';
    final teamy = RegExp(
      r'\b(partners?|partnerships?|teams? of|in teams|two teams|team play|'
      r'2\s*v\s*2|opposing teams?|your teammate)\b',
    ).hasMatch(lower);
    final either = RegExp(
      r'(individually or (in|as) teams|teams or individually|'
      r'(as|in) teams or (as )?individuals|team variant|partnership variant)',
    ).hasMatch(lower);
    if (either) {
      mode = 'either';
      findings.add('Mode: players or teams');
    } else if (teamy) {
      mode = 'team';
      findings.add('Mode: teams');
    }

    // --- Win condition -------------------------------------------------------
    final lowWins = RegExp(
      r'(lowest|fewest|least)\s+(total\s+)?(score|points|number of points)'
      r'[^.]{0,40}\b(wins?|winner)\b|'
      r'\b(wins?|winner)\b[^.]{0,40}\b(lowest|fewest|least)\s+(total\s+)?(score|points)|'
      r'goal is to (have|score) as few points',
    ).hasMatch(lower);

    String winCondition = lowWins ? 'lowest_score' : 'highest_score';
    int target = 0;

    final rounds = _detectRounds(lower);
    final targetScore = _detectTarget(lower);

    if (rounds != null) {
      winCondition = lowWins ? 'lowest_after_rounds' : 'highest_after_rounds';
      target = rounds;
      findings.add('Game length: $rounds rounds');
    } else if (targetScore != null) {
      winCondition = lowWins ? 'lowest_when_reached_score' : 'first_to_score';
      target = targetScore;
      findings.add(
        lowWins
            ? 'Ends when someone reaches $targetScore'
            : 'First to $targetScore wins',
      );
    }
    if (lowWins) findings.add('Lowest score wins');

    return RulebookParseResult(
      gameName: name,
      gameMode: mode,
      minPlayers: minP,
      maxPlayers: maxP,
      winCondition: winCondition,
      targetValue: target,
      findings: findings,
    );
  }

  static String _normalise(String raw) {
    var t = raw.replaceAll(RegExp(r'[\r\n\t]+'), ' ');
    t = t.replaceAll(RegExp(r'\s{2,}'), ' ');
    // Turn number words into digits when they count players/rounds
    // ("two to four players", "ten rounds") so one regex handles both forms.
    // Other uses ("the first one to reach...") are left alone.
    final words = _numberWords.keys.join('|');
    final countable = RegExp(
      '\\b($words)\\b(?=(?:\\s*(?:-|–|to|or)\\s*(?:$words|\\d+))?'
      '\\s+(?:players?|rounds?|hands?|turns?|innings?|teams?)\\b)',
      caseSensitive: false,
    );
    t = t.replaceAllMapped(
      countable,
      (m) => '${_numberWords[m.group(1)!.toLowerCase()]}',
    );
    return t;
  }

  static int? _detectRounds(String lower) {
    final patterns = [
      RegExp(
        r'(?:after|play|plays|played over|lasts?|over|consists? of|for)\s+'
        r'(?:exactly\s+)?(\d{1,3})\s+(?:rounds?|hands?|turns?|innings?)',
      ),
      RegExp(r'(\d{1,3})\s+(?:rounds?|hands?)\s+(?:are|is)\s+played'),
      RegExp(
        r'game (?:ends|is over) after (?:the )?(\d{1,3})(?:st|nd|rd|th)?\s+(?:rounds?|hands?)',
      ),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(lower);
      if (m != null) {
        final v = int.tryParse(m.group(1)!);
        if (v != null && v >= 1 && v <= 100) return v;
      }
    }
    return null;
  }

  // A score like "500", "1000" or "1,000".
  static const _n = r'(\d{1,3}(?:,\d{3})+|\d{2,5})';

  static int? _detectTarget(String lower) {
    const n = _n;
    final patterns = [
      // "first player to reach 500 points", "first team to score 250"
      RegExp(
        r'first\s+(?:player\s+|team\s+|person\s+|one\s+)?to\s+'
                r'(?:reach|score|get|hit|earn|accumulate|collect)?\s*'
                r'(?:a total of\s+|at least\s+)?' +
            n,
      ),
      // "when a player reaches 100 points", "until someone scores 500"
      RegExp(
        r'(?:when|until|once|as soon as)\s+(?:a|one|any|the first)?\s*'
                r'(?:player|team|someone|anyone|person)?\s*'
                r'(?:reaches|has|scores|gets|hits|passes|exceeds|goes over)\s+'
                r'(?:a total of\s+|at least\s+)?' +
            n,
      ),
      // "play to 500", "game is played to 1,000 points"
      RegExp(r'play(?:ed|s)?\s+(?:up\s+)?to\s+' + n),
      // "reaches 100 points", "score of 500 points wins"
      RegExp(r'(?:reaches|reach|score of|total of)\s+' + n + r'\s+points'),
      // "500 points wins", "100 points to win"
      RegExp(n + r'\s+points\s+(?:wins|to win|is the winner)'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(lower);
      if (m != null) {
        final v = int.tryParse(m.group(1)!.replaceAll(',', ''));
        if (v != null && v >= 5) return v;
      }
    }
    return null;
  }

  static String? _detectName(String raw) {
    final lines = raw
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .take(8);
    for (var line in lines) {
      // Strip trailing "Rules"/"Rulebook"/"Instructions"
      line = line
          .replaceAll(
            RegExp(
              r'\b(official\s+)?(rule ?book|rules|instructions|how to play)\b',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(RegExp(r'[™®©:|]'), '')
          .trim();
      if (line.length < 2 || line.length > 32) continue;
      if (_notTitle.hasMatch(line)) continue;
      final letters = RegExp(r'[A-Za-z]').allMatches(line).length;
      if (letters < line.replaceAll(' ', '').length * 0.7) continue;
      if (line.split(' ').length > 5) continue;
      return _titleCase(line);
    }
    return null;
  }

  static String _titleCase(String s) => s
      .split(RegExp(r'\s+'))
      .map(
        (w) => w.isEmpty
            ? w
            : (w.length <= 3 && w == w.toUpperCase() && w.length > 1)
            ? w // keep short acronyms like "UNO"
            : w[0].toUpperCase() + w.substring(1).toLowerCase(),
      )
      .join(' ');
}
