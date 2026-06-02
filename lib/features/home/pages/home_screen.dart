import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/shared_widgets/glass_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the user's first name, or default to 'Player'
    final user = FirebaseAuth.instance.currentUser;
    final firstName = user?.displayName?.split(' ').first ?? 'Player';
    final greeting = _getGreeting();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false, // Prevents clipping at the bottom nav
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          physics: const BouncingScrollPhysics(),
          children: [
            // --- DYNAMIC GREETING ---
            Text(
              greeting,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
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
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 32),

            // --- CREATE SCORE CARD GLASS BUTTON ---
            GlassCard(
              accentColor: const Color(0xFF7855C1), // Euchre Purple Theme
              onTap: () {
                // TODO: Open Create Score Card flow
                print("Create Score Card tapped");
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      color: Colors.white,
                      size: 28,
                    ),
                    SizedBox(width: 12),
                    Text(
                      "CREATE SCORE CARD",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 48),

            // --- SECTION HEADER ---
            const Text(
              "ACTIVE SESSIONS",
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),

            // --- SPADES TILE ---
            GlassCard(
              accentColor: const Color(0xFF00A2FF),
              onTap: () => print("Opening Spades"),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00A2FF).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF00A2FF).withOpacity(0.5),
                              ),
                            ),
                            child: const Icon(
                              Icons.style,
                              color: Color(0xFF00A2FF),
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "SPADES",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: const Text(
                          "Round 4",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _PlayerScoreProfile(
                        name: "Alex",
                        score: "120",
                        isLeader: true,
                        themeColor: Color(0xFF00A2FF),
                      ),
                      _PlayerScoreProfile(name: "Sarah", score: "80"),
                      _PlayerScoreProfile(name: "Mike", score: "40"),
                      _PlayerScoreProfile(name: "Dave", score: "10"),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- EUCHRE TILE ---
            GlassCard(
              accentColor: const Color(0xFF7855C1),
              onTap: () => print("Opening Euchre"),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7855C1).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF7855C1).withOpacity(0.5),
                              ),
                            ),
                            child: const Icon(
                              Icons.group_work,
                              color: Color(0xFF7855C1),
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "EUCHRE",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: const Text(
                          "Round 2",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const _PlayerScoreProfile(
                        name: "Team 1",
                        score: "4",
                        isLeader: false,
                      ),
                      Container(height: 40, width: 1, color: Colors.white24),
                      const _PlayerScoreProfile(
                        name: "Team 2",
                        score: "7",
                        isLeader: true,
                        themeColor: Color(0xFF7855C1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100), // Padding to clear AppShell Navbar
          ],
        ),
      ),
    );
  }
}

class _PlayerScoreProfile extends StatelessWidget {
  final String name;
  final String score;
  final bool isLeader;
  final Color? themeColor;

  const _PlayerScoreProfile({
    required this.name,
    required this.score,
    this.isLeader = false,
    this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    final leaderColor = themeColor ?? const Color(0xFF00A2FF);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isLeader ? leaderColor : Colors.transparent,
            border: isLeader
                ? null
                : Border.all(color: Colors.white24, width: 1.5),
            boxShadow: isLeader
                ? [
                    BoxShadow(
                      color: leaderColor.withOpacity(0.4),
                      blurRadius: 10,
                    ),
                  ]
                : [],
          ),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: Colors.black.withOpacity(0.4),
            child: Icon(
              Icons.person,
              color: isLeader ? Colors.white : Colors.white54,
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: TextStyle(
            color: isLeader ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          score,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
      ],
    );
  }
}
