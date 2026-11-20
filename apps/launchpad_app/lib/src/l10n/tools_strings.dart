import 'package:launchpad_domain/launchpad_domain.dart';

/// Copy for the employment tools and the progress page.
///
/// The tools give structure, not verdicts. Nothing here grades a person, and
/// the one automatic check says plainly that it only matches patterns.
mixin ToolsStrings {
  String get toolsTitle => 'All tools';

  String get toolsIntro =>
      'Everything in one place. Use any of them in any order; none depends on '
      'another.';

  String get guidanceDraftLine =>
      'This guidance was drafted with AI assistance and has not yet been '
      'reviewed by a careers adviser.';

  String doneCount(int done, int total) => '$done of $total done';

  // Job-search plan.

  String get searchPlanTitle => 'Weekly job-search plan';

  String get searchPlanDescription =>
      'Turn the time you have into a week of applications, conversations and '
      'follow-up.';

  String get searchPlanIntro =>
      'Say how much time you have, and this splits it into a week you can '
      'repeat. The numbers divide your time. They are not a benchmark, and '
      'doing them does not make a result certain.';

  String get searchHoursQuestion =>
      'How much time can you give to this each week?';

  String searchHours(SearchHours hours) => switch (hours) {
        SearchHours.light => 'A few hours',
        SearchHours.steady => 'Most evenings, or one full day',
        SearchHours.intensive => 'Several days',
      };

  String get searchThisWeek => 'This week';

  String searchTaskTitle(String title, int? count) =>
      count == null ? title : '$title: $count';

  String get searchNoteLabel => 'What got a response this week (optional)';

  String get searchCloseWeek => 'Finish this week and start the next';

  String searchWeeks(int weeks) => switch (weeks) {
        0 => 'No weeks finished yet.',
        1 => '1 week finished.',
        _ => '$weeks weeks finished.',
      };

  String get searchWeekClosed =>
      'Week finished. The list is clear for the next one.';

  String get searchRolesHeading => 'Roles you are aiming at';

  String get searchRolesEmpty =>
      'You have not saved any occupations yet. Saving one or two gives the '
      'week a target.';

  // Resume.

  String get resumeTitle => 'Resume guide';

  String get resumeDescription =>
      'Work through your resume section by section, and check the wording of '
      'a line.';

  String get resumeIntro =>
      'Go through your own resume with this next to it. Tick a section when '
      'you have checked it. Nothing here asks you to upload or paste your '
      'resume.';

  String get bulletHeading => 'Check the wording of one line';

  String get bulletIntro =>
      'Type one line from your resume. This compares the wording against a '
      'few fixed patterns. It cannot tell whether the line is true or '
      'relevant, and finding nothing is not a seal of approval.';

  String get bulletLabel => 'One line from your resume';

  String get bulletCheck => 'Check wording';

  String get bulletNothing => 'None of the patterns this looks for were found.';

  String bulletIssue(BulletIssue issue) => switch (issue) {
        BulletIssue.weakOpening =>
          'It opens with a phrase that describes a duty. Try starting with '
              'the verb for what you did: built, ran, wrote, taught.',
        BulletIssue.firstPerson =>
          'It uses "I", "my" or "me". Resume lines usually leave these out.',
        BulletIssue.noMeasure =>
          'It has no number. If you can say how many, how often or how much, '
              'add it. If you cannot, leave it.',
        BulletIssue.tooLong =>
          'It is long. It may be two points; consider splitting it.',
        BulletIssue.tooShort =>
          'It is very short. Say what you did and what came of it.',
      };

  String get bulletKeep => 'Keep this line';

  String get bulletKept => 'Line kept.';

  String get bulletKeptHeading => 'Lines you kept';

  String get bulletFull =>
      'You can keep up to 20 lines. Remove one to keep another.';

  String removeLine(String text) => 'Remove line: $text';

  String get bulletStorageNote =>
      'A line is checked on this device and then forgotten, unless you choose '
      'to keep it. Kept lines are treated like your other answers.';

  // LinkedIn.

  String get linkedInTitle => 'LinkedIn profile guide';

  String get linkedInDescription =>
      'Line your profile up with your resume and the roles you are applying '
      'for.';

  String get linkedInIntro =>
      'Open your own profile and go through it section by section. This app '
      'does not connect to LinkedIn and never sees your profile.';

  String get linkedInDisclaimer =>
      'LinkedIn is a trademark of its owner. This checklist is independent '
      'and is not affiliated with or endorsed by LinkedIn.';

  // Interview.

  String get interviewTitle => 'Interview practice';

  String get interviewDescription =>
      'Common questions, what each one is really asking, and space to build '
      'your own examples.';

  String get interviewIntro =>
      'Pick a question, read what it is for, and note an example from your '
      'own experience. Then say the answer out loud. Practice is saying it, '
      'not writing it.';

  String questionCategory(QuestionCategory category) => switch (category) {
        QuestionCategory.aboutYou => 'About you',
        QuestionCategory.behavioural => 'Examples from your experience',
        QuestionCategory.motivation => 'Why this role',
        QuestionCategory.closing => 'Closing',
      };

  String practisedCount(int done, int total) =>
      '$done of $total questions practised';

  String get practised => 'Practised';

  String get notPractised => 'Not yet practised';

  String openQuestion(String prompt) => 'Open question: $prompt';

  String get interviewPurposeHeading => 'What it is asking';

  String get interviewTipsHeading => 'Things to keep in mind';

  String get interviewExampleHeading => 'Your example';

  String get interviewExampleIntro =>
      'A few words under each heading is enough. They are prompts for '
      'speaking, not a script.';

  String examplePart(ExamplePart part) => switch (part) {
        ExamplePart.situation => 'Situation: where and when',
        ExamplePart.task => 'Task: what needed doing',
        ExamplePart.action => 'Action: what you did',
        ExamplePart.result => 'Result: what came of it',
      };

  String get interviewNotesLabel => 'Your notes for this answer';

  String get markPractised => 'Mark as practised';

  String get markNotPractised => 'Mark as not practised';

  String get backToQuestions => 'Back to the questions';

  String get unknownQuestion => 'That question link is not one we recognise.';

  String get notesStorageNote =>
      'Notes are kept like your other answers: on this device, and saved only '
      'if you turned saving on.';

  // Skills.

  String get skillsTitle => 'Skills plan';

  String get skillsDescription =>
      'Compare what a role asks for with what you can already show, and pick '
      'what to work on.';

  String get skillsIntro =>
      'Choose an occupation, then say where you are with each skill it '
      'commonly asks for. This is your own estimate. Nobody else sees it and '
      'it is not a test.';

  String get skillsChooseOccupation => 'Which occupation?';

  String get skillsChange => 'Choose a different occupation';

  String skillsFor(String occupation) => 'Skills for: $occupation';

  String skillLevel(SkillLevel level) => switch (level) {
        SkillLevel.canShow => 'I can show this',
        SkillLevel.building => 'I am building this',
        SkillLevel.notYet => 'Not yet',
      };

  String skillLevelFor(SkillLevel level, String skill) =>
      '${skillLevel(level)}: $skill';

  String get skillsFocusHeading => 'What to work on first';

  String get skillsFocusNone =>
      'Rate the skills above and the ones to work on will be listed here.';

  String get skillsFocusAll =>
      'You marked every skill as one you can show. The next step is making '
      'sure your resume shows them too.';

  String skillsFocusLine(String skill) =>
      'Pick one small project that would let you show: $skill.';

  String get skillsProjectLabel => 'Your project idea (optional)';

  String skillsRated(int rated, int total) => '$rated of $total skills rated';

  // Progress.

  String get progressTitle => 'Your progress';

  String get progressDescription =>
      'What you have done so far across every tool.';

  String get progressIntro =>
      'A record of what you have done, for your own use. There are no scores '
      'and no streaks, and nothing here measures you.';

  String get progressEmpty =>
      'Nothing yet. Choose a goal on the start page, or open any tool.';

  String get progressQuestions => 'Questions about you';

  String progressQuestionsValue(int answered, int total) =>
      '$answered of $total answered';

  String progressSaved(int count) => switch (count) {
        0 => 'None saved',
        1 => '1 saved',
        _ => '$count saved',
      };

  String progressPlan(String occupation) => 'Plan: $occupation';

  String get open => 'Open';

  String openTool(String tool) => 'Open: $tool';
}
