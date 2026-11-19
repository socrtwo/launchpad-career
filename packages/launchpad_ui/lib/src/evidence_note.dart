import 'package:flutter/material.dart';
import 'package:launchpad_core/launchpad_core.dart';
import 'package:launchpad_domain/launchpad_domain.dart';

/// The words used to say where something came from.
///
/// Supplied by the app so this package stays free of the string table.
@immutable
class EvidenceLabels {
  const EvidenceLabels({
    required this.laborMarketData,
    required this.editorial,
    required this.generatedGuidance,
    required this.userProvided,
    required this.stale,
  });

  /// Given the source and the period, e.g. "Source: X, May 2024."
  final String Function(String source, String? period) laborMarketData;

  /// Given the review date in words, if known.
  final String Function(String? reviewed) editorial;

  /// Given the draft date in words, if known.
  final String Function(String? drafted) generatedGuidance;

  final String userProvided;

  /// Shown when the figures are old enough to mislead.
  final String stale;
}

/// Says where a claim came from, differently for each kind of source.
///
/// A person must never have to guess whether a number came from a statistics
/// office or from a language model, so each kind has its own icon and its own
/// sentence, and stale figures carry a warning that does not rely on colour.
class EvidenceNote extends StatelessWidget {
  const EvidenceNote({
    super.key,
    required this.evidence,
    required this.labels,
    required this.now,
    this.period,
    this.dateText,
  });

  final Evidence evidence;
  final EvidenceLabels labels;
  final DateTime now;

  /// The reference period in the publisher's words, for labour-market data.
  final String? period;

  /// The review or draft date in words, for editorial and generated content.
  final String? dateText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, text) = switch (evidence.kind) {
      EvidenceKind.laborMarketData => (
          Icons.bar_chart,
          labels.laborMarketData(evidence.source ?? '', period),
        ),
      EvidenceKind.editorial => (
          Icons.fact_check_outlined,
          labels.editorial(dateText),
        ),
      EvidenceKind.generatedGuidance => (
          Icons.smart_toy_outlined,
          labels.generatedGuidance(dateText),
        ),
      EvidenceKind.userProvided => (Icons.person_outline, labels.userProvided),
    };
    final stale = evidence.kind == EvidenceKind.laborMarketData &&
        evidence.isStaleAt(now);

    Widget line(IconData icon, String text) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExcludeSemantics(
              child: Icon(icon, size: 18, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: Spacing.xs),
            Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        line(icon, text),
        if (stale) ...<Widget>[
          const SizedBox(height: Spacing.xxs),
          line(Icons.warning_amber_outlined, labels.stale),
        ],
      ],
    );
  }
}
