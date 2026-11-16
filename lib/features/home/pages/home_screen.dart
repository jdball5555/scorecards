import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/shared_widgets/glass_card.dart';
import '../../scorecards/pages/scorecard_create.dart';
import '../../scorecards/pages/scoring.dart';
import '../../scorecards/providers/local_scorecard_provider.dart';
import '../../scorecards/templates/game_template.dart';
import '../../scorecards/pages/custom_scorecards_screen.dart';
import '../../../core/layout/responsive.dart';
import '../../../core/shared_widgets/game_request_link.dart';
import 'package:scorecards_app/core/shared_widgets/top_bar_background.dart';
import 'package:scorecards_app/features/premium/premium_beta.dart';
import '../../auth/providers/auth_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ScorecardCreateDialog(),
    );
  }

  void _repeatLastGame(BuildContext context, LocalScorecard lastCard) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // Generate a secure, random 20-character string for the new game
    final customId = FirebaseFirestore.instance
        .collection('scorecards')
        .doc()
        .id;

    // Generate a fresh round 1 based on the game type
    final template = TemplateFactory.getTemplate(lastCard.gameType);
    var initialRound = template.createNewRound(1, lastCard.playerNames.length);

    // Persist any underlying specific template settings from the last game
    if (lastCard.rounds.isNotEmpty) {
      if (lastCard.gameType.toLowerCase() == 'poker') {
        initialRound['buyIn'] = lastCard.rounds.last['buyIn'] ?? 2;
      }
      if (lastCard.gameType.toLowerCase() == 'spades') {
        initialRound['firstBidder'] = lastCard.rounds.first['firstBidder'];
        initialRound['secondBidder'] = lastCard.rounds.first['secondBidder'];
      }
    }

    // Build the brand new scorecard using the old roster
    final newScorecard = LocalScorecard(
      id: customId,
      gameType: lastCard.gameType,
      groupName: lastCard.groupName,
      ownerType: lastCard.ownerType,
      ownerId: lastCard.ownerId,
      createdDate: DateTime.now(),
      lastUpdatedDate: DateTime.now(),
      playerNames: List.from(lastCard.playerNames),
      playerIds: List.from(lastCard.playerIds),
      rounds: [initialRound],
      isSynced: false,
      isFinalized: false,
      isLive: false,
    );

    // Pop the loading circle
    if (context.mounted) Navigator.pop(context);

    // Launch directly into the Scoring Screen, completely bypassing Setup!
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScoringScreen(
            gameType: newScorecard.gameType,
            ownerType: newScorecard.ownerType,
            ownerId: newScorecard.ownerId,
            groupName: newScorecard.groupName,
            existingCard: newScorecard,
            customId: customId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user =
        ref.watch(userProfileProvider).valueOrNull ??
        FirebaseAuth.instance.currentUser;
    final firstName = user?.displayName?.split(' ').first ?? 'Player';
    final greeting = _getGreeting();

    // Fetch the user's most recent game from the local provider
    final localCards = ref.watch(localScorecardsProvider);
    LocalScorecard? lastCard;
    if (localCards.isNotEmpty) {
      final sorted = List<LocalScorecard>.from(localCards)
        ..sort((a, b) => b.lastUpdatedDate.compareTo(a.lastUpdatedDate));
      lastCard = sorted.first;
    }

    final wide = isWideLayout(context);
    final Widget startCard = // --- START SCORING BUTTON ---
    GlassCard(
      accentColor: const Color(0xFF00A2FF), // Blue Theme
      onTap: () => _showCreateDialog(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 100),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF00A2FF).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(width: 20),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "START SCORING",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Create a new game or sync with groups",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final premium = hasPremiumBeta(ref);
    final Widget customCard = // --- CUSTOM SCORECARD TEMPLATES TILE ---
    GlassCard(
      accentColor: const Color(0xFF7855C1), // Purple Theme
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CustomScorecardsScreen()),
        );
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 100),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF7855C1).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.dashboard_customize_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(width: 20),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "CUSTOM TEMPLATES",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "View saved templates or build new ones",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white24,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      // Website layout: same black title bar as the other pages.
      appBar: wide
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              centerTitle: false,
              automaticallyImplyLeading: false,
              flexibleSpace: const TopBarBackground(),
              title: const Text(
                "Home",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  fontSize: 24,
                ),
              ),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: wide
              ? const EdgeInsets.fromLTRB(32, 32, 32, 40)
              : const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          physics: const ClampingScrollPhysics(),
          children: [
            // --- DYNAMIC GREETING ---
            Text(
              greeting,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 18,
              ),
            ),
            Text(
              firstName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Let's make today a win!",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 32),

            // Custom templates are a premium beta feature.
            if (!premium)
              wide
                  ? Row(
                      children: [
                        Expanded(child: startCard),
                        const SizedBox(width: 20),
                        const Spacer(),
                      ],
                    )
                  : startCard
            else if (wide)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: startCard),
                    const SizedBox(width: 20),
                    Expanded(child: customCard),
                  ],
                ),
              )
            else ...[
              startCard,
              const SizedBox(height: 16),
              customCard,
            ],

            const SizedBox(height: 32),

            // --- QUICK START SECTION ---
            if (lastCard != null) ...[
              const Text(
                "QUICK START",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                accentColor: const Color(0xFF7855C1), // Purple Theme
                onTap: () => _repeatLastGame(context, lastCard!),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7855C1).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.replay,
                          color: Color(0xFF7855C1),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lastCard!.playerNames.length == 1
                                  ? "Repeat Last Game?"
                                  : "Rematch?",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Builder(
                              builder: (context) {
                                String subtitle = lastCard!.gameType;
                                if (lastCard!.ownerType == 'group' &&
                                    lastCard!.groupName != null) {
                                  subtitle += ' with ${lastCard!.groupName}';
                                }

                                final validPlayers = lastCard!.playerNames
                                    .where(
                                      (p) =>
                                          p.isNotEmpty &&
                                          !p.startsWith('Player '),
                                    )
                                    .toList();

                                if (validPlayers.isNotEmpty) {
                                  subtitle += ' • ${validPlayers.join(', ')}';
                                } else {
                                  subtitle +=
                                      ' • ${lastCard!.playerNames.join(', ')}';
                                }

                                return Text(
                                  subtitle,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white24,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            const GameRequestLink(),
            SizedBox(height: wide ? 24 : 100), // Clears the phone tab bar
          ],
        ),
      ),
    );
  }
}
