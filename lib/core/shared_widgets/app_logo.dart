import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double fontSize;

  const AppLogo({
    super.key,
    this.fontSize = 32, // Default size for the login screen
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 3.0,
          shadows: [
            // Adds a subtle ambient glow to the text
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        children: const [
          TextSpan(
            text: 'SCORE',
            style: TextStyle(color: Colors.white),
          ),
          TextSpan(
            text: 'CARDS',
            style: TextStyle(color: Color(0xFF00A2FF)), // Your exact neon blue
          ),
        ],
      ),
    );
  }
}
