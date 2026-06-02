import 'dart:ui';
import 'package:flutter/material.dart';

class WhiteFrostTile extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const WhiteFrostTile({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(
      20.0,
    ), // Increased padding for bigger cards
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        // INCREASED FROST: Whiter, more opaque fill
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          // CRISPER EDGE: Brighter white border
          color: Colors.white.withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: child,
    );

    // Only add the ripple click effect if an onTap function is provided
    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.05),
          child: content,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        // HEAVIER BLUR: Jumped from 15 to 25 to create a thick ice effect
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: content,
      ),
    );
  }
}
