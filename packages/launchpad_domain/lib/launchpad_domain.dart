/// Domain layer for Launchpad Career.
///
/// This package is deliberately pure Dart: no Flutter, no HTTP, no storage.
/// Anything that needs `dart:ui` (icons, colours, text styles) lives in
/// `launchpad_core` or `launchpad_ui`; anything that talks to the outside world
/// lives in `launchpad_data`.
library;

export 'src/entities/goal.dart';
export 'src/entities/evidence.dart';
export 'src/entities/session.dart';
export 'src/repositories/goal_catalog_repository.dart';
export 'src/repositories/session_repository.dart';
