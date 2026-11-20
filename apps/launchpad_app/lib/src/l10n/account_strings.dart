import 'package:launchpad_domain/launchpad_domain.dart';

/// Copy for the optional account.
///
/// An account is never required and the copy never implies it is. Errors say
/// what happened and what to do, and never repeat what the person typed.
mixin AccountStrings {
  String monthYear(DateTime date);

  String get accountTitle => 'Account and sync';

  String get accountDescription =>
      'Optional. Keep a copy of your answers in an account so another device '
      'can use it.';

  String get accountNotConfigured =>
      'This build is not connected to an account service, so there is nothing '
      'to sign in to. Everything you enter stays on this device, and every '
      'tool works without an account.';

  String get accountIntro =>
      'An account is optional. Everything in this app works without one. The '
      'only thing an account adds is a copy of your answers that another '
      'device can pick up, and only if you turn sync on.';

  String get accountNoEmail =>
      'An account is a handle and a passphrase. We do not ask for an email '
      'address or your name, which also means a forgotten passphrase cannot '
      'be reset. Your answers on this device are not affected if that '
      'happens.';

  String get handleLabel => 'Handle';

  String get handleHelp =>
      '3 to 32 letters, numbers, hyphens or underscores. Do not use your '
      'email address or real name.';

  String get passphraseLabel => 'Passphrase';

  String get passphraseHelp =>
      'At least 12 characters. Several unrelated words work well.';

  String get showPassphrase => 'Show passphrase';

  String get hidePassphrase => 'Hide passphrase';

  String get signIn => 'Sign in';

  String get createAccount => 'Create account';

  String get signOut => 'Sign out';

  String get working => 'Working…';

  String signedInAs(String handle) => 'Signed in as $handle.';

  String get signedOutStatus =>
      'Signed out. Your answers are still on this device.';

  String get accountCreated =>
      'Account created. Sync is off until you turn it on.';

  String get signedInStatus => 'Signed in. Sync is off until you turn it on.';

  // Sync.

  String get syncHeading => 'Sync';

  String get syncOffBody =>
      'Sync is off. Nothing from this device has been sent to your account.';

  String get syncWhatIsSent =>
      'If you turn it on, pressing "Sync now" sends a copy of your goal, your '
      'answers, saved occupations, plans, tool progress and notes. Nothing is '
      'sent at any other time. Text typed under "Something else" is never '
      'sent.';

  String get syncOnBody =>
      'Sync is on. A copy is sent only when you press "Sync now".';

  String get syncTurnOn => 'Turn on sync';

  String get syncTurnOff => 'Turn off sync and delete the copy in your account';

  String get syncTurnedOn => 'Sync is on. Nothing has been sent yet.';

  String get syncTurnedOff =>
      'Sync is off and the copy in your account has been deleted.';

  String get syncNow => 'Sync now';

  String get syncDone => 'Your account now holds this device’s copy.';

  String get syncConflictHeading => 'Your account holds a different copy';

  String syncConflictBody(String? saved) => saved == null
      ? 'Choose which copy to keep. The other one is replaced.'
      : 'It was saved in $saved. Choose which copy to keep. The other one is '
          'replaced.';

  String get syncUseRemote => 'Use the account’s copy on this device';

  String get syncKeepLocal => 'Keep this device’s copy';

  String get syncUsedRemote =>
      'This device now has the copy from your account.';

  // Export and deletion.

  String get accountExportHeading => 'See what your account holds';

  String get accountExportBody =>
      'Everything the account service holds about you, as it holds it.';

  String get accountExportShow => 'Show account data';

  String get accountExportFieldLabel => 'A copy of your account data';

  String get accountDeleteHeading => 'Delete your account';

  String get accountDeleteBody =>
      'Deletes the account and everything it holds. It cannot be undone. Your '
      'answers on this device are not affected.';

  String get accountDeletePassphraseLabel => 'Passphrase, to confirm';

  String get accountDeleteAction => 'Delete account';

  String get accountDeleteConfirmTitle => 'Delete your account?';

  String get accountDeleteConfirmBody =>
      'The account and the copy it holds are deleted for good. Your answers '
      'on this device stay as they are.';

  String get accountDeleted =>
      'Your account has been deleted. Your answers are still on this device.';

  String get accountLocalNote =>
      'Deleting everything on this device does not delete your account or the '
      'copy it holds. Do that here.';

  String get yourDataAccountNote =>
      'This page is about this device. If you have an account, what it holds '
      'is managed separately.';

  String accountFailure(AccountFailure failure, {int? retryAfterSeconds}) =>
      switch (failure) {
        AccountFailure.notConfigured => accountNotConfigured,
        AccountFailure.network =>
          'We could not reach the account service. Check your connection and '
              'try again.',
        AccountFailure.invalidCredentials =>
          'That handle and passphrase do not match an account. Check both and '
              'try again.',
        AccountFailure.handleTaken =>
          'That handle is already in use. Choose a different one.',
        AccountFailure.invalidHandle =>
          'A handle is 3 to 32 letters, numbers, hyphens or underscores, and '
              'cannot be an email address. Change it and try again.',
        AccountFailure.invalidPassphrase =>
          'A passphrase needs at least 12 characters. Make it longer and try '
              'again.',
        AccountFailure.incorrectPassphrase =>
          'That passphrase is not correct, so nothing was changed. Check it '
              'and try again.',
        AccountFailure.tooManyAttempts => retryAfterSeconds == null
            ? 'Too many attempts. Wait a while and try again.'
            : 'Too many attempts. Wait about '
                '${(retryAfterSeconds / 60).ceil()} minutes and try again.',
        AccountFailure.serverBusy =>
          'The account service is busy. Wait a few seconds and try again.',
        AccountFailure.signedOut =>
          'Your sign-in has ended. Sign in again to continue.',
        AccountFailure.consentRequired =>
          'Sync is off for this account, so nothing was sent. Turn sync on '
              'first.',
        AccountFailure.tooLarge =>
          'Your notes are too large to sync. Shorten or remove some and try '
              'again.',
        AccountFailure.server =>
          'The account service returned an error and nothing was changed. Try '
              'again later.',
      };
}
