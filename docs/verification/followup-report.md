# Follow-up verification

## Delivered

- Prior optimization work saved in four local commits; CLAUDE.md mode-registration workflow updated. The live read-only occupiedCells contract is retained and documented; mutate Snake.segments instead.
- Bounded uniform free-cell selection replaces unbounded food spawning in Classic/Arcade/Zen, ASCII, CGA, Nibbles and Duel. Filled boards finish rather than hang. Snake II preserves numbered/maze progression and handles item reservations and newly loaded obstacles. Duel resolves full arenas by score, ties drawing.
- 25 focused full-board/selector regressions cover nearly full boards, terminal callbacks, restart/respawn, maze transitions and pending power-up removal. Synthetic occupancy fixtures isolate edge states, not complete legal player paths.
- Removed unused shared SnakeAI and redundant reference benchmarks/tests. Production VS AI strategy and trace tests remain; AiDifficulty now lives in lib/modes/ai_difficulty.dart.
- Added PR/main/manual Regression checks workflow: Flutter 3.44.4, Node 22, pinned Playwright lockfile, analyzer/tests, release WASM, desktop/narrow mode checks, lifecycle tests and always-uploaded evidence. No production deployment changes.
- Added reusable lifecycle and performance harnesses. Live settings writes are made through UI and checked after reload; no game-state injection.

## Parent execution

- Full unit suite: 113 passed (the unused AI tests were removed and new completion tests added).
- flutter analyze --no-pub: no issues.
- git diff --check: clean.
- flutter build web --wasm --release: successful, Flutter 3.44.4.
- Fresh build desktop: 20/20 mode checks; narrow 390px: 20/20. Includes launch identity and pause checks; no captured browser errors.
- Fresh build lifecycle: 5/5 (Classic death/restart/menu, settings persistence/extra-life consumption/restart, separate Duel keyboard players, raw touch pause/resume/up-swipe/menu).
- actionlint v1.7.7 checks.yml: exit 0. Node syntax checks and profiler self-tests: exit 0.
- Visual inspection: Classic board, HUD, retro snake and food render without obvious corruption.
- Aggregated browser results: followup-browser-results.json. Screenshots/traces remain in /tmp/naga-qa/final-{desktop,narrow,lifecycle} on this host.

## Final-build performance observation

performance-final.json.gz contains 12/12 passing samples (Classic/VS AI × unthrottled/4× CPU, three repetitions). Build hashes stayed unchanged and loaded WASM matched; no JS fallback. Each sample includes at least five seconds of guarded active RAF timestamps.

App-ready times on local headless Chrome: 482–570 ms unthrottled; 805–1016 ms at 4× CPU slowdown. These include semantics activation and local-server loading, not production cold-start or exact first-pixel timing. RAF p95/p99 around 16.67 ms is scheduler cadence, not rendered FPS; one throttled VS AI sample had a 233 ms maximum gap. No before/after speedup claim is supported by these runs. Heap/network counters and limitations are documented in performance.md. Earlier failed/incomplete diagnostics remain explicitly separate from successful samples.

## Remaining external verification

- GitHub-hosted CI has not run: commits are local, not pushed. A workflow is not branch-protection enforcement; requiring its status check needs repository settings after the first remote run.
- Physical iPad profiling blocked: Safari WebDriver reports Web Inspector disabled. Enable it on the device before an on-device run. No phone/iPad performance or physical audio-onset measurements were produced.
- Browser lifecycle tests verify score consistency/reset, not guaranteed positive scoring on every random-food run. Deterministic food growth/score/victory paths are covered by unit tests.
- Full-board policies cover the identified compatible spawning loops, not a new unified completion policy for every specialized action mode.
