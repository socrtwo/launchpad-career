import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:launchpad_core/launchpad_core.dart';
import 'package:launchpad_domain/launchpad_domain.dart';
import 'package:launchpad_ui/launchpad_ui.dart';

import '../../app/app_page.dart';
import '../../l10n/app_strings.dart';
import '../../routing/app_router.dart';
import 'occupation_widgets.dart';

/// Search and browse the occupation catalogue.
///
/// Searching happens on the device against the bundled catalogue. Nothing a
/// person types here leaves it, and the query is not kept anywhere.
class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  final TextEditingController _query = TextEditingController();
  final Set<InterestArea> _interests = <InterestArea>{};
  String? _status;

  @override
  void initState() {
    super.initState();
    _query.addListener(_onQueryChanged);
  }

  void _onQueryChanged() => setState(() => _status = null);

  @override
  void dispose() {
    _query
      ..removeListener(_onQueryChanged)
      ..dispose();
    super.dispose();
  }

  List<Occupation> _filter(List<Occupation> all) {
    final words = _query.text
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    return <Occupation>[
      for (final occupation in all)
        if (occupation.interests.containsAll(_interests) &&
            _matches(occupation, words))
          occupation,
    ];
  }

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

  void _clear() {
    _query.clear();
    setState(() {
      _interests.clear();
      _status = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);

    return AppPage(
      maxWidth: Breakpoints.maxContentWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeading(strings.exploreTitle),
          const SizedBox(height: Spacing.sm),
          Text(strings.exploreIntro, style: theme.textTheme.bodyLarge),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.xs,
            children: <Widget>[
              OutlinedButton(
                onPressed: () => context.go(Routes.saved),
                child: Text(strings.savedTitle),
              ),
              OutlinedButton(
                onPressed: () => context.go(Routes.suggestions),
                child: Text(strings.suggestionsTitle),
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          TextField(
            controller: _query,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: strings.searchLabel,
              hintText: strings.searchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: _query.clear,
                      icon: const Icon(Icons.clear),
                      tooltip: strings.clearSearch,
                    ),
            ),
          ),
          const SizedBox(height: Spacing.md),
          PageHeading(strings.filterHeading, large: false),
          const SizedBox(height: Spacing.xs),
          Wrap(
            spacing: Spacing.xs,
            runSpacing: Spacing.xxs,
            children: <Widget>[
              for (final area in InterestArea.values)
                FilterChip(
                  label: Text(strings.interestArea(area)),
                  selected: _interests.contains(area),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _interests.add(area);
                    } else {
                      _interests.remove(area);
                    }
                    _status = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          OccupationsLoader(
            builder: (context, all) {
              final found = _filter(all);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  StatusLine(
                    message: _status ?? strings.resultCount(found.length),
                  ),
                  if (found.isEmpty) ...<Widget>[
                    Text(
                      strings.noResultsHint,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: Spacing.sm),
                    OutlinedButton(
                      onPressed: _clear,
                      child: Text(strings.clearFilters),
                    ),
                  ],
                  for (final occupation in found)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.sm),
                      child: OccupationCard(
                        occupation: occupation,
                        onChanged: (message) =>
                            setState(() => _status = message),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
