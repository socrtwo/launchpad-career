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

/// The optional account: sign in, choose whether to sync, see what the
/// service holds, and delete it.
///
/// Rules this screen exists to honour: an account is never a gate; nothing is
/// sent until the person signs in, turns sync on and presses "Sync now"; a
/// difference between copies is settled by the person, never silently; and
/// export and deletion sit next to the thing they apply to.
class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  final TextEditingController _handle = TextEditingController();
  final TextEditingController _passphrase = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _showPassphrase = false;
  bool _busy = false;
  String? _status;
  bool? _consent;
  RemoteProfile? _conflict;
  String? _export;

  static final RegExp _handlePattern = RegExp(r'^[a-zA-Z0-9_-]{3,32}$');

  @override
  void initState() {
    super.initState();
    if (ref.read(accountProvider) != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadConsent());
    }
  }

  @override
  void dispose() {
    _handle.dispose();
    _passphrase.dispose();
    _confirm.dispose();
    super.dispose();
  }

  AccountController get _account => ref.read(accountProvider.notifier);

  /// Runs an account action with the controls disabled, and turns any
  /// failure into a sentence. Returns whether it succeeded.
  Future<bool> _run(Future<void> Function() action, {String? done}) async {
    final strings = AppStrings.of(context);
    setState(() {
      _busy = true;
      _status = strings.working;
    });
    try {
      await action();
      if (mounted) {
        setState(() {
          // An action may have set its own message; only the placeholder is
          // replaced or cleared here.
          if (done != null) {
            _status = done;
          } else if (_status == strings.working) {
            _status = null;
          }
        });
      }
      return true;
    } on AccountException catch (error) {
      if (mounted) {
        setState(
          () => _status = strings.accountFailure(
            error.failure,
            retryAfterSeconds: error.retryAfterSeconds,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadConsent() => _run(() async {
        final consent = await _account.syncConsent();
        if (mounted) setState(() => _consent = consent);
      });

  Future<void> _enter({required bool create}) async {
    final strings = AppStrings.of(context);
    // Checked here first so an obviously malformed entry costs no request.
    if (!_handlePattern.hasMatch(_handle.text.trim())) {
      setState(
        () => _status = strings.accountFailure(AccountFailure.invalidHandle),
      );
      return;
    }
    if (_passphrase.text.runes.length < 12) {
      setState(
        () =>
            _status = strings.accountFailure(AccountFailure.invalidPassphrase),
      );
      return;
    }
    final ok = await _run(
      () => create
          ? _account.createAccount(_handle.text, _passphrase.text)
          : _account.signIn(_handle.text, _passphrase.text),
      done: create ? strings.accountCreated : strings.signedInStatus,
    );
    if (!ok || !mounted) return;
    _passphrase.clear();
    setState(() {
      _consent = false;
      _conflict = null;
      _export = null;
    });
    if (!create) {
      final done = _status;
      await _loadConsent();
      if (mounted && _status == null) setState(() => _status = done);
    }
  }

  Future<void> _sync({int? baseRevision}) async {
    final strings = AppStrings.of(context);
    await _run(() async {
      final result = await _account.upload(baseRevision: baseRevision);
      if (!mounted) return;
      switch (result) {
        case SyncUploaded():
          setState(() {
            _conflict = null;
            _status = strings.syncDone;
          });
        case SyncConflict(:final remote):
          setState(() {
            _conflict = remote;
            _status = strings.syncConflictHeading;
          });
      }
    });
  }

  Future<void> _delete() async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.accountDeleteConfirmTitle),
        content: Text(strings.accountDeleteConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.accountDeleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await _run(
      () => _account.deleteAccount(_confirm.text),
      done: strings.accountDeleted,
    );
    if (ok && mounted) {
      _confirm.clear();
      setState(() {
        _consent = null;
        _conflict = null;
        _export = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final configured = ref.watch(accountRepositoryProvider) != null;
    final account = ref.watch(accountProvider);

    return AppPage(
      backLocation: Routes.yourData,
      backLabel: strings.yourDataTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PageHeading(strings.accountTitle),
          const SizedBox(height: Spacing.sm),
          if (!configured)
            NoticeCard(text: strings.accountNotConfigured)
          else ...<Widget>[
            Text(strings.accountIntro, style: theme.textTheme.bodyLarge),
            const SizedBox(height: Spacing.sm),
            if (account == null)
              ..._signedOut(strings, theme)
            else
              ..._signedIn(strings, theme, account),
          ],
          const SizedBox(height: Spacing.lg),
          OutlinedButton.icon(
            onPressed: () => context.go(Routes.yourData),
            icon: const Icon(Icons.arrow_back),
            label: Text(strings.yourDataTitle),
          ),
        ],
      ),
    );
  }

  List<Widget> _signedOut(AppStrings strings, ThemeData theme) => <Widget>[
        NoticeCard(text: strings.accountNoEmail),
        const SizedBox(height: Spacing.md),
        TextField(
          controller: _handle,
          enabled: !_busy,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.next,
          autofillHints: const <String>[AutofillHints.username],
          decoration: InputDecoration(
            labelText: strings.handleLabel,
            helperText: strings.handleHelp,
            helperMaxLines: 3,
          ),
        ),
        const SizedBox(height: Spacing.sm),
        TextField(
          controller: _passphrase,
          enabled: !_busy,
          obscureText: !_showPassphrase,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const <String>[AutofillHints.password],
          decoration: InputDecoration(
            labelText: strings.passphraseLabel,
            helperText: strings.passphraseHelp,
            helperMaxLines: 3,
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => _showPassphrase = !_showPassphrase),
              icon: Icon(
                _showPassphrase ? Icons.visibility_off : Icons.visibility,
              ),
              tooltip: _showPassphrase
                  ? strings.hidePassphrase
                  : strings.showPassphrase,
            ),
          ),
        ),
        const SizedBox(height: Spacing.md),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.xs,
          children: <Widget>[
            FilledButton(
              onPressed: _busy ? null : () => _enter(create: false),
              child: Text(strings.signIn),
            ),
            OutlinedButton(
              onPressed: _busy ? null : () => _enter(create: true),
              child: Text(strings.createAccount),
            ),
          ],
        ),
        StatusLine(message: _status),
      ];

  List<Widget> _signedIn(
    AppStrings strings,
    ThemeData theme,
    AccountStatus account,
  ) {
    final consent = _consent;
    final conflict = _conflict;
    final export = _export;
    final saved = conflict?.updatedAt;

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(top: Spacing.lg, bottom: Spacing.xs),
          child: PageHeading(text, large: false),
        );

    return <Widget>[
      Text(
        strings.signedInAs(account.handle),
        style: theme.textTheme.titleMedium,
      ),
      const SizedBox(height: Spacing.xs),
      OutlinedButton(
        onPressed: _busy
            ? null
            : () async {
                await _run(
                  _account.signOut,
                  done: strings.signedOutStatus,
                );
                if (mounted) {
                  setState(() {
                    _consent = null;
                    _conflict = null;
                    _export = null;
                  });
                }
              },
        child: Text(strings.signOut),
      ),
      StatusLine(message: _status),
      heading(strings.syncHeading),
      if (consent != true) ...<Widget>[
        Text(strings.syncOffBody, style: theme.textTheme.bodyLarge),
        const SizedBox(height: Spacing.xs),
        Text(strings.syncWhatIsSent, style: theme.textTheme.bodyMedium),
        const SizedBox(height: Spacing.sm),
        FilledButton.tonal(
          onPressed: _busy || consent == null
              ? null
              : () async {
                  final ok = await _run(
                    () => _account.setSyncConsent(granted: true),
                    done: strings.syncTurnedOn,
                  );
                  if (ok && mounted) setState(() => _consent = true);
                },
          child: Text(strings.syncTurnOn),
        ),
      ] else ...<Widget>[
        Text(strings.syncOnBody, style: theme.textTheme.bodyLarge),
        const SizedBox(height: Spacing.xs),
        Text(strings.syncWhatIsSent, style: theme.textTheme.bodyMedium),
        const SizedBox(height: Spacing.sm),
        if (conflict != null)
          NoticeCard(
            title: strings.syncConflictHeading,
            text: strings.syncConflictBody(
              saved == null ? null : strings.monthYear(saved),
            ),
            icon: Icons.call_split,
            action: Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.xs,
              children: <Widget>[
                FilledButton.tonal(
                  onPressed: _busy
                      ? null
                      : () async {
                          final ok = await _run(
                            () => _account.useRemote(conflict),
                            done: strings.syncUsedRemote,
                          );
                          if (ok && mounted) setState(() => _conflict = null);
                        },
                  child: Text(strings.syncUseRemote),
                ),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _sync(baseRevision: conflict.revision),
                  child: Text(strings.syncKeepLocal),
                ),
              ],
            ),
          )
        else
          FilledButton(
            onPressed: _busy ? null : _sync,
            child: Text(strings.syncNow),
          ),
        const SizedBox(height: Spacing.sm),
        OutlinedButton(
          onPressed: _busy
              ? null
              : () async {
                  final ok = await _run(
                    () => _account.setSyncConsent(granted: false),
                    done: strings.syncTurnedOff,
                  );
                  if (ok && mounted) {
                    setState(() {
                      _consent = false;
                      _conflict = null;
                    });
                  }
                },
          child: Text(strings.syncTurnOff),
        ),
      ],
      heading(strings.accountExportHeading),
      Text(strings.accountExportBody, style: theme.textTheme.bodyLarge),
      const SizedBox(height: Spacing.sm),
      OutlinedButton(
        onPressed: _busy
            ? null
            : () => _run(() async {
                  final text = await _account.exportData();
                  if (mounted) setState(() => _export = text);
                }),
        child: Text(strings.accountExportShow),
      ),
      if (export != null) ...<Widget>[
        const SizedBox(height: Spacing.sm),
        Semantics(
          label: strings.accountExportFieldLabel,
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
              export,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ],
      heading(strings.accountDeleteHeading),
      Text(strings.accountDeleteBody, style: theme.textTheme.bodyLarge),
      const SizedBox(height: Spacing.sm),
      TextField(
        controller: _confirm,
        enabled: !_busy,
        obscureText: true,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: strings.accountDeletePassphraseLabel,
        ),
      ),
      const SizedBox(height: Spacing.sm),
      OutlinedButton.icon(
        onPressed: _busy ? null : _delete,
        icon: const Icon(Icons.delete_outline),
        label: Text(strings.accountDeleteAction),
      ),
      const SizedBox(height: Spacing.sm),
      Text(strings.accountLocalNote, style: theme.textTheme.bodyMedium),
    ];
  }
}
