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
vercel deploy --yes --prod --force build/web  # Deploy to Vercel
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
4. Wire into `lib/ui/game_screen.dart` (import, mode detection, _createGame branch, _changeDirection branch)
5. Wire into `lib/ui/home_screen.dart` (import, add _ModeButton to the list)

## Conventions

- Use `withOpacity()` not `withValues()` for color alpha (withValues crashes on web)
- Wrap platform-specific APIs in `kIsWeb` checks (e.g. SystemChrome)
- AudioService methods are all try/catch wrapped (audioplayers may not work on all platforms)
- Classic mode preserves authentic retro look — no smooth rendering, no glow effects
- No Nokia brand references anywhere
- Services use nullable singletons with `_pendingInit` pattern (race-safe)
