import '../entities/evidence.dart';
import '../entities/tools.dart';

/// Supplies the content of the employment tools: checklists, the interview
/// question bank and the weekly job-search plan.
abstract interface class GuidanceRepository {
  /// Where this guidance came from, shown on every tool.
  Evidence get evidence;

  Future<List<GuideItem>> resumeSections();

  Future<List<GuideItem>> linkedInSections();

  Future<List<InterviewQuestion>> interviewQuestions();

  /// A week of job-search tasks sized to the time a person has.
  Future<List<SearchTask>> searchWeek(SearchHours hours);
}
