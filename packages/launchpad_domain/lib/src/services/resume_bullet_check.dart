/// Something a simple wording check noticed about a resume bullet.
enum BulletIssue {
  /// Opens with a phrase that describes a duty rather than something done.
  weakOpening,

  /// Uses "I", "my" or "me". Resume bullets conventionally drop the pronoun.
  firstPerson,

  /// Contains no number, so nothing says how much or how many.
  noMeasure,

  /// Long enough that it is probably two points.
  tooLong,

  /// Too short to say what was done.
  tooShort,
}

/// Checks the wording of one resume bullet against a handful of fixed rules.
///
/// This is pattern matching, and the interface says so. It cannot tell whether
/// a bullet is true, relevant or impressive, it never scores a person, and its
/// absence of complaints is not approval. The text it is given is not stored
/// or logged.
abstract final class ResumeBulletCheck {
  static const int maxWords = 32;
  static const int minWords = 4;

  static const List<String> weakOpenings = <String>[
    'responsible for',
    'duties included',
    'helped',
    'assisted',
    'worked on',
    'worked with',
    'tasked with',
    'in charge of',
    'participated in',
    'involved in',
  ];

  static final RegExp _firstPerson = RegExp(r"\b(i|i'm|i've|my|me|myself)\b");
  static final RegExp _number = RegExp(r'\d');
  static final RegExp _leading = RegExp(r'^[\s\-•*]+');

  static List<BulletIssue> check(String bullet) {
    final text = bullet.replaceFirst(_leading, '').trim();
    if (text.isEmpty) return const <BulletIssue>[];
    final lower = text.toLowerCase();
    final words = lower.split(RegExp(r'\s+')).where((word) => word.isNotEmpty);

    return <BulletIssue>[
      if (words.length < minWords) BulletIssue.tooShort,
      if (weakOpenings.any(lower.startsWith)) BulletIssue.weakOpening,
      if (_firstPerson.hasMatch(lower)) BulletIssue.firstPerson,
      if (words.length >= minWords && !_number.hasMatch(lower))
        BulletIssue.noMeasure,
      if (words.length > maxWords) BulletIssue.tooLong,
    ];
  }
}
