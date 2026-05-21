import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/theme_provider.dart';

/// Root widget of the Polarna application.
///
/// Wires [MaterialApp.router] to the single [GoRouter] provided by
/// [appRouterProvider] and applies the role-aware theme from
/// [appThemeProvider] (light for UMKM/signed-out, dark for Mitra/Admin).
class PolarnaApp extends ConsumerWidget {
  const PolarnaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final theme = ref.watch(appThemeProvider);

    return MaterialApp.router(
      title: 'Polarna',
      debugShowCheckedModeBanner: false,
      theme: theme,
      routerConfig: router,
    );
  }
}
