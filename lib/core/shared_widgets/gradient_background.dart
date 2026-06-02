import 'package:flutter/material.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    // Grabs the longest side of the screen to create a perfect square canvas.
    // This ensures the gradient never squashes into an oval on tall phones or wide tablets.
    final double maxSide = size.longestSide;

    return Container(
      color: const Color(0xFF07070A), // Extremely dark, near-black space
      child: Stack(
        children: [
          // --- MOODY SAPPHIRE GLOW (Top Left) ---
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: maxSide,
              height: maxSide,
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.4,
                  colors: [
                    // CHANGED: Darkened from 0xFF004488 to a deeper, inkier blue
                    Color(0xFF002B5E),
                    Colors.transparent,
                  ],
                  stops: [0.0, 1.0],
                ),
              ),
            ),
          ),

          // --- MOODY PLUM GLOW (Bottom Right) ---
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: maxSide,
              height: maxSide,
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.bottomRight,
                  radius: 1.4,
                  colors: [
                    // CHANGED: Darkened from 0xFF4A2080 to a deeper, bruised purple
                    Color(0xFF31135E),
                    Colors.transparent,
                  ],
                  stops: [0.0, 1.0],
                ),
              ),
            ),
          ),

          // --- ACTUAL APP CONTENT ---
          child,
        ],
      ),
    );
  }
}
