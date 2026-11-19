// Imports national pay and employment figures for the bundled occupations
// from the U.S. Bureau of Labor Statistics public data API and writes
// lib/src/labor/oews_snapshot.g.dart.
//
//   dart run tool/import_oews.dart
//       Fetch from the API (about five unregistered requests).
//   dart run tool/import_oews.dart --save-responses=DIR
//       Also keep the raw responses, so the import can be repeated and audited.
//   dart run tool/import_oews.dart --from-dir=DIR
//       Build from responses saved earlier instead of the network.
//   dart run tool/import_oews.dart --occupation-table=FILE
//       Also check every SOC code and title against the publisher's
//       `oe.occupation` table.
//
// The importer refuses to write anything if a check fails.

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:launchpad_data/launchpad_data.dart';

Future<void> main(List<String> arguments) async {
  String? option(String name) {
    for (final argument in arguments) {
      if (argument.startsWith('--$name=')) {
        return argument.substring(name.length + 3);
      }
    }
    return null;
  }

  final fromDir = option('from-dir');
  final saveDir = option('save-responses');
  final occupationTable = option('occupation-table');
  final occupations = bundledOccupations;
  final codes = occupations.map((item) => item.socCode).toList();

  if (occupationTable != null) {
    final problems = OewsImporter.checkTitles(
      catalogTitlesBySoc: <String, String>{
        for (final item in occupations) item.socCode: item.socTitle,
      },
      occupationTable: await File(occupationTable).readAsString(),
    );
    if (problems.isNotEmpty) {
      stderr.writeln('Occupation codes do not match the published list:');
      problems.forEach(stderr.writeln);
      exitCode = 1;
      return;
    }
    print('All ${codes.length} occupation codes match the published list.');
  }

  final responses = <Map<String, Object?>>[];
  if (fromDir != null) {
    final files = Directory(fromDir)
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      responses.add(
        (jsonDecode(await file.readAsString()) as Map).cast<String, Object?>(),
      );
    }
  } else {
    final client = HttpClient()..userAgent = 'launchpad-career-importer';
    try {
      final bodies = OewsImporter.requestBodies(codes);
      for (final (index, body) in bodies.indexed) {
        final request = await client.postUrl(Uri.parse(OewsImporter.apiUrl));
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
        final response = await request.close();
        final text = await utf8.decodeStream(response);
        if (response.statusCode != 200) {
          stderr.writeln('Request ${index + 1} failed: ${response.statusCode}');
          exitCode = 1;
          return;
        }
        if (saveDir != null) {
          await Directory(saveDir).create(recursive: true);
          await File(
                  '$saveDir/response_${index.toString().padLeft(2, '0')}.json')
              .writeAsString(text);
        }
        responses.add((jsonDecode(text) as Map).cast<String, Object?>());
      }
    } finally {
      client.close();
    }
  }

  try {
    final snapshot = OewsImporter.build(
      socCodes: codes,
      responses: responses,
      retrievedOn: DateTime.now().toUtc(),
    );
    final output = File('lib/src/labor/oews_snapshot.g.dart');
    await output.writeAsString(OewsImporter.render(snapshot));
    print(
      'Wrote ${output.path}: ${snapshot.statsBySoc.length} occupations, '
      '${snapshot.referencePeriod}. Run `dart format` and the tests.',
    );
  } on OewsImportException catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
