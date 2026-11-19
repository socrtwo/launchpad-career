import 'package:launchpad_domain/launchpad_domain.dart';

/// Where the occupation text below came from.
///
/// It was drafted with AI assistance and has not yet been reviewed by a
/// careers adviser, so it is labelled as generated guidance and the interface
/// says so on every occupation. When an editor has reviewed an entry, that
/// entry's evidence changes to [EvidenceKind.editorial] with the review date.
/// See `docs/product/content-review.md`.
final Evidence draftContentEvidence = Evidence(
  kind: EvidenceKind.generatedGuidance,
  source: 'Launchpad Career draft content',
  asOf: DateTime.utc(2026, 11),
  confidence: ConfidenceBand.moderate,
);

const String _licenceNote =
    'Licensing rules are set by each state, so check the board for the state '
    'you plan to work in.';

EntryRoute _bachelors(String description) => EntryRoute(
      kind: RouteKind.bachelorsDegree,
      title: "Bachelor's degree",
      description: description,
    );

EntryRoute _graduate(String title, String description) => EntryRoute(
      kind: RouteKind.graduateDegree,
      title: title,
      description: description,
    );

EntryRoute _associate(String description) => EntryRoute(
      kind: RouteKind.associateDegree,
      title: 'Associate degree',
      description: description,
    );

EntryRoute _certificate(String title, String description) => EntryRoute(
      kind: RouteKind.certificate,
      title: title,
      description: description,
    );

EntryRoute _apprenticeship(String description) => EntryRoute(
      kind: RouteKind.apprenticeship,
      title: 'Registered apprenticeship',
      description: description,
    );

EntryRoute _employer(String title, String description) => EntryRoute(
      kind: RouteKind.employerTraining,
      title: title,
      description: description,
    );

EntryRoute _selfDirected(String title, String description) => EntryRoute(
      kind: RouteKind.selfDirected,
      title: title,
      description: description,
    );

/// The bundled occupation catalogue.
///
/// Copy lives here, not in widgets, so it can be reviewed as a block against
/// `docs/product/tone-and-language.md` and replaced by a content-management
/// service without touching layout code. Rules the tests in this package
/// enforce: no outcome promises, no figures (pay and employment come only
/// from the labour-market snapshot, with a source and date), at least one
/// route per occupation, and unique ids and SOC codes.
final List<Occupation> bundledOccupations = <Occupation>[
  Occupation(
    id: 'software-developer',
    socCode: '15-1252',
    socTitle: 'Software Developers',
    title: 'Software developer',
    summary: 'Designs, writes and maintains the programs that run on phones, '
        'websites and business systems.',
    tasks: const <String>[
      'Turn a description of what people need into working code',
      'Test changes and fix what breaks',
      'Review other developers’ work and explain your own',
    ],
    interests: const <InterestArea>{
      InterestArea.technology,
      InterestArea.data,
    },
    skills: const <String>[
      'Programming in at least one language',
      'Version control',
      'Testing and debugging',
      'Explaining technical work in writing',
    ],
    routes: <EntryRoute>[
      _bachelors(
        'Computer science, software engineering or a related subject. The '
        'route most job postings name.',
      ),
      _associate(
        'A two-year programme in programming or software development, often '
        'with credits that transfer towards a bachelor’s degree.',
      ),
      _selfDirected(
        'Portfolio of your own projects',
        'Courses or a bootcamp plus projects you can show. Employers vary '
            'widely in how they treat this route, and it leans heavily on what '
            'you have built.',
      ),
    ],
    evidence: draftContentEvidence,
    flexibleArrangementsCommon: true,
    changeNote:
        'AI coding tools are changing what entry-level work in this field '
        'looks like, and published figures lag that change. Treat recent '
        'history as a rough guide rather than a forecast.',
  ),
  Occupation(
    id: 'data-scientist',
    socCode: '15-2051',
    socTitle: 'Data Scientists',
    title: 'Data scientist',
    summary:
        'Uses statistics and programming to find patterns in data and explain '
        'what they mean for a decision.',
    tasks: const <String>[
      'Clean and combine data from different sources',
      'Build and check statistical models',
      'Present findings to people who do not work with data',
    ],
    interests: const <InterestArea>{
      InterestArea.data,
      InterestArea.science,
      InterestArea.technology,
    },
    skills: const <String>[
      'Statistics',
      'Programming for data analysis',
      'Database queries',
      'Presenting findings clearly',
    ],
    routes: <EntryRoute>[
      _bachelors(
        'Statistics, mathematics, computer science or a subject with a strong '
        'quantitative core.',
      ),
      _graduate(
        'Master’s degree',
        'Many postings ask for a master’s in data science, statistics or '
            'a related field, particularly for modelling-heavy roles.',
      ),
    ],
    evidence: draftContentEvidence,
    flexibleArrangementsCommon: true,
    changeNote: 'Tools in this field change quickly. The statistical reasoning '
        'underneath them changes slowly and is the part worth investing in.',
  ),
  Occupation(
    id: 'information-security-analyst',
    socCode: '15-1212',
    socTitle: 'Information Security Analysts',
    title: 'Information security analyst',
    summary: 'Protects an organisation’s computer systems and data, and '
        'investigates when something goes wrong.',
    tasks: const <String>[
      'Monitor systems for signs of intrusion',
      'Test defences and fix the weaknesses found',
      'Write and practise the plan for responding to an incident',
    ],
    interests: const <InterestArea>{
      InterestArea.technology,
      InterestArea.advocacy,
    },
    skills: const <String>[
      'Networking fundamentals',
      'Operating systems administration',
      'Risk assessment',
      'Clear incident reporting',
    ],
    routes: <EntryRoute>[
      _bachelors(
        'Cybersecurity, computer science or information systems.',
      ),
      _certificate(
        'Industry certification plus support experience',
        'A recognised security certification added to time spent in an IT '
            'support or systems administration job. A common way in for people '
            'already working in IT.',
      ),
    ],
    evidence: draftContentEvidence,
    flexibleArrangementsCommon: true,
  ),
  Occupation(
    id: 'computer-support-specialist',
    socCode: '15-1232',
    socTitle: 'Computer User Support Specialists',
    title: 'Computer support specialist',
    summary:
        'Helps people and organisations keep their computers, software and '
        'accounts working.',
    tasks: const <String>[
      'Diagnose problems from a description that is often incomplete',
      'Set up equipment, accounts and software',
      'Write down fixes so the next person does not start from nothing',
    ],
    interests: const <InterestArea>{
      InterestArea.technology,
      InterestArea.teaching,
    },
    skills: const <String>[
      'Troubleshooting hardware and software',
      'Explaining technical steps patiently',
      'Operating systems basics',
      'Keeping clear records',
    ],
    routes: <EntryRoute>[
      _certificate(
        'Entry-level IT certification',
        'A short course ending in an industry certification in computer '
            'support fundamentals.',
      ),
      _associate(
        'A two-year programme in information technology or networking.',
      ),
      _employer(
        'Help-desk training on the job',
        'Some employers hire for customer-service ability and train the '
            'technical side themselves.',
      ),
    ],
    evidence: draftContentEvidence,
  ),
  Occupation(
    id: 'registered-nurse',
    socCode: '29-1141',
    socTitle: 'Registered Nurses',
    title: 'Registered nurse',
    summary:
        'Assesses patients, gives treatment and medication, and coordinates '
        'care with doctors and families.',
    tasks: const <String>[
      'Monitor patients and record how they are doing',
      'Give medication and carry out treatments',
      'Explain conditions and care plans to patients and families',
    ],
    interests: const <InterestArea>{
      InterestArea.caring,
      InterestArea.science,
    },
    skills: const <String>[
      'Clinical assessment',
      'Medication safety',
      'Calm communication under pressure',
      'Accurate record keeping',
    ],
    routes: <EntryRoute>[
      _associate(
        'An associate degree in nursing, then the national licensing exam for '
        'registered nurses. $_licenceNote',
      ),
      _bachelors(
        'A bachelor of science in nursing, then the same licensing exam. Some '
        'hospitals prefer or require this degree.',
      ),
    ],
    evidence: draftContentEvidence,
    handsOn: true,
  ),
  Occupation(
    id: 'licensed-practical-nurse',
    socCode: '29-2061',
    socTitle: 'Licensed Practical and Licensed Vocational Nurses',
    title: 'Licensed practical nurse',
    summary:
        'Provides basic nursing care under the direction of registered nurses '
        'and doctors, often in long-term care and clinics.',
    tasks: const <String>[
      'Check vital signs and report changes',
      'Help patients with daily care and comfort',
      'Give some medications and treatments, depending on state rules',
    ],
    interests: const <InterestArea>{InterestArea.caring},
    skills: const <String>[
      'Basic patient care',
      'Observation and reporting',
      'Patience with people who are unwell',
      'Accurate record keeping',
    ],
    routes: <EntryRoute>[
      _certificate(
        'Practical nursing programme',
        'A state-approved certificate programme, commonly at a community or '
            'technical college, then the licensing exam for practical nurses. '
            '$_licenceNote',
      ),
    ],
    evidence: draftContentEvidence,
    handsOn: true,
  ),
  Occupation(
    id: 'medical-assistant',
    socCode: '31-9092',
    socTitle: 'Medical Assistants',
    title: 'Medical assistant',
    summary:
        'Keeps a clinic running: prepares patients, takes basic measurements '
        'and handles scheduling and records.',
    tasks: const <String>[
      'Bring patients in and record their history and vital signs',
      'Prepare rooms and assist during examinations',
      'Schedule appointments and update records',
    ],
    interests: const <InterestArea>{
      InterestArea.caring,
      InterestArea.organising,
    },
    skills: const <String>[
      'Taking vital signs',
      'Medical records software',
      'Putting patients at ease',
      'Managing a busy schedule',
    ],
    routes: <EntryRoute>[
      _certificate(
        'Medical assisting certificate',
        'A certificate programme at a community or technical college.',
      ),
      _employer(
        'Training in the clinic',
        'Some clinics hire people with a high school diploma and train them '
            'on the job.',
      ),
    ],
    evidence: draftContentEvidence,
    handsOn: true,
  ),
  Occupation(
    id: 'dental-hygienist',
    socCode: '29-1292',
    socTitle: 'Dental Hygienists',
    title: 'Dental hygienist',
    summary:
        'Cleans teeth, checks for signs of oral disease and teaches patients '
        'how to look after their teeth and gums.',
    tasks: const <String>[
      'Clean and examine patients’ teeth and gums',
      'Take dental X-rays',
      'Show patients how to care for their teeth',
    ],
    interests: const <InterestArea>{
      InterestArea.caring,
      InterestArea.teaching,
    },
    skills: const <String>[
      'Fine manual dexterity',
      'Infection control',
      'Explaining care to patients',
      'Attention to detail',
    ],
    routes: <EntryRoute>[
      _associate(
        'An accredited associate degree in dental hygiene, then a licence. '
        '$_licenceNote',
      ),
    ],
    evidence: draftContentEvidence,
    handsOn: true,
    flexibleArrangementsCommon: true,
  ),
  Occupation(
    id: 'physical-therapist',
    socCode: '29-1123',
    socTitle: 'Physical Therapists',
    title: 'Physical therapist',
    summary:
        'Helps people recover movement and manage pain after injury, illness '
        'or surgery.',
    tasks: const <String>[
      'Assess how a patient moves and what limits them',
      'Design and adjust an exercise and treatment plan',
      'Teach patients what to do between appointments',
    ],
    interests: const <InterestArea>{
      InterestArea.caring,
      InterestArea.science,
      InterestArea.teaching,
    },
    skills: const <String>[
      'Anatomy and movement science',
      'Hands-on treatment techniques',
      'Motivating people through slow progress',
      'Clinical documentation',
    ],
    routes: <EntryRoute>[
      _graduate(
        'Doctor of physical therapy',
        'A doctoral programme entered after a bachelor’s degree, then a '
            'licence. There is no shorter route to this occupation; physical '
            'therapist assistant is a related one that starts from an associate '
            'degree.',
      ),
    ],
    evidence: draftContentEvidence,
    handsOn: true,
  ),
  Occupation(
    id: 'elementary-school-teacher',
    socCode: '25-2021',
    socTitle: 'Elementary School Teachers, Except Special Education',
    title: 'Elementary school teacher',
    summary:
        'Teaches young children reading, mathematics and other subjects, and '
        'helps them learn how to learn.',
    tasks: const <String>[
      'Plan and teach lessons across several subjects',
      'Assess how each child is doing and adjust',
      'Talk with families about progress',
    ],
    interests: const <InterestArea>{
      InterestArea.teaching,
      InterestArea.caring,
      InterestArea.creative,
    },
    skills: const <String>[
      'Lesson planning',
      'Classroom management',
      'Explaining one idea several ways',
      'Working with families',
    ],
    routes: <EntryRoute>[
      _bachelors(
        'A bachelor’s degree with a teacher preparation programme, then '
        'a state teaching licence. $_licenceNote',
      ),
      _certificate(
        'Alternative certification',
        'For people who already hold a bachelor’s degree in another '
            'subject: a state-approved programme that leads to a licence, often '
            'while teaching.',
      ),
    ],
    evidence: draftContentEvidence,
  ),
  Occupation(
    id: 'school-and-career-counselor',
    socCode: '21-1012',
    socTitle: 'Educational, Guidance, and Career Counselors and Advisors',
    title: 'School or career counselor',
    summary: 'Helps students and adults plan their education and work, and '
        'connects them with the support they need.',
    tasks: const <String>[
      'Meet with people to talk through choices about study and work',
      'Help with applications, schedules and plans',
      'Refer people to other services when a need is outside your role',
    ],
    interests: const <InterestArea>{
      InterestArea.teaching,
      InterestArea.advocacy,
      InterestArea.caring,
    },
    skills: const <String>[
      'Listening without steering',
      'Knowledge of education and training routes',
      'Keeping confidences',
      'Clear written plans',
    ],
    routes: <EntryRoute>[
      _graduate(
        'Master’s degree',
        'A master’s in school counseling or a related field; school '
            'roles also need a state credential. Some advising roles in colleges '
            'and workforce agencies hire with a bachelor’s degree.',
      ),
    ],
    evidence: draftContentEvidence,
  ),
  Occupation(
    id: 'social-worker',
    socCode: '21-1021',
    socTitle: 'Child, Family, and School Social Workers',
    title: 'Child, family or school social worker',
    summary:
        'Supports children and families through difficult circumstances and '
        'helps them reach services.',
    tasks: const <String>[
      'Assess what a family needs and what is already in place',
      'Arrange services and follow up on whether they are working',
      'Keep careful records and work with schools and courts',
    ],
    interests: const <InterestArea>{
      InterestArea.caring,
      InterestArea.advocacy,
    },
    skills: const <String>[
      'Interviewing with care',
      'Knowledge of local services',
      'Case documentation',
      'Staying steady in hard conversations',
    ],
    routes: <EntryRoute>[
      _bachelors(
        'A bachelor’s degree in social work for most entry-level roles.',
      ),
      _graduate(
        'Master of social work',
        'Needed for clinical roles and for many school positions, together '
            'with a state licence.',
      ),
    ],
    evidence: draftContentEvidence,
  ),
  Occupation(
    id: 'accountant',
    socCode: '13-2011',
    socTitle: 'Accountants and Auditors',
    title: 'Accountant or auditor',
    summary:
        'Prepares and examines financial records so that they are accurate '
        'and follow the rules.',
    tasks: const <String>[
      'Prepare financial statements and tax filings',
      'Check records for errors and unusual entries',
      'Explain what the numbers mean to managers or clients',
    ],
    interests: const <InterestArea>{
      InterestArea.data,
      InterestArea.organising,
    },
    skills: const <String>[
      'Accounting principles',
      'Spreadsheets',
      'Attention to detail',
      'Explaining figures plainly',
    ],
    routes: <EntryRoute>[
      _bachelors(
        'Accounting or a related subject. Becoming a certified public '
        'accountant adds an exam and further requirements set by each state.',
      ),
      _associate(
        'An associate degree in accounting can lead to junior accounting '
        'roles, with credits that often transfer towards a bachelor’s.',
      ),
    ],
    evidence: draftContentEvidence,
    flexibleArrangementsCommon: true,
  ),
  Occupation(
    id: 'bookkeeper',
    socCode: '43-3031',
    socTitle: 'Bookkeeping, Accounting, and Auditing Clerks',
    title: 'Bookkeeper',
    summary: 'Records an organisation’s day-to-day money in and out and keeps '
        'its accounts in order.',
    tasks: const <String>[
      'Enter invoices, payments and receipts',
      'Reconcile accounts against bank records',
      'Produce routine reports for the owner or accountant',
    ],
    interests: const <InterestArea>{
      InterestArea.data,
      InterestArea.organising,
    },
    skills: const <String>[
      'Accounting software',
      'Spreadsheets',
      'Accuracy with numbers',
      'Organised record keeping',
    ],
    routes: <EntryRoute>[
      _certificate(
        'Bookkeeping certificate',
        'A short programme at a community college or an industry '
            'certification in bookkeeping.',
      ),
      _employer(
        'Training on the job',
        'Many employers train people who are careful with numbers and '
            'comfortable with software.',
      ),
    ],
    evidence: draftContentEvidence,
    flexibleArrangementsCommon: true,
    changeNote:
        'Accounting software now automates much routine data entry. The work '
        'is shifting towards checking, exceptions and advising.',
  ),
  Occupation(
    id: 'market-research-analyst',
    socCode: '13-1161',
    socTitle: 'Market Research Analysts and Marketing Specialists',
    title: 'Market research analyst',
    summary:
        'Studies what people buy and why, so an organisation can decide what '
        'to offer and how to describe it.',
    tasks: const <String>[
      'Design surveys and gather data on customers and competitors',
      'Analyse the results and look for patterns',
      'Turn findings into recommendations people can act on',
    ],
    interests: const <InterestArea>{
      InterestArea.data,
      InterestArea.creative,
      InterestArea.advocacy,
    },
    skills: const <String>[
      'Survey design',
      'Data analysis',
      'Writing clear reports',
      'Presenting to non-specialists',
    ],
    routes: <EntryRoute>[
      _bachelors(
        'Marketing, business, statistics, psychology or a related subject.',
      ),
    ],
    evidence: draftContentEvidence,
    flexibleArrangementsCommon: true,
  ),
  Occupation(
    id: 'human-resources-specialist',
    socCode: '13-1071',
    socTitle: 'Human Resources Specialists',
    title: 'Human resources specialist',
    summary: 'Recruits and supports an organisation’s staff, and helps apply '
        'its employment policies fairly.',
    tasks: const <String>[
      'Advertise jobs and screen and interview applicants',
      'Answer staff questions about pay, benefits and policies',
      'Keep employment records accurate and confidential',
    ],
    interests: const <InterestArea>{
      InterestArea.organising,
      InterestArea.advocacy,
    },
    skills: const <String>[
      'Interviewing',
      'Knowledge of employment rules',
      'Discretion with personal information',
      'Clear written communication',
    ],
    routes: <EntryRoute>[
      _bachelors(
        'Human resources, business, psychology or a related subject.',
      ),
      _employer(
        'Moving across from an administrative role',
        'Some people move into human resources from office or recruiting '
            'support roles, often adding a professional certificate.',
      ),
    ],
    evidence: draftContentEvidence,
  ),
  Occupation(
    id: 'project-management-specialist',
    socCode: '13-1082',
    socTitle: 'Project Management Specialists',
    title: 'Project management specialist',
    summary:
        'Plans a piece of work, keeps it on schedule and budget, and keeps '
        'everyone involved informed.',
    tasks: const <String>[
      'Break a goal into tasks, owners and dates',
      'Track progress and deal with what slips',
      'Report honestly on status and risks',
    ],
    interests: const <InterestArea>{InterestArea.organising},
    skills: const <String>[
      'Planning and scheduling',
      'Budget tracking',
      'Running useful meetings',
      'Managing competing requests',
    ],
    routes: <EntryRoute>[
      _bachelors(
        'A degree in business or in the field the projects are in, such as '
        'construction, engineering or information technology.',
      ),
      _certificate(
        'Project management certification',
        'A professional certification added to experience coordinating work '
            'in any field.',
      ),
    ],
    evidence: draftContentEvidence,
    flexibleArrangementsCommon: true,
  ),
  Occupation(
    id: 'graphic-designer',
    socCode: '27-1024',
    socTitle: 'Graphic Designers',
    title: 'Graphic designer',
    summary: 'Creates visual material - layouts, logos, illustrations - that '
        'communicates an idea clearly.',
    tasks: const <String>[
      'Turn a brief into concepts and then finished artwork',
      'Choose type, colour and images that fit the message',
      'Revise work in response to feedback',
    ],
    interests: const <InterestArea>{
      InterestArea.creative,
      InterestArea.technology,
    },
    skills: const <String>[
      'Layout and typography',
      'Design software',
      'Taking and using feedback',
      'Presenting your ideas',
    ],
    routes: <EntryRoute>[
      _bachelors('Graphic design or a related art and design subject.'),
      _associate(
        'A two-year design programme focused on building a portfolio.',
      ),
      _selfDirected(
        'Portfolio of your own work',
        'Courses plus real or self-set projects. In this field the portfolio '
            'is examined more closely than the credential.',
      ),
    ],
    evidence: draftContentEvidence,
    flexibleArrangementsCommon: true,
    changeNote:
        'Image-generating software is changing how routine design work is '
        'produced. What that does to entry-level roles is not yet clear in '
        'published figures.',
  ),
  Occupation(
    id: 'technical-writer',
    socCode: '27-3042',
    socTitle: 'Technical Writers',
    title: 'Technical writer',
    summary:
        'Writes the instructions, guides and reference material that explain '
        'how a product or process works.',
    tasks: const <String>[
      'Learn how something works by using it and asking the people who built it',
      'Write and organise instructions for a specific reader',
      'Keep documents accurate as the product changes',
    ],
    interests: const <InterestArea>{
      InterestArea.creative,
      InterestArea.teaching,
      InterestArea.technology,
    },
    skills: const <String>[
      'Plain, precise writing',
      'Interviewing subject experts',
      'Structuring information',
      'Learning new tools quickly',
    ],
    routes: <EntryRoute>[
      _bachelors(
        'English, communications, or a technical subject combined with '
        'strong writing.',
      ),
      _selfDirected(
        'Writing samples',
        'A set of documentation samples, often built by documenting '
            'open-source projects or tools you already use.',
      ),
    ],
    evidence: draftContentEvidence,
    flexibleArrangementsCommon: true,
  ),
  Occupation(
    id: 'civil-engineer',
    socCode: '17-2051',
    socTitle: 'Civil Engineers',
    title: 'Civil engineer',
    summary:
        'Designs and oversees roads, bridges, water systems and buildings so '
        'that they are safe and last.',
    tasks: const <String>[
      'Analyse sites, loads and materials',
      'Produce designs and check them against codes',
      'Visit sites and solve problems as construction proceeds',
    ],
    interests: const <InterestArea>{
      InterestArea.building,
      InterestArea.science,
      InterestArea.outdoors,
    },
    skills: const <String>[
      'Engineering mathematics',
      'Design and drafting software',
      'Reading and applying codes',
      'Coordinating with contractors',
    ],
    routes: <EntryRoute>[
      _bachelors(
        'An accredited civil engineering degree. A professional engineer '
        'licence, earned later through exams and supervised experience, is '
        'needed to sign off public work.',
      ),
    ],
    evidence: draftContentEvidence,
  ),
  Occupation(
    id: 'electrician',
    socCode: '47-2111',
    socTitle: 'Electricians',
    title: 'Electrician',
    summary: 'Installs, maintains and repairs wiring and electrical systems in '
        'homes, businesses and industry.',
    tasks: const <String>[
      'Read plans and install wiring, panels and fixtures',
      'Find and fix faults',
      'Work to electrical codes and safety rules',
    ],
    interests: const <InterestArea>{
      InterestArea.building,
      InterestArea.outdoors,
    },
    skills: const <String>[
      'Reading electrical plans',
      'Safe working practice',
      'Fault finding',
      'Practical mathematics',
    ],
    routes: <EntryRoute>[
      _apprenticeship(
        'A multi-year apprenticeship that combines paid work under a licensed '
        'electrician with classroom instruction, ending in a licence. '
        '$_licenceNote',
      ),
      _certificate(
        'Trade school programme',
        'A technical school programme that covers the classroom part and can '
            'shorten the apprenticeship that follows.',
      ),
    ],
    evidence: draftContentEvidence,
    handsOn: true,
  ),
  Occupation(
    id: 'hvac-technician',
    socCode: '49-9021',
    socTitle:
        'Heating, Air Conditioning, and Refrigeration Mechanics and Installers',
    title: 'Heating and cooling technician',
    summary: 'Installs and repairs the systems that heat, cool and ventilate '
        'buildings.',
    tasks: const <String>[
      'Install equipment, ducts and controls',
      'Diagnose and repair systems that are not working',
      'Carry out routine maintenance and explain it to customers',
    ],
    interests: const <InterestArea>{
      InterestArea.building,
      InterestArea.outdoors,
    },
    skills: const <String>[
      'Mechanical and electrical troubleshooting',
      'Safe handling of refrigerants',
      'Reading technical manuals',
      'Dealing well with customers',
    ],
    routes: <EntryRoute>[
      _certificate(
        'Technical school certificate',
        'A certificate programme in heating, ventilation and air '
            'conditioning, plus the federal certification needed to handle '
            'refrigerants.',
      ),
      _apprenticeship(
        'A paid apprenticeship with a contractor or union, combining work '
        'and classroom instruction.',
      ),
    ],
    evidence: draftContentEvidence,
    handsOn: true,
  ),
  Occupation(
    id: 'plumber',
    socCode: '47-2152',
    socTitle: 'Plumbers, Pipefitters, and Steamfitters',
    title: 'Plumber or pipefitter',
    summary:
        'Installs and repairs the pipes and fixtures that carry water, gas '
        'and waste.',
    tasks: const <String>[
      'Read plans and install pipes, fittings and fixtures',
      'Find leaks and blockages and repair them',
      'Test systems and make sure they meet code',
    ],
    interests: const <InterestArea>{
      InterestArea.building,
      InterestArea.outdoors,
    },
    skills: const <String>[
      'Reading plans',
      'Pipe cutting and joining',
      'Problem solving on site',
      'Physical stamina',
    ],
    routes: <EntryRoute>[
      _apprenticeship(
        'A multi-year paid apprenticeship under a licensed plumber, with '
        'classroom instruction, ending in a licence. $_licenceNote',
      ),
    ],
    evidence: draftContentEvidence,
    handsOn: true,
  ),
  Occupation(
    id: 'wind-turbine-technician',
    socCode: '49-9081',
    socTitle: 'Wind Turbine Service Technicians',
    title: 'Wind turbine technician',
    summary: 'Inspects, maintains and repairs wind turbines, often working at '
        'height and outdoors.',
    tasks: const <String>[
      'Climb towers to inspect blades, gearboxes and controls',
      'Carry out scheduled maintenance',
      'Diagnose electrical and mechanical faults',
    ],
    interests: const <InterestArea>{
      InterestArea.building,
      InterestArea.outdoors,
      InterestArea.technology,
    },
    skills: const <String>[
      'Electrical and mechanical repair',
      'Working safely at height',
      'Reading technical diagrams',
      'Careful maintenance records',
    ],
    routes: <EntryRoute>[
      _certificate(
        'Technical school certificate',
        'A certificate or associate programme in wind energy technology.',
      ),
      _employer(
        'Manufacturer and employer training',
        'Employers and turbine manufacturers provide substantial training '
            'after hiring.',
      ),
    ],
    evidence: draftContentEvidence,
    handsOn: true,
  ),
  Occupation(
    id: 'environmental-scientist',
    socCode: '19-2041',
    socTitle: 'Environmental Scientists and Specialists, Including Health',
    title: 'Environmental scientist',
    summary: 'Studies the environment and how human activity affects it, and '
        'advises on reducing harm.',
    tasks: const <String>[
      'Collect samples of air, water and soil',
      'Analyse data and write up what it shows',
      'Advise organisations and agencies on meeting environmental rules',
    ],
    interests: const <InterestArea>{
      InterestArea.science,
      InterestArea.outdoors,
      InterestArea.data,
    },
    skills: const <String>[
      'Field sampling methods',
      'Data analysis',
      'Scientific report writing',
      'Knowledge of environmental regulations',
    ],
    routes: <EntryRoute>[
      _bachelors(
        'Environmental science, biology, chemistry, geology or a related '
        'natural science.',
      ),
    ],
    evidence: draftContentEvidence,
  ),
  Occupation(
    id: 'forest-and-conservation-technician',
    socCode: '19-4071',
    socTitle: 'Forest and Conservation Technicians',
    title: 'Forest and conservation technician',
    summary:
        'Collects information on forests and natural areas and helps carry '
        'out plans to manage and protect them.',
    tasks: const <String>[
      'Measure and record trees, soil and wildlife habitat',
      'Maintain trails, equipment and facilities',
      'Help with fire prevention and reforestation work',
    ],
    interests: const <InterestArea>{
      InterestArea.outdoors,
      InterestArea.science,
    },
    skills: const <String>[
      'Field measurement',
      'Map and GPS use',
      'Working safely in remote places',
      'Recording data accurately',
    ],
    routes: <EntryRoute>[
      _associate(
        'An associate degree in forestry technology or natural resources.',
      ),
      _employer(
        'Seasonal work and agency training',
        'Seasonal field jobs with land-management agencies are a common '
            'starting point and come with training.',
      ),
    ],
    evidence: draftContentEvidence,
    handsOn: true,
  ),
  Occupation(
    id: 'paralegal',
    socCode: '23-2011',
    socTitle: 'Paralegals and Legal Assistants',
    title: 'Paralegal',
    summary:
        'Supports lawyers by researching, organising documents and preparing '
        'material for cases and transactions.',
    tasks: const <String>[
      'Research laws, rulings and records',
      'Draft and organise legal documents',
      'Keep case files and deadlines in order',
    ],
    interests: const <InterestArea>{
      InterestArea.advocacy,
      InterestArea.organising,
    },
    skills: const <String>[
      'Legal research',
      'Precise writing',
      'Document management',
      'Meeting firm deadlines',
    ],
    routes: <EntryRoute>[
      _associate('An associate degree in paralegal studies.'),
      _certificate(
        'Paralegal certificate',
        'A certificate in paralegal studies, commonly taken by people who '
            'already hold a degree in another subject.',
      ),
    ],
    evidence: draftContentEvidence,
  ),
  Occupation(
    id: 'logistician',
    socCode: '13-1081',
    socTitle: 'Logisticians',
    title: 'Logistician',
    summary: 'Plans how goods move from suppliers to customers and fixes the '
        'problems that interrupt them.',
    tasks: const <String>[
      'Plan purchasing, storage and transport',
      'Track shipments and resolve delays',
      'Look for ways to cut cost and waste in the supply chain',
    ],
    interests: const <InterestArea>{
      InterestArea.organising,
      InterestArea.data,
    },
    skills: const <String>[
      'Supply chain planning',
      'Spreadsheets and logistics software',
      'Negotiating with suppliers',
      'Staying organised under time pressure',
    ],
    routes: <EntryRoute>[
      _bachelors(
        'Supply chain management, business or a related subject.',
      ),
      _associate(
        'An associate degree in logistics, or warehouse and dispatch '
        'experience, can lead to coordinator roles that grow into this one.',
      ),
    ],
    evidence: draftContentEvidence,
  ),
];
