import 'dart:async';

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
