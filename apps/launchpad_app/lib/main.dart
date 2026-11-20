import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:launchpad_data/launchpad_data.dart';

import 'src/app/app.dart';
import 'src/app/providers.dart';
import 'src/app/shared_preferences_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Opening the store reads nothing the person has not already chosen to save
  // and writes nothing. If the platform refuses (a locked-down browser, for
  // example) the app runs in memory and says so.
  KeyValueStore? store;
  try {
    store = await SharedPreferencesStore.open();
  } on Object {
    store = null;
  }

  runApp(
    ProviderScope(
      overrides: [
        if (store != null)
          keyValueStoreProvider.overrideWithValue(store)
        else
          durableStorageAvailableProvider.overrideWithValue(false),
      ],
      child: const LaunchpadApp(),
    ),
  );
}
