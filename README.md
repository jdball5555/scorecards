# Scorecards 🃏 (v0.1.0 - Foundation)

A scalable, feature-first Flutter application designed to sync and track game statistics for card and board games like Spades, Hearts, Euchre, and Rummy Cube.

Currently in its foundational pre-release phase, this repository serves as a robust boilerplate demonstrating enterprise-level architecture, reactive state management, and secure backend integration.

## 🚀 Current Architecture & Features

This project is built with scalability in mind, utilizing a Feature-First folder structure to keep domains isolated and maintainable.

- Authentication Flow: Complete Firebase Authentication handling both Email/Password and Google Sign-In, complete with strict client-side and server-side error handling.
- Reactive State Management: Powered by Riverpod for predictable, safe, and easily testable state across the application.
- Custom UI/UX: Built with a modern, glassmorphism design system. All native Material snackbars have been overridden with a custom SleekNotificationBanner overlay system that persists across complex navigation stacks.
- Push Notifications: Deep integration with Firebase Cloud Messaging (FCM). Handles foreground, background, and dead-state notification routing, seamlessly pushing users to a dedicated Mail Inbox screen.
- Real-time Database: Firestore integration for syncing group data, invites, and user mail instantly across devices.

## 🛠 Tech Stack

- Frontend: Flutter / Dart
- Backend: Firebase (Auth, Firestore, Cloud Messaging)
- State Management: Riverpod
- Design: Custom Glassmorphism UI elements

## 📂 Project Structure

The app utilizes a strictly separated feature-driven architecture:

lib/
├── app/ (Global app shell and routing)
├── core/ (Shared widgets, themes, and global utilities)
├── features/
│ ├── auth/ (Login, Sign Up, and Auth Providers)
│ ├── groups/ (Group creation, management, and services)
│ ├── home/ (Main dashboards)
│ └── settings/ (User preferences, mail inbox, push toggles)
└── main.dart (App entry point)

## 🔜 Roadmap

- Apple Sign-In Integration
- Scorecard Logic & Probability Tracking
- Offline-first local caching

---

Developed for iOS and Android.
