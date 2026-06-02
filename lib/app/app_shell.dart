import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/pages/home_screen.dart';
import '../features/groups/pages/groups_screen.dart';
import '../features/settings/pages/settings_screen.dart';
import '../core/shared_widgets/gradient_background.dart';
import '../features/settings/providers/mail_provider.dart';

final bottomNavIndexProvider = StateProvider<int>((ref) => 0);

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(bottomNavIndexProvider);

    // SMART BADGE LOGIC
    final notifState =
        ref.watch(mailNotificationProvider).value ?? {'unread': 0, 'action': 0};
    final actionCount = notifState['action']!;
    final unreadCount = notifState['unread']!;
    final totalCount = actionCount + unreadCount;
    final hasAction = actionCount > 0;

    final List<Widget> screens = const [
      HomeScreen(),
      GroupsScreen(),
      SettingsScreen(),
    ];

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: IndexedStack(index: currentIndex, children: screens),
        bottomNavigationBar: SafeArea(
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: BottomNavigationBar(
                  currentIndex: currentIndex,
                  backgroundColor: Colors.transparent,
                  selectedItemColor: const Color(0xFF00A2FF),
                  unselectedItemColor: Colors.white54,
                  elevation: 0,
                  onTap: (index) =>
                      ref.read(bottomNavIndexProvider.notifier).state = index,
                  items: [
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.dashboard),
                      label: 'Games',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.group),
                      label: 'Groups',
                    ),
                    BottomNavigationBarItem(
                      icon: Badge(
                        isLabelVisible: totalCount > 0,
                        // DYNAMIC COLOR: Blue if action needed, otherwise White
                        backgroundColor: hasAction
                            ? const Color(0xFF00A2FF)
                            : Colors.white,
                        textColor: hasAction ? Colors.white : Colors.black,
                        label: Text(totalCount.toString()),
                        child: const Icon(Icons.settings),
                      ),
                      label: 'Settings',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
