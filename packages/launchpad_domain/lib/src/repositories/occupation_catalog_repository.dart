import '../entities/occupation.dart';
import '../entities/profile.dart';

/// Supplies the occupations a person can explore.
abstract interface class OccupationCatalogRepository {
  /// Every occupation, in title order.
  Future<List<Occupation>> all();

  Future<Occupation?> byId(String id);

  /// Occupations whose title, summary, tasks or skills contain every word of
  /// [query], narrowed to those involving every interest in [interests]. An
  /// empty query and no interests returns everything.
  Future<List<Occupation>> search({
    String query = '',
    Set<InterestArea> interests = const <InterestArea>{},
  });

  /// The steps of a plan towards [occupation] by the given kind of route.
  Future<List<PlanStep>> planSteps(Occupation occupation, RouteKind route);
}

/// Supplies published labour-market figures.
///
/// Returns null, not zeros, when nothing is loaded: the interface then says
/// the figures are not available instead of showing a number with no source.
abstract interface class LaborMarketRepository {
  Future<LaborMarketSnapshot?> snapshot();
}
