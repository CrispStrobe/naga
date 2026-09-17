# Available-build desktop WASM baseline

**12/12 passed**, four scenarios × three fresh-context samples, each with ≥5 seconds of guarded active RAF. Collection: 2026-09-17 19:02:23–19:04:17 UTC. Actual loaded Dart WASM matched the fingerprint in every sample; build fingerprints were unchanged before/after.

**Not final-build evidence or an optimization speedup claim.** This is the earlier optimization release-WASM served at port 8766. Parent must rebuild and rerun for final source changes.

Host: MacBookAir10,1, Apple M1, 8 logical CPUs, 16 GiB, macOS 26.2. Chrome 153.0.8010.47 headless, Playwright 1.58.2, Node v26.4.0; 1280×800 / DPR 1. Other repository CPU work was present: load averages at start 8.63/14.77/20.34, end 18.25/15.82/20.01. **Not a controlled idle-host baseline.**

## Measurements

RAF percentiles below pool the three repetitions within each scenario only. Startup lists all three observations.

| Mode | CPU | App-ready samples (ms) | RAF p50 / p95 / p99 (ms) | Guarded live seconds / gaps |
|---|---|---|---|---|
| Classic | 1× | 527.3, 495.0, 574.8 | 16.665 / 16.670 / 16.670 | 15.366 / 922 |
| VS AI | 1× | 574.4, 449.6, 541.2 | 16.665 / 16.670 / 16.670 | 15.349 / 921 |
| Classic | 4× | 1493.4, 1591.1, 1097.8 | 16.665 / 16.670 / 16.670 | 15.283 / 917 |
| VS AI | 4× | 1275.8, 1569.7, 1551.2 | 16.665 / 16.670 / 16.670 | 15.266 / 916 |

| Mode | CPU | Encoded network bytes, each sample | End JS heap used bytes, each sample | Restarts |
|---|---|---|---|---|
| Classic | 1× | 3970042, 3970042, 3970042 | 15287976, 13497420, 13692928 | 2, 2, 2 |
| VS AI | 1× | 3831087, 3821533, 3821534 | 12521252, 19431728, 11438816 | 3, 2, 2 |
| Classic | 4× | 3970042, 3970042, 3970042 | 12563680, 14024332, 16376288 | 2, 2, 2 |
| VS AI | 4× | 3840642, 3831088, 3831088 | 18702240, 9532240, 17737552 | 3, 3, 3 |

RAF observations are effectively pinned to headless Chrome’s ~16.67 ms cadence for this short unattended-forward/restart workload. They do **not** establish engine/raster/presentation FPS, input latency, or absence of missed visible frames. Default AI, short snakes and unseeded food are not worst-case gameplay. App readiness includes accessibility activation scheduling, not exact first paint.

CDP CPU counters and full request/ResourceTiming data are retained in the raw JSON. CPU deltas include polling/restart windows. JS heap is **not total WASM/application memory**. Network totals reflect local-server/main-target accounting, not production transfer budgets. See `performance.md` for exact definitions and omissions.

Physical audio output latency: **unmeasured**; headless Chrome is muted and downloading an asset is not an onset measurement. Physical iPad: **unmeasured**; Safari session creation was blocked because Web Inspector was not enabled. Desktop 4× CPU throttle is not a calibrated phone.

## Evidence and verification

- Completed raw matrix: `performance-baseline-complete.json`, including exact script hash, runtime/GPU metadata, every raw RAF timestamp and transition, per-sample errors, and build hashes.
- Served Dart WASM: 2,336,894 bytes; SHA-256 `091363de2367b7a46e595316448292eae1df25c278399f9a4cb6a42064dcc8fa`.
- Independent Node assertions verified 12 unique samples, all 12 passed, unchanged build, exact mode identity and ≥5000 ms guarded live time each. Syntax and embedded percentile/boundary tests pass.
- Failed/incomplete attempts remain separate and are not pooled: readiness pilot 0/4, immediate-info diagnostic 0/1, first matrix interrupted after six successes with a seventh target-crashed record during termination. Successful one-sample diagnostics are also separate. `performance.md` records the causes known and unresolved browser hang.
- No production instrumentation or commits. Parent owns final rebuild and rerun; choose a fresh output filename.
