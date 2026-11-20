import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:launchpad_core/launchpad_core.dart';
import 'package:launchpad_ui/launchpad_ui.dart';

import '../../app/providers.dart';
import '../../l10n/app_strings.dart';
import '../explore/occupation_widgets.dart';

/// Shows [value] once loaded, with the shared loading and error states.
class Loaded<T> extends StatelessWidget {
  const Loaded({
    super.key,
    required this.value,
    required this.onRetry,
    required this.builder,
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(BuildContext context, T data) builder;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return value.when(
      loading: () => Semantics(
        liveRegion: true,
        label: strings.loading,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: Spacing.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stack) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            strings.goalsUnavailable,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: Spacing.sm),
          OutlinedButton(onPressed: onRetry, child: Text(strings.retry)),
        ],
      ),
      data: (data) => builder(context, data),
    );
  }
}

/// The label every tool ends with: where the guidance came from, and that it
/// promises nothing.
class GuidanceFooter extends ConsumerWidget {
  const GuidanceFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final evidence = ref.watch(guidanceRepositoryProvider).evidence;
    final asOf = evidence.asOf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: Spacing.lg),
        const Divider(),
        const SizedBox(height: Spacing.sm),
        EvidenceNote(
          evidence: evidence,
          labels: EvidenceLabels(
            laborMarketData: strings.sourceLine,
            editorial: strings.editorialLine,
            generatedGuidance: (_) => strings.guidanceDraftLine,
            userProvided: strings.userProvidedLine,
            stale: strings.staleLine,
          ),
          now: ref.watch(clockProvider)(),
          dateText: asOf == null ? null : strings.monthYear(asOf),
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          strings.noGuarantee,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/// A text field bound to one note in the session.
///
/// It writes through on every change so nothing is lost by leaving the page,
/// and it never reads the note back while the person is typing.
class NoteField extends ConsumerStatefulWidget {
  const NoteField({
    super.key,
    required this.noteKey,
    required this.label,
    this.minLines = 2,
  });

  final String noteKey;
  final String label;
  final int minLines;

  @override
  ConsumerState<NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends ConsumerState<NoteField> {
  late final TextEditingController _controller = TextEditingController(
    text: ref.read(sessionProvider).workspace.notes[widget.noteKey] ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      minLines: widget.minLines,
      maxLines: widget.minLines + 4,
      maxLength: 600,
      textCapitalization: TextCapitalization.sentences,
      keyboardType: TextInputType.multiline,
      onChanged: (text) =>
          ref.read(sessionProvider.notifier).setNote(widget.noteKey, text),
      decoration: InputDecoration(
        labelText: widget.label,
        alignLabelWithHint: true,
      ),
    );
  }
}

/// A checklist of guide sections, each with its points and a done mark.
class GuideChecklist extends ConsumerWidget {
  const GuideChecklist({
    super.key,
    required this.sections,
    required this.keyFor,
  });

  final List<({String id, String title, List<String> points})> sections;
  final String Function(String sectionId) keyFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final workspace = ref.watch(
      sessionProvider.select((session) => session.workspace),
    );
    final done =
        sections.where((item) => workspace.isDone(keyFor(item.id))).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        StatusLine(message: strings.doneCount(done, sections.length)),
        for (final section in sections)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                OptionTile(
                  label: section.title,
                  multiSelect: true,
                  selected: workspace.isDone(keyFor(section.id)),
                  onPressed: () => ref
                      .read(sessionProvider.notifier)
                      .toggleDone(keyFor(section.id)),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: Spacing.md,
                    top: Spacing.xs,
                  ),
                  child: BulletList(items: section.points),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
