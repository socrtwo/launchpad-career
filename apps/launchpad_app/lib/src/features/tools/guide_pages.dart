import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:launchpad_core/launchpad_core.dart';
import 'package:launchpad_domain/launchpad_domain.dart';
import 'package:launchpad_ui/launchpad_ui.dart';

import '../../app/app_page.dart';
import '../../app/providers.dart';
import '../../l10n/app_strings.dart';
import '../../routing/app_router.dart';
import '../explore/occupation_widgets.dart';
import 'tool_widgets.dart';

List<({String id, String title, List<String> points})> _rows(
  List<GuideItem> items,
) =>
    <({String id, String title, List<String> points})>[
      for (final item in items)
        (id: item.id, title: item.title, points: item.points),
    ];

/// A section-by-section guide to a person's own resume, plus a wording check
/// for single lines. Nothing is uploaded and the resume itself is never seen.
class ResumePage extends ConsumerStatefulWidget {
  const ResumePage({super.key});

  @override
  ConsumerState<ResumePage> createState() => _ResumePageState();
}

class _ResumePageState extends ConsumerState<ResumePage> {
  final TextEditingController _line = TextEditingController();
  List<BulletIssue>? _issues;
  String? _status;

  @override
  void dispose() {
    _line.dispose();
    super.dispose();
  }

  void _check() {
    if (_line.text.trim().isEmpty) return;
    setState(() {
      _issues = ResumeBulletCheck.check(_line.text);
      _status = null;
    });
  }

  void _keep() {
    final strings = AppStrings.of(context);
    final kept = ref.read(sessionProvider.notifier).keepBullet(_line.text);
    setState(() {
      _status = kept ? strings.bulletKept : strings.bulletFull;
      if (kept) {
        _line.clear();
        _issues = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final kept = ref.watch(
      sessionProvider.select((session) => session.workspace.savedBullets),
    );
    final issues = _issues;

    return AppPage(
      backLocation: Routes.tools,
      backLabel: strings.toolsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeading(strings.resumeTitle),
          const SizedBox(height: Spacing.sm),
          Text(strings.resumeIntro, style: theme.textTheme.bodyLarge),
          Loaded<List<GuideItem>>(
            value: ref.watch(resumeSectionsProvider),
            onRetry: () => ref.invalidate(resumeSectionsProvider),
            builder: (context, sections) => GuideChecklist(
              sections: _rows(sections),
              keyFor: Workspace.resumeKey,
            ),
          ),
          const SizedBox(height: Spacing.md),
          PageHeading(strings.bulletHeading, large: false),
          const SizedBox(height: Spacing.xs),
          Text(strings.bulletIntro, style: theme.textTheme.bodyLarge),
          const SizedBox(height: Spacing.sm),
          TextField(
            controller: _line,
            minLines: 2,
            maxLines: 4,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              if (_issues != null || _status != null) {
                setState(() {
                  _issues = null;
                  _status = null;
                });
              }
            },
            decoration: InputDecoration(
              labelText: strings.bulletLabel,
              alignLabelWithHint: true,
            ),
          ),
          Text(strings.bulletStorageNote, style: theme.textTheme.bodyMedium),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.xs,
            children: <Widget>[
              FilledButton.tonal(
                onPressed: _check,
                child: Text(strings.bulletCheck),
              ),
              OutlinedButton(
                onPressed: _keep,
                child: Text(strings.bulletKeep),
              ),
            ],
          ),
          StatusLine(
            message: _status ??
                (issues != null && issues.isEmpty
                    ? strings.bulletNothing
                    : null),
          ),
          if (issues != null && issues.isNotEmpty)
            Semantics(
              liveRegion: true,
              container: true,
              child: BulletList(
                items: issues.map(strings.bulletIssue).toList(),
              ),
            ),
          if (kept.isNotEmpty) ...<Widget>[
            const SizedBox(height: Spacing.md),
            PageHeading(strings.bulletKeptHeading, large: false),
            const SizedBox(height: Spacing.xs),
            for (final line in kept)
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(line, style: theme.textTheme.bodyLarge),
                  ),
                  IconButton(
                    onPressed: () =>
                        ref.read(sessionProvider.notifier).removeBullet(line),
                    icon: const Icon(Icons.close),
                    tooltip: strings.removeLine(line),
                  ),
                ],
              ),
          ],
          const GuidanceFooter(),
        ],
      ),
    );
  }
}

/// A checklist for a person's own LinkedIn profile. The app does not connect
/// to LinkedIn and never sees the profile.
class LinkedInPage extends ConsumerWidget {
  const LinkedInPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    return AppPage(
      backLocation: Routes.tools,
      backLabel: strings.toolsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeading(strings.linkedInTitle),
          const SizedBox(height: Spacing.sm),
          Text(strings.linkedInIntro, style: theme.textTheme.bodyLarge),
          Loaded<List<GuideItem>>(
            value: ref.watch(linkedInSectionsProvider),
            onRetry: () => ref.invalidate(linkedInSectionsProvider),
            builder: (context, sections) => GuideChecklist(
              sections: _rows(sections),
              keyFor: Workspace.linkedInKey,
            ),
          ),
          const GuidanceFooter(),
          const SizedBox(height: Spacing.xs),
          Text(strings.linkedInDisclaimer, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
