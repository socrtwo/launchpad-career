import 'package:launchpad_domain/launchpad_domain.dart';

/// Converts the goal and occupation catalogues to and from the JSON documents
/// the server publishes (`{"schemaVersion": 1, "items": [...]}`).
///
/// Decoding is strict, unlike the session codec: a published catalogue is
/// shown to everyone, so a document with any problem is rejected whole and
/// the app keeps using the catalogue it was built with. The checks are the
/// ones the bundled catalogue is tested against - no outcome promises, no
/// figures in text, every occupation complete.
abstract final class CatalogCodec {
  static const int schemaVersion = 1;

  static final RegExp outcomePromise = RegExp(
    r"\b(guarantee[ds]?|guaranteed|ensures? you get|will land you|"
    r"land the job|you will get (the|a) job|sure to|certain to)\b",
    caseSensitive: false,
  );

  static final RegExp bareFigure = RegExp(r'[$£€]\s?\d|\d\s?%|\d{2,}[,.]\d{3}');

  // Goals.

  static Map<String, Object?> encodeGoals(List<Goal> goals) =>
      <String, Object?>{
        'schemaVersion': schemaVersion,
        'items': <Object?>[
          for (final goal in goals)
            <String, Object?>{
              'id': goal.id.slug,
              'title': goal.title,
              'description': goal.description,
              'icon': goal.icon.name,
              'nextStep': goal.nextStep,
            },
        ],
      };

  /// Reads a goals document. The set of goals is fixed in the app, so the
  /// document must contain exactly the known goals, each once.
  static CatalogResult<Goal> decodeGoals(Object? document) {
    final problems = <String>[];
    final items = _items(document, problems);
    final goals = <Goal>[];
    for (final (index, raw) in items.indexed) {
      final where = 'items[$index]';
      if (raw is! Map) {
        problems.add('$where is not an object.');
        continue;
      }
      final id = GoalId.fromSlug(_text(raw['id']));
      final icon = GoalIcon.values
          .where((value) => value.name == raw['icon'])
          .firstOrNull;
      final title = _required(raw, 'title', where, problems);
      final description = _required(raw, 'description', where, problems);
      final nextStep = _required(raw, 'nextStep', where, problems);
      if (id == null) problems.add('$where has an unknown goal id.');
      if (icon == null) problems.add('$where has an unknown icon.');
      if (id == null ||
          icon == null ||
          title == null ||
          description == null ||
          nextStep == null) {
        continue;
      }
      goals.add(
        Goal(
          id: id,
          title: title,
          description: description,
          icon: icon,
          nextStep: nextStep,
        ),
      );
    }
    final ids = goals.map((goal) => goal.id).toSet();
    if (problems.isEmpty &&
        (ids.length != goals.length || ids.length != GoalId.values.length)) {
      problems.add('The document must contain each of the known goals once.');
    }
    goals.sort((a, b) => a.id.index.compareTo(b.id.index));
    return CatalogResult<Goal>(goals, problems);
  }

  // Occupations.

  static Map<String, Object?> encodeOccupations(List<Occupation> occupations) =>
      <String, Object?>{
        'schemaVersion': schemaVersion,
        'items': <Object?>[
          for (final item in occupations)
            <String, Object?>{
              'id': item.id,
              'socCode': item.socCode,
              'socTitle': item.socTitle,
              'title': item.title,
              'summary': item.summary,
              'tasks': item.tasks,
              'interests': item.interests.map((area) => area.slug).toList()
                ..sort(),
              'skills': item.skills,
              'routes': <Object?>[
                for (final route in item.routes)
                  <String, Object?>{
                    'kind': route.kind.slug,
                    'title': route.title,
                    'description': route.description,
                  },
              ],
              'handsOn': item.handsOn,
              'flexibleArrangementsCommon': item.flexibleArrangementsCommon,
              if (item.changeNote != null) 'changeNote': item.changeNote,
              'evidence': <String, Object?>{
                'kind': item.evidence.kind == EvidenceKind.editorial
                    ? 'editorial'
                    : 'generated',
                if (item.evidence.source != null)
                  'source': item.evidence.source,
                if (item.evidence.asOf != null)
                  'asOf': item.evidence.asOf!.toIso8601String(),
              },
            },
        ],
      };

  static CatalogResult<Occupation> decodeOccupations(Object? document) {
    final problems = <String>[];
    final items = _items(document, problems);
    final occupations = <Occupation>[];
    final seenIds = <String>{};
    final seenCodes = <String>{};

    for (final (index, raw) in items.indexed) {
      final where = 'items[$index]';
      if (raw is! Map) {
        problems.add('$where is not an object.');
        continue;
      }
      final before = problems.length;
      final id = _required(raw, 'id', where, problems, checkText: false);
      final socCode =
          _required(raw, 'socCode', where, problems, checkText: false);
      final socTitle =
          _required(raw, 'socTitle', where, problems, checkText: false);
      final title = _required(raw, 'title', where, problems);
      final summary = _required(raw, 'summary', where, problems);
      final tasks = _texts(raw, 'tasks', where, problems);
      final skills = _texts(raw, 'skills', where, problems);
      final changeNote = _optional(raw, 'changeNote', where, problems);

      if (id != null && !RegExp(r'^[a-z]+(-[a-z]+)*$').hasMatch(id)) {
        problems.add('$where.id must be lower-case words joined by hyphens.');
      }
      if (socCode != null && !RegExp(r'^\d{2}-\d{4}$').hasMatch(socCode)) {
        problems.add('$where.socCode is not a SOC code.');
      }
      if (id != null && !seenIds.add(id)) {
        problems.add('$where repeats the id "$id".');
      }
      if (socCode != null && !seenCodes.add(socCode)) {
        problems.add('$where repeats the SOC code "$socCode".');
      }

      final interests = <InterestArea>{};
      final rawInterests = raw['interests'];
      if (rawInterests is List) {
        for (final slug in rawInterests) {
          final area = InterestArea.fromSlug(_text(slug));
          if (area == null) {
            problems.add('$where.interests has an unknown value.');
          } else {
            interests.add(area);
          }
        }
      }
      if (interests.isEmpty) {
        problems.add('$where needs at least one interest.');
      }

      final routes = <EntryRoute>[];
      final rawRoutes = raw['routes'];
      if (rawRoutes is List) {
        for (final (routeIndex, rawRoute) in rawRoutes.indexed) {
          final routeWhere = '$where.routes[$routeIndex]';
          if (rawRoute is! Map) {
            problems.add('$routeWhere is not an object.');
            continue;
          }
          final kind = RouteKind.fromSlug(_text(rawRoute['kind']));
          final routeTitle = _required(rawRoute, 'title', routeWhere, problems);
          final description =
              _required(rawRoute, 'description', routeWhere, problems);
          if (kind == null) problems.add('$routeWhere has an unknown kind.');
          if (kind != null && routeTitle != null && description != null) {
            routes.add(
              EntryRoute(
                kind: kind,
                title: routeTitle,
                description: description,
              ),
            );
          }
        }
      }
      if (routes.isEmpty) problems.add('$where needs at least one route.');

      final rawEvidence = raw['evidence'];
      final evidenceMap = rawEvidence is Map ? rawEvidence : const {};
      final evidence = Evidence(
        // Anything not explicitly marked as reviewed stays labelled a draft.
        kind: evidenceMap['kind'] == 'editorial'
            ? EvidenceKind.editorial
            : EvidenceKind.generatedGuidance,
        source: _text(evidenceMap['source']),
        asOf: DateTime.tryParse('${evidenceMap['asOf']}')?.toUtc(),
      );

      if (problems.length != before ||
          id == null ||
          socCode == null ||
          socTitle == null ||
          title == null ||
          summary == null) {
        continue;
      }
      occupations.add(
        Occupation(
          id: id,
          socCode: socCode,
          socTitle: socTitle,
          title: title,
          summary: summary,
          tasks: List<String>.unmodifiable(tasks),
          interests: Set<InterestArea>.unmodifiable(interests),
          skills: List<String>.unmodifiable(skills),
          routes: List<EntryRoute>.unmodifiable(routes),
          evidence: evidence,
          handsOn: raw['handsOn'] == true,
          flexibleArrangementsCommon: raw['flexibleArrangementsCommon'] == true,
          changeNote: changeNote,
        ),
      );
    }
    if (problems.isEmpty && occupations.isEmpty) {
      problems.add('The document has no occupations.');
    }
    return CatalogResult<Occupation>(occupations, problems);
  }

  static List<Object?> _items(Object? document, List<String> problems) {
    if (document is! Map) {
      problems.add('The document is not an object.');
      return const <Object?>[];
    }
    if (document['schemaVersion'] != schemaVersion) {
      problems.add('schemaVersion must be $schemaVersion.');
    }
    final items = document['items'];
    if (items is! List) {
      problems.add('items must be a list.');
      return const <Object?>[];
    }
    return items;
  }

  static String? _text(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static String? _required(
    Map<Object?, Object?> raw,
    String field,
    String where,
    List<String> problems, {
    bool checkText = true,
  }) {
    final value = _text(raw[field]);
    if (value == null) {
      problems.add('$where.$field is missing.');
      return null;
    }
    if (checkText) _checkText(value, '$where.$field', problems);
    return value;
  }

  static String? _optional(
    Map<Object?, Object?> raw,
    String field,
    String where,
    List<String> problems,
  ) {
    final value = _text(raw[field]);
    if (value != null) _checkText(value, '$where.$field', problems);
    return value;
  }

  static List<String> _texts(
    Map<Object?, Object?> raw,
    String field,
    String where,
    List<String> problems,
  ) {
    final value = raw[field];
    final result = <String>[];
    if (value is List) {
      for (final item in value) {
        final text = _text(item);
        if (text == null) {
          problems.add('$where.$field has an empty entry.');
        } else {
          _checkText(text, '$where.$field', problems);
          result.add(text);
        }
      }
    }
    if (result.isEmpty) problems.add('$where.$field needs at least one entry.');
    return result;
  }

  static void _checkText(String text, String where, List<String> problems) {
    if (outcomePromise.hasMatch(text)) {
      problems.add('$where promises an outcome.');
    }
    if (bareFigure.hasMatch(text)) {
      problems.add(
        '$where contains a figure. Figures come only from the labour-market '
        'snapshot, with a source and date.',
      );
    }
  }
}

/// A decoded catalogue, usable only when [problems] is empty.
class CatalogResult<T> {
  const CatalogResult(this.items, this.problems);

  final List<T> items;
  final List<String> problems;

  bool get isValid => problems.isEmpty;
}
