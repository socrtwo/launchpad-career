/// Data layer for Launchpad Career.
///
/// Pure Dart: no Flutter, no plugins, no network client. Catalogues are bundled
/// in memory. The session lives in memory and is mirrored to a [KeyValueStore]
/// only after the person opts in. Swapping in a real backend means adding an
/// implementation beside these, not editing the UI.
library;

export 'src/bundled_labor_market_repository.dart';
export 'src/catalog/guidance.dart';
export 'src/catalog/occupations.dart';
export 'src/catalog/plan_templates.dart';
export 'src/in_memory_goal_catalog_repository.dart';
export 'src/in_memory_occupation_catalog_repository.dart';
export 'src/in_memory_session_repository.dart';
export 'src/key_value_store.dart';
export 'src/labor/oews_importer.dart';
export 'src/persistent_session_repository.dart';
export 'src/session_codec.dart';
