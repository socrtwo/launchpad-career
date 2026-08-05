import 'package:meta/meta.dart';

/// Stable identifiers for the primary goals offered on the home screen.
///
/// The wire/route value is [slug]; never persist the enum index, because
/// reordering the enum would silently repoint saved links and stored state.
enum GoalId {
  direction('direction'),
  majorOrGraduatePath('major-or-graduate-path'),
  internshipOrJob('internship-or-job'),
  resumeAndLinkedIn('resume-and-linkedin'),
  interviewPreparation('interview-preparation'),
  employableSkills('employable-skills');

  const GoalId(this.slug);

  /// URL- and storage-safe identifier.
  final String slug;

  static GoalId? fromSlug(String? slug) {
    if (slug == null) return null;
    for (final id in GoalId.values) {
      if (id.slug == slug) return id;
    }
    return null;
  }
}

/// Icon identifiers resolved to a concrete icon set by the UI layer.
///
/// Keeping this a token rather than an `IconData` is what allows the domain
/// package to stay free of Flutter.
enum GoalIcon {
  explore,
  school,
  search,
  document,
  microphone,
  growth,
  conversation,
}

/// A selectable goal presented to the user.
@immutable
class Goal {
  const Goal({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.nextStep,
  });

  final GoalId id;

  /// Short, action-first label shown on the card.
  final String title;

  /// One-sentence explanation. Progressive disclosure is a presentation
  /// decision; the text itself is always available to assistive technology.
  final String description;

  final GoalIcon icon;

  /// Plain-language description of what the product will do next for this goal.
  /// Shown on the placeholder goal page until the real flow ships.
  final String nextStep;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Goal && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
