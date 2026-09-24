# CLAUDE.md — Naga

## Quick commands

```bash
export PATH="/mnt/volume1/toolchain/flutter/bin:$PATH"
flutter pub get
flutter gen-l10n              # After editing ARB files
flutter analyze               # Check for errors
flutter build web --profile   # Web build (profile mode — works on web)
flutter build web --release   # Release build (smaller, verify with Playwright)
flutter build web --wasm      # WASM build (fastest, requires modern browser)
flutter test                  # Run tests
```

## Deploy

```bash
flutter clean && flutter pub get              # Clean build cache (required after plugin changes)
# Build with version info:
flutter build web --wasm \
  --dart-define=GIT_COMMIT=$(git rev-parse HEAD) \
  --dart-define=BUILD_MODE=wasm
cp vercel.json build/web/vercel.json          # Copy COOP/COEP headers config
# Link the build folder to naga-game. Without this, `vercel deploy build/web`
# ignores the repo's .vercel/ link and picks the project named after the
# folder: `web`, which is another app's production project.
mkdir -p build/web/.vercel && cp .vercel/project.json build/web/.vercel/
# No interactive login on this server: use the token from ~/.env.
vercel deploy --yes --prod --force build/web --scope crispstrobes-projects \
  --token "$(grep '^VERCEL_TOKEN=' ~/.env | cut -d= -f2-)"
# The output must say "Deploying crispstrobes-projects/naga-game"; if it names
# another project, stop and roll that project back (vercel promote <previous>).
# Verify: npx playwright screenshot --browser chromium --wait-for-timeout 30000 URL /tmp/check.png
```

**WASM requirements:** `vercel.json` must set `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: credentialless` headers (already configured). Must `flutter clean` before WASM builds to regenerate plugin registrant.

## Architecture

- **Framework:** Flutter 3.44.1 + Flame 1.37.0
- **State:** No state management library — game state lives in FlameGame subclasses
- **i18n:** Flutter gen-l10n, class `S`, ARB files in lib/l10n/, generated in lib/generated/
- **Persistence:** SharedPreferences (settings, high scores, audio prefs)

### Key directories

```
lib/game/          Game implementations (each mode has its own FlameGame subclass)
lib/modes/         Mode definitions (colors, speeds, rules — extend GameMode)
lib/components/    Shared Flame components (snake, food, ghost, maze, power_up, etc.)
lib/ui/            Flutter widgets (screens: home, game, settings, high scores, about)
lib/services/      Services (settings, high scores, audio)
lib/l10n/          ARB translation files (app_en.arb, app_de.arb)
lib/generated/     Auto-generated l10n code (do not edit manually)
assets/audio/      Music (OGG per mode) and SFX
```

### Adding a new game mode

1. Create `lib/modes/foo_mode.dart` extending `GameMode`
2. Create `lib/game/foo_game.dart` extending `FlameGame with KeyboardEvents`
   - Must have: `changeDirection(Direction dir)`, `onGameOver` callback, `onScoreChanged` callback
3. Add i18n strings to both ARB files, run `flutter gen-l10n`
4. Register construction and typed controls in `lib/game/game_registry.dart` (`GameSession`: direction, pause, respawn, action and result). Preserve mode-specific lifecycle rules; do not add concrete-game casts to the screen.
5. Add a `_MenuEntry` in `lib/ui/home_screen.dart` and mode instructions in `GameScreen._getInstructions`.
6. Add registry, gameplay and mounted-screen regression tests. Reuse `lib/game/shared/` primitives only where rules match. `Snake.occupiedCells` is a live read-only view; edit the body rather than that view.
7. Run `flutter test`, `flutter analyze`, and WASM browser checks. Raster fixtures were recorded with Flutter 3.44.4; pin that SDK for reproducible tests. Shape-only renderers stay byte-exact. Text renderers (ASCII, CGA, Nibbles, Snake II) are compared structurally instead — dimensions, ink bounding box and normalized 16x16 tile coverage — because glyph antialiasing and alpha banding are resolved by the host rasterizer and differ across macOS and Linux. `.github/workflows/checks.yml` runs the raster test on both.

## Conventions

- Use `withValues(alpha: x)` for color alpha. (The old rule said the opposite; `withValues` was verified on 2026-09-16 under both dart2js and WASM on Flutter 3.44 and works correctly.)
- Wrap platform-specific APIs in `kIsWeb` checks (e.g. SystemChrome)
- AudioService methods are all try/catch wrapped (audioplayers may not work on all platforms).
  Note this hides asset-path mistakes: audio paths are relative to audioplayers' `assets/`
  prefix, so they must start with `audio/` (e.g. `audio/sfx/eat.ogg`). Verify with a real
  build — a wrong path fails silently.
- Classic mode preserves authentic retro look — no smooth rendering, no glow effects
- No Nokia brand references anywhere
- Services use a `_pendingInit` future as the singleton (race-safe); there is no `_instance` field
