import 'package:launchpad_domain/launchpad_domain.dart';

/// Builds a [LaborMarketSnapshot] from the U.S. Bureau of Labor Statistics
/// public data API, for the Occupational Employment and Wage Statistics
/// (OEWS) programme.
///
/// This file is pure: it builds request bodies, reads response bodies and
/// renders Dart source. The network lives in `tool/import_oews.dart`, so the
/// reading and the checks can be tested without it.
///
/// The importer refuses to produce a snapshot rather than produce a doubtful
/// one. A figure shown to a student with the Bureau's name on it has to be
/// the Bureau's figure.
abstract final class OewsImporter {
  static const String source =
      'U.S. Bureau of Labor Statistics, Occupational Employment and Wage '
      'Statistics';
  static const String sourceUrl = 'https://www.bls.gov/oes/';
  static const String apiUrl =
      'https://api.bls.gov/publicAPI/v2/timeseries/data/';

  /// OEWS data-type codes, from the programme's `oe.datatype` table.
  static const String employment = '01';
  static const String annualLow = '11';
  static const String annualMedian = '13';
  static const String annualHigh = '15';

  static const List<String> dataTypes = <String>[
    employment,
    annualLow,
    annualMedian,
    annualHigh,
  ];

  /// The occupation code OEWS uses for "all occupations".
  static const String allOccupations = '00-0000';

  /// The most series the API accepts in one unregistered request.
  static const int seriesPerRequest = 25;

  /// National, cross-industry series for one occupation and data type:
  /// `OE` + `U` (not seasonally adjusted) + `N` (national) + seven-digit area
  /// + six-digit industry + six-digit occupation + two-digit data type.
  static String seriesId(String socCode, String dataType) {
    final digits = socCode.replaceAll('-', '');
    if (!RegExp(r'^\d{6}$').hasMatch(digits)) {
      throw ArgumentError.value(socCode, 'socCode', 'not a SOC code');
    }
    return 'OEUN0000000000000$digits$dataType';
  }

  /// Every series needed for [socCodes], plus the all-occupations median.
  static List<String> seriesFor(Iterable<String> socCodes) => <String>[
        seriesId(allOccupations, annualMedian),
        for (final code in socCodes)
          for (final type in dataTypes) seriesId(code, type),
      ];

  /// [seriesFor] split into request bodies the API will accept.
  static List<Map<String, Object?>> requestBodies(Iterable<String> socCodes) {
    final all = seriesFor(socCodes);
    return <Map<String, Object?>>[
      for (var i = 0; i < all.length; i += seriesPerRequest)
        <String, Object?>{
          'seriesid': all.skip(i).take(seriesPerRequest).toList(),
        },
    ];
  }

  /// Reads decoded API responses into a snapshot.
  ///
  /// Throws [OewsImportException] listing every problem found if: a response
  /// did not succeed; any series reports a different year from the others; an
  /// occupation has no median; or the all-occupations median is missing.
  static LaborMarketSnapshot build({
    required Iterable<String> socCodes,
    required Iterable<Map<String, Object?>> responses,
    required DateTime retrievedOn,
  }) {
    final problems = <String>[];
    final latest = <String, _Observation>{};

    for (final response in responses) {
      if (response['status'] != 'REQUEST_SUCCEEDED') {
        problems.add(
          'A request did not succeed: status ${response['status']}, '
          'message ${response['message']}.',
        );
        continue;
      }
      final results = response['Results'];
      final series = results is Map ? results['series'] : null;
      if (series is! List) {
        problems.add('A response had no series list.');
        continue;
      }
      for (final item in series.whereType<Map<Object?, Object?>>()) {
        final id = item['seriesID'];
        final data = item['data'];
        if (id is! String || data is! List) continue;
        final observation = _latestAnnual(data);
        if (observation != null) latest[id] = observation;
      }
    }

    final years = latest.values.map((item) => item.year).toSet();
    if (years.length > 1) {
      problems.add(
        'Series report different years (${(years.toList()..sort()).join(', ')}); '
        'a snapshot must describe one reference period.',
      );
    }

    final baseline = latest[seriesId(allOccupations, annualMedian)]?.value;
    if (baseline == null) {
      problems.add('The all-occupations median is missing.');
    }

    if (years.length != 1) {
      if (years.isEmpty) problems.add('No figures were returned.');
      throw OewsImportException(problems);
    }
    final year = years.single;
    final asOf = DateTime.utc(year, 5);
    final referencePeriod = 'May $year';
    final evidence = Evidence(
      kind: EvidenceKind.laborMarketData,
      source: source,
      sourceUrl: sourceUrl,
      asOf: asOf,
      confidence: ConfidenceBand.high,
    );

    final stats = <String, LaborStats>{};
    for (final code in socCodes) {
      final median = latest[seriesId(code, annualMedian)];
      if (median == null || (median.value == null && !median.topCoded)) {
        problems.add('No median annual wage for $code.');
        continue;
      }
      stats[code] = LaborStats(
        socCode: code,
        medianAnnualWage: median.value,
        medianIsTopCoded: median.topCoded,
        lowAnnualWage: latest[seriesId(code, annualLow)]?.value,
        highAnnualWage: latest[seriesId(code, annualHigh)]?.value,
        employment: latest[seriesId(code, employment)]?.value,
        evidence: evidence,
      );
    }

    if (problems.isNotEmpty) throw OewsImportException(problems);

    return LaborMarketSnapshot(
      source: source,
      sourceUrl: sourceUrl,
      referencePeriod: referencePeriod,
      asOf: asOf,
      retrievedOn: retrievedOn,
      statsBySoc: stats,
      allOccupationsMedianAnnualWage: baseline,
    );
  }

  /// Renders [snapshot] as the generated Dart file.
  static String render(LaborMarketSnapshot snapshot) {
    String date(DateTime value) =>
        'DateTime.utc(${value.year}, ${value.month}, ${value.day})';
    final buffer = StringBuffer()
      ..writeln('// GENERATED FILE. Do not edit by hand.')
      ..writeln('//')
      ..writeln('// Written by `dart run tool/import_oews.dart` from figures '
          'published by the')
      ..writeln('// U.S. Bureau of Labor Statistics. Reference period: '
          '${snapshot.referencePeriod}.')
      ..writeln('// See docs/product/labour-market-data.md.')
      ..writeln()
      ..writeln("import 'package:launchpad_domain/launchpad_domain.dart';")
      ..writeln()
      ..writeln('/// The bundled labour-market figures, or null when none have '
          'been imported.')
      ..writeln('LaborMarketSnapshot? buildBundledOewsSnapshot() {')
      ..writeln('  final evidence = Evidence(')
      ..writeln('    kind: EvidenceKind.laborMarketData,')
      ..writeln("    source: '${snapshot.source}',")
      ..writeln("    sourceUrl: '${snapshot.sourceUrl}',")
      ..writeln('    asOf: ${date(snapshot.asOf)},')
      ..writeln('    confidence: ConfidenceBand.high,')
      ..writeln('  );')
      ..writeln('  return LaborMarketSnapshot(')
      ..writeln("    source: '${snapshot.source}',")
      ..writeln("    sourceUrl: '${snapshot.sourceUrl}',")
      ..writeln("    referencePeriod: '${snapshot.referencePeriod}',")
      ..writeln('    asOf: ${date(snapshot.asOf)},')
      ..writeln('    retrievedOn: ${date(snapshot.retrievedOn)},')
      ..writeln('    allOccupationsMedianAnnualWage: '
          '${snapshot.allOccupationsMedianAnnualWage},')
      ..writeln('    statsBySoc: <String, LaborStats>{');
    final codes = snapshot.statsBySoc.keys.toList()..sort();
    for (final code in codes) {
      final item = snapshot.statsBySoc[code]!;
      buffer
        ..writeln("      '$code': LaborStats(")
        ..writeln("        socCode: '$code',")
        ..writeln('        medianAnnualWage: ${item.medianAnnualWage},')
        ..writeln('        medianIsTopCoded: ${item.medianIsTopCoded},')
        ..writeln('        lowAnnualWage: ${item.lowAnnualWage},')
        ..writeln('        highAnnualWage: ${item.highAnnualWage},')
        ..writeln('        employment: ${item.employment},')
        ..writeln('        evidence: evidence,')
        ..writeln('      ),');
    }
    buffer
      ..writeln('    },')
      ..writeln('  );')
      ..writeln('}');
    return buffer.toString();
  }

  /// Checks catalogue titles against the publisher's occupation list
  /// (`oe.occupation`, tab-separated, code in the first column and title in
  /// the second). Returns one problem per code that is missing or whose title
  /// differs, so a mistyped code cannot attach one occupation's pay to
  /// another.
  static List<String> checkTitles({
    required Map<String, String> catalogTitlesBySoc,
    required String occupationTable,
  }) {
    final published = <String, String>{};
    for (final line in occupationTable.split('\n').skip(1)) {
      final cells = line.split('\t');
      if (cells.length < 2) continue;
      published[cells[0].trim()] = cells[1].trim();
    }
    final problems = <String>[];
    for (final entry in catalogTitlesBySoc.entries) {
      final digits = entry.key.replaceAll('-', '');
      final title = published[digits];
      if (title == null) {
        problems.add('${entry.key} is not in the published occupation list.');
      } else if (title.toLowerCase() != entry.value.toLowerCase()) {
        problems.add(
          '${entry.key} is "$title" in the published list but '
          '"${entry.value}" in the catalogue.',
        );
      }
    }
    return problems;
  }

  static _Observation? _latestAnnual(List<Object?> data) {
    _Observation? best;
    for (final point in data.whereType<Map<Object?, Object?>>()) {
      if (point['period'] != 'A01') continue;
      final year = int.tryParse('${point['year']}');
      if (year == null) continue;
      if (best != null && best.year >= year) continue;
      final footnotes = point['footnotes'];
      final notes = footnotes is List
          ? footnotes
              .whereType<Map<Object?, Object?>>()
              .map((note) => '${note['text'] ?? ''}'.toLowerCase())
              .join(' ')
          : '';
      best = _Observation(
        year: year,
        value: _wholeNumber('${point['value']}'),
        topCoded: notes.contains('equal to or greater than'),
      );
    }
    return best;
  }

  /// Figures arrive as text. Anything that is not a plain non-negative number
  /// ("-", "*", "#") means the publisher did not release a value.
  static int? _wholeNumber(String raw) {
    final cleaned = raw.replaceAll(',', '').trim();
    final value = num.tryParse(cleaned);
    if (value == null || value < 0) return null;
    return value.round();
  }
}

class OewsImportException implements Exception {
  OewsImportException(this.problems);

  final List<String> problems;

  @override
  String toString() =>
      'The import was refused:\n${problems.map((item) => '  - $item').join('\n')}';
}

class _Observation {
  const _Observation({
    required this.year,
    required this.value,
    required this.topCoded,
  });

  final int year;
  final int? value;
  final bool topCoded;
}
