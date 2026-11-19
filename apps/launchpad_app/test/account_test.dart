import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launchpad_app/src/app/providers.dart';
import 'package:launchpad_app/src/features/account/account_page.dart';
import 'package:launchpad_app/src/features/explore/explore_page.dart';
import 'package:launchpad_app/src/features/goal/goal_page.dart';
import 'package:launchpad_app/src/routing/app_router.dart';
import 'package:launchpad_domain/launchpad_domain.dart';

import 'helpers.dart';

const String passphrase = 'correct horse battery';

Finder field(String label) => find.widgetWithText(TextField, label);

Future<void> enter(
  WidgetTester tester, {
  required String handle,
  required String secret,
  required String action,
}) async {
  await tester.ensureVisible(field('Handle'));
  await tester.enterText(field('Handle'), handle);
  await tester.enterText(field('Passphrase'), secret);
  await tapVisible(
    tester,
    find.ancestor(
      of: find.text(action),
      matching: find.bySubtype<ButtonStyleButton>(),
    ),
  );
}

Future<FakeAccountRepository> signedIn(
  WidgetTester tester, {
  FakeAccountRepository? service,
  bool create = true,
}) async {
  final account = service ?? FakeAccountRepository();
  await pumpApp(tester, account: account);
  await goTo(tester, Routes.account);
  await enter(
    tester,
    handle: 'sam_k',
    secret: passphrase,
    action: create ? 'Create account' : 'Sign in',
  );
  return account;
}

void main() {
  group('without an account service', () {
    testWidgets('the page says so and offers nothing to fill in',
        (tester) async {
      await pumpApp(tester);
      await tapVisible(tester, find.widgetWithText(TextButton, 'Your data'));
      await tapVisible(
        tester,
        find.widgetWithText(OutlinedButton, 'Account and sync'),
      );

      expect(find.byType(AccountPage), findsOneWidget);
      expect(
        find.textContaining('not connected to an account service'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('an account is never a gate', () {
    testWidgets('every part of the app works signed out', (tester) async {
      await pumpApp(tester, account: FakeAccountRepository());
      await chooseGoalAndContinue(tester);
      await tapVisible(tester, find.text('Skip the questions'));
      expect(find.byType(GoalPage), findsOneWidget);
      await goTo(tester, Routes.explore);
      expect(find.byType(ExplorePage), findsOneWidget);
      expect(find.byType(AccountPage), findsNothing);
    });

    testWidgets('the page says an account is optional and asks for no email',
        (tester) async {
      await pumpApp(tester, account: FakeAccountRepository());
      await goTo(tester, Routes.account);
      expect(find.textContaining('An account is optional'), findsOneWidget);
      expect(
        find.textContaining('We do not ask for an email address'),
        findsOneWidget,
      );
      expect(find.textContaining('cannot be reset'), findsOneWidget);
    });
  });

  group('signing in', () {
    testWidgets('create an account, sign out, sign back in', (tester) async {
      final account = await signedIn(tester);

      expect(find.text('Signed in as sam_k.'), findsOneWidget);
      expect(
        find.text('Account created. Sync is off until you turn it on.'),
        findsOneWidget,
      );
      expect(account.hasAccount('sam_k'), isTrue);

      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Sign out'));
      expect(find.textContaining('Signed out.'), findsOneWidget);
      expect(field('Handle'), findsOneWidget);

      await enter(
        tester,
        handle: 'sam_k',
        secret: passphrase,
        action: 'Sign in',
      );
      expect(find.text('Signed in as sam_k.'), findsOneWidget);
    });

    testWidgets('a malformed handle is caught before anything is sent',
        (tester) async {
      final account = FakeAccountRepository();
      await pumpApp(tester, account: account);
      await goTo(tester, Routes.account);
      await enter(
        tester,
        handle: 'sam@example.org',
        secret: passphrase,
        action: 'Create account',
      );

      expect(
        find.textContaining('cannot be an email address'),
        findsOneWidget,
      );
      expect(account.hasAccount('sam@example.org'), isFalse);
    });

    testWidgets('a short passphrase is caught before anything is sent',
        (tester) async {
      final account = FakeAccountRepository();
      await pumpApp(tester, account: account);
      await goTo(tester, Routes.account);
      await enter(
        tester,
        handle: 'sam_k',
        secret: 'short',
        action: 'Create account',
      );
      expect(find.textContaining('at least 12 characters'), findsWidgets);
      expect(account.hasAccount('sam_k'), isFalse);
    });

    testWidgets('wrong credentials are explained without saying which',
        (tester) async {
      final account = FakeAccountRepository()
        ..seed('sam_k', passphrase, const Session());
      await pumpApp(tester, account: account);
      await goTo(tester, Routes.account);
      await enter(
        tester,
        handle: 'sam_k',
        secret: 'wrong wrong wrong',
        action: 'Sign in',
      );
      expect(
        find.text(
          'That handle and passphrase do not match an account. Check both '
          'and try again.',
        ),
        findsOneWidget,
      );
      expect(field('Handle'), findsOneWidget);
    });

    testWidgets('each failure says what happened and what to do',
        (tester) async {
      final cases = <AccountFailure, String>{
        AccountFailure.network: 'Check your connection and try again',
        AccountFailure.handleTaken: 'Choose a different one',
        AccountFailure.tooManyAttempts: 'Wait about 10 minutes',
        AccountFailure.serverBusy: 'Wait a few seconds',
        AccountFailure.server: 'Try again later',
      };
      for (final entry in cases.entries) {
        final account = FakeAccountRepository()..failNext = entry.key;
        await pumpApp(tester, account: account);
        await goTo(tester, Routes.account);
        await enter(
          tester,
          handle: 'sam_k',
          secret: passphrase,
          action: 'Create account',
        );
        expect(
          find.textContaining(entry.value),
          findsOneWidget,
          reason: entry.key.name,
        );
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('the passphrase is hidden until asked for', (tester) async {
      await pumpApp(tester, account: FakeAccountRepository());
      await goTo(tester, Routes.account);
      expect(
        tester.widget<TextField>(field('Passphrase')).obscureText,
        isTrue,
      );
      await tapVisible(tester, find.byTooltip('Show passphrase'));
      expect(
        tester.widget<TextField>(field('Passphrase')).obscureText,
        isFalse,
      );
      expect(find.byTooltip('Hide passphrase'), findsOneWidget);
    });
  });

  group('sync', () {
    testWidgets('is off by default and nothing is sent until asked',
        (tester) async {
      final account = await signedIn(tester);

      expect(
        find.textContaining('Nothing from this device has been sent'),
        findsOneWidget,
      );
      expect(find.text('Sync now'), findsNothing);
      expect(account.uploads, isEmpty);

      await tapVisible(tester, find.text('Turn on sync'));
      expect(
        find.text('Sync is on. Nothing has been sent yet.'),
        findsOneWidget,
      );
      expect(account.uploads, isEmpty);
    });

    testWidgets('says what is sent, and that Something else never is',
        (tester) async {
      await signedIn(tester);
      expect(
        find.textContaining('Text typed under "Something else" is never sent'),
        findsOneWidget,
      );
    });

    testWidgets('Sync now sends the session without the free text',
        (tester) async {
      final account = await signedIn(tester);
      containerOf(tester).read(sessionProvider.notifier)
        ..chooseGoal(GoalId.direction)
        ..setFreeText('I have two offers.')
        ..toggleSaved('electrician');
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('Turn on sync'));
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Sync now'));

      expect(
        find.text('Your account now holds this device’s copy.'),
        findsOneWidget,
      );
      expect(account.uploads.single.selectedGoal, GoalId.direction);
      expect(account.uploads.single.workspace.isSaved('electrician'), isTrue);
      expect(account.uploads.single.freeTextPrompt, isNull);
    });

    testWidgets(
        'a different copy on the account is never overwritten '
        'silently; the person can take it', (tester) async {
      final service = FakeAccountRepository()
        ..seed(
          'sam_k',
          passphrase,
          const Session(selectedGoal: GoalId.interviewPreparation),
        );
      await signedIn(tester, service: service, create: false);
      final session = containerOf(tester).read(sessionProvider.notifier)
        ..chooseGoal(GoalId.direction)
        ..setFreeText('A local note.');
      expect(session, isNotNull);
      await tester.pumpAndSettle();

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Sync now'));

      expect(find.text('Your account holds a different copy'), findsWidgets);
      expect(
        find.textContaining('It was saved in October 2026'),
        findsOneWidget,
      );
      expect(
        service.stored('sam_k')!.session.selectedGoal,
        GoalId.interviewPreparation,
      );
      expect(
        containerOf(tester).read(sessionProvider).selectedGoal,
        GoalId.direction,
      );

      await tapVisible(
        tester,
        find.text('Use the account’s copy on this device'),
      );
      final local = containerOf(tester).read(sessionProvider);
      expect(local.selectedGoal, GoalId.interviewPreparation);
      expect(local.freeTextPrompt, 'A local note.');
      expect(
        find.text('This device now has the copy from your account.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Sync now'), findsOneWidget);
    });

    testWidgets('or keep this device\'s copy instead', (tester) async {
      final service = FakeAccountRepository()
        ..seed(
          'sam_k',
          passphrase,
          const Session(selectedGoal: GoalId.interviewPreparation),
        );
      await signedIn(tester, service: service, create: false);
      containerOf(tester)
          .read(sessionProvider.notifier)
          .chooseGoal(GoalId.direction);
      await tester.pumpAndSettle();

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Sync now'));
      await tapVisible(tester, find.text('Keep this device’s copy'));

      expect(service.stored('sam_k')!.session.selectedGoal, GoalId.direction);
      expect(service.stored('sam_k')!.revision, 2);
      expect(
        find.text('Your account now holds this device’s copy.'),
        findsOneWidget,
      );
    });

    testWidgets('turning sync off deletes the copy and says so',
        (tester) async {
      final account = await signedIn(tester);
      await tapVisible(tester, find.text('Turn on sync'));
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Sync now'));
      expect(account.stored('sam_k'), isNotNull);

      await tapVisible(
        tester,
        find.text('Turn off sync and delete the copy in your account'),
      );
      expect(account.stored('sam_k'), isNull);
      expect(
        find.text('Sync is off and the copy in your account has been deleted.'),
        findsOneWidget,
      );
      expect(find.text('Sync now'), findsNothing);
    });

    testWidgets('an ended sign-in returns to the sign-in form with a reason',
        (tester) async {
      final account = await signedIn(tester);
      await tapVisible(tester, find.text('Turn on sync'));
      account.failNext = AccountFailure.signedOut;
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Sync now'));

      expect(
        find.text('Your sign-in has ended. Sign in again to continue.'),
        findsOneWidget,
      );
      expect(field('Handle'), findsOneWidget);
    });
  });

  group('export and deletion', () {
    testWidgets('shows what the account holds', (tester) async {
      await signedIn(tester);
      await tapVisible(tester, find.text('Show account data'));
      expect(find.textContaining('"handle": "sam_k"'), findsOneWidget);
    });

    testWidgets('deletion needs the passphrase and a confirmation',
        (tester) async {
      final account = await signedIn(tester);
      containerOf(tester)
          .read(sessionProvider.notifier)
          .chooseGoal(GoalId.direction);
      await tester.pumpAndSettle();

      final confirm = field('Passphrase, to confirm');
      await tester.ensureVisible(confirm);
      await tester.enterText(confirm, 'wrong wrong wrong');
      await tapVisible(
        tester,
        find.widgetWithText(OutlinedButton, 'Delete account'),
      );
      expect(find.text('Delete your account?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('That passphrase is not correct'),
        findsOneWidget,
      );
      expect(account.hasAccount('sam_k'), isTrue);

      await tester.ensureVisible(confirm);
      await tester.enterText(confirm, passphrase);
      await tapVisible(
        tester,
        find.widgetWithText(OutlinedButton, 'Delete account'),
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(account.hasAccount('sam_k'), isTrue);

      await tapVisible(
        tester,
        find.widgetWithText(OutlinedButton, 'Delete account'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
      await tester.pumpAndSettle();

      expect(account.hasAccount('sam_k'), isFalse);
      expect(
        find.textContaining('Your account has been deleted.'),
        findsOneWidget,
      );
      expect(
        containerOf(tester).read(sessionProvider).selectedGoal,
        GoalId.direction,
        reason: 'answers on the device are not touched',
      );
    });
  });

  group('accessibility', () {
    Future<void> signedOutPage(WidgetTester tester) async {
      await goTo(tester, Routes.account);
    }

    Future<void> signedInPage(WidgetTester tester) async {
      await goTo(tester, Routes.account);
      await enter(
        tester,
        handle: 'sam_k',
        secret: passphrase,
        action: 'Sign in',
      );
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Sync now'));
      await tapVisible(tester, find.text('Show account data'));
    }

    final states = <String, Future<void> Function(WidgetTester)>{
      'signed out': signedOutPage,
      'signed in with a conflict': signedInPage,
    };

    FakeAccountRepository service() => FakeAccountRepository()
      ..seed(
        'sam_k',
        passphrase,
        const Session(selectedGoal: GoalId.direction),
      );

    for (final entry in states.entries) {
      testWidgets('${entry.key} meets the guidelines in both themes',
          (tester) async {
        for (final brightness in Brightness.values) {
          final handle = tester.ensureSemantics();
          await pumpApp(
            tester,
            platformBrightness: brightness,
            account: service(),
          );
          await entry.value(tester);
          await expectMeetsGuidelines(tester);
          handle.dispose();
          await tester.pumpWidget(const SizedBox());
        }
      });

      testWidgets('${entry.key} survives 2x text on a phone', (tester) async {
        await pumpApp(
          tester,
          surfaceSize: const Size(360, 740),
          textScaleFactor: 2.0,
          account: service(),
        );
        await entry.value(tester);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the not-connected page meets the guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester);
      await goTo(tester, Routes.account);
      await expectMeetsGuidelines(tester);
      handle.dispose();
    });
  });
}
