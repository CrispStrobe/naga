# Naga — The Snake Game

Naga is a cross-platform Snake game built with Flutter and Flame. It is not one Snake game with many skins: its 27 modes each start from "steer a growing snake" and then change the rules, from a faithful LCD-phone classic to a turn-based roguelike, a land-claiming game against AI rivals, and a mode where you catch fireflies by closing a loop of your own body. Local high scores, achievements, AI opponents, and full English/German localization.

🌐 Play it in the browser: **https://naga-game.vercel.app**
📦 Prebuilt Android/iOS/web builds: [GitHub Releases](https://github.com/CrispStrobe/naga/releases) (tag pushes of the form `vX.Y.Z` trigger a build; Android and iOS builds are **unsigned** — Android is debug-signed for sideloading, iOS requires resigning before it will run on a device)

## Game modes

| Section | Modes | Notes |
|---|---|---|
| Daily | Daily Serpent | One seeded board per day, identical on every platform; best score and streak |
| Classic | Classic, Arcade, Zen, Nightfall, Portals | LCD-phone classic · neon speed run · no death · lantern-lit board · a portal pair that moves after every meal |
| Crossover | Maze Hunter, Trail, Fangs, Venom, Shed | Maze chase with pathfinding ghosts · light-cycle arena · brick breaker with the snake as paddle · bomb-and-blast campaign · shed skin becomes wall, full rows clear |
| Action | Pit, Swarm, Rush, Ouroboros, Echo, Territory | Last snake standing · eat the invaders · endless auto-scroll · catch fireflies by enclosing them · your last run returns as a ghost · claim land against AI rivals |
| Legacy | Snake II, ASCII, CGA, Nibbles | Maze levels & wrap-around · terminal text mode · 4-color retro PC · a 1991 DOS classic |
| Minigames | Stampede, Naga Dive | Five-lane animal race · underwater swim |
| Adventure | Dungeon | Turn-based roguelike crawler |
| Multiplayer | Duel, VS AI, VS AI Split | Local 2-player on one device · AI opponents at 4 difficulty levels (BFS pathfinding) |

## Features

- 27 game modes, each with its own rules, palette, and music
- Configurable grid size, wall behavior, lives, controls, difficulty, and starting speed
- Power-up system: Speed, Shield, Magnet, Slow, Shrink
- Local high scores, a daily-challenge streak, and achievements (no accounts, no ads, no tracking)
- AI opponents using BFS pathfinding with tail-reachability checks
- D-pad, swipe and full keyboard controls, direction input queue, pause (Esc/P)
- Per-mode OGG music and SFX, toggleable
- English and German localization (Flutter gen-l10n)
- Runs on iOS, macOS, Android, and Web (including WASM builds)

## Tech stack

- **Framework:** Flutter 3.44+ with the [Flame](https://flame-engine.org/) game engine (1.37)
- **State:** no external state management — game state lives inside each mode's `FlameGame` subclass
- **Persistence:** `shared_preferences` for settings, high scores, and audio prefs
- **Audio:** `flame_audio` + `audioplayers`
- **i18n:** Flutter `gen-l10n`, ARB files, generated class `S`

## Project structure

```
lib/game/          Game implementations — one FlameGame subclass per mode
lib/modes/         Mode definitions (colors, speeds, rules — extend GameMode)
lib/components/    Shared Flame components (snake, food, ghost, maze, power-ups, ...)
lib/ui/            Flutter screens (home, game, settings, high scores, about)
lib/services/      Settings, high scores, audio services
lib/l10n/          ARB translation files (app_en.arb, app_de.arb)
lib/generated/     Auto-generated l10n code (do not edit)
lib/theme/         Shared color palette
assets/audio/      Per-mode music (OGG) and SFX
assets/icon/       App icon source images
```

## Getting started

```bash
flutter pub get
flutter gen-l10n              # regenerate lib/generated after editing ARB files
flutter analyze
flutter test
flutter run                   # launch on a connected device/simulator, or Chrome
```

### Building for web

```bash
flutter build web --profile   # profile build — closest to release behavior in dev
flutter build web --release   # release build (smaller)
flutter build web --wasm      # WASM build (fastest; requires a modern browser)
```

`flutter clean` is required before a WASM build after changing any plugin.

### Deploying

```bash
flutter clean && flutter pub get
flutter build web --wasm \
  --dart-define=GIT_COMMIT=$(git rev-parse HEAD) \
  --dart-define=BUILD_MODE=wasm
cp vercel.json build/web/vercel.json
vercel deploy --yes --prod --force build/web
```

`vercel.json` sets the `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: credentialless` headers WASM needs. CI (`.github/workflows/deploy.yml`) builds and deploys to Vercel automatically on push to `main`.

## Adding a new game mode

1. Create `lib/modes/foo_mode.dart` extending `GameMode`.
2. Create `lib/game/foo_game.dart` extending `FlameGame with KeyboardEvents`, implementing `changeDirection(Direction dir)`, an `onGameOver` callback, and an `onScoreChanged` callback.
3. Add i18n strings to both ARB files and run `flutter gen-l10n`.
4. Wire it into `lib/ui/game_screen.dart` (import, mode detection, `_createGame` branch, `_changeDirection` branch).
5. Wire it into `lib/ui/home_screen.dart` (import, add a `_ModeButton`).

## License

AGPL-3.0. See the in-app About screen or https://www.gnu.org/licenses/agpl-3.0.html.

© Christian Ströbele
