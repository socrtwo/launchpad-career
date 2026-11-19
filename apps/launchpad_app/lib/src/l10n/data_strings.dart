/// Copy for storage, export and deletion.
///
/// These sentences are promises about behaviour, so each one is backed by a
/// test in `packages/launchpad_data/test` or `test/your_data_test.dart`.
/// Nothing here claims regulatory compliance.
mixin DataStrings {
  String get yourDataTitle => 'Your data';

  String get yourDataIntro =>
      'What you enter is kept on this device. There are no accounts in this '
      'build and your answers are not sent to us.';

  String get storageHeading => 'Keep your answers on this device?';

  String get storageOffBody =>
      'Right now your answers last until you close the app. If you choose to '
      'save them, they stay on this device so you can pick up where you left '
      'off. You can erase them at any time.';

  String get storageOnBody =>
      'Your answers are saved on this device. They are erased if you turn '
      'saving off, and automatically if you do not open the app for 12 months.';

  String get storageUnavailable =>
      'This device or browser does not allow saving. Your answers stay until '
      'you close the app.';

  String get storageEnable => 'Save on this device';

  String get storageDisable => 'Stop saving and erase the saved copy';

  String get storageEnabledStatus => 'Saved on this device.';

  String get storageDisabledStatus =>
      'Saving is off and the saved copy has been erased.';

  String get storageProblem =>
      'We could not save your latest change on this device. Your answers are '
      'still here until you close the app. Check that the device has free '
      'space, then turn saving off and on again.';

  String get whatIsStoredHeading => 'What is saved';

  String get whatIsStoredBody =>
      'If you turn saving on: the goal you chose, your answers to the '
      'questions, and the step you reached. Nothing else.';

  String get whatIsNotStoredHeading => 'What is never saved';

  String get whatIsNotStoredBody =>
      'Anything you type under "Something else" is kept only until you close '
      'the app, even when saving is on.';

  String get manageData => 'Manage your data';

  String get exportHeading => 'See a copy of your data';

  String get exportBody =>
      'This is everything the app currently holds about you, in a format you '
      'can read and keep.';

  String get exportShow => 'Show my data';

  String get exportCopy => 'Copy to clipboard';

  String get exportCopied => 'Copied to the clipboard.';

  String get exportFieldLabel => 'A copy of your data';

  String get deleteHeading => 'Delete everything';

  String get deleteBody =>
      'Erases the saved copy and clears your answers from this session. This '
      'cannot be undone.';

  String get deleteAction => 'Delete everything';

  String get deleteConfirmTitle => 'Delete everything you have entered?';

  String get deleteConfirmBody =>
      'This erases the saved copy and clears your goal and answers. It cannot '
      'be undone.';

  String get cancel => 'Cancel';

  String get deletedStatus => 'Everything you entered has been deleted.';

  String get resumeHeading => 'Pick up where you left off';

  String resumeBodyGoal(String goalTitle) => 'Your goal: $goalTitle';

  String resumeGreeting(String name) => 'Welcome back, $name.';

  String resumeAnswers(int answered, int total) =>
      'You have answered $answered of $total questions.';

  String get resumeAction => 'Continue where you left off';

  String get yourAnswers => 'Your answers';

  String get yourAnswersHint =>
      'See or change what you told us, and choose whether it is saved.';
}
