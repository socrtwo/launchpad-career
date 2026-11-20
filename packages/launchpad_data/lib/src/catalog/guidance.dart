import 'package:launchpad_domain/launchpad_domain.dart';

import 'occupations.dart';

/// The content of the employment tools.
///
/// Like the occupation catalogue, this was drafted with AI assistance and has
/// not yet been reviewed by a careers adviser, so it carries the same label
/// ([draftContentEvidence]). The tests in this package hold it to the same
/// rules: no outcome promises and no unsourced figures.
const List<GuideItem> bundledResumeSections = <GuideItem>[
  GuideItem(
    id: 'contact',
    title: 'Contact details',
    points: <String>[
      'Name, phone number, a plain email address and your city are enough.',
      'Leave out your full street address, date of birth and photo unless the '
          'country you are applying in expects them.',
      'If you include a link, check that it opens and shows what you want '
          'seen.',
    ],
  ),
  GuideItem(
    id: 'education',
    title: 'Education',
    points: <String>[
      'Put it first if you are a student or graduated recently, lower once '
          'you have relevant experience.',
      'Give the qualification, the institution and the date you finished or '
          'expect to finish.',
      'Add relevant courses or a result only where the posting cares about '
          'them.',
    ],
  ),
  GuideItem(
    id: 'experience',
    title: 'Experience',
    points: <String>[
      'Include part-time, seasonal, volunteer and family work. All of it is '
          'experience.',
      'Start each line with what you did, then how much or how many, then '
          'what changed.',
      'Use the words the posting uses for the same thing, where they are true '
          'of you.',
    ],
  ),
  GuideItem(
    id: 'projects',
    title: 'Projects',
    points: <String>[
      'Course, personal and club projects count, especially where paid '
          'experience is thin.',
      'Say what the project was for, what you did yourself and what came of '
          'it.',
      'Link to the work if it can be seen.',
    ],
  ),
  GuideItem(
    id: 'skills',
    title: 'Skills',
    points: <String>[
      'List tools, languages and methods you could be asked to use on day '
          'one.',
      'Group them, and leave out anything you would not want to be '
          'questioned on.',
      'Show the important ones in your experience lines as well, not only in '
          'this list.',
    ],
  ),
  GuideItem(
    id: 'layout',
    title: 'Layout and checks',
    points: <String>[
      'One page is usual early in a career. Use a plain, single-column layout '
          'that software can read.',
      'Keep dates, tenses and punctuation consistent from line to line.',
      'Read it aloud once, then ask someone else to read it.',
    ],
  ),
];

const List<GuideItem> bundledLinkedInSections = <GuideItem>[
  GuideItem(
    id: 'headline',
    title: 'Headline',
    points: <String>[
      'Say what you do or are studying and the kind of role you are looking '
          'for.',
      'Use the job titles that appear in the postings you are reading.',
    ],
  ),
  GuideItem(
    id: 'about',
    title: 'About',
    points: <String>[
      'Three or four short sentences: what you are working towards, what you '
          'have done so far, and what you are looking for now.',
      'Write it the way you would say it to someone you had just met.',
    ],
  ),
  GuideItem(
    id: 'experience',
    title: 'Experience',
    points: <String>[
      'Match your resume: same roles, same dates, same claims.',
      'A sentence or two per role is enough. You do not need every line of '
          'the resume.',
    ],
  ),
  GuideItem(
    id: 'education',
    title: 'Education',
    points: <String>[
      'List your institution so that classmates and alumni can find you.',
      'Add clubs or societies you were active in.',
    ],
  ),
  GuideItem(
    id: 'skills',
    title: 'Skills',
    points: <String>[
      'Add the skills named in postings for your target roles that you '
          'really have.',
      'Put the most relevant ones at the top.',
    ],
  ),
  GuideItem(
    id: 'evidence',
    title: 'Work you can show',
    points: <String>[
      'Feature one or two pieces of work: a project, a write-up or a '
          'presentation.',
      'Say in a line what each one is and what your part was.',
    ],
  ),
  GuideItem(
    id: 'settings',
    title: 'Settings and privacy',
    points: <String>[
      'Check what your public profile shows to people who are not signed in.',
      'Choose who can see that you are open to work. Your current employer '
          'may be able to.',
      'Use a web address for your profile that contains your name.',
    ],
  ),
];

const List<InterviewQuestion> bundledInterviewQuestions = <InterviewQuestion>[
  InterviewQuestion(
    id: 'about-you',
    category: QuestionCategory.aboutYou,
    prompt: 'Tell me about yourself.',
    purpose:
        'A short account of where you are now, how you got here and why you '
        'are in this room. It sets the direction of the interview.',
    tips: <String>[
      'Aim for about a minute: present, past, then why this role.',
      'Leave out your life story. Choose what is relevant to this job.',
    ],
    usesExample: false,
  ),
  InterviewQuestion(
    id: 'strength',
    category: QuestionCategory.aboutYou,
    prompt: 'What is one of your strengths?',
    purpose: 'Whether you know what you are good at and can back it up with '
        'something that happened.',
    tips: <String>[
      'Name one strength the role needs, then give the example.',
      'An example beats an adjective.',
    ],
  ),
  InterviewQuestion(
    id: 'weakness',
    category: QuestionCategory.aboutYou,
    prompt: 'What is something you are working to improve?',
    purpose: 'Whether you can look at your own work honestly and do something '
        'about what you see.',
    tips: <String>[
      'Choose something real that is not central to the job.',
      'Say what you are doing about it and what has changed.',
    ],
  ),
  InterviewQuestion(
    id: 'challenge',
    category: QuestionCategory.behavioural,
    prompt: 'Tell me about a time you dealt with a difficult problem.',
    purpose: 'How you think when something does not go to plan.',
    tips: <String>[
      'Spend most of the answer on what you did, not on the problem.',
      'Say what you would do differently now.',
    ],
  ),
  InterviewQuestion(
    id: 'teamwork',
    category: QuestionCategory.behavioural,
    prompt: 'Tell me about a time you worked as part of a team.',
    purpose: 'What you are like to work with, and what you contribute.',
    tips: <String>[
      'Say "I" for your part and "we" for the result.',
      'Pick an example where something had to be sorted out between people.',
    ],
  ),
  InterviewQuestion(
    id: 'disagreement',
    category: QuestionCategory.behavioural,
    prompt: 'Tell me about a time you disagreed with someone you worked with.',
    purpose: 'Whether you can disagree and still get the work done with that '
        'person.',
    tips: <String>[
      'Describe the other person’s view fairly.',
      'End with what happened to the working relationship.',
    ],
  ),
  InterviewQuestion(
    id: 'mistake',
    category: QuestionCategory.behavioural,
    prompt: 'Tell me about a mistake you made and what you did about it.',
    purpose: 'Whether you own mistakes and learn from them.',
    tips: <String>[
      'Choose a real mistake with a limited cost.',
      'Say how you found it, what you did, and what you changed afterwards.',
    ],
  ),
  InterviewQuestion(
    id: 'deadline',
    category: QuestionCategory.behavioural,
    prompt: 'Tell me about a time you had too much to do and not enough time.',
    purpose: 'How you decide what matters when you cannot do everything.',
    tips: <String>[
      'Say how you chose what to do first and who you told.',
      'It is fine if not everything got done. Say what you let go and why.',
    ],
  ),
  InterviewQuestion(
    id: 'initiative',
    category: QuestionCategory.behavioural,
    prompt: 'Tell me about something you did without being asked.',
    purpose: 'Whether you notice what needs doing and act on it.',
    tips: <String>[
      'Small examples work if the effect was real.',
      'Say what you noticed and why you decided to act.',
    ],
  ),
  InterviewQuestion(
    id: 'why-role',
    category: QuestionCategory.motivation,
    prompt: 'Why do you want this role?',
    purpose: 'Whether you understand the job and have a reason for wanting it.',
    tips: <String>[
      'Connect one thing the role involves to one thing you have done.',
      'Use what you learned from the posting and from anyone you spoke to.',
    ],
    usesExample: false,
  ),
  InterviewQuestion(
    id: 'why-us',
    category: QuestionCategory.motivation,
    prompt: 'Why do you want to work here?',
    purpose: 'Whether you have looked into the organisation.',
    tips: <String>[
      'Name something specific: a product, a project, how they work.',
      'Say why that matters to you in particular.',
    ],
    usesExample: false,
  ),
  InterviewQuestion(
    id: 'questions-for-us',
    category: QuestionCategory.closing,
    prompt: 'Do you have any questions for us?',
    purpose:
        'Whether you are thinking seriously about doing the job. It is also '
        'your chance to find out if you want it.',
    tips: <String>[
      'Prepare three. Ask what a good first few months looks like.',
      'Ask what the interviewer finds hard about the work.',
    ],
    usesExample: false,
  ),
];

/// A week of job-search tasks sized to the time a person has.
///
/// The counts split the time; they are not a benchmark and the interface says
/// so. Applications are kept deliberately few, because a tailored application
/// takes real time.
List<SearchTask> searchWeekFor(SearchHours hours) {
  final (applications, conversations) = switch (hours) {
    SearchHours.light => (2, 1),
    SearchHours.steady => (4, 2),
    SearchHours.intensive => (6, 3),
  };
  return <SearchTask>[
    const SearchTask(
      id: 'shortlist',
      title: 'Add new postings to your shortlist',
      detail: 'Look in the same few places each week and keep only roles you '
          'would accept.',
    ),
    SearchTask(
      id: 'apply',
      title: 'Send tailored applications',
      detail: 'Adjust your resume to each posting’s wording where it is true '
          'of you. Note the date you applied.',
      count: applications,
    ),
    SearchTask(
      id: 'talk',
      title: 'Have conversations with people doing the work',
      detail:
          'Classmates a year ahead, alumni, former colleagues. Ask about the '
          'work, not for a job.',
      count: conversations,
    ),
    const SearchTask(
      id: 'follow-up',
      title: 'Follow up on last week’s applications',
      detail: 'One short, polite message for each. Then let it rest.',
    ),
    const SearchTask(
      id: 'review',
      title: 'Note what got a response',
      detail:
          'Which kinds of role and which version of your resume drew replies. '
          'Change one thing next week.',
    ),
  ];
}

/// The employment-tool content bundled with the app.
class InMemoryGuidanceRepository implements GuidanceRepository {
  const InMemoryGuidanceRepository();

  @override
  Evidence get evidence => draftContentEvidence;

  @override
  Future<List<GuideItem>> resumeSections() async => bundledResumeSections;

  @override
  Future<List<GuideItem>> linkedInSections() async => bundledLinkedInSections;

  @override
  Future<List<InterviewQuestion>> interviewQuestions() async =>
      bundledInterviewQuestions;

  @override
  Future<List<SearchTask>> searchWeek(SearchHours hours) async =>
      searchWeekFor(hours);
}
