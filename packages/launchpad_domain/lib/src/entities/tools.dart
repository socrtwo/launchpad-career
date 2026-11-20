import 'package:meta/meta.dart';

/// One section of a checklist-style guide: a thing to do and how to do it.
@immutable
class GuideItem {
  const GuideItem({
    required this.id,
    required this.title,
    required this.points,
  });

  /// Stable within its guide, e.g. `education`.
  final String id;
  final String title;

  /// Two or three specific things to check or do.
  final List<String> points;
}

/// The kinds of interview question in the practice bank.
enum QuestionCategory {
  aboutYou('about-you'),
  behavioural('behavioural'),
  motivation('motivation'),
  closing('closing');

  const QuestionCategory(this.slug);

  final String slug;
}

@immutable
class InterviewQuestion {
  const InterviewQuestion({
    required this.id,
    required this.category,
    required this.prompt,
    required this.purpose,
    required this.tips,
    this.usesExample = true,
  });

  final String id;
  final QuestionCategory category;

  /// The question as an interviewer would ask it.
  final String prompt;

  /// What the interviewer is trying to find out.
  final String purpose;

  final List<String> tips;

  /// Whether the answer is best built from one concrete example, in which
  /// case the situation / task / action / result notes are offered.
  final bool usesExample;
}

/// The four parts of an example-based interview answer.
enum ExamplePart {
  situation('situation'),
  task('task'),
  action('action'),
  result('result');

  const ExamplePart(this.slug);

  final String slug;
}

/// How far along a person says they are with a skill.
enum SkillLevel {
  canShow('can-show'),
  building('building'),
  notYet('not-yet');

  const SkillLevel(this.slug);

  final String slug;

  static SkillLevel? fromSlug(String? slug) {
    if (slug == null) return null;
    for (final level in SkillLevel.values) {
      if (level.slug == slug) return level;
    }
    return null;
  }
}

/// How much time a week a person can give to a job search.
enum SearchHours {
  light('light'),
  steady('steady'),
  intensive('intensive');

  const SearchHours(this.slug);

  final String slug;

  static SearchHours? fromSlug(String? slug) {
    if (slug == null) return null;
    for (final hours in SearchHours.values) {
      if (hours.slug == slug) return hours;
    }
    return null;
  }
}

/// One line of a weekly job-search plan.
///
/// [count] is how many times to do the thing this week. It is a way of
/// splitting the time a person said they have, not a benchmark and not a
/// statistic about what works.
@immutable
class SearchTask {
  const SearchTask({
    required this.id,
    required this.title,
    required this.detail,
    this.count,
  });

  final String id;
  final String title;
  final String detail;
  final int? count;
}
