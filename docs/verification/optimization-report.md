# Optimization verification

## Implemented

- Typed `GameRegistry` / `GameSession` centralize mode construction and screen lifecycle/control dispatch. Maze retains no-respawn policy; specialized modes pause their Flame engine; covered games cannot receive input behind pause/instructions overlays.
- `GridSnakeBody` is an indexed ring buffer with reference-counted occupancy and mutable List operations. Compatible grid games use it; `DirectionBuffer` shares ten compatible bounded input queues. Distinct collision, reversal, timing and scoring rules remain mode-local.
- Snake exposes a stable live occupancy view. The view is explicitly read-only: writing to the old public set is not supported. External body-list aliases remain supported.
- Shared SnakeAI has reusable integer search buffers and correctness tests. It has no production callers; its benchmark is not evidence of live-game acceleration.
- The separate production `VsAiGame` search path now reuses typed occupancy, visited stamps, queues and distances while retaining its strategy. Seeded trace/checksum tests cover both arenas and all difficulties.
- Snake and ASCII/CGA/Nibbles/Snake II renderers reuse paints, paths and bounded text resources. Semantic palette colors live in their existing modes; Classic keeps its retro rendering. This is targeted hot-path work, not replacement of every color literal across the app.
- GridBoard's picture-cache key now includes offset values as well as cell size. Four raster regressions fail against the original code and pass with the fix.
- Removed unused `flame_audio`; retained directly imported `audioplayers`. Audio asset contract checks all 15 mapped music/SFX files.

## Independently executed final gates

Environment: macOS, Flutter 3.44.4, Dart 3.12.2, local Chrome, WASM/skwasm.

- `flutter test --reporter expanded`: 117 passed, exit 0. Output: `/tmp/naga-qa/final-tests.log`.
- `flutter analyze`: no issues found, exit 0.
- `git diff --check`: clean.
- `flutter clean && flutter pub get && flutter build web --wasm --dart-define=BUILD_MODE=wasm`: succeeded, output `build/web`.
- Render tests retain 56 pre-optimization RGBA fixtures inside `test/snake_render_test.dart`; exact comparisons pass under the test rasterizer.
- `flutter test --no-pub benchmark/vs_ai_runtime_benchmark.dart --reporter expanded`: all 16 scenario checksums match recorded pre-optimization baselines. This independent run measured 5.36–7.90x lower median tick time versus recorded historical timings. It is debug/JIT, not WASM FPS, and not a controlled simultaneous old/new run. Evidence: `vs-ai-runtime.log`; methodology and baseline values are in the benchmark file.

## Live browser checks on the optimized build

Local HTTP server supplied COOP same-origin and COEP credentialless headers.

| Viewport | Modes checked | Exact mode title verified | Pause/resume + P-block check | Captured errors |
| --- | ---: | ---: | ---: | ---: |
| 1280x800 | 20/20 | 20/20 | 20/20 | 0 |
| 390x800 | 20/20 | 20/20 | 20/20 | 0 |

Each run navigated the menu with keyboard input, waited for the exact SCORE label, opened instructions to verify the intended mode's title, closed it, paused via toolbar, pressed P to check the overlay could not be bypassed, resumed, sent directional/action input, and captured screenshots. Duel additionally received WASD. Console errors, page exceptions, failed requests and HTTP >=400 responses were collected. These are smoke/input/lifecycle checks, not proof of completing every game or score rule.

Machine-readable results: `web-desktop.json`, `web-narrow.json`. Screenshot evidence is local at `/tmp/naga-qa/optimized/` and `/tmp/naga-qa/optimized-mobile/`. Earlier baseline checks used pristine HEAD at `/tmp/naga-baseline`; final checks used the changed `build/web` on port 8766.

The original canvas-count smoke detector was invalid for skwasm. It was replaced by real Flutter accessibility semantics and exact mode-title checks; PNG inequality and generic "High Scores" menu text are not considered launch assertions.

### Reproduce web checks

Install Playwright outside the Flutter dependency tree (Chrome must be installed):

```
mkdir -p /tmp/naga-qa
npm install --prefix /tmp/naga-qa playwright@1.60.0
python3 scripts/qa/serve_web.py build/web --port 8766
# In another terminal:
NODE_PATH=/tmp/naga-qa/node_modules node scripts/qa/web_modes.cjs 8766 /tmp/naga-qa/optimized
QA_WIDTH=390 NODE_PATH=/tmp/naga-qa/node_modules node scripts/qa/web_modes.cjs 8766 /tmp/naga-qa/optimized-mobile
```

## Limits / left explicit

- Pre-existing full-board food spawning can loop indefinitely. No new completion/victory policy was invented; resolving that needs a gameplay decision and follow-up test.
- Stable `occupiedCells` read access is preserved; mutation is intentionally rejected to protect body/occupancy consistency.
- Tests do not establish every randomized maze/food variant, all level transitions, browser FPS, native mobile behavior, physical touch behavior, subjective audio playback, or every mode's death/restart end-to-end. Narrow tests use desktop Chrome at mobile width.
- Work is committed and pushed on the `release/readiness` branch under PR #1. No production deployment was performed by this branch.
- `CLAUDE.md` item 7 was updated with the cross-platform raster policy; its older screen-branch wording is still pending review.
- Final read-only review: spec PASS, quality PASS; no concrete new correctness issues found. The reviewer inspected the lifecycle fixes, live occupancy view, direction buffer, render caches and production AI trace coverage. Tests/build/browser results above were independently executed by the parent, not claimed by the reviewer.

## Cross-platform raster determinism (added after CI runs)

The byte-exact raster baselines only held on the machine that recorded them, which is why the raster job had to skip the comparison on Linux. Two findings emerged from the CI runs on PR #1:

- Version skew was not the cause. Both runners use Flutter 3.44.4, the same engine as local.
- Font substitution was one cause. ASCII, CGA, Nibbles and the Snake II maze label resolved the generic default/monospace family, which each platform maps to a different physical font. JetBrains Mono is now bundled as `NagaMono` (`assets/fonts/`, OFL) and referenced explicitly by all four.

Font choice alone does not make text rasters byte-comparable. Measured on commit f0f7704: the same frame renders alpha 18 at pixel 10361 locally, 17 on the macOS runner and 0 on Linux, and total ink is 773 locally, 820 on the macOS runner and 724 on Linux, a 6 to 7 percent spread. A palette comparison fails for the same reason, because the retro renderers band per-pixel alpha and the banded colors shift per platform.

Text renderers are therefore compared structurally — file size, ink bounding box within 2px, total ink within 15 percent, and each 16x16 tile's share of total ink within 0.04. The share bound was calibrated by sweeping the ink alpha threshold from 100 to 170 across all reference frames: worst drift 0.026, so the bound keeps about double the headroom. Shape-only renderers (Classic, Arcade) remain byte-exact. This weakens glyph-level detection for the four text renderers; a wrong glyph of similar mass would not be caught, while a missing glyph, shifted board or resized cell is.
