import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launchpad_app/src/app/providers.dart';
import 'package:launchpad_app/src/app/shared_preferences_store.dart';
import 'package:launchpad_app/src/features/your_data/your_data_page.dart';
import 'package:launchpad_data/launchpad_data.dart';
import 'package:launchpad_domain/launchpad_domain.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'helpers.dart';

Future<void> openYourData(WidgetTester tester) async {
  await tapVisible(tester, find.widgetWithText(TextButton, 'Your data'));
  expect(find.byType(YourDataPage), findsOneWidget);
}

Session sessionOf(WidgetTester tester) => ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    ).read(sessionProvider);

void main() {
  testWidgets('explains what is and is not saved', (tester) async {
    await pumpApp(tester);
    await openYourData(tester);

    expect(find.text('Keep your answers on this device?'), findsOneWidget);
    expect(find.text('What is saved'), findsOneWidget);
    expect(find.text('What is never saved'), findsOneWidget);
    expect(find.textContaining('12 months'), findsNothing);
    expect(find.textContaining('last until you close the app'), findsOneWidget);
  });

  testWidgets('saving can be turned on and off, and off erases the copy',
      (tester) async {
    final store = InMemoryKeyValueStore();
    await pumpApp(tester, store: store);
    await chooseGoalAndContinue(tester);
    await tapVisible(tester, find.text('Skip the questions'));
    await tester.tap(find.byTooltip('Back to start'));
    await tester.pumpAndSettle();
    await openYourData(tester);

    await tapVisible(tester, find.text('Save on this device'));
    expect(
      store.snapshot.keys,
      contains(PersistentSessionRepository.sessionKey),
    );
    expect(find.textContaining('12 months'), findsOneWidget);

    await tapVisible(tester, find.text('Stop saving and erase the saved copy'));
    expect(store.snapshot, isEmpty);
    expect(
      find.text('Saving is off and the saved copy has been erased.'),
      findsOneWidget,
    );
  });

  testWidgets('shows a readable copy of everything held and copies it',
      (tester) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard =
              (call.arguments as Map<Object?, Object?>)['text']! as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await pumpApp(tester);
    await chooseGoalAndContinue(tester, title: 'Prepare for interviews');
    await tester.enterText(find.byType(TextField), 'Sam');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));
    await tester.tap(find.byTooltip('Back to start'));
    await tester.pumpAndSettle();
    await openYourData(tester);

    expect(find.text('Copy to clipboard'), findsNothing);
    await tapVisible(tester, find.text('Show my data'));
    await tapVisible(tester, find.text('Copy to clipboard'));

    expect(find.text('Copied to the clipboard.'), findsOneWidget);
    final export = jsonDecode(clipboard!) as Map<String, Object?>;
    expect(export['format'], 'launchpad-career-export');
    final session = export['session']! as Map<String, Object?>;
    expect(session['goal'], 'interview-preparation');
    expect((session['profile']! as Map)['preferredName'], 'Sam');
  });

  testWidgets('delete asks first, then removes everything', (tester) async {
    final store = InMemoryKeyValueStore();
    await pumpApp(tester, store: store);
    await chooseGoalAndContinue(tester);
    await tapVisible(tester, find.text('Skip the questions'));
    await tester.tap(find.byTooltip('Back to start'));
    await tester.pumpAndSettle();
    await openYourData(tester);
    await tapVisible(tester, find.text('Save on this device'));
    expect(store.snapshot, isNotEmpty);

    await tapVisible(
      tester,
      find.widgetWithText(OutlinedButton, 'Delete everything'),
    );
    expect(find.text('Delete everything you have entered?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.snapshot, isNotEmpty);
    expect(sessionOf(tester).selectedGoal, GoalId.internshipOrJob);

    await tapVisible(
      tester,
      find.widgetWithText(OutlinedButton, 'Delete everything'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Delete everything'));
    await tester.pumpAndSettle();

    expect(store.snapshot, isEmpty);
    expect(sessionOf(tester), const Session());
    expect(
      find.text('Everything you entered has been deleted.'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Back to start'));
    await tester.pumpAndSettle();
    expect(find.text('Pick up where you left off'), findsNothing);
  });

  testWidgets('delete is unavailable when there is nothing to delete',
      (tester) async {
    await pumpApp(tester);
    await openYourData(tester);
    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Delete everything'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Something else text is held for the session but never saved',
      (tester) async {
    final store = InMemoryKeyValueStore();
    await pumpApp(tester, store: store);
    await openYourData(tester);
    await tapVisible(tester, find.text('Save on this device'));
    await tester.tap(find.byTooltip('Back to start'));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Something else'));
    await tester.enterText(find.byType(TextField), 'I have two offers.');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Send'));

    expect(sessionOf(tester).freeTextPrompt, 'I have two offers.');
    expect(store.snapshot.values.join(), isNot(contains('two offers')));
  });

  testWidgets('meets the guidelines in both themes, with the copy shown',
      (tester) async {
    for (final brightness in Brightness.values) {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, platformBrightness: brightness);
      await chooseGoalAndContinue(tester);
      await tapVisible(tester, find.text('Skip the questions'));
      await tester.tap(find.byTooltip('Back to start'));
      await tester.pumpAndSettle();
      await openYourData(tester);
      await tapVisible(tester, find.text('Show my data'));

      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('survives 2x text on a phone', (tester) async {
    await pumpApp(
      tester,
      surfaceSize: const Size(360, 740),
      textScaleFactor: 2.0,
    );
    await openYourData(tester);
    await tapVisible(tester, find.text('Show my data'));
    expect(tester.takeException(), isNull);
  });

  group('SharedPreferencesStore', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test('reads back what it writes and deletes on request', () async {
      final store = await SharedPreferencesStore.open();
      expect(store.read(PersistentSessionRepository.sessionKey), isNull);

      await store.write(PersistentSessionRepository.sessionKey, 'value');
      expect(store.read(PersistentSessionRepository.sessionKey), 'value');

      final reopened = await SharedPreferencesStore.open();
      expect(reopened.read(PersistentSessionRepository.sessionKey), 'value');

      await store.delete(PersistentSessionRepository.sessionKey);
      expect(store.read(PersistentSessionRepository.sessionKey), isNull);
    });

    test('refuses keys the session repository does not own', () async {
      final store = await SharedPreferencesStore.open();
      expect(
        () => store.write('some.other.key', 'value'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('carries a session across a restart end to end', () async {
      final first = PersistentSessionRepository(
        await SharedPreferencesStore.open(),
      );
      await first.enableStorage();
      await first.update(const Session(selectedGoal: GoalId.direction));

      final second = PersistentSessionRepository(
        await SharedPreferencesStore.open(),
      );
      expect(second.storageEnabled, isTrue);
      expect(second.current().selectedGoal, GoalId.direction);
    });
  });
}
