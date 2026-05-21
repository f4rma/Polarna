import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // Ensure Flutter bindings are initialised before calling any platform code.
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise locale data for Indonesian date formatting.
  await initializeDateFormatting('id_ID', null);

  // Initialise Firebase using the platform-specific options.
  // Guard against duplicate initialisation (e.g. during hot restart).
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // Wrap the entire widget tree in ProviderScope so all Riverpod providers
  // are accessible throughout the app.
  runApp(
    const ProviderScope(
      child: PolarnaApp(),
    ),
  );
}
