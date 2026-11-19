import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:launchpad_data/launchpad_data.dart';
import 'package:launchpad_domain/launchpad_domain.dart';
import 'package:launchpad_server/launchpad_server.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:test/test.dart';

/// These tests run the app's account client against the real server handler,
/// in process and without sockets. They are the contract between the two: if
/// either side changes the interface, this file fails.

const String adminToken = 'admin-token-for-tests-0123456789';
const String passphrase = 'correct horse battery';
final Uri baseUrl = Uri.parse('https://sync.example.org');

/// Everything the client sent, for asserting on what left the device.
class Wire {
  final List<http.Request> requests = <http.Request>[];

  String get everything => requests
      .map((request) => '${request.method} ${request.url} ${request.body}')
      .join('\n');
}

http.Client clientFor(shelf.Handler handler, [Wire? wire]) =>
    MockClient((request) async {
      wire?.requests.add(request);
      final response = await handler(
        shelf.Request(
          request.method,
          request.url,
          headers: request.headers,
          body: request.bodyBytes,
        ),
      );
      final bytes = <int>[];
      await response.read().forEach(bytes.addAll);
      return http.Response.bytes(
        bytes,
        response.statusCode,
        headers: response.headers,
      );
    });

class Fixture {
  Fixture({DateTime Function()? clock})
      : serverStore = InMemoryServerStore(),
        wire = Wire() {
    handler = buildHandler(
      ServerConfig(adminToken: adminToken, pbkdf2Iterations: 2),
      serverStore,
      clock: clock,
    );
  }

  final InMemoryServerStore serverStore;
  final Wire wire;
  late final shelf.Handler handler;

  HttpAccountRepository device({
    KeyValueStore? store,
    bool mayPersist = false,
    DateTime Function()? clock,
  }) =>
      HttpAccountRepository(
        baseUrl: baseUrl,
        client: clientFor(handler, wire),
        store: store ?? InMemoryKeyValueStore(),
        mayPersist: () => mayPersist,
        clock: clock,
      );
}

final Session answers = Session(
  selectedGoal: GoalId.internshipOrJob,
  freeTextPrompt: 'I have two offers and cannot choose.',
  onboardingStatus: OnboardingStatus.completed,
  profile: const Profile().copyWith(
    preferredName: 'Sam',
    interests: <InterestArea>{InterestArea.data},
  ),
  workspace: const Workspace()
      .toggleSaved('electrician')
      .withNote('interview/teamwork/action', 'Rewrote the rota.'),
);

Matcher throwsFailure(AccountFailure failure) => throwsA(
      isA<AccountException>().having((e) => e.failure, 'failure', failure),
    );

void main() {
  group('accounts', () {
    test('create, sign out, sign in', () async {
      final fixture = Fixture();
      final device = fixture.device();

      final created = await device.createAccount(
        handle: 'Sam_K',
        passphrase: passphrase,
      );
      expect(created.handle, 'sam_k');
      expect(created.expiresAt, isNotNull);
      expect(device.current, created);

      await device.signOut();
      expect(device.current, isNull);

      final again =
          await device.signIn(handle: 'sam_k', passphrase: passphrase);
      expect(again.handle, 'sam_k');
    });

    test('maps the service\'s refusals to failures the page can word',
        () async {
      final fixture = Fixture();
      final device = fixture.device();
      await device.createAccount(handle: 'sam_k', passphrase: passphrase);

      await expectLater(
        fixture.device().createAccount(handle: 'sam_k', passphrase: passphrase),
        throwsFailure(AccountFailure.handleTaken),
      );
      await expectLater(
        fixture
            .device()
            .createAccount(handle: 'sam@example.org', passphrase: passphrase),
        throwsFailure(AccountFailure.invalidHandle),
      );
      await expectLater(
        fixture.device().createAccount(handle: 'other', passphrase: 'short'),
        throwsFailure(AccountFailure.invalidPassphrase),
      );
      await expectLater(
        fixture
            .device()
            .signIn(handle: 'sam_k', passphrase: 'wrong wrong wrong'),
        throwsFailure(AccountFailure.invalidCredentials),
      );
      await expectLater(
        fixture.device().signIn(handle: 'nobody', passphrase: passphrase),
        throwsFailure(AccountFailure.invalidCredentials),
      );
    });

    test('repeated wrong passphrases are rate limited with a wait', () async {
      final fixture = Fixture();
      await fixture.device().createAccount(
            handle: 'sam_k',
            passphrase: passphrase,
          );
      final device = fixture.device();
      for (var i = 0; i < 5; i++) {
        await expectLater(
          device.signIn(handle: 'sam_k', passphrase: 'wrong wrong wrong'),
          throwsFailure(AccountFailure.invalidCredentials),
        );
      }
      await expectLater(
        device.signIn(handle: 'sam_k', passphrase: passphrase),
        throwsA(
          isA<AccountException>()
              .having(
                  (e) => e.failure, 'failure', AccountFailure.tooManyAttempts)
              .having((e) => e.retryAfterSeconds, 'retryAfter', greaterThan(0)),
        ),
      );
    });

    test('an unreachable service is a network failure, not a crash', () async {
      final device = HttpAccountRepository(
        baseUrl: baseUrl,
        client: MockClient((request) async => throw http.ClientException('x')),
        store: InMemoryKeyValueStore(),
        mayPersist: () => false,
      );
      await expectLater(
        device.signIn(handle: 'sam_k', passphrase: passphrase),
        throwsFailure(AccountFailure.network),
      );
    });

    test('actions that need a sign-in say so without calling the service',
        () async {
      final fixture = Fixture();
      await expectLater(
        fixture.device().upload(answers),
        throwsFailure(AccountFailure.signedOut),
      );
      expect(fixture.wire.requests, isEmpty);
    });

    test('an expired sign-in is forgotten and reported as signed out',
        () async {
      var now = DateTime.utc(2026, 1, 1);
      final fixture = Fixture(clock: () => now);
      final device = fixture.device();
      await device.createAccount(handle: 'sam_k', passphrase: passphrase);

      now = DateTime.utc(2026, 3, 1);
      await expectLater(
        device.syncConsent(),
        throwsFailure(AccountFailure.signedOut),
      );
      expect(device.current, isNull);
    });
  });

  group('the sign-in on the device', () {
    test('is kept in memory only unless storage is allowed', () async {
      final fixture = Fixture();
      final store = InMemoryKeyValueStore();
      final device = fixture.device(store: store);
      await device.createAccount(handle: 'sam_k', passphrase: passphrase);

      expect(store.snapshot, isEmpty);
      expect(fixture.device(store: store, mayPersist: true).current, isNull);
    });

    test('survives a restart when storage is allowed', () async {
      final fixture = Fixture();
      final store = InMemoryKeyValueStore();
      final device = fixture.device(store: store, mayPersist: true);
      await device.createAccount(handle: 'sam_k', passphrase: passphrase);

      expect(
        store.snapshot.keys,
        <String>[PersistentSessionRepository.accountKey],
      );
      final restarted = fixture.device(store: store, mayPersist: true);
      expect(restarted.current?.handle, 'sam_k');
      expect(await restarted.syncConsent(), isFalse);
    });

    test('the passphrase is never written to the device', () async {
      final fixture = Fixture();
      final store = InMemoryKeyValueStore();
      final device = fixture.device(store: store, mayPersist: true);
      await device.createAccount(handle: 'sam_k', passphrase: passphrase);
      expect(store.snapshot.values.join(), isNot(contains(passphrase)));
    });

    test('is erased by signing out and by deleting everything on the device',
        () async {
      final fixture = Fixture();
      final store = InMemoryKeyValueStore();
      final device = fixture.device(store: store, mayPersist: true);
      await device.createAccount(handle: 'sam_k', passphrase: passphrase);
      await device.signOut();
      expect(store.snapshot, isEmpty);

      await device.signIn(handle: 'sam_k', passphrase: passphrase);
      expect(store.snapshot, isNotEmpty);
      final local = PersistentSessionRepository(store);
      await local.deleteEverything();
      expect(store.snapshot, isEmpty);
    });

    test('a stored sign-in past its expiry is erased, not used', () async {
      final fixture = Fixture();
      final store = InMemoryKeyValueStore();
      await fixture
          .device(store: store, mayPersist: true)
          .createAccount(handle: 'sam_k', passphrase: passphrase);

      final later = fixture.device(
        store: store,
        mayPersist: true,
        clock: () => DateTime.now().add(const Duration(days: 60)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(later.current, isNull);
      expect(store.snapshot, isEmpty);
    });
  });

  group('sync', () {
    Future<HttpAccountRepository> signedIn(Fixture fixture) async {
      final device = fixture.device();
      await device.createAccount(handle: 'sam_k', passphrase: passphrase);
      return device;
    }

    test('is refused until the person turns it on', () async {
      final fixture = Fixture();
      final device = await signedIn(fixture);

      expect(await device.syncConsent(), isFalse);
      await expectLater(
        device.upload(answers),
        throwsFailure(AccountFailure.consentRequired),
      );
      expect(await device.download(), isNull);
    });

    test('uploads the session and another device can take it', () async {
      final fixture = Fixture();
      final first = await signedIn(fixture);
      await first.setSyncConsent(granted: true);
      expect(await first.syncConsent(), isTrue);

      final result = await first.upload(answers);
      expect(result, isA<SyncUploaded>());
      expect(first.current?.syncedRevision, 1);

      final second = fixture.device();
      await second.signIn(handle: 'sam_k', passphrase: passphrase);
      final remote = await second.download();
      expect(remote?.revision, 1);
      expect(remote?.session, answers.copyWith(freeTextPrompt: null));
      expect(second.current?.syncedRevision, 1);
    });

    test('the "Something else" text never leaves the device', () async {
      final fixture = Fixture();
      final device = await signedIn(fixture);
      await device.setSyncConsent(granted: true);
      await device.upload(answers);

      expect(fixture.wire.everything, isNot(contains('two offers')));
      expect(fixture.wire.everything, contains('Rewrote the rota.'));
      expect(await device.exportData(), isNot(contains('two offers')));
    });

    test(
        'a device that has not seen the stored copy gets a conflict, and '
        'nothing is overwritten', () async {
      final fixture = Fixture();
      final first = await signedIn(fixture);
      await first.setSyncConsent(granted: true);
      await first.upload(answers);

      final second = fixture.device();
      await second.signIn(handle: 'sam_k', passphrase: passphrase);
      const local = Session(selectedGoal: GoalId.direction);
      final result = await second.upload(local);

      expect(result, isA<SyncConflict>());
      final conflict = result as SyncConflict;
      expect(conflict.remote.revision, 1);
      expect(conflict.remote.session.selectedGoal, GoalId.internshipOrJob);
      expect((await first.download())?.session.selectedGoal,
          GoalId.internshipOrJob);

      // The person chooses to keep this device's copy.
      final forced = await second.upload(
        local,
        baseRevision: conflict.remote.revision,
      );
      expect((forced as SyncUploaded).revision, 2);
      expect((await first.download())?.session.selectedGoal, GoalId.direction);
    });

    test('successive uploads from one device do not conflict', () async {
      final fixture = Fixture();
      final device = await signedIn(fixture);
      await device.setSyncConsent(granted: true);
      await device.upload(answers);
      final second = await device.upload(
        answers.copyWith(selectedGoal: GoalId.direction),
      );
      expect((second as SyncUploaded).revision, 2);
    });

    test('turning sync off deletes the copy on the service', () async {
      final fixture = Fixture();
      final device = await signedIn(fixture);
      await device.setSyncConsent(granted: true);
      await device.upload(answers);

      await device.setSyncConsent(granted: false);

      expect(device.current?.syncedRevision, isNull);
      expect(await device.download(), isNull);
      expect(await device.exportData(), isNot(contains('Rewrote the rota.')));

      // Turning it back on starts again from nothing, without a conflict.
      await device.setSyncConsent(granted: true);
      expect(await device.upload(answers), isA<SyncUploaded>());
    });
  });

  group('export and deletion', () {
    test('export shows what the service holds and no secrets', () async {
      final fixture = Fixture();
      final device = fixture.device();
      await device.createAccount(handle: 'sam_k', passphrase: passphrase);
      await device.setSyncConsent(granted: true);
      await device.upload(answers);

      final export =
          jsonDecode(await device.exportData()) as Map<String, Object?>;
      expect(export['handle'], 'sam_k');
      expect((export['consents']! as Map)['sync'], isNotNull);
      expect(
        ((export['profile']! as Map)['data']! as Map)['goal'],
        'internship-or-job',
      );
      expect(jsonEncode(export), isNot(contains(passphrase)));
      expect(jsonEncode(export).toLowerCase(), isNot(contains('salt')));
    });

    test('deleting the account needs the passphrase and removes everything',
        () async {
      final fixture = Fixture();
      final device = fixture.device();
      await device.createAccount(handle: 'sam_k', passphrase: passphrase);
      await device.setSyncConsent(granted: true);
      await device.upload(answers);

      await expectLater(
        device.deleteAccount(passphrase: 'wrong wrong wrong'),
        throwsFailure(AccountFailure.incorrectPassphrase),
      );
      expect(device.current, isNotNull);

      await device.deleteAccount(passphrase: passphrase);
      expect(device.current, isNull);
      await expectLater(
        fixture.device().signIn(handle: 'sam_k', passphrase: passphrase),
        throwsFailure(AccountFailure.invalidCredentials),
      );
      // The handle is free again and the new account starts empty.
      final fresh = fixture.device();
      await fresh.createAccount(handle: 'sam_k', passphrase: passphrase);
      expect(await fresh.download(), isNull);
    });
  });

  test('the service address must be HTTPS, or this machine', () {
    bool ok(String url) =>
        HttpAccountRepository.isAcceptableBaseUrl(Uri.parse(url));
    expect(ok('https://sync.example.org'), isTrue);
    expect(ok('http://localhost:8080'), isTrue);
    expect(ok('http://127.0.0.1:8080'), isTrue);
    expect(ok('http://sync.example.org'), isFalse);
    expect(ok('ftp://sync.example.org'), isFalse);
    expect(ok('sync.example.org'), isFalse);
  });

  group('published catalogues', () {
    Future<int> publish(Fixture fixture, String name, Object document) async {
      final response = await fixture.handler(
        shelf.Request(
          'PUT',
          baseUrl.resolve('/v1/admin/catalog/$name'),
          headers: <String, String>{
            'authorization': 'Bearer $adminToken',
            'content-type': 'application/json',
          },
          body: jsonEncode(document),
        ),
      );
      return response.statusCode;
    }

    CatalogClient catalogClient(Fixture fixture) => CatalogClient(
          baseUrl: baseUrl,
          client: clientFor(fixture.handler, fixture.wire),
        );

    test('the bundled catalogues round-trip through the codec', () async {
      final goals = await const InMemoryGoalCatalogRepository().primaryGoals();
      final decodedGoals =
          CatalogCodec.decodeGoals(CatalogCodec.encodeGoals(goals));
      expect(decodedGoals.problems, isEmpty);
      expect(decodedGoals.items.map((goal) => goal.title),
          goals.map((goal) => goal.title));

      final occupations = await InMemoryOccupationCatalogRepository().all();
      final decoded = CatalogCodec.decodeOccupations(
        jsonDecode(jsonEncode(CatalogCodec.encodeOccupations(occupations))),
      );
      expect(decoded.problems, isEmpty);
      expect(decoded.items, hasLength(occupations.length));
      final nurse =
          decoded.items.firstWhere((item) => item.id == 'registered-nurse');
      final original =
          occupations.firstWhere((item) => item.id == 'registered-nurse');
      expect(nurse.routes, original.routes);
      expect(nurse.interests, original.interests);
      expect(nurse.handsOn, original.handsOn);
      expect(nurse.evidence.kind, EvidenceKind.generatedGuidance);
    });

    test('with nothing published the app uses the catalogue it was built with',
        () async {
      final fixture = Fixture();
      final goals = RemoteFirstGoalCatalogRepository(
        client: catalogClient(fixture),
        fallback: const InMemoryGoalCatalogRepository(),
      );
      expect(await goals.primaryGoals(), hasLength(GoalId.values.length));
      final occupations = RemoteFirstOccupationCatalogRepository(
        client: catalogClient(fixture),
        fallback: InMemoryOccupationCatalogRepository(),
      );
      expect(await occupations.all(), hasLength(bundledOccupations.length));
    });

    test('a published catalogue replaces the bundled one, fetched once',
        () async {
      final fixture = Fixture();
      final bundled =
          await const InMemoryGoalCatalogRepository().primaryGoals();
      final edited = CatalogCodec.encodeGoals(bundled);
      ((edited['items']! as List).first as Map)['title'] =
          'Help me choose a direction';
      expect(await publish(fixture, 'goals', edited), 200);

      final goals = RemoteFirstGoalCatalogRepository(
        client: catalogClient(fixture),
        fallback: const InMemoryGoalCatalogRepository(),
      );
      expect((await goals.primaryGoals()).first.title,
          'Help me choose a direction');
      expect((await goals.goalById(GoalId.direction))?.title,
          'Help me choose a direction');
      expect(
        fixture.wire.requests.where((r) => r.url.path.endsWith('/goals')),
        hasLength(1),
      );
    });

    test('an entry published as reviewed is labelled as reviewed', () async {
      final fixture = Fixture();
      final document = CatalogCodec.encodeOccupations(
        await InMemoryOccupationCatalogRepository().all(),
      );
      final first = (document['items']! as List).first as Map;
      first['evidence'] = <String, Object?>{
        'kind': 'editorial',
        'source': 'Reviewed by a careers adviser',
        'asOf': '2027-02-01T00:00:00.000Z',
      };
      expect(await publish(fixture, 'occupations', document), 200);

      final occupations = RemoteFirstOccupationCatalogRepository(
        client: catalogClient(fixture),
        fallback: InMemoryOccupationCatalogRepository(),
      );
      final reviewed = await occupations.byId(first['id']! as String);
      expect(reviewed?.evidence.kind, EvidenceKind.editorial);
      expect(reviewed?.evidence.asOf, DateTime.utc(2027, 2));
      final others = (await occupations.all())
          .where((item) => item.id != first['id'])
          .map((item) => item.evidence.kind)
          .toSet();
      expect(others, <EvidenceKind>{EvidenceKind.generatedGuidance});
      expect(await occupations.search(query: 'wind turbine'), hasLength(1));
    });

    test('the server refuses a catalogue that promises an outcome', () async {
      final fixture = Fixture();
      final document = CatalogCodec.encodeGoals(
        await const InMemoryGoalCatalogRepository().primaryGoals(),
      );
      ((document['items']! as List).first as Map)['description'] =
          'This will land you a job.';
      expect(await publish(fixture, 'goals', document), 422);
    });

    test('the app rejects a published document the server let through',
        () async {
      final fixture = Fixture();
      // Valid for the server (ids, shape) but incomplete for the app.
      expect(
        await publish(fixture, 'occupations', <String, Object?>{
          'schemaVersion': 1,
          'items': <Object?>[
            <String, Object?>{'id': 'mystery', 'title': 'Mystery'},
          ],
        }),
        200,
      );
      final occupations = RemoteFirstOccupationCatalogRepository(
        client: catalogClient(fixture),
        fallback: InMemoryOccupationCatalogRepository(),
      );
      expect(await occupations.all(), hasLength(bundledOccupations.length));
    });

    test('the codec names every problem it finds', () {
      final result = CatalogCodec.decodeOccupations(<String, Object?>{
        'schemaVersion': 1,
        'items': <Object?>[
          <String, Object?>{
            'id': 'Bad Id',
            'socCode': '15',
            'socTitle': 'X',
            'title': 'Pays 90% more',
            'summary': 'You are sure to succeed.',
            'tasks': <String>['A task'],
            'skills': <String>[],
            'interests': <String>['juggling'],
            'routes': <Object?>[
              <String, Object?>{
                'kind': 'teleport',
                'title': 'T',
                'description': 'D'
              },
            ],
          },
        ],
      });
      final text = result.problems.join('\n');
      expect(result.isValid, isFalse);
      expect(text, contains('id must be lower-case'));
      expect(text, contains('not a SOC code'));
      expect(text, contains('contains a figure'));
      expect(text, contains('promises an outcome'));
      expect(text, contains('skills needs at least one entry'));
      expect(text, contains('unknown value'));
      expect(text, contains('unknown kind'));
      expect(text, contains('needs at least one route'));
    });

    test('a goals document must hold each known goal exactly once', () async {
      final document = CatalogCodec.encodeGoals(
        await const InMemoryGoalCatalogRepository().primaryGoals(),
      );
      (document['items']! as List).removeLast();
      expect(CatalogCodec.decodeGoals(document).isValid, isFalse);
      expect(CatalogCodec.decodeGoals('nonsense').isValid, isFalse);
    });

    test('fetching a catalogue sends no credentials', () async {
      final fixture = Fixture();
      await catalogClient(fixture).fetch('goals');
      expect(
        fixture.wire.requests.single.headers.containsKey('authorization'),
        isFalse,
      );
    });
  });
}
