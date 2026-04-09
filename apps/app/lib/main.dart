import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/app.dart';
import 'core/push/push_notification_service.dart';

void main() {
  // Everything — binding init, Firebase init, error handlers, and the
  // runApp call — lives inside a single `runZonedGuarded` so they all
  // share the same zone. The previous layout initialized the binding
  // outside the guarded zone, which produced the Flutter "Zone mismatch"
  // warning and meant some async errors from the binding / platform
  // channels bypassed our error handler entirely.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Use bundled fonts, no network fetching.
    GoogleFonts.config.allowRuntimeFetching = false;

    // Catch synchronous Flutter framework errors (build/layout/render).
    FlutterError.onError = (details) {
      debugPrint('[App] FlutterError: ${details.exception}');
      FlutterError.presentError(details);
    };

    // Catch platform-level errors (e.g. native plugin crashes). Returning
    // true tells the engine the error was handled so it doesn't crash the
    // app process.
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('[App] PlatformError: $error');
      return true;
    };

    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    runApp(
      const ProviderScope(
        child: DingitApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('[App] Unhandled error: $error');
  });
}
