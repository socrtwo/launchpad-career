/// Data layer for Launchpad Career.
///
/// Everything here is mock/in-memory for Phase 1. No network, no analytics, no
/// persistence. Swapping in a real backend means adding an implementation
/// beside these, not editing the UI.
library;

export 'src/in_memory_goal_catalog_repository.dart';
export 'src/in_memory_session_repository.dart';
