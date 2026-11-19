import 'package:launchpad_domain/launchpad_domain.dart';

import 'labor/oews_snapshot.g.dart';

/// Labour-market figures compiled into the app.
///
/// Bundled rather than fetched at run time so that reading about an
/// occupation makes no network request and discloses nothing about what a
/// person looked at. The price is that the figures are as old as the last
/// import, which is why every one is shown with its reference period.
class BundledLaborMarketRepository implements LaborMarketRepository {
  const BundledLaborMarketRepository();

  @override
  Future<LaborMarketSnapshot?> snapshot() async => buildBundledOewsSnapshot();
}

/// A fixed snapshot, for tests and previews.
class FixedLaborMarketRepository implements LaborMarketRepository {
  const FixedLaborMarketRepository(this._snapshot);

  final LaborMarketSnapshot? _snapshot;

  @override
  Future<LaborMarketSnapshot?> snapshot() async => _snapshot;
}
