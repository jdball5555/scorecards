import 'dart:ui';

import 'package:flutter/material.dart';

import '../layout/responsive.dart';

/// Tint of the page top bars (and the website sidebar).
const Color kTopBarTint = Color(0x66000000);

/// The thin line under the top bar.
const Color kTopBarEdge = Color(0x1AFFFFFF);

/// Radius of the page's top-left corner on the website.
const double kPageCornerRadius = 12;

/// Background for every page's top bar (pass as `AppBar.flexibleSpace`):
/// blurred, tinted black, with a thin line along the bottom.
///
/// On the website, that line also turns down at the page's left edge with a
/// rounded corner and runs the height of the page, so the sidebar and top bar
/// read as one frame around the page. (Drawn here, past the bar's own bounds,
/// so it belongs to the page: dialogs cover it and it moves with the page.)
/// Bars narrower than the page keep the plain line. In a split screen each
/// pane is its own page (see [SplitPaneScope]).
class TopBarBackground extends StatelessWidget {
  const TopBarBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        foregroundPainter: _TopBarEdgePainter(
          leftEdge: touchesSiteLeftEdge(context),
          page: MediaQuery.sizeOf(context),
          bottomInset: _leftEdgeBottomInset(context),
        ),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: const ColoredBox(
              color: kTopBarTint,
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBarEdgePainter extends CustomPainter {
  final bool leftEdge;
  final Size page;
  final double bottomInset;

  _TopBarEdgePainter({
    required this.leftEdge,
    required this.page,
    required this.bottomInset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final edge = Paint()
      ..color = kTopBarEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final y = size.height - 0.5; // the bar's last pixel row
    if (!leftEdge || size.width < page.width - 1) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), edge);
      return;
    }

    const r = kPageCornerRadius;
    const x = 0.5; // the page's first pixel column

    // Outside the rounded corner, just under the bar: same tint as the bar,
    // so the corner reads as part of the frame.
    final corner = Path.combine(
      PathOperation.difference,
      Path()..addRect(Rect.fromLTWH(0, size.height, r + 1, r + 1)),
      Path()..addRRect(
        RRect.fromLTRBAndCorners(
          x,
          y,
          x + r * 4,
          y + r * 4,
          topLeft: const Radius.circular(r),
        ),
      ),
    );
    canvas.drawPath(corner, Paint()..color = kTopBarTint);

    canvas.drawPath(
      Path()
        ..moveTo(size.width, y)
        ..lineTo(x + r, y)
        ..arcToPoint(
          Offset(x, y + r),
          radius: const Radius.circular(r),
          clockwise: false,
        )
        ..lineTo(x, page.height - bottomInset),
      edge,
    );
  }

  @override
  bool shouldRepaint(_TopBarEdgePainter old) =>
      old.leftEdge != leftEdge ||
      old.page != page ||
      old.bottomInset != bottomInset;
}

/// True on the website when this page's left edge is the page area's left
/// edge (next to the sidebar), where the frame's border line runs down.
/// In a split screen that's both stacked panes, or the left one side by side.
bool touchesSiteLeftEdge(BuildContext context) {
  if (!SiteSidebarScope.isActive(context)) return false;
  final split = SplitPaneScope.maybeOf(context);
  return split == null || split.axis == Axis.vertical || split.isStart;
}

/// How far above the page's bottom the left border line stops: the top pane
/// of a stacked split rounds that corner into the divider (the split screen
/// draws the curve), so the straight line ends where the curve begins.
double _leftEdgeBottomInset(BuildContext context) {
  final split = SplitPaneScope.maybeOf(context);
  if (split == null || split.axis != Axis.vertical || !split.isStart) return 0;
  return kPageCornerRadius + 0.5;
}

/// Carries the website frame's left border line down through a page's
/// bottom bar (which would otherwise cover it), to the bottom of the page.
class SiteLeftEdgeLine extends StatelessWidget {
  final Widget child;
  const SiteLeftEdgeLine({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!touchesSiteLeftEdge(context)) return child;
    return CustomPaint(
      foregroundPainter: _LeftLinePainter(_leftEdgeBottomInset(context)),
      child: child,
    );
  }
}

class _LeftLinePainter extends CustomPainter {
  final double bottomInset;
  _LeftLinePainter(this.bottomInset);

  @override
  void paint(Canvas canvas, Size size) {
    final bottom = size.height - bottomInset;
    if (bottom <= 0) return;
    canvas.drawLine(
      const Offset(0.5, 0),
      Offset(0.5, bottom),
      Paint()
        ..color = kTopBarEdge
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_LeftLinePainter old) => old.bottomInset != bottomInset;
}

/// Present above each pane of a SplitScreen: which way the panes are laid
/// out and which one this is.
class SplitPaneScope extends InheritedWidget {
  final Axis axis;

  /// The left (side by side) or top (stacked) pane.
  final bool isStart;

  const SplitPaneScope({
    super.key,
    required this.axis,
    required this.isStart,
    required super.child,
  });

  static SplitPaneScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SplitPaneScope>();

  @override
  bool updateShouldNotify(SplitPaneScope old) =>
      axis != old.axis || isStart != old.isStart;
}
