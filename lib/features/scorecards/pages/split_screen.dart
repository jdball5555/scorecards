import 'package:flutter/material.dart';

import '../../../core/layout/responsive.dart';
import '../../../core/shared_widgets/top_bar_background.dart';

/// Two pages side by side (landscape) or stacked (portrait), with a thin
/// draggable line between them.
///
/// The panes touch, and every page shown in them has a standard-height top
/// bar, so the bars read as one band across the top. Side by side, the line
/// runs from that band's edge to the bottom of the page. Stacked, it runs
/// the full width; on the website the top pane's bottom-left corner rounds
/// into it, matching the frame's other corners. A small six-dot grip sits in
/// the middle of the line.
class SplitScreen extends StatefulWidget {
  final Widget mainPane;
  final Widget secondaryPane;
  final bool swapPanes;

  /// The narrowest each pane can be dragged to when side by side: as narrow
  /// as each side's Customize page can go with its title still fitting.
  final double mainMinExtent;
  final double secondaryMinExtent;

  const SplitScreen({
    super.key,
    required this.mainPane,
    required this.secondaryPane,
    this.swapPanes = false,
    this.mainMinExtent = 360,
    this.secondaryMinExtent = 320,
  });

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  /// Share of the space taken by the first pane (left, or top).
  late double _splitRatio;

  bool _hovering = false;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _splitRatio = widget.swapPanes ? 0.71 : 0.29;
  }

  @override
  void didUpdateWidget(SplitScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Invert the ratio so the big side stays the big side when swapping.
    if (widget.swapPanes != oldWidget.swapPanes) {
      _splitRatio = 1.0 - _splitRatio;
    }
  }

  /// The first pane's extent in whole pixels, kept within both panes'
  /// minimums. If the space can't fit both minimums, they share it in
  /// proportion to them.
  double _startExtent(double total, double startMin, double endMin) {
    if (total <= 0) return 0;
    if (startMin + endMin > total) {
      return (total * startMin / (startMin + endMin)).roundToDouble();
    }
    return (total * _splitRatio)
        .clamp(startMin, total - endMin)
        .roundToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isHorizontal = media.orientation == Orientation.landscape;
    final axis = isHorizontal ? Axis.horizontal : Axis.vertical;
    final site = SiteSidebarScope.isActive(context);

    // Side by side, metrics is on the left; stacked, the scorecard is on
    // top. Swapping flips either.
    final mainFirst = isHorizontal ? widget.swapPanes : !widget.swapPanes;
    final startPane = mainFirst ? widget.mainPane : widget.secondaryPane;
    final endPane = mainFirst ? widget.secondaryPane : widget.mainPane;

    // Bottom of the panes' top bars (all standard height).
    final barBottom = media.padding.top + kToolbarHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final total = isHorizontal ? size.width : size.height;
        // Side by side, the minimums are widths. Stacked, each pane keeps a
        // share of the height (main 35%, secondary 20%).
        final mainMin = isHorizontal ? widget.mainMinExtent : total * 0.35;
        final secondaryMin = isHorizontal
            ? widget.secondaryMinExtent
            : total * 0.20;
        final startMin = mainFirst ? mainMin : secondaryMin;
        final endMin = mainFirst ? secondaryMin : mainMin;
        final start = _startExtent(total, startMin, endMin);
        final end = total - start;

        // Each pane lays itself out for its own size (side padding, tile
        // widths), not the whole page's.
        Widget pane(Widget child, {required bool isStart}) {
          final paneSize = isHorizontal
              ? Size(isStart ? start : end, size.height)
              : Size(size.width, isStart ? start : end);
          var data = media.copyWith(size: paneSize);
          // Each pane only keeps the system insets (status bar, notch, home
          // indicator) on the screen edges it actually touches.
          data = data.removePadding(
            removeTop: !isHorizontal && !isStart,
            removeBottom: !isHorizontal && isStart,
            removeLeft: isHorizontal && !isStart,
            removeRight: isHorizontal && isStart,
          );
          return Positioned(
            left: isHorizontal && !isStart ? start : 0,
            top: !isHorizontal && !isStart ? start : 0,
            width: paneSize.width,
            height: paneSize.height,
            child: ClipRect(
              child: MediaQuery(
                data: data,
                child: SplitPaneScope(
                  axis: axis,
                  isStart: isStart,
                  child: child,
                ),
              ),
            ),
          );
        }

        void drag(double delta) {
          if (total <= 0) return;
          setState(() {
            final current = _startExtent(total, startMin, endMin);
            final next = (current + delta).clamp(startMin, total - endMin);
            _splitRatio = next / total;
          });
        }

        return SizedBox.fromSize(
          size: size,
          child: Stack(
            children: [
              pane(startPane, isStart: true),
              pane(endPane, isStart: false),
              // The divider line, painted over both panes (and over their
              // bottom bars), under the grab area.
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _DividerPainter(
                      axis: axis,
                      boundary: start,
                      barBottom: barBottom,
                      roundedCorner: site && !isHorizontal,
                      active: _hovering || _dragging,
                    ),
                  ),
                ),
              ),
              _grabArea(
                isHorizontal: isHorizontal,
                boundary: start,
                barBottom: barBottom,
                onDrag: drag,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _grabArea({
    required bool isHorizontal,
    required double boundary,
    required double barBottom,
    required void Function(double delta) onDrag,
  }) {
    // A wider grab area for fingers in the app than for a mouse on the site.
    final half = SiteSidebarScope.isActive(context) ? 8.0 : 12.0;
    void startDrag(_) => setState(() => _dragging = true);
    void endDrag(_) => setState(() => _dragging = false);
    final area = MouseRegion(
      cursor: isHorizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: isHorizontal ? startDrag : null,
        onHorizontalDragUpdate: isHorizontal ? (d) => onDrag(d.delta.dx) : null,
        onHorizontalDragEnd: isHorizontal ? endDrag : null,
        onVerticalDragStart: isHorizontal ? null : startDrag,
        onVerticalDragUpdate: isHorizontal ? null : (d) => onDrag(d.delta.dy),
        onVerticalDragEnd: isHorizontal ? null : endDrag,
      ),
    );

    if (isHorizontal) {
      // Starts below the top bars so it doesn't cover their buttons.
      return Positioned(
        left: boundary - half,
        width: half * 2,
        top: barBottom,
        bottom: 0,
        child: area,
      );
    }
    return Positioned(
      top: boundary - half,
      height: half * 2,
      left: 0,
      right: 0,
      child: area,
    );
  }
}

/// The line between the panes and its six-dot grip.
class _DividerPainter extends CustomPainter {
  final Axis axis;
  final double boundary;

  /// Bottom of the top bars: side by side, the line starts at their edge.
  final double barBottom;

  /// Stacked on the website: the top pane's bottom-left corner rounds from
  /// the frame's left border into the line.
  final bool roundedCorner;
  final bool active;

  _DividerPainter({
    required this.axis,
    required this.boundary,
    required this.barBottom,
    required this.roundedCorner,
    required this.active,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = active ? const Color(0x33FFFFFF) : kTopBarEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final dot = Paint()
      ..color = active ? const Color(0x99FFFFFF) : const Color(0x59FFFFFF);

    final horizontal = axis == Axis.horizontal;
    final c = boundary - 0.5; // the first pane's last pixel row/column

    final double mid;
    if (horizontal) {
      // From the top bars' line down to the bottom of the page.
      canvas.drawLine(Offset(c, barBottom), Offset(c, size.height), line);
      mid = (barBottom + size.height) / 2;
    } else if (roundedCorner) {
      const r = kPageCornerRadius;
      const x = 0.5; // the page's first pixel column
      // Outside the rounded corner: same tint as the frame around it.
      canvas.drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(Rect.fromLTWH(0, boundary - r - 1, r + 1, r + 1)),
          Path()..addRRect(
            RRect.fromLTRBAndCorners(
              x,
              c - r * 4,
              x + r * 4,
              c,
              bottomLeft: const Radius.circular(r),
            ),
          ),
        ),
        Paint()..color = kTopBarTint,
      );
      // The curve belongs to the frame, so it keeps the frame's color; only
      // the straight, draggable part lights up on hover.
      canvas.drawPath(
        Path()
          ..moveTo(x, c - r)
          ..arcToPoint(
            Offset(x + r, c),
            radius: const Radius.circular(r),
            clockwise: false,
          ),
        Paint()
          ..color = kTopBarEdge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      canvas.drawLine(Offset(x + r, c), Offset(size.width, c), line);
      mid = size.width / 2;
    } else {
      canvas.drawLine(Offset(0, c), Offset(size.width, c), line);
      mid = size.width / 2;
    }

    // The grip: two rows of three dots, one either side of the line.
    const dotRadius = 1.1;
    for (final along in const [-4.0, 0.0, 4.0]) {
      for (final across in const [-2.5, 2.5]) {
        canvas.drawCircle(
          horizontal
              ? Offset(c + across, mid + along)
              : Offset(mid + along, c + across),
          dotRadius,
          dot,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DividerPainter old) =>
      old.axis != axis ||
      old.boundary != boundary ||
      old.barBottom != barBottom ||
      old.roundedCorner != roundedCorner ||
      old.active != active;
}
