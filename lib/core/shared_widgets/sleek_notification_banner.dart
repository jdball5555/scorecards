import 'package:flutter/material.dart';

final GlobalKey<ScaffoldMessengerState> globalMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class SleekNotificationBanner extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback? onViewPressed;
  final IconData icon;
  final Color color;

  const SleekNotificationBanner({
    super.key,
    required this.title,
    required this.body,
    this.onViewPressed,
    this.icon = Icons.mail,
    this.color = const Color(0xFF00A2FF),
  });

  static void show(
    String title,
    String body, {
    IconData icon = Icons.mail,
    Color color = const Color(0xFF00A2FF),
    VoidCallback? onViewPressed,
  }) {
    globalMessengerKey.currentState?.hideCurrentSnackBar();
    globalMessengerKey.currentState?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,

        // CHANGED: Bumped up to 65 to clear the standard Flutter BottomNavigationBar!
        margin: const EdgeInsets.only(bottom: 65, left: 16, right: 16),

        content: SleekNotificationBanner(
          title: title,
          body: body,
          icon: icon,
          color: color,
          onViewPressed: onViewPressed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onViewPressed != null)
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onViewPressed,
              child: Text(
                "VIEW",
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
