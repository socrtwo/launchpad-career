# Performance review (internal)

Measured by the project's author, an AI coding assistant, on 19 November 2026. These are
single-machine measurements, recorded with their method so they can be repeated; they are
not a benchmark and say nothing about slow devices or real networks.

## Web build size

Release build from `./tool/build_web.sh`, Flutter 3.44.8, measured with `ls -l` and
`gzip -c | wc -c` (default compression level).

| File | Bytes | Gzipped |
| --- | --- | --- |
| `main.dart.js` (the whole app) | 3,254,374 | 945,005 |
| `canvaskit/chromium/canvaskit.wasm` (renderer, Chromium browsers) | 5,760,502 | 2,191,710 |
| `canvaskit/canvaskit.wasm` (renderer, other browsers) | 7,229,467 | not measured |
| Roboto, three weights | 514,500 | not measured |
| Material icons, tree-shaken | 12,640 | not measured |

A first visit in Chromium transferred about 9.0 MB uncompressed. With gzip on the host
the two largest files come to about 3.1 MB. The renderer is most of it, and it is the
price of serving it ourselves rather than from a shared CDN.

## Start-up

Chromium 153 (headless, Playwright), 4-core Linux container, files served from the same
machine with no compression and nothing cached, five runs.

| Measure | Range |
| --- | --- |
| Navigation to the Flutter view being attached | 563–698 ms |
| Navigation to network idle | 755–820 ms |

This excludes network latency entirely. On a real connection the first visit is dominated
by downloading the renderer.

## Observations

- **Everything is local after load.** Search, suggestions, comparison and every tool run
  on bundled data with no requests, so there is no per-interaction latency to measure.
- **The catalogue is small** (28 occupations). Search is a linear scan and stays cheap
  into the low thousands; beyond that it should move behind an index.
- **Every change re-encodes the whole session** when storage is on. With the caps on notes
  (200 notes of 600 characters) the worst case is about 120 KB of JSON per keystroke in a
  note field. It has not been a problem in testing; debouncing writes is the first thing
  to do if it becomes one.
- **Server sign-in costs about 1.2 s of CPU by design** at 600,000 iterations, as timed
  on the same container by the automated agent that built the server (account creation
  1.34 s, sign-in 1.20 s; a single run each). It runs off the main isolate, two at a time.

## Not measured

Native start-up and frame times on real devices; memory; behaviour on low-end phones;
anything under real network conditions; the server under load.
