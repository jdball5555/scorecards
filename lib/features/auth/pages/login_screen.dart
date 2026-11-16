import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/shared_widgets/gradient_background.dart';
import '../../../core/shared_widgets/sleek_notification_banner.dart';
import '../../../core/layout/responsive.dart';
import '../../../core/shared_widgets/top_bar_background.dart';
import '../../groups/player_invite.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  // Opened from an invite link? Most of those people are new: start on
  // "make an account".
  late bool _isSignUpMode = ref.read(pendingInviteProvider) != null;

  // --- EMAIL LOGIN ---
  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Client-side check to save Firebase backend calls!
    if (email.isEmpty || password.isEmpty) {
      SleekNotificationBanner.show(
        "Missing Information",
        "Please enter both your email and password.",
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFF7855C1),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMsg = e.message ?? 'An error occurred while logging in.';

        // Translating Firebase errors to human-readable text
        if (e.code == 'invalid-email') {
          errorMsg = "This email address is not formatted correctly.";
        } else if (e.code == 'user-not-found') {
          errorMsg = "No account exists with this email address.";
        } else if (e.code == 'wrong-password') {
          errorMsg = "Incorrect password. Please try again.";
        } else if (e.code == 'invalid-credential') {
          // Note: Firebase may send this generic error instead of 'user-not-found' if "Email Enumeration Protection" is turned on.
          errorMsg = "Account not found or incorrect password.";
        } else if (e.code == 'user-disabled') {
          errorMsg = "This account has been disabled.";
        }

        SleekNotificationBanner.show(
          "Login Failed",
          errorMsg,
          icon: Icons.error_outline,
          color: Colors.redAccent,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- EMAIL SIGN UP ---
  Future<void> _handleSignUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      SleekNotificationBanner.show(
        "Missing Information",
        "Please fill out all fields to create an account.",
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFF7855C1),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(name);
        await user.reload();

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'displayName': name,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMsg = e.message ?? 'An error occurred while signing up.';

        if (e.code == 'invalid-email') {
          errorMsg = "This email address is not formatted correctly.";
        } else if (e.code == 'email-already-in-use') {
          errorMsg =
              "An account already exists for this email. Try logging in.";
        } else if (e.code == 'weak-password') {
          errorMsg =
              "Your password is too weak. Please use a stronger password.";
        }

        SleekNotificationBanner.show(
          "Sign Up Failed",
          errorMsg,
          icon: Icons.error_outline,
          color: Colors.redAccent,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FORGOT PASSWORD ---
  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      SleekNotificationBanner.show(
        "Email Required",
        "Please enter your email address first.",
        icon: Icons.mark_email_unread_outlined,
        color: const Color(0xFF7855C1),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        SleekNotificationBanner.show(
          "Email Sent!",
          "Password reset email sent! Make sure you check your spam folder.",
          icon: Icons.mark_email_read_outlined,
          color: const Color(0xFF00A2FF),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMsg = e.message ?? 'Failed to send reset email.';

        if (e.code == 'invalid-email') {
          errorMsg = "This email address is not formatted correctly.";
        } else if (e.code == 'user-not-found') {
          errorMsg = "No account exists with this email address.";
        }

        SleekNotificationBanner.show(
          "Reset Failed",
          errorMsg,
          icon: Icons.error_outline,
          color: Colors.redAccent,
        );
      }
    }
  }

  // google_sign_in v7 must be initialised exactly once per app run.
  static Future<void>? _googleInit;

  Future<UserCredential?> _signInWithGoogleCredential() async {
    if (kIsWeb) {
      // GoogleSignIn.authenticate() isn't supported on the web; Firebase's
      // popup flow is the supported path there.
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');
      return FirebaseAuth.instance.signInWithPopup(provider);
    }

    final googleSignIn = GoogleSignIn.instance;
    _googleInit ??= googleSignIn.initialize();
    await _googleInit;
    final GoogleSignInAccount googleUser = await googleSignIn.authenticate();

    final googleAuth = googleUser.authentication;
    final clientAuth = await googleUser.authorizationClient.authorizeScopes([
      'email',
      'profile',
    ]);

    final credential = GoogleAuthProvider.credential(
      accessToken: clientAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return FirebaseAuth.instance.signInWithCredential(credential);
  }

  // --- GOOGLE SIGN IN ---
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final userCredential = await _signInWithGoogleCredential();
      final user = userCredential?.user;

      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName ?? "Player",
        }, SetOptions(merge: true));
      }
    } on FirebaseAuthException catch (e) {
      // Closing the web popup isn't an error worth shouting about.
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return;
      }
      if (mounted) {
        SleekNotificationBanner.show(
          "Google Sign-In Failed",
          e.message ?? 'An error occurred.',
          icon: Icons.error_outline,
          color: Colors.redAccent,
        );
      }
    } on PlatformException catch (e) {
      if (e.code == 'sign_in_canceled' || e.code == 'sign_in_cancelled') {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      if (mounted) {
        SleekNotificationBanner.show(
          "Error",
          e.message ?? 'An unexpected error occurred.',
          icon: Icons.error_outline,
          color: Colors.redAccent,
        );
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('canceled') || errorStr.contains('cancelled')) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      if (mounted) {
        SleekNotificationBanner.show(
          "Error",
          'An error occurred: $e',
          icon: Icons.error_outline,
          color: Colors.redAccent,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- Sign-in panel: same look as Optimizer and the other Axis apps ---
  static const _surface = Color(0xFF0F141E);
  static const _secondaryText = Color(0xFF94A3B8);
  static const _border = Color(0x1FFFFFFF);

  ThemeData _opticTheme(ThemeData base) {
    final pill = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(30),
    );
    OutlineInputBorder field(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c),
    );
    return base.copyWith(
      // Optimizer uses standard density (desktop would otherwise be compact).
      visualDensity: VisualDensity.standard,
      colorScheme: base.colorScheme.copyWith(
        primary: Colors.white,
        onPrimary: Colors.black,
        onSurfaceVariant: _secondaryText,
        outline: const Color(0x40FFFFFF),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surface,
        hintStyle: const TextStyle(color: _secondaryText),
        labelStyle: const TextStyle(color: _secondaryText),
        floatingLabelStyle: const TextStyle(color: Colors.white),
        border: field(_border),
        enabledBorder: field(_border),
        focusedBorder: field(const Color(0x80FFFFFF)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          disabledBackgroundColor: const Color(0x14FFFFFF),
          disabledForegroundColor: _secondaryText,
          shape: pill,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Color(0x40FFFFFF)),
          shape: pill,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: Colors.white),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Colors.white,
        selectionColor: Color(0x40FFFFFF),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Colors.white,
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final creating = _isSignUpMode;
    final invite = ref.watch(pendingInviteProvider);
    const spinner = SizedBox(
      height: 18,
      width: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
    void submit() {
      if (_isLoading) return;
      creating ? _handleSignUp() : _handleLogin();
    }

    // Sized to its content: the open card around it hugs the form.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(40, 40, 40, 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Image.asset(
                  // Rounded square on the website, circle in the app.
                  kIsWeb
                      ? 'assets/branding/app_logo_square.png'
                      : 'assets/branding/app_logo.png',
                  width: 56,
                  height: 56,
                  filterQuality: FilterQuality.high,
                  semanticLabel: 'Scorecards',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Scorecards',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                creating
                    ? 'Create your Scorecards account'
                    : 'Sign in to score your games',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _secondaryText,
                ),
              ),
              if (invite != null) ...[
                const SizedBox(height: 16),
                _InviteNote(invite),
              ],
              const SizedBox(height: 28),
              if (creating) ...[
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(labelText: 'Your name'),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                autofillHints: [
                  creating ? AutofillHints.newPassword : AutofillHints.password,
                ],
                decoration: InputDecoration(
                  labelText: creating ? 'Choose a password' : 'Password',
                ),
                onSubmitted: (_) => submit(),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _isLoading ? null : submit,
                child: _isLoading
                    ? spinner
                    : Text(creating ? 'Create account' : 'Sign in'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                icon: const Icon(Icons.account_circle_outlined),
                label: Text(
                  creating ? 'Sign up with Google' : 'Continue with Google',
                ),
              ),
              if (!creating)
                TextButton(
                  onPressed: _isLoading ? null : _handleForgotPassword,
                  child: const Text('Forgot password'),
                ),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () => setState(() => _isSignUpMode = !_isSignUpMode),
                child: Text(
                  creating
                      ? 'I already have an account'
                      : 'New here? Make an account',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final form = Theme(
      data: _opticTheme(Theme.of(context)),
      child: Builder(builder: _buildForm),
    );

    final wide = isWideLayout(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: _LoginFrame(
          wide: wide,
          hero: wide ? const _LoginHero() : null,
          panel: form,
        ),
      ),
    );
  }
}

/// The site's look on the sign-in page: everything is the tinted black frame
/// (like the sidebar and top bars), and the form sits in a rounded "open"
/// card that shows the background, like the pages inside the app. The card
/// is just big enough for the form.
class _LoginFrame extends StatelessWidget {
  final bool wide;
  final Widget? hero;
  final Widget panel;

  const _LoginFrame({
    required this.wide,
    required this.hero,
    required this.panel,
  });

  @override
  Widget build(BuildContext context) {
    final card = Padding(
      padding: EdgeInsets.all(wide ? 32 : 16),
      child: _OpenCard(
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          removeBottom: true,
          removeLeft: true,
          removeRight: true,
          child: panel,
        ),
      ),
    );
    return SafeArea(
      child: wide
          // Right-to-left so the card (on the right) paints first and the
          // pitch paints over the tint it draws.
          ? Row(
              textDirection: TextDirection.rtl,
              children: [
                Expanded(child: Center(child: card)),
                Expanded(child: hero ?? const SizedBox()),
              ],
            )
          : Center(child: card),
    );
  }
}

/// A rounded card that leaves the background clear inside and tints
/// everything outside it (the whole screen), with a thin edge.
class _OpenCard extends SingleChildRenderObjectWidget {
  const _OpenCard({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderOpenCard();
}

class _RenderOpenCard extends RenderProxyBox {
  static const double radius = 24;

  @override
  void paint(PaintingContext context, Offset offset) {
    final rect = offset & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(radius));
    // Even-odd fill: a huge rectangle minus the card, so everything around
    // the card is tinted and the card itself stays clear.
    context.canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rect.inflate(20000))
        ..addRRect(rrect),
      Paint()..color = kTopBarTint,
    );
    context.pushClipRRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(radius),
      ),
      super.paint,
    );
    context.canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..color = kTopBarEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }
}

/// Left-hand pitch shown beside the sign-in form on wide screens.
class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    Widget point(IconData icon, String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF00A2FF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF00A2FF), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(56, 32, 32, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Every game night,\nscored.",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Scorecards keeps score for your card and board games, so you can play instead of doing math.",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 17,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),
              point(
                Icons.style_rounded,
                "Ready-made scorecards",
                "Spades, Yahtzee, Nerts, Nines, Wavelength and more.",
              ),
              point(
                Icons.groups_rounded,
                "Play with your group",
                "Share scorecards live and track everyone's stats over time.",
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "You're invited to join ..." above the sign-in form (invite links).
class _InviteNote extends StatelessWidget {
  final PendingInvite invite;
  const _InviteNote(this.invite);

  @override
  Widget build(BuildContext context) {
    final group = invite.groupName ?? 'a group';
    final player = invite.playerName;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF00A2FF).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF00A2FF).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.group_add, color: Color(0xFF00A2FF), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              player == null
                  ? "You're invited to join $group. Make an account or sign in to accept."
                  : "You're invited to join $group as $player. Make an account or sign in to accept.",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
