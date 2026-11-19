import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:launchpad_core/launchpad_core.dart';
import 'package:launchpad_domain/launchpad_domain.dart';
import 'package:launchpad_ui/launchpad_ui.dart';

import '../../app/app_page.dart';
import '../../app/providers.dart';
import '../../l10n/app_strings.dart';
import '../../routing/app_router.dart';
import 'storage_choice.dart';

/// Everything a person can do about their own data, in one place: choose
/// whether it is saved, see exactly what is held, and delete it.
///
/// Export and deletion ship in the same change as storage itself, because a
/// product that can keep something must be able to show it and remove it.
class YourDataPage extends ConsumerStatefulWidget {
  const YourDataPage({super.key});

  @override
  ConsumerState<YourDataPage> createState() => _YourDataPageState();
}

class _YourDataPageState extends ConsumerState<YourDataPage> {
  String? _export;
  String? _status;

  Future<void> _confirmDelete() async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.deleteConfirmTitle),
        content: Text(strings.deleteConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.deleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(storageEnabledProvider.notifier).deleteEverything();
    if (!mounted) return;
    setState(() {
      _export = null;
      _status = strings.deletedStatus;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeading(strings.yourDataTitle),
          const SizedBox(height: Spacing.sm),
          Text(strings.yourDataIntro, style: theme.textTheme.bodyLarge),
          const SizedBox(height: Spacing.lg),
          const StorageChoice(),
          _Section(
            heading: strings.whatIsStoredHeading,
            body: strings.whatIsStoredBody,
          ),
          _Section(
            heading: strings.whatIsNotStoredHeading,
            body: strings.whatIsNotStoredBody,
          ),
          _Section(
            heading: strings.yourAnswers,
            body: strings.yourAnswersHint,
            action: OutlinedButton(
              onPressed: () =>
                  context.go(Routes.onboarding(OnboardingStep.review)),
              child: Text(strings.yourAnswers),
            ),
          ),
          _Section(
            heading: strings.exportHeading,
            body: strings.exportBody,
            action: Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.xs,
              children: <Widget>[
                OutlinedButton(
                  onPressed: () => setState(() {
                    _export =
                        ref.read(storageEnabledProvider.notifier).exportData();
                    _status = null;
                  }),
                  child: Text(strings.exportShow),
                ),
                if (_export != null)
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _export!));
                      if (!mounted) return;
                      setState(() => _status = strings.exportCopied);
                    },
                    icon: const Icon(Icons.copy),
                    label: Text(strings.exportCopy),
                  ),
              ],
            ),
          ),
          if (_export != null) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            Semantics(
              label: strings.exportFieldLabel,
              container: true,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(Radii.control),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: SelectableText(
                  _export!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
          _Section(
            heading: strings.deleteHeading,
            body: strings.deleteBody,
            action: OutlinedButton.icon(
              onPressed: session.isEmpty && !ref.watch(storageEnabledProvider)
                  ? null
                  : _confirmDelete,
              icon: const Icon(Icons.delete_outline),
              label: Text(strings.deleteAction),
            ),
          ),
          StatusLine(message: _status),
          _Section(
            heading: strings.accountTitle,
            body: '${strings.accountDescription} '
                '${strings.yourDataAccountNote}',
            action: OutlinedButton(
              onPressed: () => context.go(Routes.account),
              child: Text(strings.accountTitle),
            ),
          ),
          const SizedBox(height: Spacing.md),
          OutlinedButton.icon(
            onPressed: () => context.go(Routes.home),
            icon: const Icon(Icons.arrow_back),
            label: Text(strings.backToStart),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.heading, required this.body, this.action});

  final String heading;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeading(heading, large: false),
          const SizedBox(height: Spacing.xs),
          Text(body, style: theme.textTheme.bodyLarge),
          if (action != null) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            action!,
          ],
        ],
      ),
    );
  }
}
