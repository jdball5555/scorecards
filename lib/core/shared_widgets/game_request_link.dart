import 'package:flutter/material.dart';

import '../../features/settings/pages/feedback_form.dart';

/// "Want a game that's not here?" prompt. Opens the feedback form with
/// Suggest an Idea → New Game already selected.
class GameRequestLink extends StatelessWidget {
  final String label;
  final EdgeInsetsGeometry padding;

  /// Called before navigating (e.g. to close the sheet/dialog it lives in).
  final VoidCallback? onBeforeOpen;

  const GameRequestLink({
    super.key,
    this.label = "Want a game that's not here? Request it",
    this.padding = const EdgeInsets.symmetric(vertical: 4),
    this.onBeforeOpen,
  });

  @override
  Widget build(BuildContext context) {
    // Capture a navigator that survives a dialog closing.
    final navigator = Navigator.of(context, rootNavigator: true);
    return Padding(
      padding: padding,
      child: Center(
        child: TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF00A2FF),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
          onPressed: () {
            onBeforeOpen?.call();
            FeedbackFormScreen.openGameRequest(navigator.context);
          },
          icon: const Icon(Icons.add_comment_outlined, size: 18),
          label: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ),
    );
  }
}
