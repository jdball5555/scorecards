import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/shared_widgets/gradient_background.dart';
import '../../../core/shared_widgets/glass_text_field.dart';
import '../../../core/shared_widgets/app_logo.dart';
import '../../../core/shared_widgets/sleek_notification_banner.dart';

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
  bool _rememberMe = true;
  bool _isSignUpMode = false;

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

  // --- GOOGLE SIGN IN ---
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize();
      final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();

      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final clientAuth = await googleUser.authorizationClient.authorizeScopes([
        'email',
        'profile',
      ]);

      final credential = GoogleAuthProvider.credential(
        accessToken: clientAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final user = userCredential.user;

      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName ?? "Player",
        }, SetOptions(merge: true));
      }
    } on FirebaseAuthException catch (e) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppLogo(fontSize: 40),

                  const SizedBox(height: 8),

                  Text(
                    _isSignUpMode
                        ? "Create an account to score your games."
                        : "Sign in to score your games.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 48),

                  if (_isSignUpMode) ...[
                    GlassTextField(
                      controller: _nameController,
                      hintText: "Display Name",
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 16),
                  ],

                  GlassTextField(
                    controller: _emailController,
                    hintText: "Email Address",
                    icon: Icons.email_outlined,
                  ),
                  const SizedBox(height: 16),
                  GlassTextField(
                    controller: _passwordController,
                    hintText: "Password",
                    icon: Icons.lock_outline,
                    isPassword: true,
                  ),

                  const SizedBox(height: 12),

                  if (!_isSignUpMode)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: _rememberMe,
                                onChanged: (value) =>
                                    setState(() => _rememberMe = value ?? true),
                                activeColor: const Color(0xFF00A2FF),
                                checkColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Remember this device",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),

                        TextButton(
                          onPressed: _handleForgotPassword,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF00A2FF),
                          ),
                          child: const Text(
                            "Forgot Password?",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    const SizedBox(height: 24),

                  const SizedBox(height: 32),

                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00A2FF).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : (_isSignUpMode ? _handleSignUp : _handleLogin),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A2FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : Text(
                              _isSignUpMode ? "CREATE ACCOUNT" : "LOGIN",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _isSignUpMode = !_isSignUpMode;
                          _passwordController.clear();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: Colors.black.withOpacity(0.2),
                      ),
                      child: Text(
                        _isSignUpMode ? "LOG IN INSTEAD" : "CREATE NEW ACCOUNT",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Colors.white.withOpacity(0.2),
                          thickness: 1.5,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "OR",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Colors.white.withOpacity(0.2),
                          thickness: 1.5,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      icon: const Icon(
                        Icons.g_mobiledata,
                        size: 36,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "CONTINUE WITH GOOGLE",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
