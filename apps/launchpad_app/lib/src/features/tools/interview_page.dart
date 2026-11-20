import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:launchpad_core/launchpad_core.dart';
import 'package:launchpad_domain/launchpad_domain.dart';
import 'package:launchpad_ui/launchpad_ui.dart';

import '../../app/app_page.dart';
import '../../app/providers.dart';
import '../../l10n/app_strings.dart';
import '../../routing/app_router.dart';
import '../explore/occupation_widgets.dart';
import 'tool_widgets.dart';

/// The question bank, or one question with space to build an answer.
///
/// The question is in the URL (`/tools/interview?q=teamwork`) so a refreshed
/// page keeps its place.
class InterviewPage extends ConsumerWidget {
  const InterviewPage({super.key, this.questionId});

  final String? questionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final id = questionId;
    return AppPage(
      backLocation: id == null ? Routes.tools : Routes.interview,
      backLabel: id == null ? strings.toolsTitle : strings.backToQuestions,
      child: Loaded<List<InterviewQuestion>>(
        value: ref.watch(interviewQuestionsProvider),
        onRetry: () => ref.invalidate(interviewQuestionsProvider),
        builder: (context, questions) {
          if (id == null) return _QuestionList(questions: questions);
          final question = questions.where((item) => item.id == id).firstOrNull;
          if (question == null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  strings.unknownQuestion,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: Spacing.md),
                FilledButton(
                  onPressed: () => context.go(Routes.interview),
                  child: Text(strings.backToQuestions),
                ),
              ],
            );
          }
          return _Question(question: question);
        },
      ),
    );
  }
}

class _QuestionList extends ConsumerWidget {
  const _QuestionList({required this.questions});

  final List<InterviewQuestion> questions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final workspace = ref.watch(
      sessionProvider.select((session) => session.workspace),
    );
    final done = questions
        .where((item) => workspace.isDone(Workspace.interviewKey(item.id)))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PageHeading(strings.interviewTitle),
        const SizedBox(height: Spacing.sm),
        Text(strings.interviewIntro, style: theme.textTheme.bodyLarge),
        StatusLine(message: strings.practisedCount(done, questions.length)),
        for (final category in QuestionCategory.values) ...<Widget>[
          const SizedBox(height: Spacing.sm),
          PageHeading(strings.questionCategory(category), large: false),
          const SizedBox(height: Spacing.xs),
          for (final question
              in questions.where((item) => item.category == category))
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.xs),
              child: _QuestionTile(
                question: question,
                practised:
                    workspace.isDone(Workspace.interviewKey(question.id)),
              ),
            ),
        ],
        const GuidanceFooter(),
      ],
    );
  }
}

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({required this.question, required this.practised});

  final InterviewQuestion question;
  final bool practised;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final state = practised ? strings.practised : strings.notPractised;
    void open() => context.go(Routes.interviewQuestion(question.id));
    return Semantics(
      container: true,
      button: true,
      label: strings.openQuestion(question.prompt),
      value: state,
      onTap: open,
      excludeSemantics: true,
      child: OutlinedButton(
        onPressed: open,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(Spacing.md),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(question.prompt, style: theme.textTheme.titleMedium),
                  const SizedBox(height: Spacing.xxs),
                  FactLabel(
                    icon: practised
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    text: state,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _Question extends ConsumerWidget {
  const _Question({required this.question});

  final InterviewQuestion question;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final key = Workspace.interviewKey(question.id);
    final practised = ref.watch(
      sessionProvider.select((session) => session.workspace.isDone(key)),
    );

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(top: Spacing.lg, bottom: Spacing.xs),
          child: PageHeading(text, large: false),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          strings.questionCategory(question.category),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: Spacing.xxs),
        PageHeading(question.prompt),
        heading(strings.interviewPurposeHeading),
        Text(question.purpose, style: theme.textTheme.bodyLarge),
        heading(strings.interviewTipsHeading),
        BulletList(items: question.tips),
        heading(strings.interviewExampleHeading),
        if (question.usesExample) ...<Widget>[
          Text(
            strings.interviewExampleIntro,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: Spacing.sm),
          for (final part in ExamplePart.values)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.xs),
              child: NoteField(
                noteKey: Workspace.interviewNoteKey(question.id, part),
                label: strings.examplePart(part),
              ),
            ),
        ] else
          NoteField(
            noteKey: Workspace.interviewNoteKey(
              question.id,
              ExamplePart.situation,
            ),
            label: strings.interviewNotesLabel,
            minLines: 4,
          ),
        Text(strings.notesStorageNote, style: theme.textTheme.bodyMedium),
        const SizedBox(height: Spacing.md),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.xs,
          children: <Widget>[
            FilledButton.tonal(
              onPressed: () =>
                  ref.read(sessionProvider.notifier).toggleDone(key),
              child: Text(
                practised ? strings.markNotPractised : strings.markPractised,
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go(Routes.interview),
              icon: const Icon(Icons.arrow_back),
              label: Text(strings.backToQuestions),
            ),
          ],
        ),
        StatusLine(message: practised ? strings.practised : null),
        const GuidanceFooter(),
      ],
    );
  }
}
