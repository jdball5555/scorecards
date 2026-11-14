import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../core/shared_widgets/glass_card.dart';
import '../../../core/shared_widgets/gradient_background.dart';
import '../../../core/shared_widgets/sleek_notification_banner.dart';
import '../scan/rulebook_parser.dart';
import '../scorecard_template_create/template_create_screen.dart';
import 'package:scorecards_app/core/shared_widgets/top_bar_background.dart';

/// On-device ML Kit text recognition only exists on Android and iOS.
bool get isRulebookScanSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

class AiTemplateScanScreen extends StatefulWidget {
  const AiTemplateScanScreen({super.key});

  @override
  State<AiTemplateScanScreen> createState() => _AiTemplateScanScreenState();
}

class _AiTemplateScanScreenState extends State<AiTemplateScanScreen> {
  static const _purple = Color(0xFF7855C1);
  static const _blue = Color(0xFF00A2FF);

  bool _isProcessing = false;
  String _statusText = "";
  RulebookParseResult? _result;

  final ImagePicker _picker = ImagePicker();
  TextRecognizer? _textRecognizer;

  @override
  void dispose() {
    // Free the on-device model.
    _textRecognizer?.close();
    super.dispose();
  }

  Future<void> _scan(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 90, // High enough for reliable text recognition
        maxWidth: 2400,
      );
      if (photo == null) return;

      setState(() {
        _isProcessing = true;
        _statusText = "Reading text...";
      });

      _textRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
      final recognized = await _textRecognizer!.processImage(
        InputImage.fromFilePath(photo.path),
      );

      if (!mounted) return;
      if (recognized.text.trim().length < 10) {
        setState(() => _isProcessing = false);
        SleekNotificationBanner.show(
          "No Text Found",
          "Try again with the page flat, well lit and filling the frame.",
          icon: Icons.image_not_supported_outlined,
          color: Colors.orangeAccent,
        );
        return;
      }

      setState(() => _statusText = "Analyzing rules...");
      final result = RulebookParser.parse(recognized.text);

      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _result = result;
      });
    } catch (e) {
      debugPrint("Rulebook scan failed: $e");
      if (!mounted) return;
      setState(() => _isProcessing = false);
      SleekNotificationBanner.show(
        "Scan Failed",
        "Couldn't read that photo. Please try again or set up manually.",
        icon: Icons.error_outline,
        color: Colors.redAccent,
      );
    }
  }

  void _continueToReview() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateCreateScreen(
          isGroupGame: false,
          initialSettings: _result?.toSettings(),
        ),
      ),
    );
  }

  void _setUpManually() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const TemplateCreateScreen(isGroupGame: false),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    Color color = _blue,
    bool loading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onPressed,
        icon: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }

  Widget _secondaryButton(String label, IconData icon, VoidCallback? onTap) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    return GlassCard(
      accentColor: _purple,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _purple.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.center_focus_strong_rounded,
                color: Colors.white,
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Snap a Rulebook Photo",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isRulebookScanSupported
                  ? "Take a clear picture of the box or the rulebook's scoring section. We'll read the player count, game length and how to win, then you can review everything."
                  : "Rulebook scanning uses on-device text recognition, which is available in the iPhone and Android apps. You can still build your template manually here.",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            if (isRulebookScanSupported) ...[
              _primaryButton(
                label: _isProcessing ? _statusText.toUpperCase() : "TAKE PHOTO",
                icon: Icons.camera_alt_rounded,
                loading: _isProcessing,
                onPressed: _isProcessing
                    ? null
                    : () => _scan(ImageSource.camera),
              ),
              const SizedBox(height: 12),
              _secondaryButton(
                "CHOOSE FROM PHOTOS",
                Icons.photo_library_outlined,
                _isProcessing ? null : () => _scan(ImageSource.gallery),
              ),
            ] else
              _primaryButton(
                label: "SET UP MANUALLY",
                icon: Icons.edit_note_rounded,
                onPressed: _setUpManually,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(RulebookParseResult result) {
    return GlassCard(
      accentColor: _purple,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result.foundAnything
                      ? Icons.auto_awesome_rounded
                      : Icons.help_outline_rounded,
                  color: const Color(0xFFB79CFF),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.foundAnything
                        ? "Here's what we found"
                        : "We couldn't spot the scoring rules",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (result.foundAnything)
              ...result.findings.map(
                (f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          f,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              const Text(
                "Try a photo of the box's back or the \"Scoring\" / \"Winning\" section, or continue and fill in the answers yourself.",
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
            const SizedBox(height: 24),
            _primaryButton(
              label: "REVIEW & CONTINUE",
              icon: Icons.arrow_forward_rounded,
              onPressed: _continueToReview,
            ),
            const SizedBox(height: 12),
            _secondaryButton(
              "SCAN AGAIN",
              Icons.refresh_rounded,
              () => setState(() => _result = null),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          title: const FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              "Scan Rulebook with AI",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                fontSize: 22,
              ),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          flexibleSpace: const TopBarBackground(),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 48).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _result == null
                            ? _buildIntroCard()
                            : _buildResultCard(_result!),
                        const SizedBox(height: 20),
                        if (isRulebookScanSupported)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.lock_outline_rounded,
                                color: Colors.white38,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  "Processed 100% offline on your device",
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
