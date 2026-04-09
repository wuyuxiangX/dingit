import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/app.dart';
import 'core/push/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use bundled fonts, no network fetching
  GoogleFonts.config.allowRuntimeFetching = false;

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Catch synchronous Flutter framework errors (build/layout/render)
  FlutterError.onError = (details) {
    debugPrint('[App] FlutterError: ${details.exception}');
    FlutterError.presentError(details);
  };

  // Catch platform-level errors (e.g. native plugin crashes)
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[App] PlatformError: $error');
    return true; // prevent crash
  };

  // Catch unhandled async errors to prevent crashes when offline
  runZonedGuarded(
    () => runApp(
      const ProviderScope(
        child: DingitApp(),
      ),
    ),
    (error, stack) {
      debugPrint('[App] Unhandled error: $error');
    },
  );
}
