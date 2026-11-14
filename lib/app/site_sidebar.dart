import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_version.dart';
import '../core/layout/responsive.dart';
import '../core/shared_widgets/gradient_background.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/settings/pages/feedback_form.dart';
import '../features/settings/providers/mail_provider.dart';
import 'app.dart' show navigatorKey;
import 'app_shell.dart' show bottomNavIndexProvider;

/// Website layout: the collapsible left sidebar used across the Axis Optic
/// sites (same sizes, timings and fade as Axis Team's MainLayout).
///
/// It wraps the app's root Navigator (MaterialApp.builder), so it stays put
/// on every page and dialog; pages render in the area to its right.

const double _kExpandedWidth = 240;
const double _kCollapsedWidth = 70;
const Duration _kAnim = Duration(milliseconds: 200);

// Same tinted black as the pages' top bars (black 40% over the background),
// with no edge between them so the sidebar and top bar read as one frame.
const Color _kSidebarColor = Color(0x66000000);
// Solid equivalent, for things drawn on top of the sidebar (badge rings).
const Color _kSidebarSolid = Color(0xFF07070C);
const Color _kPrimaryText = Color(0xFFD7D7D7);
const Color _kGray = Color(0xFFC9C9C9);
// Scorecards blue, for the page you're on.
const Color _kAccent = Color(0xFF00A2FF);

/// null until the user toggles it: starts open on roomy windows.
final sidebarExpandedProvider = StateProvider<bool?>((ref) => null);

/// Tracks the root navigator's stack so the sidebar can tell which page is
/// showing and close pages before switching sections.
class RouteStackObserver extends NavigatorObserver with ChangeNotifier {
  final List<Route<dynamic>> stack = [];

  void _changed() {
    // Navigator callbacks can fire mid-build; notify after the frame.
    SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    stack.add(route);
    _changed();
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    stack.remove(route);
    _changed();
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    stack.remove(route);
    _changed();
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    final i = oldRoute == null ? -1 : stack.indexOf(oldRoute);
    if (i >= 0 && newRoute != null) {
      stack[i] = newRoute;
    } else if (newRoute != null) {
      stack.add(newRoute);
    }
    _changed();
  }

  String? get topName => stack.isEmpty ? null : stack.last.settings.name;
}

final routeStackObserver = RouteStackObserver();

const _feedbackRouteName = '/feedback';

/// Closes pages/dialogs above the main tabs, respecting "unsaved changes"
/// prompts. Returns false if a page asked to stay open.
Future<bool> popToShell() async {
  final nav = navigatorKey.currentState;
  if (nav == null) return true;
  while (nav.canPop()) {
    final before = routeStackObserver.stack.length;
    await nav.maybePop();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    // Still there, or it opened a "save changes?" dialog: let the user decide.
    if (routeStackObserver.stack.length >= before) return false;
  }
  return true;
}

/// Wraps the whole app (MaterialApp.builder). Adds the sidebar on wide
/// screens when someone is signed in; phones get the app layout unchanged.
class SiteChrome extends ConsumerWidget {
  final Widget child;
  const SiteChrome({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final user = ref.watch(authStateProvider).value;
    if (user == null || width < kWideBreakpoint) return child;

    final expanded = ref.watch(sidebarExpandedProvider) ?? width >= 1100;

    return _FrameOverlay(
      child: GradientBackground(
        // Laid out right-to-left so the sidebar is still on the left but is
        // painted *after* the pages: page routes hide the semantics of anything
        // painted before them, which would make the sidebar invisible to
        // screen readers. (Only this Row is RTL; its children stay LTR.)
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) => MediaQuery(
                  // Pages lay themselves out for the space beside the sidebar.
                  data: MediaQuery.of(context).copyWith(size: box.biggest),
                  child: SiteSidebarScope(child: child),
                ),
              ),
            ),
            _SiteSidebar(expanded: expanded),
          ],
        ),
      ),
    );
  }
}

/// An Overlay around the whole frame. The sidebar sits outside the app's
/// Navigator (whose Overlay only covers the pages), and its tooltips need an
/// Overlay to show in, one that reaches over the page beside it.
class _FrameOverlay extends StatefulWidget {
  final Widget child;
  const _FrameOverlay({required this.child});

  @override
  State<_FrameOverlay> createState() => _FrameOverlayState();
}

class _FrameOverlayState extends State<_FrameOverlay> {
  late final OverlayEntry _entry = OverlayEntry(builder: (_) => widget.child);

  @override
  void didUpdateWidget(_FrameOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The entry builds from `widget.child`; rebuild it with the new one.
    if (oldWidget.child != widget.child) _entry.markNeedsBuild();
  }

  @override
  void dispose() {
    _entry.remove();
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}

class _SiteSidebar extends ConsumerWidget {
  final bool expanded;
  const _SiteSidebar({required this.expanded});

  Future<void> _goToTab(WidgetRef ref, int index) async {
    if (!await popToShell()) return;
    ref.read(bottomNavIndexProvider.notifier).state = index;
  }

  Future<void> _openFeedback() async {
    if (routeStackObserver.topName == _feedbackRouteName) return;
    if (!await popToShell()) return;
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: _feedbackRouteName),
        builder: (_) => const FeedbackFormScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(bottomNavIndexProvider);
    final notif =
        ref.watch(mailNotificationProvider).value ?? {'unread': 0, 'action': 0};
    final mailCount = (notif['unread'] ?? 0) + (notif['action'] ?? 0);
    final hasAction = (notif['action'] ?? 0) > 0;

    return Material(
      type: MaterialType.transparency,
      child: AnimatedContainer(
        duration: _kAnim,
        width: expanded ? _kExpandedWidth : _kCollapsedWidth,
        decoration: const BoxDecoration(color: _kSidebarColor),
        child: SafeArea(
          right: false,
          child: ListenableBuilder(
            listenable: routeStackObserver,
            builder: (context, _) {
              final onFeedback =
                  routeStackObserver.topName == _feedbackRouteName;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Everything but the bottom toggle scrolls when the window
                  // is too short; the arrow and version always stay visible.
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: box.maxHeight),
                          child: IntrinsicHeight(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 20),
                                _SidebarHeader(expanded: expanded),
                                const SizedBox(height: 18),
                                for (int i = 0; i < _items.length; i++)
                                  _NavItem(
                                    title: _items[i].title,
                                    icon: _items[i].icon,
                                    expanded: expanded,
                                    isSelected:
                                        !onFeedback && currentIndex == i,
                                    badgeCount: i == 4 && mailCount > 0
                                        ? '$mailCount'
                                        : null,
                                    badgeColor: i == 4 && hasAction
                                        ? const Color(0xFF00A2FF)
                                        : null,
                                    onTap: () => _goToTab(ref, i),
                                  ),
                                const Spacer(),
                                _NavItem(
                                  title: 'Feedback',
                                  icon: Icons.feedback_outlined,
                                  expanded: expanded,
                                  isSelected: onFeedback,
                                  onTap: _openFeedback,
                                ),
                                const SizedBox(height: 6),
                                _AccountRow(
                                  expanded: expanded,
                                  onTap: () => _goToTab(ref, 4),
                                ),
                                const SizedBox(height: 4),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // The version and the fold arrow: one pill, all clickable.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
                    child: _Pill(
                      onTap: () =>
                          ref.read(sidebarExpandedProvider.notifier).state =
                              !expanded,
                      tooltip: expanded ? null : 'Expand',
                      semanticsLabel: expanded
                          ? 'Collapse sidebar'
                          : 'Expand sidebar',
                      child: SizedBox(
                        height: 44,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 16,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: AnimatedOpacity(
                                  duration: _kAnim,
                                  opacity: expanded ? 1.0 : 0.0,
                                  child: const Text(
                                    'v$appVersion',
                                    softWrap: false,
                                    style: TextStyle(
                                      color: _kGray,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Centered in the pill when folded (50 wide).
                            Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 13),
                                child: Icon(
                                  expanded
                                      ? Icons.keyboard_arrow_left
                                      : Icons.keyboard_arrow_right,
                                  color: _kGray,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Item {
  final String title;
  final IconData icon;
  const _Item(this.title, this.icon);
}

// Same order as the phone tab bar (bottomNavIndexProvider).
const _items = [
  _Item('Home', Icons.dashboard_outlined),
  _Item('Scorecards', Icons.style_outlined),
  _Item('Metrics', Icons.bar_chart),
  _Item('Groups', Icons.people_outline),
  _Item('Settings', Icons.settings_outlined),
];

/// App icon (always shown, centered over the nav icons when collapsed) +
/// the app name (fades).
class _SidebarHeader extends StatelessWidget {
  final bool expanded;
  const _SidebarHeader({required this.expanded});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: SizedBox(
        width: _kExpandedWidth,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 4, 12, 4),
          child: Row(
            children: [
              Image.asset(
                'assets/branding/app_mark.png',
                width: 36,
                height: 36,
                filterQuality: FilterQuality.high,
                semanticLabel: 'Scorecards',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedOpacity(
                  duration: _kAnim,
                  opacity: expanded ? 1.0 : 0.0,
                  child: const Text(
                    'Scorecards',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: 0.5,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Width of a pill's inside: the bar less its 10px margins on each side.
const double _kPillWidth = _kExpandedWidth - 20;

/// Puts an icon at the center of the folded pill (70 - 20 = 50 wide).
const double _kIconInset = (_kCollapsedWidth - 20 - 20) / 2;

/// A rounded pill: softly lit under the mouse, filled when [selected].
/// Given a [tooltip] (when folded), its name shows beside it on hover.
class _Pill extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  final bool selected;
  final String? tooltip;
  final String semanticsLabel;

  const _Pill({
    required this.onTap,
    required this.child,
    required this.semanticsLabel,
    this.selected = false,
    this.tooltip,
  });

  @override
  State<_Pill> createState() => _PillState();
}

class _PillState extends State<_Pill> {
  bool _hover = false;

  // The name label beside a folded pill (Tooltip can only sit above or
  // below, where it would cover the next icon).
  final _label = OverlayPortalController();
  final _link = LayerLink();
  Timer? _labelTimer;

  void _enter() {
    setState(() => _hover = true);
    if (widget.tooltip == null) return;
    _labelTimer?.cancel();
    _labelTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted && _hover && widget.tooltip != null) _label.show();
    });
  }

  void _exit() {
    setState(() => _hover = false);
    _hideLabel();
  }

  void _hideLabel() {
    _labelTimer?.cancel();
    if (_label.isShowing) _label.hide();
  }

  @override
  void didUpdateWidget(_Pill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tooltip == null) _hideLabel();
  }

  @override
  void dispose() {
    _labelTimer?.cancel();
    super.dispose();
  }

  Widget _buildLabel(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: CompositedTransformFollower(
        link: _link,
        targetAnchor: Alignment.centerRight,
        followerAnchor: Alignment.centerLeft,
        offset: const Offset(12, 0),
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1B2130),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0x1AFFFFFF)),
              boxShadow: const [
                BoxShadow(color: Color(0x66000000), blurRadius: 12),
              ],
            ),
            child: Text(
              widget.tooltip ?? '',
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: widget.selected
            ? const Color(0x1FFFFFFF)
            : (_hover ? const Color(0x12FFFFFF) : const Color(0x00FFFFFF)),
      ),
      clipBehavior: Clip.antiAlias,
      child: widget.child,
    );
    return Semantics(
      container: true,
      button: true,
      selected: widget.selected,
      label: widget.semanticsLabel,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _enter(),
        onExit: (_) => _exit(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _hideLabel();
            widget.onTap();
          },
          child: CompositedTransformTarget(
            link: _link,
            child: OverlayPortal(
              controller: _label,
              overlayChildBuilder: _buildLabel,
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays [child] out at the open width always, so nothing reflows while the
/// bar folds; the bar just shows less of it.
Widget _fixedWidth(Widget child) => SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  physics: const NeverScrollableScrollPhysics(),
  child: SizedBox(width: _kPillWidth, child: child),
);

class _NavItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool expanded;
  final bool isSelected;
  final VoidCallback onTap;
  final String? badgeCount;
  final Color? badgeColor;

  const _NavItem({
    required this.title,
    required this.icon,
    required this.expanded,
    required this.isSelected,
    required this.onTap,
    this.badgeCount,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: _Pill(
        onTap: onTap,
        selected: isSelected,
        tooltip: expanded ? null : title,
        semanticsLabel: '$title tab',
        child: SizedBox(
          height: 42,
          child: _fixedWidth(
            Row(
              children: [
                const SizedBox(width: _kIconInset),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, size: 20, color: isSelected ? _kAccent : _kGray),
                    // Folded: a dot on the icon instead of the count.
                    if (badgeCount != null && !expanded)
                      Positioned(
                        right: -3,
                        top: -3,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: badgeColor ?? Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _kSidebarSolid,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: AnimatedOpacity(
                    duration: _kAnim,
                    opacity: expanded ? 1.0 : 0.0,
                    child: Text(
                      title,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: TextStyle(
                        color: isSelected ? Colors.white : _kPrimaryText,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                ),
                if (badgeCount != null)
                  AnimatedOpacity(
                    duration: _kAnim,
                    opacity: expanded ? 1.0 : 0.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor ?? const Color(0x26FFFFFF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeCount!,
                        maxLines: 1,
                        softWrap: false,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;
  const _AccountRow({required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()
        : (user?.email ?? 'Account');
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: _Pill(
        onTap: onTap,
        tooltip: expanded ? null : name,
        semanticsLabel: 'Account: $name',
        child: SizedBox(
          height: 48,
          child: _fixedWidth(
            Row(
              children: [
                const SizedBox(width: (_kCollapsedWidth - 20 - 30) / 2),
                CircleAvatar(
                  radius: 15,
                  backgroundColor: const Color(0x33FFFFFF),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AnimatedOpacity(
                    duration: _kAnim,
                    opacity: expanded ? 1.0 : 0.0,
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: _kPrimaryText,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
