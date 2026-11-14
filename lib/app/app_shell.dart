import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/pages/home_screen.dart';
import '../features/scorecards/pages/scorecards_screen.dart';
import '../features/metrics/pages/metrics_screen.dart'; // NEW IMPORT
import '../features/groups/pages/groups_screen.dart';
import '../features/settings/pages/settings_screen.dart';
import '../core/shared_widgets/gradient_background.dart';
import '../core/layout/responsive.dart';
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

    // Lazily-built screens: only instantiated on first visit, then kept alive.
    // This replaces IndexedStack which builds ALL screens simultaneously,
    // causing OOM when combined with memory-heavy screens like ScoringScreen.
    const List<Widget Function()> screenBuilders = [
      HomeScreen.new,
      ScorecardsScreen.new,
      MetricsScreen.new,
      GroupsScreen.new,
      SettingsScreen.new,
    ];

    final screens = ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: _LazyIndexedStack(
        index: currentIndex,
        screenBuilders: screenBuilders,
      ),
    );

    void select(int index) =>
        ref.read(bottomNavIndexProvider.notifier).state = index;

    // --- Website layout: the sidebar (SiteChrome) handles navigation ---
    if (SiteSidebarScope.isActive(context)) {
      return GradientBackground(
        child: Scaffold(backgroundColor: Colors.transparent, body: screens),
      );
    }

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: screens,
        bottomNavigationBar: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                child: BottomNavigationBar(
                  currentIndex: currentIndex,
                  type: BottomNavigationBarType
                      .fixed, // CRITICAL: Fixes the 4+ item bug
                  backgroundColor: Colors.transparent,
                  selectedItemColor: const Color(0xFF00A2FF),
                  // Fits "Scorecards" on small phones (320pt wide).
                  selectedFontSize: 12,
                  unselectedFontSize: 11,
                  unselectedItemColor: Colors.white54,
                  elevation: 0,
                  onTap: select,
                  items: [
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.dashboard),
                      label: 'Home',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.style),
                      label: 'Scorecards',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.bar_chart), // Icon for Metrics
                      label: 'Metrics',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.group),
                      label: 'Groups',
                    ),
                    BottomNavigationBarItem(
                      icon: Badge(
                        isLabelVisible: totalCount > 0,
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

// Builds each screen lazily on first visit, then keeps it alive with Offstage.
// Memory cost: only screens that have been visited are in the widget tree.
class _LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget Function()> screenBuilders;

  const _LazyIndexedStack({required this.index, required this.screenBuilders});

  @override
  State<_LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<_LazyIndexedStack> {
  late final List<Widget?> _cache;

  @override
  void initState() {
    super.initState();
    _cache = List<Widget?>.filled(widget.screenBuilders.length, null);
    // Build the initial screen immediately
    _cache[widget.index] = widget.screenBuilders[widget.index]();
  }

  @override
  void didUpdateWidget(_LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Build the new screen on first visit
    if (_cache[widget.index] == null) {
      _cache[widget.index] = widget.screenBuilders[widget.index]();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(_cache.length, (i) {
        final screen = _cache[i];
        if (screen == null) return const SizedBox.shrink();
        return Offstage(offstage: i != widget.index, child: screen);
      }),
    );
  }
}
