import 'package:flutter/material.dart';

import 'data_strings.dart';
import 'explore_strings.dart';
import 'onboarding_strings.dart';
import 'tools_strings.dart';

/// Hand-written localisation table.
///
/// Why not `gen_l10n`/ARB yet: codegen adds a build step to every checkout for
/// one locale's worth of strings. The shape here (a delegate + a subclassable
/// string table) is the same shape `gen_l10n` produces, so moving to ARB later
/// is a mechanical change confined to this folder. Goal titles and blurbs are
/// intentionally *not* here - they come from the catalogue repository, because
/// they are editorial content destined for a CMS.
@immutable
class AppStrings
    with OnboardingStrings, DataStrings, ExploreStrings, ToolsStrings {
  const AppStrings();

  static const AppStrings en = AppStrings();

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ?? en;

  String get appName => 'Launchpad Career';

  String get tagline =>
      'Practical career guidance for college students, graduate students, and '
      'recent graduates. Start with one goal, and we will help you turn it into '
      'a realistic plan.';

  String get mainQuestion => 'What can we help you with today?';

  String get instruction =>
      'Choose one to start. You can return to the other options anytime.';

  String get somethingElseTitle => 'Something else';

  String get somethingElseDescription =>
      'Tell us what is on your mind, including if you feel stuck or are not '
      'sure where to begin.';

  String get continueLabel => 'Continue';

  String get continueHintDisabled => 'Choose an option above to continue.';

  String selectionAnnouncement(String title) => 'Selected: $title';

  String get goalsUnavailable =>
      'We could not load the options just now. Check your connection and try '
      'again.';

  String get retry => 'Try again';

  String get loading => 'Loading options';

  String get backToStart => 'Back to start';

  String get goalToolsHeading => 'Start here';

  String get goalLinkUnknown => 'That goal link is not one we recognise.';

  String get pageNotFoundTitle => 'Page not found';

  String get pageNotFoundBody => 'That page does not exist.';

  String get goToStart => 'Go to the start';

  String get footerAbout => 'About';

  String get footerPrivacy => 'Privacy';

  String get footerAccessibility => 'Accessibility';

  String get somethingElsePrompt => 'What is on your mind?';

  String get somethingElseFieldLabel => 'Describe your situation';

  String get somethingElseFieldHint =>
      'For example: what you are studying, what you have tried, and what is '
      'making the decision hard.';

  String get somethingElsePrivacyNote =>
      'What you type stays on this device until you close the app. It is not '
      'sent to us and it is never saved, and you do not need an account.';

  String get submitLabel => 'Send';

  String get somethingElseThanks =>
      'Thanks - we have your note. In a later release this starts a short '
      'conversation that ends with two or three concrete next steps.';

  String get aboutTitle => 'About Launchpad Career';

  String get aboutBody =>
      'Launchpad Career helps students, recent graduates, and career changers '
      'turn a goal into a realistic plan. It is a career-planning and '
      'employment-guidance tool. It is not a mental-health service, and it does '
      'not give medical, psychological, or legal advice.';

  String get privacyTitle => 'Privacy';

  String get privacyBody =>
      'This is not yet a reviewed privacy notice; one must be published before '
      'release. What is true of this build: there are no accounts, what you '
      'enter stays on this device, nothing is saved unless you choose it, and '
      'you can see or delete it at any time under Your data.';

  String get accessibilityTitle => 'Accessibility';

  String get accessibilityBody =>
      'Placeholder for the published accessibility statement. Current targets '
      'and known gaps are listed in docs/accessibility/accessibility-requirements.md.';

  String get noGuarantee =>
      'Launchpad Career offers guidance, not guarantees about admission, hiring, '
      'or pay.';
}

class AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const AppStringsDelegate();

  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<AppStrings> load(Locale locale) async => AppStrings.en;

  @override
  bool shouldReload(AppStringsDelegate old) => false;
}
