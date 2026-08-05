import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:launchpad_core/launchpad_core.dart';
import 'package:launchpad_ui/launchpad_ui.dart';

import '../../l10n/app_strings.dart';
import '../../routing/app_router.dart';

/// Open-ended entry point.
///
/// Rules this screen exists to honour: do not label the user, do not treat "I
/// am not sure" as a symptom, do not ask for identity before help, and say
/// plainly where the text goes.
class SomethingElsePage extends StatefulWidget {
  const SomethingElsePage({super.key});

  @override
  State<SomethingElsePage> createState() => _SomethingElsePageState();
}

class _SomethingElsePageState extends State<SomethingElsePage> {
  final TextEditingController _controller = TextEditingController();
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  /// Rebuilds on every keystroke: the Send button's enabled state is derived
  /// from the field contents, so it has to be recomputed as the user types.
  void _onChanged() {
    setState(() => _submitted = false);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.appName),
        leading: IconButton(
          onPressed: () => context.go(Routes.home),
          icon: const Icon(Icons.arrow_back),
          tooltip: strings.backToStart,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ContentColumn(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(
                    strings.somethingElsePrompt,
                    style: theme.textTheme.headlineLarge,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  strings.somethingElseDescription,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: Spacing.lg),
                TextField(
                  controller: _controller,
                  minLines: 5,
                  maxLines: 12,
                  autofocus: false,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: strings.somethingElseFieldLabel,
                    hintText: strings.somethingElseFieldHint,
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: Spacing.xs),
                    Expanded(
                      child: Text(
                        strings.somethingElsePrivacyNote,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.lg),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _controller.text.trim().isEmpty
                        ? null
                        : () => setState(() => _submitted = true),
                    child: Text(strings.submitLabel),
                  ),
                ),
                StatusLine(
                  message: _submitted ? strings.somethingElseThanks : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
