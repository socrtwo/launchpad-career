import 'package:launchpad_domain/launchpad_domain.dart';

import 'catalog/occupations.dart';
import 'catalog/plan_templates.dart';

/// The bundled occupation catalogue, searchable in memory.
class InMemoryOccupationCatalogRepository
    implements OccupationCatalogRepository {
  InMemoryOccupationCatalogRepository([List<Occupation>? occupations])
      : _occupations = <Occupation>[...(occupations ?? bundledOccupations)]
          ..sort((a, b) => a.title.compareTo(b.title));

  final List<Occupation> _occupations;

  @override
  Future<List<Occupation>> all() async =>
      List<Occupation>.unmodifiable(_occupations);

  @override
  Future<Occupation?> byId(String id) async {
    for (final occupation in _occupations) {
      if (occupation.id == id) return occupation;
    }
    return null;
  }

  @override
  Future<List<Occupation>> search({
    String query = '',
    Set<InterestArea> interests = const <InterestArea>{},
  }) async {
    final words = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    return <Occupation>[
      for (final occupation in _occupations)
        if (occupation.interests.containsAll(interests) &&
            _matches(occupation, words))
          occupation,
    ];
  }

  @override
  Future<List<PlanStep>> planSteps(
    Occupation occupation,
    RouteKind route,
  ) async =>
      planTemplateFor(route);

  static bool _matches(Occupation occupation, List<String> words) {
    if (words.isEmpty) return true;
    final haystack = <String>[
      occupation.title,
      occupation.socTitle,
      occupation.summary,
      ...occupation.tasks,
      ...occupation.skills,
    ].join(' ').toLowerCase();
    return words.every(haystack.contains);
  }
}
