# Labour-market data

How pay and employment figures get into the product, and what keeps them honest.

## Rules

1. **A figure never appears without its source and the period it describes.** `LaborStats`
   cannot be constructed without labour-market `Evidence`, and `Evidence` of that kind
   cannot be constructed without a source and an as-of date.
2. **No figures loaded means no figures shown.** `BundledLaborMarketRepository` returns
   `null` when nothing has been imported. The occupation page then says pay figures are
   not loaded; it does not show a placeholder number.
3. **Occupation text contains no figures of its own.** A test in
   `packages/launchpad_data/test/occupation_catalog_test.dart` rejects currency amounts,
   percentages and large numbers in the catalogue copy.
4. **Figures describe a distribution.** The median is shown with the 10th and 90th
   percentiles where the publisher releases them, and a wide spread is called out in words.
5. **Figures older than 18 months carry a warning** (`Evidence.stalenessThreshold`).
6. **Bundled, not fetched.** Figures are compiled into the app. Reading about an occupation
   makes no network request, so what a person looks at is disclosed to nobody. The cost is
   that figures are as old as the last import, which is why rule 1 matters.

## Source

U.S. Bureau of Labor Statistics, Occupational Employment and Wage Statistics (OEWS),
national cross-industry estimates, read through the Bureau's public data API
(`https://api.bls.gov/publicAPI/v2/timeseries/data/`). The figures are works of the U.S.
government. Occupations are joined on the 2018 Standard Occupational Classification code
held on each catalogue entry.

Series used per occupation (OEWS data-type codes): `01` employment, `11` annual 10th
percentile wage, `13` annual median wage, `15` annual 90th percentile wage; plus the
all-occupations annual median for "above the median" comparisons.

Not used: employment projections. They come from a different programme, and the product's
principles caution against projecting recent history forward. Where a field is visibly
changing, the catalogue says so in words (`Occupation.changeNote`).

## Importing

```sh
cd packages/launchpad_data
dart run tool/import_oews.dart --save-responses=/tmp/oews --occupation-table=oe.occupation
dart format lib/src/labor/oews_snapshot.g.dart
flutter test
```

- `--save-responses` keeps the raw API responses so an import can be audited and repeated
  with `--from-dir`.
- `--occupation-table` checks every catalogue SOC code and official title against the
  Bureau's own `oe.occupation` list, so a mistyped code cannot attach one occupation's pay
  to another. Run with it whenever the catalogue's codes change.

The importer writes nothing if any check fails: a request that did not succeed, series
that report different years, an occupation with no median, or a missing all-occupations
median.

## Status

The importer and its checks are built and tested against a fixture in the API's response
format. See the roadmap for whether a snapshot has been imported; the generated file
`packages/launchpad_data/lib/src/labor/oews_snapshot.g.dart` is the ground truth.
