/// Wording that promises an outcome. The product never does that, so the
/// server refuses to publish catalogue text containing it.
final RegExp outcomePromisePattern = RegExp(
  r'\b(guarantee[ds]?|guaranteed|ensures? you get|will land you|land the job)\b',
  caseSensitive: false,
);

final RegExp _whitespaceRun = RegExp(r'\s+');

/// The most problems reported for one document, so the error response for a
/// thoroughly broken upload stays small.
const int maxCatalogProblems = 50;

/// The deepest nesting accepted in a catalogue document.
const int maxCatalogDepth = 32;

/// Checks a catalogue document and returns what is wrong with it.
///
/// An empty list means the document can be published. The rules:
///
/// * the document is a JSON object;
/// * `schemaVersion` is an integer;
/// * `items` is a list of objects, each with a non-empty string `id`, and
///   no two items share an `id`;
/// * nothing is nested deeper than [maxCatalogDepth] levels;
/// * no string value anywhere matches [outcomePromisePattern].
List<String> validateCatalogDocument(Object? document) {
  final problems = _Problems();

  if (document is! Map<String, Object?>) {
    problems.add('The document must be a JSON object.');
    return problems.list;
  }

  if (document['schemaVersion'] is! int) {
    problems.add('"schemaVersion" must be an integer.');
  }

  final items = document['items'];
  if (items is! List) {
    problems.add('"items" must be a list.');
  } else {
    final seen = <String>{};
    for (var i = 0; i < items.length && !problems.isFull; i++) {
      final item = items[i];
      if (item is! Map<String, Object?>) {
        problems.add('items[$i] must be an object.');
        continue;
      }
      final id = item['id'];
      if (id is! String || id.isEmpty) {
        problems.add('items[$i].id must be a non-empty string.');
      } else if (!seen.add(id)) {
        problems.add('items[$i].id repeats an id used by an earlier item.');
      }
    }
  }

  _scanStrings(document, problems);
  return problems.list;
}

/// Walks every value without recursion and reports outcome-promise wording
/// and excessive nesting.
void _scanStrings(Map<String, Object?> document, _Problems problems) {
  final pending = <(Object?, String, int)>[(document, '', 1)];
  var tooDeepReported = false;

  while (pending.isNotEmpty && !problems.isFull) {
    final (node, path, depth) = pending.removeLast();
    if (node is String) {
      // Collapse whitespace so a promise split across a line break or
      // padded with extra spaces is still caught.
      final text = node.replaceAll(_whitespaceRun, ' ');
      final match = outcomePromisePattern.firstMatch(text);
      if (match != null) {
        problems.add(
          '$path contains outcome-promise wording ("${match.group(0)}"). '
          'Describe what the reader can do, not a result.',
        );
      }
    } else if (node is Map || node is List) {
      if (depth > maxCatalogDepth) {
        if (!tooDeepReported) {
          tooDeepReported = true;
          problems.add(
            'The document is nested more than $maxCatalogDepth levels deep.',
          );
        }
        continue;
      }
      if (node is Map) {
        // Reversed so that problems come out in document order.
        for (final entry in node.entries.toList().reversed) {
          final key = entry.key as String;
          pending.add(
            (entry.value, path.isEmpty ? key : '$path.$key', depth + 1),
          );
        }
      } else if (node is List) {
        for (var i = node.length - 1; i >= 0; i--) {
          pending.add((node[i], '$path[$i]', depth + 1));
        }
      }
    }
  }
}

final class _Problems {
  final List<String> list = [];

  bool get isFull => list.length >= maxCatalogProblems;

  void add(String problem) {
    if (!isFull) list.add(problem);
  }
}
