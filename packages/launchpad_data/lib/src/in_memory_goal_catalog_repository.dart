import 'package:launchpad_domain/launchpad_domain.dart';

/// The Phase 1 goal catalogue.
///
/// Copy lives here rather than in the widgets so that (a) it can be moved to
/// ARB files or a CMS without touching layout code, and (b) it can be reviewed
/// as a block against `docs/product/tone-and-language.md`.
class InMemoryGoalCatalogRepository implements GoalCatalogRepository {
  const InMemoryGoalCatalogRepository();

  static const List<Goal> _goals = <Goal>[
    Goal(
      id: GoalId.direction,
      title: 'Help me pick a direction',
      description:
          'Explore career paths that fit your interests, strengths, priorities, and circumstances.',
      icon: GoalIcon.explore,
      nextStep:
          'Next, we will ask a short set of questions about what you enjoy, what you are good at, '
          'and what your situation allows, then show a handful of paths worth a closer look.',
    ),
    Goal(
      id: GoalId.majorOrGraduatePath,
      title: 'Help me choose a major or graduate path',
      description:
          'Compare programs, costs, requirements, and likely career outcomes.',
      icon: GoalIcon.school,
      nextStep:
          'Next, we will build a side-by-side comparison of the programs you are weighing, including '
          'what each one costs, what it requires, and what graduates typically go on to do.',
    ),
    Goal(
      id: GoalId.internshipOrJob,
      title: 'Help me find an internship or job',
      description:
          'Create a focused search plan for roles, networking, applications, and follow-up.',
      icon: GoalIcon.search,
      nextStep:
          'Next, we will turn your target roles into a weekly search plan: where to look, who to talk '
          'to, how many applications are realistic, and when to follow up.',
    ),
    Goal(
      id: GoalId.resumeAndLinkedIn,
      title: 'Improve my resume and LinkedIn',
      description:
          'Present your education, projects, experience, and skills more effectively.',
      icon: GoalIcon.document,
      nextStep:
          'Next, we will work through your resume section by section and line up your LinkedIn profile '
          'with the roles you are actually applying for.',
    ),
    Goal(
      id: GoalId.interviewPreparation,
      title: 'Prepare for interviews',
      description:
          'Practice common questions and develop clear examples from your experience.',
      icon: GoalIcon.microphone,
      nextStep:
          'Next, we will build a small set of examples from your own experience and practise the '
          'questions most likely to come up for the roles you are targeting.',
    ),
    Goal(
      id: GoalId.employableSkills,
      title: 'Build skills employers are looking for',
      description:
          'Identify useful skills and projects based on the roles you are considering.',
      icon: GoalIcon.growth,
      nextStep:
          'Next, we will compare what your target roles ask for against what you already have, and '
          'pick one or two skills plus a project that demonstrates them.',
    ),
  ];

  @override
  Future<List<Goal>> primaryGoals() async => _goals;

  @override
  Future<Goal?> goalById(GoalId id) async {
    for (final goal in _goals) {
      if (goal.id == id) return goal;
    }
    return null;
  }
}
