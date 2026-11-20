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
import '../your_data/storage_choice.dart';

/// One onboarding question, or the review of all of them.
///
/// Rules this screen exists to honour:
///
///  * every question says why it is asked, next to the question;
///  * every question can be skipped, and so can the whole sequence;
///  * nothing here is required to reach a goal's tools;
///  * answers are shown back to the person and each one can be changed.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key, required this.step});

  final OnboardingStep step;

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  late final TextEditingController _name;
  String? _status;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: ref.read(sessionProvider).profile.preferredName ?? '',
    );
    // Recording the step changes provider state, which is not allowed while
    // the tree is building, so it waits for the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(sessionProvider.notifier).reachStep(widget.step);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  SessionController get _session => ref.read(sessionProvider.notifier);

  Profile get _profile => ref.read(sessionProvider).profile;

  void _saveName() {
    if (widget.step != OnboardingStep.name) return;
    _session.updateProfile(_profile.copyWith(preferredName: _name.text));
  }

  void _goTo(OnboardingStep? step) {
    _saveName();
    if (step == null) return;
    context.go(Routes.onboarding(step));
  }

  void _skipAll() {
    _session.skipOnboarding();
    context.go(Routes.afterOnboarding(ref.read(sessionProvider)));
  }

  void _finish() {
    _session.finishOnboarding();
    context.go(Routes.afterOnboarding(ref.read(sessionProvider)));
  }

  void _toggleInterest(InterestArea area) {
    final next = <InterestArea>{..._profile.interests};
    if (!next.remove(area)) next.add(area);
    _session.updateProfile(_profile.copyWith(interests: next));
    setState(
      () => _status = AppStrings.of(context).selectedCount(next.length),
    );
  }

  void _togglePriority(Priority priority) {
    final strings = AppStrings.of(context);
    final next = <Priority>{..._profile.priorities};
    if (next.remove(priority)) {
      _session.updateProfile(_profile.copyWith(priorities: next));
      setState(() => _status = strings.selectedCount(next.length));
      return;
    }
    if (next.length >= Priority.maxChoices) {
      setState(() => _status = strings.priorityLimitReached);
      return;
    }
    next.add(priority);
    _session.updateProfile(_profile.copyWith(priorities: next));
    setState(() => _status = strings.selectedCount(next.length));
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final step = widget.step;
    final session = ref.watch(sessionProvider);
    final profile = session.profile;
    final isReview = step == OnboardingStep.review;

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Progress(step: step),
          const SizedBox(height: Spacing.lg),
          PageHeading(strings.onboardingTitle(step), large: false),
          const SizedBox(height: Spacing.xs),
          Text(
            strings.onboardingReason(step),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: Spacing.lg),
          switch (step) {
            OnboardingStep.name => TextField(
                controller: _name,
                maxLength: Profile.maxNameLength,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[AutofillHints.nickname],
                onSubmitted: (_) => _goTo(step.next),
                decoration: InputDecoration(
                  labelText: strings.nameFieldLabel,
                ),
              ),
            OnboardingStep.education => _Options(
                children: <Widget>[
                  for (final level in EducationLevel.values)
                    OptionTile(
                      label: strings.educationLevel(level),
                      selected: profile.educationLevel == level,
                      onPressed: () => _session.updateProfile(
                        profile.copyWith(
                          educationLevel:
                              profile.educationLevel == level ? null : level,
                        ),
                      ),
                    ),
                ],
              ),
            OnboardingStep.plans => _Options(
                children: <Widget>[
                  for (final plan in PlannedEducation.values)
                    OptionTile(
                      label: strings.plannedEducation(plan),
                      selected: profile.plannedEducation == plan,
                      onPressed: () => _session.updateProfile(
                        profile.copyWith(
                          plannedEducation:
                              profile.plannedEducation == plan ? null : plan,
                        ),
                      ),
                    ),
                ],
              ),
            OnboardingStep.interests => _Options(
                children: <Widget>[
                  for (final area in InterestArea.values)
                    OptionTile(
                      label: strings.interestArea(area),
                      selected: profile.interests.contains(area),
                      multiSelect: true,
                      onPressed: () => _toggleInterest(area),
                    ),
                ],
              ),
            OnboardingStep.priorities => _Options(
                children: <Widget>[
                  for (final priority in Priority.values)
                    OptionTile(
                      label: strings.priority(priority),
                      selected: profile.priorities.contains(priority),
                      multiSelect: true,
                      onPressed: () => _togglePriority(priority),
                    ),
                ],
              ),
            OnboardingStep.review => _Review(session: session),
          },
          StatusLine(message: _status),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              if (step.previous != null)
                OutlinedButton.icon(
                  onPressed: () => _goTo(step.previous),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(strings.back),
                ),
              if (isReview)
                FilledButton(onPressed: _finish, child: Text(strings.finish))
              else ...<Widget>[
                FilledButton.icon(
                  onPressed: () => _goTo(step.next),
                  icon: const Icon(Icons.arrow_forward),
                  iconAlignment: IconAlignment.end,
                  label: Text(strings.continueLabel),
                ),
                TextButton(
                  onPressed: () => context.go(Routes.onboarding(step.next!)),
                  child: Text(strings.skipQuestion),
                ),
              ],
            ],
          ),
          if (!isReview && !session.onboardingStatus.isFinished) ...<Widget>[
            const SizedBox(height: Spacing.lg),
            const Divider(),
            const SizedBox(height: Spacing.sm),
            Text(strings.skipAllHint, style: theme.textTheme.bodyMedium),
            TextButton(
              onPressed: _skipAll,
              child: Text(strings.skipAllQuestions),
            ),
          ],
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step});

  final OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final label = strings.stepOf(step.position, OnboardingStep.total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // The words carry the progress; the bar repeats it for sighted users
        // and is hidden from assistive technology so it is not read twice.
        Text(label, style: theme.textTheme.bodyMedium),
        const SizedBox(height: Spacing.xs),
        ExcludeSemantics(
          child: LinearProgressIndicator(
            value: step.position / OnboardingStep.total,
            minHeight: 6,
            borderRadius: BorderRadius.circular(Radii.chip),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _Options extends StatelessWidget {
  const _Options({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final (index, child) in children.indexed) ...<Widget>[
          if (index > 0) const SizedBox(height: Spacing.xs),
          child,
        ],
      ],
    );
  }
}

class _Review extends ConsumerWidget {
  const _Review({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final profile = session.profile;
    final goals = ref.watch(goalsProvider).value ?? const <Goal>[];
    final goal =
        goals.where((item) => item.id == session.selectedGoal).firstOrNull;

    String joined(Iterable<String> values) =>
        values.isEmpty ? strings.noAnswer : values.join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Answer(
          label: strings.reviewGoalLabel,
          value: goal?.title ?? strings.reviewNoGoal,
          actionLabel: goal == null ? strings.chooseGoal : strings.changeGoal,
          onPressed: () => context.go(Routes.home),
        ),
        _Answer(
          label: strings.onboardingShortLabel(OnboardingStep.name),
          value: profile.preferredName ?? strings.noAnswer,
          actionLabel: strings.changeAnswer(
            strings.onboardingShortLabel(OnboardingStep.name),
          ),
          onPressed: () => context.go(Routes.onboarding(OnboardingStep.name)),
        ),
        _Answer(
          label: strings.onboardingShortLabel(OnboardingStep.education),
          value: profile.educationLevel == null
              ? strings.noAnswer
              : strings.educationLevel(profile.educationLevel!),
          actionLabel: strings.changeAnswer(
            strings.onboardingShortLabel(OnboardingStep.education),
          ),
          onPressed: () =>
              context.go(Routes.onboarding(OnboardingStep.education)),
        ),
        _Answer(
          label: strings.onboardingShortLabel(OnboardingStep.plans),
          value: profile.plannedEducation == null
              ? strings.noAnswer
              : strings.plannedEducation(profile.plannedEducation!),
          actionLabel: strings.changeAnswer(
            strings.onboardingShortLabel(OnboardingStep.plans),
          ),
          onPressed: () => context.go(Routes.onboarding(OnboardingStep.plans)),
        ),
        _Answer(
          label: strings.onboardingShortLabel(OnboardingStep.interests),
          value: joined(
            InterestArea.values
                .where(profile.interests.contains)
                .map(strings.interestArea),
          ),
          actionLabel: strings.changeAnswer(
            strings.onboardingShortLabel(OnboardingStep.interests),
          ),
          onPressed: () =>
              context.go(Routes.onboarding(OnboardingStep.interests)),
        ),
        _Answer(
          label: strings.onboardingShortLabel(OnboardingStep.priorities),
          value: joined(
            Priority.values
                .where(profile.priorities.contains)
                .map(strings.priority),
          ),
          actionLabel: strings.changeAnswer(
            strings.onboardingShortLabel(OnboardingStep.priorities),
          ),
          onPressed: () =>
              context.go(Routes.onboarding(OnboardingStep.priorities)),
        ),
        const SizedBox(height: Spacing.md),
        const StorageChoice(),
        TextButton(
          onPressed: () => context.go(Routes.yourData),
          child: Text(strings.manageData),
        ),
      ],
    );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({
    required this.label,
    required this.value,
    required this.actionLabel,
    required this.onPressed,
  });

  final String label;
  final String value;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.control),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: theme.textTheme.bodyMedium),
            const SizedBox(height: Spacing.xxs),
            Text(value, style: theme.textTheme.bodyLarge),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onPressed,
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
