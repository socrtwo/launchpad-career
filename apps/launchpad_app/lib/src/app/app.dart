import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:launchpad_core/launchpad_core.dart';

import '../l10n/app_strings.dart';
import '../routing/app_router.dart';

class LaunchpadApp extends ConsumerWidget {
  const LaunchpadApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Launchpad Career',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // The OS decides. There is no in-app theme toggle in Phase 1, because a
      // toggle that does not persist is worse than none.
      themeMode: ThemeMode.system,
      routerConfig: router,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        AppStringsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppStringsDelegate.supportedLocales,
    );
  }
}
