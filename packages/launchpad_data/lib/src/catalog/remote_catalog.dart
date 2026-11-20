import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:launchpad_domain/launchpad_domain.dart';

import '../in_memory_occupation_catalog_repository.dart';
import 'catalog_codec.dart';

/// Fetches published catalogue documents from the server.
///
/// Returns null for every kind of failure - nothing published, no network, a
/// reply that is not JSON - because the caller's answer is always the same:
/// use the catalogue the app was built with. A fetch is a plain public GET
/// with no credentials and nothing about the person in it.
class CatalogClient {
  CatalogClient({
    required Uri baseUrl,
    required http.Client client,
    this.timeout = const Duration(seconds: 10),
  })  : _baseUrl = baseUrl,
        _client = client;

  final Uri _baseUrl;
  final http.Client _client;
  final Duration timeout;

  Future<Object?> fetch(String name) async {
    try {
      final response = await _client.get(
        _baseUrl.resolve('/v1/catalog/$name'),
        headers: const <String, String>{'accept': 'application/json'},
      ).timeout(timeout);
      if (response.statusCode != 200) return null;
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      return body is Map ? body['document'] : null;
    } on Exception {
      return null;
    }
  }
}

/// Goals from the server when a valid catalogue is published there, otherwise
/// the bundled ones. Fetched once per run.
class RemoteFirstGoalCatalogRepository implements GoalCatalogRepository {
  RemoteFirstGoalCatalogRepository({
    required CatalogClient client,
    required GoalCatalogRepository fallback,
  })  : _client = client,
        _fallback = fallback;

  final CatalogClient _client;
  final GoalCatalogRepository _fallback;
  Future<List<Goal>>? _goals;

  @override
  Future<List<Goal>> primaryGoals() => _goals ??= _load();

  @override
  Future<Goal?> goalById(GoalId id) async {
    for (final goal in await primaryGoals()) {
      if (goal.id == id) return goal;
    }
    return null;
  }

  Future<List<Goal>> _load() async {
    final document = await _client.fetch('goals');
    if (document != null) {
      final result = CatalogCodec.decodeGoals(document);
      if (result.isValid) return result.items;
    }
    return _fallback.primaryGoals();
  }
}

/// Occupations from the server when a valid catalogue is published there,
/// otherwise the bundled ones. Fetched once per run.
class RemoteFirstOccupationCatalogRepository
    implements OccupationCatalogRepository {
  RemoteFirstOccupationCatalogRepository({
    required CatalogClient client,
    required OccupationCatalogRepository fallback,
  })  : _client = client,
        _fallback = fallback;

  final CatalogClient _client;
  final OccupationCatalogRepository _fallback;
  Future<OccupationCatalogRepository>? _resolved;

  Future<OccupationCatalogRepository> get _repository => _resolved ??= _load();

  Future<OccupationCatalogRepository> _load() async {
    final document = await _client.fetch('occupations');
    if (document != null) {
      final result = CatalogCodec.decodeOccupations(document);
      if (result.isValid) {
        return InMemoryOccupationCatalogRepository(result.items);
      }
    }
    return _fallback;
  }

  @override
  Future<List<Occupation>> all() async => (await _repository).all();

  @override
  Future<Occupation?> byId(String id) async => (await _repository).byId(id);

  @override
  Future<List<Occupation>> search({
    String query = '',
    Set<InterestArea> interests = const <InterestArea>{},
  }) async =>
      (await _repository).search(query: query, interests: interests);

  @override
  Future<List<PlanStep>> planSteps(
    Occupation occupation,
    RouteKind route,
  ) async =>
      (await _repository).planSteps(occupation, route);
}
