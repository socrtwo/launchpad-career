import 'package:launchpad_server/launchpad_server.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('accepts a well-formed document', () {
    expect(validateCatalogDocument(validCatalog()), isEmpty);
    expect(
      validateCatalogDocument({'schemaVersion': 3, 'items': <Object?>[]}),
      isEmpty,
    );
  });

  test('requires a JSON object', () {
    for (final document in [null, 1, 'text', <Object?>[], true]) {
      expect(
        validateCatalogDocument(document),
        ['The document must be a JSON object.'],
      );
    }
  });

  test('requires an integer schemaVersion', () {
    for (final version in [null, '1', 1.5, true, <Object?>[]]) {
      expect(
        validateCatalogDocument({'schemaVersion': version, 'items': []}),
        ['"schemaVersion" must be an integer.'],
        reason: '$version',
      );
    }
    expect(
      validateCatalogDocument({'items': <Object?>[]}),
      ['"schemaVersion" must be an integer.'],
    );
  });

  test('requires items to be a list', () {
    expect(
      validateCatalogDocument({'schemaVersion': 1}),
      ['"items" must be a list.'],
    );
    expect(
      validateCatalogDocument(
          {'schemaVersion': 1, 'items': <String, Object?>{}}),
      ['"items" must be a list.'],
    );
  });

  test('requires every item to be an object with a non-empty string id', () {
    final problems = validateCatalogDocument({
      'schemaVersion': 1,
      'items': [
        'not an object',
        <String, Object?>{},
        {'id': ''},
        {'id': 7},
        {'id': 'fine'},
      ],
    });
    expect(problems, [
      'items[0] must be an object.',
      'items[1].id must be a non-empty string.',
      'items[2].id must be a non-empty string.',
      'items[3].id must be a non-empty string.',
    ]);
  });

  test('requires ids to be unique', () {
    final problems = validateCatalogDocument({
      'schemaVersion': 1,
      'items': [
        {'id': 'a'},
        {'id': 'b'},
        {'id': 'a'},
      ],
    });
    expect(problems, ['items[2].id repeats an id used by an earlier item.']);
  });

  group('outcome promises', () {
    Map<String, Object?> withText(String text) => {
          'schemaVersion': 1,
          'items': [
            {'id': 'a', 'summary': text},
          ],
        };

    test('each form of the pattern is refused', () {
      for (final text in [
        'We guarantee an interview.',
        'A guaranteed offer.',
        'This guarantees success.',
        'It ensures you get hired.',
        'We ensure you get the role.',
        'Skills that will land you a job.',
        'How to land the job.',
      ]) {
        final problems = validateCatalogDocument(withText(text));
        expect(problems, hasLength(1), reason: text);
        expect(problems.single, startsWith('items[0].summary contains'));
        expect(problems.single, contains('outcome-promise wording'));
      }
    });

    test('matching ignores case', () {
      expect(validateCatalogDocument(withText('GUARANTEED results')),
          hasLength(1));
      expect(validateCatalogDocument(withText('Land The Job')), hasLength(1));
    });

    test('a promise split across a line break is still caught', () {
      expect(
        validateCatalogDocument(withText('This will\n  land   you a job')),
        hasLength(1),
      );
    });

    test('ordinary wording that only resembles a promise is accepted', () {
      for (final text in [
        'Build skills employers are looking for.',
        'Find a guarantor for your lease.',
        'Landing pages for your portfolio.',
        'Compare programs, costs, and requirements.',
        'Ensure your references are up to date.',
      ]) {
        expect(validateCatalogDocument(withText(text)), isEmpty, reason: text);
      }
    });

    test('strings nested anywhere are checked, and the path is reported', () {
      final problems = validateCatalogDocument({
        'schemaVersion': 1,
        'title': 'Results guaranteed',
        'items': [
          {
            'id': 'a',
            'sections': [
              {
                'steps': [
                  'Write a draft.',
                  {
                    'detail': {'note': 'This will land you interviews.'},
                  },
                ],
              },
            ],
          },
        ],
        'footer': {
          'links': ['fine', 'Land the job today'],
        },
      });
      expect(problems, hasLength(3));
      expect(problems[0], startsWith('title contains'));
      expect(
        problems[1],
        startsWith('items[0].sections[0].steps[1].detail.note contains'),
      );
      expect(problems[2], startsWith('footer.links[1] contains'));
    });

    test('an item id is a string value like any other', () {
      final problems = validateCatalogDocument({
        'schemaVersion': 1,
        'items': [
          {'id': 'land the job'},
        ],
      });
      expect(problems.single, startsWith('items[0].id contains'));
    });
  });

  test('reports structural and wording problems together', () {
    final problems = validateCatalogDocument({
      'schemaVersion': 'one',
      'items': [
        {'id': 'a', 'title': 'Guaranteed placement'},
        {'id': 'a'},
      ],
    });
    expect(problems, hasLength(3));
  });

  test('refuses documents nested deeper than the limit', () {
    Object? nested = 'leaf';
    for (var i = 0; i < maxCatalogDepth + 5; i++) {
      nested = [nested];
    }
    final problems = validateCatalogDocument({
      'schemaVersion': 1,
      'items': <Object?>[],
      'extra': nested,
    });
    expect(problems, hasLength(1));
    expect(problems.single, contains('nested more than'));
  });

  test('survives nesting deep enough to overflow a recursive walk', () {
    Object? nested = 'guaranteed';
    for (var i = 0; i < 200000; i++) {
      nested = [nested];
    }
    final problems = validateCatalogDocument({
      'schemaVersion': 1,
      'items': <Object?>[],
      'extra': nested,
    });
    expect(problems.single, contains('nested more than'));
  });

  test('caps the number of problems reported', () {
    final problems = validateCatalogDocument({
      'schemaVersion': 1,
      'items': [
        for (var i = 0; i < 500; i++) {'id': ''},
      ],
    });
    expect(problems, hasLength(maxCatalogProblems));
  });
}
