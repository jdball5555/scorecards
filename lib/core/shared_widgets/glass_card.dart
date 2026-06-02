import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final Color accentColor; // Allows us to make the rim blue, pink, etc.
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.accentColor = const Color(0xFF00A2FF), // Default to that electric blue
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // 1. The Neon Outer Glow
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: -2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            // Lower blur makes the glass look "clearer" and less frosted
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            // 2. The 3D Gradient Rim
            child: Container(
              padding: const EdgeInsets.all(
                2.0,
              ), // The thickness of the glass edge
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0.0, 0.15, 0.7, 1.0],
                  colors: [
                    Colors.white.withOpacity(
                      0.9,
                    ), // Sharp white specular reflection on top left
                    accentColor.withOpacity(0.8), // Bright neon rim
                    accentColor.withOpacity(0.2), // Faded dark sides
                    accentColor.withOpacity(0.6), // Bottom right edge catch
                  ],
                ),
              ),
              // 3. The Clear Inner Void
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  // Very dark center to match your reference image
                  color: Colors.black.withOpacity(0.4),
                  // Inner glow simulates the light bouncing inside the thick glass wall
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.15),
                      blurRadius: 20,
                      spreadRadius: 2,
                      blurStyle: BlurStyle.inner,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
