import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../features/auth/pages/login_screen.dart';
import '../features/auth/providers/auth_provider.dart';
import '../app/app_shell.dart';
import '../features/settings/pages/mail_inbox_screen.dart';
import '../features/settings/providers/notification_settings_provider.dart';
// NEW IMPORT: We must import the banner file so we can use its single, global key!
import '../core/shared_widgets/sleek_notification_banner.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// DELETED the duplicate globalMessengerKey from here!

Future<void> saveDeviceToken() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    String? token = await messaging.getToken();

    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
    }
  } catch (e) {
    debugPrint("Error storing device token: $e");
  }
}

// SMART ROUTER: Prevents the Mail Screen from being pushed twice!
void _goToMail() {
  bool isMailBoxOpen = false;
  navigatorKey.currentState?.popUntil((route) {
    if (route.settings.name == '/mail_inbox') {
      isMailBoxOpen = true;
    }
    return true; // Check top route without popping anything
  });

  if (!isMailBoxOpen) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/mail_inbox'),
        builder: (_) => MailInboxScreen(),
      ),
    );
  }
}

void setupNotificationRouting(WidgetRef ref) {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint("Foreground message received: ${message.messageId}");

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        bool isMailBoxOpen = false;
        navigatorKey.currentState?.popUntil((route) {
          if (route.settings.name == '/mail_inbox') {
            isMailBoxOpen = true;
          }
          return true;
        });

        final settingsState =
            ref.read(notificationSettingsProvider).value ?? {};
        final showBanner = settingsState['in_app_banner'] ?? true;

        if (showBanner && !isMailBoxOpen) {
          // CHANGED: We are now using your custom SleekNotificationBanner here too!
          SleekNotificationBanner.show(
            "New Mail Received",
            "Check your Mail Box for updates.",
            icon: Icons.mail_outline,
            color: const Color(0xFF00A2FF),
            onViewPressed: () {
              globalMessengerKey.currentState?.hideCurrentSnackBar();
              _goToMail();
            },
          );
        }
      } catch (e) {
        debugPrint("Error showing in-app banner: $e");
      }
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    if (message.data['type'] == 'group_invite' ||
        message.data['type'] == 'system_notice') {
      _goToMail();
    }
  });

  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null &&
        (message.data['type'] == 'group_invite' ||
            message.data['type'] == 'system_notice')) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _goToMail();
      });
    }
  });
}

class ScorecardsApp extends ConsumerStatefulWidget {
  const ScorecardsApp({super.key});

  @override
  ConsumerState<ScorecardsApp> createState() => _ScorecardsAppState();
}

class _ScorecardsAppState extends ConsumerState<ScorecardsApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setupNotificationRouting(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
      // FIXED: This is now using the one true key exported from sleek_notification_banner.dart
      scaffoldMessengerKey: globalMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: authState.when(
        data: (user) {
          if (user == null) {
            return const LoginScreen();
          } else {
            saveDeviceToken();
            return const AppShell();
          }
        },
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFF00A2FF)),
          ),
        ),
        error: (error, stack) =>
            Scaffold(body: Center(child: Text("Authentication Error: $error"))),
      ),
    );
  }
}
