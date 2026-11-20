import 'dart:convert';
import 'dart:io';

import 'package:launchpad_data/launchpad_data.dart';
import 'package:launchpad_domain/launchpad_domain.dart';
import 'package:test/test.dart';

/// Phrases that promise an outcome. The product offers guidance, never a
/// promise about admission, hiring or pay.
final RegExp outcomePromise = RegExp(
  r"\b(guarantee[ds]?|guaranteed|ensures? you get|will land you|land the job|"
  r"you will get (the|a) job|sure to|certain to)\b",
  caseSensitive: false,
);

/// A bare figure with a currency or percent sign. Pay and employment figures
/// come only from the labour-market snapshot, with a source and a date.
final RegExp bareFigure = RegExp(r'[$£€]\s?\d|\d\s?%|\d{2,}[,.]\d{3}');

Iterable<String> textOf(Occupation occupation) => <String>[
      occupation.title,
      occupation.summary,
      ...occupation.tasks,
      ...occupation.skills,
      for (final route in occupation.routes) ...<String>[
        route.title,
        route.description,
      ],
      if (occupation.changeNote != null) occupation.changeNote!,
    ];

void main() {
  final repository = InMemoryOccupationCatalogRepository();

  group('bundled occupations', () {
    test('have unique ids and SOC codes in the expected shapes', () {
      final ids = bundledOccupations.map((item) => item.id).toList();
      final codes = bundledOccupations.map((item) => item.socCode).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(codes.toSet(), hasLength(codes.length));
      for (final id in ids) {
        expect(id, matches(RegExp(r'^[a-z]+(-[a-z]+)*$')));
      }
      for (final code in codes) {
        expect(code, matches(RegExp(r'^\d{2}-\d{4}$')));
      }
    });

    test('are complete enough to read, compare and plan from', () {
      for (final occupation in bundledOccupations) {
        final reason = occupation.id;
        expect(occupation.title, isNotEmpty, reason: reason);
        expect(occupation.socTitle, isNotEmpty, reason: reason);
        expect(occupation.summary, endsWith('.'), reason: reason);
        expect(occupation.tasks, hasLength(3), reason: reason);
        expect(occupation.skills, hasLength(4), reason: reason);
        expect(occupation.interests, isNotEmpty, reason: reason);
        expect(occupation.routes, isNotEmpty, reason: reason);
      }
    });

    test('never promise an outcome', () {
      for (final occupation in bundledOccupations) {
        for (final text in textOf(occupation)) {
          expect(
            outcomePromise.hasMatch(text),
            isFalse,
            reason: 'outcome promise in ${occupation.id}: "$text"',
          );
        }
      }
    });

    test('carry no figures of their own', () {
      for (final occupation in bundledOccupations) {
        for (final text in textOf(occupation)) {
          expect(
            bareFigure.hasMatch(text),
            isFalse,
            reason: 'unsourced figure in ${occupation.id}: "$text"',
          );
        }
      }
    });

    test('are labelled as drafted, not as reviewed by an editor', () {
      for (final occupation in bundledOccupations) {
        expect(occupation.evidence.kind, EvidenceKind.generatedGuidance);
        expect(occupation.evidence.asOf, isNotNull);
      }
    });

    test('offer routes without a four-year degree across the catalogue', () {
      final withAlternative =
          bundledOccupations.where((item) => item.hasNonDegreeRoute).length;
      expect(withAlternative, greaterThan(bundledOccupations.length ~/ 2));
    });

    test('cover every interest area with at least two occupations', () {
      for (final area in InterestArea.values) {
        expect(
          bundledOccupations.where((item) => item.interests.contains(area)),
          hasLength(greaterThanOrEqualTo(2)),
          reason: area.slug,
        );
      }
    });

    test('no route describes itself with a different kind of title', () {
      for (final occupation in bundledOccupations) {
        final kinds = occupation.routes.map((route) => route.kind).toList();
        expect(
          kinds.toSet(),
          hasLength(kinds.length),
          reason: '${occupation.id} lists a route kind twice',
        );
      }
    });
  });

  group('plan templates', () {
    test('every route kind has five steps with unique ids', () {
      for (final kind in RouteKind.values) {
        final steps = planTemplateFor(kind);
        expect(steps, hasLength(5), reason: kind.slug);
        expect(
          steps.map((step) => step.id).toSet(),
          hasLength(5),
          reason: kind.slug,
        );
        for (final step in steps) {
          expect(
            outcomePromise.hasMatch('${step.title} ${step.detail}'),
            isFalse,
            reason: 'outcome promise in ${kind.slug}/${step.id}',
          );
        }
      }
    });
  });

  group('search', () {
    test('returns everything, in title order, for an empty query', () async {
      final all = await repository.all();
      final found = await repository.search();
      expect(found, all);
      final titles = all.map((item) => item.title).toList();
      expect(titles, <String>[...titles]..sort());
    });

    test('matches title, tasks and skills, ignoring case', () async {
      expect(
        (await repository.search(query: 'NURSE')).map((item) => item.id),
        containsAll(<String>['registered-nurse', 'licensed-practical-nurse']),
      );
      expect(
        (await repository.search(query: 'refrigerants')).single.id,
        'hvac-technician',
      );
    });

    test('requires every word of the query', () async {
      expect(
        (await repository.search(query: 'wind turbine')).single.id,
        'wind-turbine-technician',
      );
      expect(await repository.search(query: 'wind accounting'), isEmpty);
    });

    test('narrows by interest', () async {
      final found = await repository.search(
        interests: <InterestArea>{InterestArea.outdoors, InterestArea.science},
      );
      expect(found, isNotEmpty);
      for (final occupation in found) {
        expect(
          occupation.interests,
          containsAll(<InterestArea>{
            InterestArea.outdoors,
            InterestArea.science,
          }),
        );
      }
    });

    test('looks up by id and returns null for an unknown one', () async {
      expect((await repository.byId('electrician'))?.socCode, '47-2111');
      expect(await repository.byId('astronaut'), isNull);
    });
  });

  group('bundled labour-market figures', () {
    test('are either absent or fully sourced and dated', () async {
      final snapshot = await const BundledLaborMarketRepository().snapshot();
      if (snapshot == null) return;
      expect(snapshot.source, isNotEmpty);
      expect(snapshot.referencePeriod, isNotEmpty);
      for (final stats in snapshot.statsBySoc.values) {
        expect(stats.evidence.kind, EvidenceKind.laborMarketData);
        expect(stats.evidence.source, isNotNull);
        expect(stats.evidence.asOf, isNotNull);
      }
      final codes = bundledOccupations.map((item) => item.socCode).toSet();
      expect(snapshot.statsBySoc.keys.toSet().difference(codes), isEmpty);
    });
  });

  group('OewsImporter', () {
    final response = (jsonDecode(
      File('test/fixtures/oews_response.json').readAsStringSync(),
    ) as Map)
        .cast<String, Object?>();
    const codes = <String>['11-1111', '22-2222'];
    final retrieved = DateTime.utc(2026, 11, 19);

    test('builds national series identifiers', () {
      expect(
        OewsImporter.seriesId('15-1252', OewsImporter.annualMedian),
        'OEUN000000000000015125213',
      );
      expect(
        OewsImporter.seriesId('15-1252', OewsImporter.annualMedian),
        hasLength(25),
      );
      expect(
        () => OewsImporter.seriesId('software', OewsImporter.annualMedian),
        throwsArgumentError,
      );
    });

    test('splits requests to the size the API accepts', () {
      final bodies = OewsImporter.requestBodies(
        List<String>.generate(28, (i) => '11-${1000 + i}'),
      );
      expect(bodies, hasLength(5));
      for (final body in bodies) {
        expect(body['seriesid']! as List, hasLength(lessThanOrEqualTo(25)));
      }
      expect(
        bodies.expand((body) => body['seriesid']! as List),
        hasLength(28 * 4 + 1),
      );
    });

    test('reads the latest annual figure for each series', () {
      final snapshot = OewsImporter.build(
        socCodes: codes,
        responses: <Map<String, Object?>>[response],
        retrievedOn: retrieved,
      );

      expect(snapshot.referencePeriod, 'May 2024');
      expect(snapshot.asOf, DateTime.utc(2024, 5));
      expect(snapshot.retrievedOn, retrieved);
      expect(snapshot.allOccupationsMedianAnnualWage, 49500);

      final first = snapshot.statsBySoc['11-1111']!;
      expect(first.medianAnnualWage, 98765);
      expect(first.lowAnnualWage, 61000);
      expect(first.highAnnualWage, isNull, reason: 'not released');
      expect(first.employment, 1534790);
      expect(first.evidence.kind, EvidenceKind.laborMarketData);
      expect(first.evidence.source, contains('Bureau of Labor Statistics'));
      expect(first.evidence.asOf, DateTime.utc(2024, 5));

      final second = snapshot.statsBySoc['22-2222']!;
      expect(second.medianAnnualWage, 41000);
      expect(second.hasWideSpread, isFalse);
    });

    test('refuses when an occupation has no median', () {
      expect(
        () => OewsImporter.build(
          socCodes: <String>[...codes, '33-3333'],
          responses: <Map<String, Object?>>[response],
          retrievedOn: retrieved,
        ),
        throwsA(
          isA<OewsImportException>().having(
            (error) => error.problems.join(),
            'problems',
            contains('33-3333'),
          ),
        ),
      );
    });

    test('refuses when a request failed', () {
      expect(
        () => OewsImporter.build(
          socCodes: codes,
          responses: <Map<String, Object?>>[
            <String, Object?>{
              'status': 'REQUEST_NOT_PROCESSED',
              'message': <String>['daily threshold reached'],
            },
          ],
          retrievedOn: retrieved,
        ),
        throwsA(isA<OewsImportException>()),
      );
    });

    test('refuses the quota answer the API really gives', () {
      // Recorded from api.bls.gov on 20 November 2026: an unregistered
      // request from a shared address after the daily allowance was spent.
      // It arrives with HTTP 200, so only the body says nothing was returned.
      final refusal = (jsonDecode(
        File('test/fixtures/oews_quota_refusal.json').readAsStringSync(),
      ) as Map)
          .cast<String, Object?>();
      expect(
        () => OewsImporter.build(
          socCodes: codes,
          responses: <Map<String, Object?>>[refusal],
          retrievedOn: retrieved,
        ),
        throwsA(
          isA<OewsImportException>().having(
            (error) => error.problems.join(),
            'problems',
            allOf(
                contains('REQUEST_NOT_PROCESSED'), contains('daily threshold')),
          ),
        ),
      );
    });

    test('a registration key goes in the body and allows larger requests', () {
      final many = List<String>.generate(28, (i) => '11-${1000 + i}');
      final bodies = OewsImporter.requestBodies(many, registrationKey: ' k3y ');
      expect(bodies, hasLength(3));
      for (final body in bodies) {
        expect(body['registrationkey'], 'k3y');
        expect(body['seriesid']! as List, hasLength(lessThanOrEqualTo(50)));
      }
      for (final body in OewsImporter.requestBodies(many)) {
        expect(body.containsKey('registrationkey'), isFalse);
      }
      expect(
        OewsImporter.requestBodies(many, registrationKey: '  ').first,
        isNot(contains('registrationkey')),
      );
    });

    test('refuses to mix reference years', () {
      final mixed =
          (jsonDecode(jsonEncode(response)) as Map).cast<String, Object?>();
      final series = ((mixed['Results']! as Map)['series']! as List)
          .cast<Map<String, Object?>>();
      (series[3]['data']! as List).cast<Map<String, Object?>>().single['year'] =
          '2023';
      expect(
        () => OewsImporter.build(
          socCodes: codes,
          responses: <Map<String, Object?>>[mixed],
          retrievedOn: retrieved,
        ),
        throwsA(
          isA<OewsImportException>().having(
            (error) => error.problems.join(),
            'problems',
            contains('different years'),
          ),
        ),
      );
    });

    test('renders a snapshot file that names its source and period', () {
      final source = OewsImporter.render(
        OewsImporter.build(
          socCodes: codes,
          responses: <Map<String, Object?>>[response],
          retrievedOn: retrieved,
        ),
      );
      expect(source, contains('GENERATED FILE'));
      expect(source, contains('Reference period: May 2024'));
      expect(source, contains("'11-1111': LaborStats("));
      expect(source, contains('medianAnnualWage: 98765'));
      expect(source, contains('highAnnualWage: null'));
      expect(source, contains('retrievedOn: DateTime.utc(2026, 11, 19)'));
      expect(
          source, contains('LaborMarketSnapshot? buildBundledOewsSnapshot()'));
    });

    test('checks catalogue titles against the published occupation list', () {
      const table = 'occupation_code\toccupation_name\tdisplay_level\n'
          '151252\tSoftware Developers\t3\n'
          '472111\tElectricians\t3\n';
      expect(
        OewsImporter.checkTitles(
          catalogTitlesBySoc: const <String, String>{
            '15-1252': 'Software Developers',
            '47-2111': 'electricians',
          },
          occupationTable: table,
        ),
        isEmpty,
      );
      final problems = OewsImporter.checkTitles(
        catalogTitlesBySoc: const <String, String>{
          '15-1252': 'Web Developers',
          '99-9999': 'Astronauts',
        },
        occupationTable: table,
      );
      expect(problems, hasLength(2));
      expect(problems.first, contains('Software Developers'));
      expect(problems.last, contains('99-9999'));
    });
  });

  group('SessionCodec with a workspace', () {
    final session = const Session().copyWith(
      workspace: const Workspace()
          .toggleSaved('electrician')
          .toggleSaved('registered-nurse')
          .withPlan(
            const ActionPlan(
              occupationId: 'electrician',
              route: RouteKind.apprenticeship,
              customSteps: <CustomStep>[
                CustomStep(id: 'c1', text: 'Call the union local'),
              ],
            ),
          )
          .toggleDone(
            Workspace.planStepKey(
              'electrician',
              RouteKind.apprenticeship,
              'find-sponsors',
            ),
          ),
    );

    test('round-trips saved options, plans and completion', () {
      expect(SessionCodec.decode(SessionCodec.encode(session)), session);
    });

    test('writes route kinds by slug', () {
      final json = jsonEncode(SessionCodec.encode(session));
      expect(json, contains('"route":"apprenticeship"'));
      expect(json, contains('plan/electrician/apprenticeship/find-sponsors'));
    });

    test('drops malformed plans and caps custom steps', () {
      final decoded = SessionCodec.decode(<String, Object?>{
        'workspace': <String, Object?>{
          'saved': <Object?>['electrician', 4],
          'plans': <Object?>[
            'nonsense',
            <String, Object?>{'route': 'apprenticeship'},
            <String, Object?>{
              'occupation': 'electrician',
              'route': 'teleportation',
              'customSteps': <Object?>[
                for (var i = 0; i < 30; i++)
                  <String, Object?>{'id': 'c$i', 'text': 'Step $i'},
                <String, Object?>{'id': 'blank', 'text': '   '},
              ],
            },
          ],
        },
      });
      expect(decoded.workspace.savedOccupations, <String>{'electrician'});
      final plan = decoded.workspace.plans.values.single;
      expect(plan.route, isNull);
      expect(plan.customSteps, hasLength(ActionPlan.maxCustomSteps));
    });

    test('an empty workspace adds nothing to the stored session', () {
      expect(
        SessionCodec.encode(const Session()).containsKey('workspace'),
        isFalse,
      );
    });
  });
}
