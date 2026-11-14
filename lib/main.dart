import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'app/app.dart'; // Adjust this path to match your file location
import 'core/web/splash_remover.dart';

void main() async {
  // Fixes the native isolate crash by binding the engine before initializing Firebase
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }

  runApp(const ProviderScope(child: ScorecardsApp()));
  WidgetsBinding.instance.addPostFrameCallback((_) => removeWebSplash());
}
