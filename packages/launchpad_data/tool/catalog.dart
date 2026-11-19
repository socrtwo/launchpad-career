// Content management for the goal and occupation catalogues.
//
//   dart run tool/catalog.dart export goals|occupations
//       Print the bundled catalogue as a JSON document, to edit and publish.
//   dart run tool/catalog.dart validate goals|occupations FILE
//       Check a document against the rules the app enforces when it loads one.
//   dart run tool/catalog.dart publish goals|occupations FILE --server=URL
//       Validate, then publish as the next revision.
//   dart run tool/catalog.dart rollback goals|occupations --server=URL
//       Restore the previous revision.
//
// publish and rollback read the admin token from the ADMIN_TOKEN environment
// variable. It is never taken from the command line, where it would be kept
// in shell history.

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:launchpad_data/launchpad_data.dart';

Future<void> main(List<String> arguments) async {
  final positional =
      arguments.where((argument) => !argument.startsWith('--')).toList();
  String? option(String name) {
    for (final argument in arguments) {
      if (argument.startsWith('--$name=')) {
        return argument.substring(name.length + 3);
      }
    }
    return null;
  }

  if (positional.length < 2 ||
      !const <String>{'goals', 'occupations'}.contains(positional[1])) {
    stderr.writeln(
      'Usage: catalog.dart export|validate|publish|rollback '
      'goals|occupations [FILE] [--server=URL]',
    );
    exitCode = 64;
    return;
  }
  final command = positional[0];
  final name = positional[1];

  List<String> problemsIn(Object? document) => name == 'goals'
      ? CatalogCodec.decodeGoals(document).problems
      : CatalogCodec.decodeOccupations(document).problems;

  switch (command) {
    case 'export':
      final document = name == 'goals'
          ? CatalogCodec.encodeGoals(
              await const InMemoryGoalCatalogRepository().primaryGoals(),
            )
          : CatalogCodec.encodeOccupations(
              await InMemoryOccupationCatalogRepository().all(),
            );
      print(const JsonEncoder.withIndent('  ').convert(document));
    case 'validate' || 'publish':
      if (positional.length < 3) {
        stderr.writeln('Give the file to $command.');
        exitCode = 64;
        return;
      }
      final Object? document;
      try {
        document = jsonDecode(await File(positional[2]).readAsString());
      } on FormatException catch (error) {
        stderr.writeln('The file is not valid JSON: ${error.message}');
        exitCode = 65;
        return;
      }
      final problems = problemsIn(document);
      if (problems.isNotEmpty) {
        stderr.writeln('The document was refused:');
        for (final problem in problems) {
          stderr.writeln('  - $problem');
        }
        exitCode = 65;
        return;
      }
      if (command == 'validate') {
        print('The document is valid.');
        return;
      }
      await _call(
        method: 'PUT',
        path: '/v1/admin/catalog/$name',
        server: option('server'),
        body: jsonEncode(document),
      );
    case 'rollback':
      await _call(
        method: 'POST',
        path: '/v1/admin/catalog/$name/rollback',
        server: option('server'),
      );
    default:
      stderr.writeln('Unknown command: $command');
      exitCode = 64;
  }
}

Future<void> _call({
  required String method,
  required String path,
  required String? server,
  String? body,
}) async {
  final token = Platform.environment['ADMIN_TOKEN'];
  final base = server == null ? null : Uri.tryParse(server);
  if (base == null || !HttpAccountRepository.isAcceptableBaseUrl(base)) {
    stderr.writeln(
      'Give the server as --server=https://… (plain http is accepted only '
      'for localhost).',
    );
    exitCode = 64;
    return;
  }
  if (token == null || token.isEmpty) {
    stderr.writeln('Set ADMIN_TOKEN in the environment.');
    exitCode = 64;
    return;
  }
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, base.resolve(path));
    request.headers.set('authorization', 'Bearer $token');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(body));
    }
    final response = await request.close();
    final text = await utf8.decodeStream(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      print('Done (${response.statusCode}). $text');
    } else {
      stderr.writeln('The server refused (${response.statusCode}): $text');
      exitCode = 1;
    }
  } finally {
    client.close();
  }
}
