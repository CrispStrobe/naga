# Desktop release-WASM profiling

## Reproduce

Serve an **immutable release-WASM build directory** with `scripts/qa/serve_web.py` (COOP `same-origin`, COEP `credentialless`). Do not rebuild into the served directory during collection. Run from the repository root, with Playwright available in `scripts/qa/node_modules` or `/tmp/naga-qa/node_modules` and installed Google Chrome:

```sh
node --check scripts/qa/profile_web.cjs
node scripts/qa/profile_web.cjs --self-test
QA_BUILD_LABEL='describe exact immutable build here' \
  node scripts/qa/profile_web.cjs 8766 /tmp/naga-qa/performance-new.json 3 5000
```

Arguments: port (or full base URL), new output JSON path, repetitions per scenario, minimum **guarded active** milliseconds per repetition. Existing output files are refused, not overwritten. Default matrix: Classic / VS AI × unthrottled / CDP 4× CPU slowdown, three fresh browser contexts each. For a diagnostic single sample:

```sh
QA_MODE=Classic QA_CPU_RATES=1 \
  node scripts/qa/profile_web.cjs 8766 docs/verification/performance-diagnostic.json 1 5000
```

`QA_BROWSER_CHANNEL` defaults to `chrome`. Native here means **unthrottled browser**, not a native Flutter executable. Do not run multiple profiling jobs or builds/tests concurrently. Host load averages are saved; these do not prove an idle host. Quiesce other work for a controlled comparison.

## Measurements and raw evidence

- **App-ready startup:** navigation time origin to the first accessible home-menu content (`CLASSIC Retro phone legacy` plus `Settings`) after enabling Flutter semantics. The exact Classic menu button must also be visible. This includes Playwright's accessibility activation scheduling; it is not HTML load, exact first-pixel time, or proof that every asset has loaded. Navigation timing is retained separately.
- **Actual mode identity:** real menu keyboard navigation, SCORE HUD, then exact mode title in the info dialog. No game object injection or production instrumentation. A 350 ms route-settling wait mirrors the working mode smoke harness before clicking info. Close info and resume before recording.
- **Active RAF:** page `requestAnimationFrame` timestamps recorded only when the HUD is present, game-over/menu/pause/dialog text is absent and the document is visible. Unattended default forward movement is intentionally repeatable; after death the harness clicks PLAY AGAIN. Each contiguous live segment is trimmed by 100 ms at both ends, and gaps never cross lives. Require at least the requested guarded live duration and 100 positive gaps, otherwise fail. Raw timestamps and observed live/dead transitions are saved. This is an accessibility-observed liveness proxy, not access to the engine's private state; boundary trimming reduces but cannot prove zero semantics lag. Idle/game-over RAF is not pooled into the result.
- **Statistics:** nearest-rank p50/p95/p99/max; report both per-repetition and pooled per-scenario values. Pooling frames does not create independent experimental repetitions. The workload has short snakes, default AI settings, random food placement and restarts; it is not a long-game/worst-case benchmark.
- **CPU and JS heap:** CDP Performance counters before/after capture, raw plus deltas. CPU counter deltas include polling and restart gaps, not exclusively live game time. Main-target counters omit worker/GPU activity. JSHeapUsedSize is **not total application memory**: WASM linear memory, renderer, workers and GPU/native allocations are outside this accounting; WASM-GC accounting is implementation-dependent. No total-memory or leak conclusion follows.
- **Network:** main-target CDP completed encodedDataLength from navigation to sample end, plus request metadata and ResourceTiming. HTTP cache disabled, service workers blocked, no artificial network throttle. Local server transfer/compression policy differs from production. Worker traffic may be omitted. A zero ResourceTiming transferSize can mean cross-origin timing is unavailable. Repeated audio/music requests on restart can change totals. These numbers are not asset-size-only budgets.
- **Build/runtime identity:** fetched SHA-256 and byte counts for bootstrap/index/Dart module/Dart WASM/version; actual page-loaded Dart WASM response hash must match, and loading `main.dart.js` fails the sample. End-of-run fingerprints must be unchanged. Runtime, browser, GPU/system info and hardware metadata are retained. The source checkout HEAD is explicitly context only, not an assertion that the served build came from that revision. Build mode provenance remains supplied by the operator; the script verifies WASM execution, not compiler optimization flags.
- **Crash safety:** after every completed sample, append its record to the result array and atomically checkpoint the JSON. Failed records remain failed with errors and, in current script versions, DOM/AX/observer evidence. Final counts and summaries are recomputed from the saved samples; no failed samples enter summaries. Script SHA-256 identifies the exact harness version used.

## Scope exclusions

Headless desktop Chrome at 1280×800 / DPR 1 is not a target phone or real display presentation measurement. RAF gaps are not Flutter build/raster times, GPU frame deadlines, physical display FPS, or interaction latency. CDP 4× slowdown is a separate synthetic main-target CPU condition, not a calibrated mobile device. Three short samples establish an available-build observation, not a statistically strong regression threshold or before/after improvement.

Physical audio onset/output latency is **UNMEASURED**. Downloading an audio asset does not establish when sound becomes audible. A physical iPad is paired, but Safari session creation was reported blocked because Web Inspector was not enabled; there are **no physical-iPad measurements** in these artifacts.

## Diagnostic history (not performance claims)

- `performance-pilot.json.gz`: **0/4 failed**. The original startup predicate incorrectly required `THE SNAKE GAME` in `body.innerText`; actual inspection showed that string only as an AX group label, while innerText contained the exact Classic menu button and Settings. Summaries are empty. The file is retained unchanged.
- `performance-readiness-check.json.gz`: **0/1 failed** after correcting readiness. Immediate info-button click preceded the route transition completing; the final failure evidence records GAME OVER and no info dialog. No performance summary.
- `performance-classic-check.json.gz`: **1/1 passed**, unthrottled Classic, after matching the existing smoke harness's 350 ms route settle before info. This diagnostic is separate from the baseline matrix, not an extra pooled sample.

- `performance-baseline.json.gz`: first matrix attempt was interrupted after six successful unthrottled samples when the first 4× run became unresponsive for several minutes. Only the owned profiling process was terminated; the seventh record reports a crashed target from that termination. It remains `complete: false`, with no final summary or end fingerprint. This is not a completed matrix or a demonstrated app regression.
- `performance-throttle-check.json.gz`: an isolated fresh-browser 4× Classic diagnostic passed. Root cause of the preceding hang was not established. A 90-second per-sample watchdog now checkpoints failure with its phase and aborts rather than waiting indefinitely for an unresponsive browser/CDP call.

The retried available-build matrix and numeric summary are recorded in `performance-baseline-complete.json.gz` and `performance-baseline.md`. Diagnostic/failed/incomplete attempts are not pooled into it. The parent must rebuild and rerun to establish evidence for final source changes.
