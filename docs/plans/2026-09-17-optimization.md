# Naga Optimization Implementation Plan

> **For Hermes:** Use subagent-driven-development to implement and review the independent workstreams.

**Goal:** Reduce wiring duplication and runtime allocations without changing mode rules or appearance, backed by unit, integration and live browser tests.

**Architecture:** Keep mode-specific rules/renderers. Extract reusable grid-body/input primitives by composition, not a universal superclass; add a typed game-session registry for UI lifecycle dispatch. Optimize AI search buffers and render resources where the actual code shows repeated work.

**Tech Stack:** Flutter/Dart, Flame, flutter_test, browser automation of a locally served WASM build.

No commits, pushes or production deployment without explicit instruction. Earlier suggestions about line savings and speedups were hypotheses, not measurements. audioplayers is directly imported; flame_audio appears unused. Classic already has an occupancy set, whose tail overlap semantics need regression coverage.

## 1. Baseline
- Run flutter test and flutter analyze, retain outputs.
- Build baseline web WASM and keep a separate copy outside build/ for screenshot comparison.
- Check actual tools and browser availability locally; use a local HTTP server with COOP/COEP headers.

## 2. Typed game registry and screen dispatch
- Read lib/ui/game_screen.dart, lib/ui/home_screen.dart, lib/modes/*.dart and public game lifecycle APIs.
- Create lib/game/game_registry.dart with typed session callbacks for direction, pause, restart/respawn and mode capabilities; centralize construction and special options without dynamic invocation.
- Write test/game_registry_test.dart first, run to expose missing registry, then migrate game_screen.dart dispatch. Preserve victory callbacks, multiplayer player selection, AI settings, classic overrides and mode-specific HUD behavior.
- Exercise every registered mode constructor and control/lifecycle integration; document the new-mode steps in CLAUDE.md after integration.

## 3. Shared grid snake state
- Read body mutations and direction queues in lib/components/{snake,ai_snake,trail_snake}.dart and game implementations, starting with snake2/ascii/cga/nibbles.
- Add pure Dart shared primitives under lib/game/shared/ with tests under test/ first: indexed ring body with consistent occupancy counts; bounded direction queue and grid movement/wrapping helpers where semantics match.
- Validate growth, shrink, reverse, occupied tail movement, duplicate cells, index access, reset, full-board spawning, bounds and wrapped directions. Run tests before implementation and after each behavioral slice.
- Migrate compatible call sites in small batches; preserve distinct input capacities, collision rules and game timing. Keep mode-specific collision/score/food policy in each game rather than forcing superficially similar modes to share rules.
- Run all existing dungeon/venom tests after migration.

## 4. AI search allocation reduction
- Read lib/components/snake_ai.dart and callers.
- Add test/snake_ai_test.dart scenario tests and a reproducible benchmark before refactoring.
- Reuse integer-indexed grid BFS/flood-fill queues, visit generations and occupancy arrays where safe; preserve search ordering and public API. Verify wrap handling, safety, tail reachability and fallback; deterministic seeded injection only if required for reliable tests.
- Run tests and report measured benchmark results, not estimated speedups.

## 5. Rendering and palettes
- Inspect render methods and distinguish already cached fields from per-frame allocations.
- Add render regression tests before refactoring. Hoist Paint instances with explicit style resets, cache TextPainter layout by content/style/size using bounded storage, dispose resources when applicable. Never cache animated alpha as a fixed color.
- Put semantic per-mode palettes under lib/modes/; avoid replacing each literal with an opaque numeric alias.
- Keep Classic pixel rendering unchanged; compare actual raster output and live screenshots.

## 6. Dependencies and audio contracts
- Verify imports across the repo, remove only unused flame_audio, retain audioplayers.
- Add an audio asset existence contract covering mapped music and SFX, and test silent-service settings without hanging platform futures.
- flutter pub get; flutter clean before final WASM build because plugins changed.

## 7. Integration review and verification
- Spec review of all workstreams, then code-quality review; fix material findings.
- Run flutter analyze and full flutter test. Build web WASM with version information.
- Live browser matrix: launch every home-screen mode, input, pause/resume, back navigation; explicitly check two-player/AI controls and settings, restart/death where reproducible. Check desktop and narrow viewport, console/page errors and asset network failures. Save per-mode evidence and aggregate count in code.
- Save an honest verification report with commands, counts, screenshots, benchmark method and any untested paths or blockers. Update CLAUDE.md with the registry workflow.
