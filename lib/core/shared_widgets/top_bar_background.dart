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
/// Bars narrower than the page (split-screen panes) keep the plain line.
class TopBarBackground extends StatelessWidget {
  const TopBarBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final page = MediaQuery.sizeOf(context);
    return SizedBox.expand(
      child: CustomPaint(
        foregroundPainter: _TopBarEdgePainter(
          site: SiteSidebarScope.isActive(context),
          page: page,
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
  final bool site;
  final Size page;

  _TopBarEdgePainter({required this.site, required this.page});

  @override
  void paint(Canvas canvas, Size size) {
    final edge = Paint()
      ..color = kTopBarEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final y = size.height - 0.5; // the bar's last pixel row
    if (!site || size.width < page.width - 1) {
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
      Path()
        ..addRRect(
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
        ..lineTo(x, page.height),
      edge,
    );
  }

  @override
  bool shouldRepaint(_TopBarEdgePainter old) =>
      old.site != site || old.page != page;
}
