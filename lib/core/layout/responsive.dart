import 'package:flutter/material.dart';


/// Screens narrower than this (phones, small browser windows) use the app
/// layout with the bottom tab bar. Wider screens get the website layout.
const double kWideBreakpoint = 840;

/// Max width for forms / settings-style pages so lines stay readable.
const double kReadableMaxWidth = 760;

/// True for the website layout (sidebar showing, or a wide signed-out page).
bool isWideLayout(BuildContext context) =>
    SiteSidebarScope.isActive(context) ||
    MediaQuery.sizeOf(context).width >= kWideBreakpoint;

/// Centers [child] and caps its width. On narrow screens it just fills.
class ReadableWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final AlignmentGeometry alignment;

  const ReadableWidth({
    super.key,
    required this.child,
    this.maxWidth = kReadableMaxWidth,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Horizontal padding that keeps a full-width scroll view's content inside
/// [maxWidth] (so the scrollbar / wheel area still spans the page).
EdgeInsets readablePadding(
  BoxConstraints constraints, {
  double maxWidth = kReadableMaxWidth,
  double minSide = 20,
  double top = 0,
  double bottom = 0,
}) {
  final side = constraints.maxWidth > maxWidth + minSide * 2
      ? (constraints.maxWidth - maxWidth) / 2
      : minSide;
  return EdgeInsets.fromLTRB(side, top, side, bottom);
}

/// Present above every page when the website sidebar is showing.
class SiteSidebarScope extends InheritedWidget {
  const SiteSidebarScope({super.key, required super.child});

  static bool isActive(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SiteSidebarScope>() != null;

  @override
  bool updateShouldNotify(SiteSidebarScope oldWidget) => false;
}

/// Side padding that keeps a page's content within [maxWidth] on wide
/// screens (inside the site frame) and is [minSide] on phones.
double readableSide(
  BuildContext context, {
  double maxWidth = kReadableMaxWidth,
  double minSide = 20,
}) {
  // Beside the sidebar, MediaQuery's width is the page area's width.
  final page = MediaQuery.sizeOf(context).width;
  final side = (page - maxWidth) / 2;
  return side > minSide ? side : minSide;
}
