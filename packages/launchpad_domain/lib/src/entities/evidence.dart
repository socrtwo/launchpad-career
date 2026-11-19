import 'package:meta/meta.dart';

/// How a statement shown to the user was produced.
///
/// Every recommendation surface must be able to answer "where did this come
/// from?" without the UI having to guess. See
/// `docs/product/career-recommendation-principles.md`.
enum EvidenceKind {
  /// Published labour-market statistics (e.g. BLS OEWS). Requires [Evidence.source]
  /// and [Evidence.asOf].
  laborMarketData,

  /// Content written and reviewed by a human editor.
  editorial,

  /// Model-generated guidance. Must be labelled as such in the interface.
  generatedGuidance,

  /// Something the user told us.
  userProvided,
}

/// Confidence band shown to the user in words, never as a bare percentage.
enum ConfidenceBand { low, moderate, high }

/// Provenance metadata attached to any claim the product displays.
@immutable
class Evidence {
  const Evidence({
    required this.kind,
    this.source,
    this.sourceUrl,
    this.asOf,
    this.confidence = ConfidenceBand.moderate,
  }) : assert(
          kind != EvidenceKind.laborMarketData ||
              (source != null && asOf != null),
          'Labour-market claims must carry a source and an as-of date.',
        );

  final EvidenceKind kind;
  final String? source;
  final String? sourceUrl;
  final DateTime? asOf;
  final ConfidenceBand confidence;

  bool get isGenerated => kind == EvidenceKind.generatedGuidance;

  /// Labour-market data goes stale. Anything older than this is shown with a
  /// warning rather than as if it were current.
  static const Duration stalenessThreshold = Duration(days: 548);

  /// Whether [asOf] is far enough behind [now] to need a staleness warning.
  /// Undated evidence is never called stale; it is simply undated.
  bool isStaleAt(DateTime now) {
    final date = asOf;
    return date != null && now.difference(date) > stalenessThreshold;
  }
}
