import 'package:launchpad_domain/launchpad_domain.dart';

/// Plan steps for each kind of route.
///
/// The steps are deliberately small and checkable. They describe what to find
/// out and do, and promise nothing about the result.
List<PlanStep> planTemplateFor(RouteKind kind) => switch (kind) {
      RouteKind.bachelorsDegree => const <PlanStep>[
          PlanStep(
            id: 'list-programmes',
            title: 'List three programmes you could realistically attend',
            detail: 'Include at least one public option near you. Note the '
                'application deadline for each.',
          ),
          PlanStep(
            id: 'check-requirements',
            title: 'Check each programme’s entry requirements',
            detail:
                'Courses, grades, tests and any portfolio or interview. Mark '
                'what you already have.',
          ),
          PlanStep(
            id: 'cost-and-aid',
            title: 'Work out the cost and the aid you can apply for',
            detail: 'Use each school’s own net price calculator rather than '
                'the published tuition figure.',
          ),
          PlanStep(
            id: 'talk-to-someone',
            title: 'Talk to one person doing this work',
            detail:
                'Ask what the first two years were like and what they would '
                'do differently.',
          ),
          PlanStep(
            id: 'experience',
            title: 'Line up one piece of related experience',
            detail: 'An internship, a part-time job, a research project or '
                'volunteering that you can describe on a resume.',
          ),
        ],
      RouteKind.graduateDegree => const <PlanStep>[
          PlanStep(
            id: 'confirm-need',
            title: 'Confirm the degree is required for the roles you want',
            detail: 'Read ten current job postings and note what they actually '
                'ask for.',
          ),
          PlanStep(
            id: 'list-programmes',
            title: 'List programmes and their prerequisites',
            detail: 'Note required courses, tests, experience hours and '
                'deadlines.',
          ),
          PlanStep(
            id: 'cost-and-funding',
            title: 'Compare total cost against funding offered',
            detail: 'Ask each programme what share of students receive '
                'assistantships or scholarships.',
          ),
          PlanStep(
            id: 'references',
            title: 'Ask two people to write references',
            detail: 'Give them your goals and plenty of notice.',
          ),
          PlanStep(
            id: 'talk-to-someone',
            title: 'Talk to a current student or recent graduate',
            detail: 'Ask about workload, placements and what surprised them.',
          ),
        ],
      RouteKind.associateDegree => const <PlanStep>[
          PlanStep(
            id: 'find-programmes',
            title: 'Find accredited programmes at colleges near you',
            detail:
                'For licensed occupations, check the programme is approved by '
                'the state board.',
          ),
          PlanStep(
            id: 'check-prerequisites',
            title: 'Check prerequisites and waiting lists',
            detail:
                'Some programmes need specific courses first or admit once a '
                'year.',
          ),
          PlanStep(
            id: 'cost-and-aid',
            title: 'Work out the cost and apply for aid',
            detail: 'Ask the college’s financial aid office what applies.',
          ),
          PlanStep(
            id: 'transfer',
            title: 'Ask whether the credits transfer',
            detail: 'If a bachelor’s degree is a later possibility, find out '
                'which four-year schools accept this programme’s credits.',
          ),
          PlanStep(
            id: 'talk-to-someone',
            title: 'Talk to one person doing this work',
            detail: 'Ask what a normal week looks like.',
          ),
        ],
      RouteKind.certificate => const <PlanStep>[
          PlanStep(
            id: 'identify-credential',
            title: 'Identify the credential employers near you ask for',
            detail: 'Read ten local job postings and note which certificate or '
                'certification they name.',
          ),
          PlanStep(
            id: 'find-provider',
            title: 'Find a recognised provider',
            detail:
                'Prefer community colleges and bodies that employers in the '
                'postings mention by name.',
          ),
          PlanStep(
            id: 'cost-and-time',
            title: 'Check the cost, schedule and exam fee',
            detail: 'Ask whether workforce funding or employer sponsorship is '
                'available.',
          ),
          PlanStep(
            id: 'enrol',
            title: 'Enrol and set a date for the exam or completion',
            detail: 'A date on the calendar makes the rest of the plan real.',
          ),
          PlanStep(
            id: 'talk-to-someone',
            title: 'Talk to one person who holds the credential',
            detail: 'Ask how they found their first job with it.',
          ),
        ],
      RouteKind.apprenticeship => const <PlanStep>[
          PlanStep(
            id: 'find-sponsors',
            title: 'Find apprenticeship sponsors in your area',
            detail: 'Look at union locals, contractor associations and the '
                'official apprenticeship finder for your state.',
          ),
          PlanStep(
            id: 'check-requirements',
            title: 'Check the entry requirements and application window',
            detail:
                'Many programmes take applications only at certain times of '
                'year and include an aptitude test.',
          ),
          PlanStep(
            id: 'prepare-test',
            title: 'Prepare for the aptitude test',
            detail: 'Usually practical mathematics and reading comprehension.',
          ),
          PlanStep(
            id: 'apply',
            title: 'Apply to more than one programme',
            detail: 'Places are limited and timing varies between sponsors.',
          ),
          PlanStep(
            id: 'talk-to-someone',
            title: 'Talk to a current apprentice or journeyworker',
            detail: 'Ask what the first year is like.',
          ),
        ],
      RouteKind.employerTraining => const <PlanStep>[
          PlanStep(
            id: 'find-employers',
            title: 'List employers near you that train new staff',
            detail:
                'Look for postings that say training is provided or that ask '
                'for no prior experience.',
          ),
          PlanStep(
            id: 'match-skills',
            title: 'Match what you have to what the postings ask for',
            detail:
                'Customer service, reliability and careful record keeping all '
                'count. Note an example of each.',
          ),
          PlanStep(
            id: 'resume',
            title: 'Write a resume aimed at this role',
            detail: 'Lead with the examples from the previous step.',
          ),
          PlanStep(
            id: 'apply',
            title: 'Apply to five employers and note the dates',
            detail: 'Follow up once, about a week after each application.',
          ),
          PlanStep(
            id: 'talk-to-someone',
            title: 'Talk to one person doing this work',
            detail: 'Ask how they were trained and what helped.',
          ),
        ],
      RouteKind.selfDirected => const <PlanStep>[
          PlanStep(
            id: 'pick-focus',
            title: 'Pick one narrow area to get good at first',
            detail: 'Breadth comes later. Depth is what a portfolio shows.',
          ),
          PlanStep(
            id: 'choose-course',
            title: 'Choose one structured course and finish it',
            detail: 'One completed course is worth more than five started.',
          ),
          PlanStep(
            id: 'build-projects',
            title: 'Build two projects that solve a real problem',
            detail:
                'Write a short account of each: the problem, what you did and '
                'what you would change.',
          ),
          PlanStep(
            id: 'get-feedback',
            title: 'Ask someone working in the field to review one project',
            detail: 'Act on what they say and note what changed.',
          ),
          PlanStep(
            id: 'publish',
            title: 'Put the work somewhere an employer can see it',
            detail: 'A simple page with the projects and the write-ups.',
          ),
        ],
    };
