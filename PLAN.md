# Naga — Development Plan

## Current State (2026-07-05)

### Done
- [x] Flutter + Flame project scaffold, cross-platform (iOS, Android, Web)
- [x] i18n (EN + DE) with Flutter gen-l10n, class `S`
- [x] About screen (AGPL-3.0, mirrors CrispSudoku pattern)
- [x] Settings: grid size (S/M/L), wall behavior (die/wrap), lives (0-5), control type (swipe/buttons)
- [x] Local high scores per mode (SharedPreferences)
- [x] Audio service with per-mode music + SFX, toggles in settings
- [x] Generated chiptune music (10 tracks) and SFX (5 sounds) via CrispAudio synth
- [x] Virtual d-pad controls (toggle in-game via icon button, or via settings)
- [x] Input lag reduction (early tick trigger on direction change)
- [x] Release build fix (late field → nullable, bounds-checked enum indexing)
- [x] Vercel web deployment (profile mode, https://web-ten-ebon-14.vercel.app)
- [x] GitHub repo (private, https://github.com/CrispStrobe/naga)

### Game Modes — 14 total

**Classic category (3):**
- [x] Classic — retro phone LCD green, blocky segments, walls kill, no grid
- [x] Arcade — neon, wrap-around, speed ramp
- [x] Zen — no death, no walls, slow and peaceful

**Crossover category (4):**
- [x] Maze Hunter — Pac-Man: maze, dots, 4 ghosts, power pellets, fixed-length snake
- [x] Trail — Tron: light trails, AI opponent, shrinking arena
- [x] Fangs — Breakout: snake paddle, bouncing ball, breakable blocks
- [x] Venom — Bomberman: venom bombs, chain explosions, destructible walls, enemies

**Action category (3):**
- [x] Pit — Battle Royale: 5 AI snakes, shrinking danger zone, last alive wins
- [x] Swarm — Centipede: enemy formation marches down, waves, power-ups
- [x] Rush — Endless runner: obstacles scroll down, dodge and eat

**Legacy/Retro category (4 — files created, not yet wired):**
- [x] Snake II — wrap-around, 5 cycling maze layouts, bonus items, chain-link snake
- [x] ASCII — terminal text mode, `@#*` characters, green-on-black
- [x] CGA — 4-color IBM PC palette (cyan/magenta/white/black)
- [x] Nibbles — QBasic style, bright colors on black, numbered food

### Visual Upgrades (done for base SnakeGame modes)
- [x] Smooth snake: rounded head with eyes/tongue, body corners, tapered tail
- [x] Food: pulsing glow, highlight, stem, hops away when snake is close
- [x] Grid: subtle checkerboard for modern modes, no grid for Classic

---

## Phase 1: Wire Retro Modes + Chain-Link Snake (NEXT)

### 1.1 Wire 4 retro modes into game_screen + home_screen
- Add imports, mode detection, _createGame branches, _changeDirection branches
- Add i18n strings (EN + DE) for Snake II, ASCII, CGA, Nibbles
- Add to home_screen under new "LEGACY" section
- Regenerate l10n
- **Effort:** small, single task

### 1.2 Chain-link snake style for Classic mode
- Based on actual retro phone screenshot: each segment is a small outlined square with gap
- Head slightly different from body
- Multiple food items on screen (2-3 like original)
- Score display at top matches retro style (left-aligned score, right-aligned level)
- Update Classic mode food rendering: small scattered items, not single dot
- **Effort:** medium, modify snake.dart _renderClassic + food.dart

### 1.3 Build, test with Playwright, deploy, commit + push
- Build profile mode
- Screenshot-verify with Playwright
- Deploy to Vercel
- Commit and push to GitHub

---

## Phase 2: Polish & Gameplay Quality

### 2.1 Per-mode board styles
- Each mode with its own game class already renders its own board
- For modes using base SnakeGame, pass board style via GameMode:
  - Classic: LCD green, no grid, solid dark border
  - Arcade: neon checkerboard, glowing border
  - Zen: no grid, no border, dark gradient background
  - CGA: chunky pixel grid, white border
  - Nibbles: no grid, blue border

### 2.2 Reactive food across all modes
- Food animals/items that hop away when snake approaches (already in base, extend to other game classes)
- Different food types per mode (visual variety)

### 2.3 Buff/debuff system (from DungeonRush research)
- Power-ups: speed boost, shield, freeze (slows enemies), magnet (food attracted)
- Can appear in Arcade, Maze Hunter, Pit, Swarm modes
- Visual indicator on snake head when buff active

### 2.4 Audio improvements
- Convert WAV to MP3/OGG for smaller bundle size
- Music loops should be seamless (crossfade)
- Add more SFX: bomb explode, ghost eaten, wall break, bonus collect

---

## Phase 3: Multiplayer

### 3.1 Local same-screen multiplayer
- Split controls: Player 1 uses left side of screen (or WASD), Player 2 uses right side (or arrows)
- Both snakes on same grid
- Modes: cooperative (shared score) or competitive (separate scores, last alive wins)
- Works in: Classic, Arcade, Pit modes

### 3.2 Local split-screen (tablet)
- Two separate game views side by side
- Each player has own d-pad controls

### 3.3 Online multiplayer (future)
- WebSocket server (can be Vercel serverless or dedicated)
- Matchmaking, lobbies
- Anti-cheat: server-authoritative game state
- Latency compensation

---

## Phase 4: New Mode — Dungeon (Roguelike)

Based on DungeonRush research:
- Procedurally generated rooms/corridors
- Snake collects hero segments with different abilities (Knight=melee, Wizard=ranged, etc.)
- Weapons drop from enemies with buff effects (freeze, shield, attack boost)
- Boss fights at room exits
- Individual segments can take damage and die
- Progressive difficulty: HP scaling, enemy count, trap density
- Death is permanent (roguelike)
- Visual: dark dungeon aesthetic, torch lighting effect

---

## Phase 5: App Store Preparation

### 5.1 App icon and splash screen
- Design Naga snake logo
- Adaptive icon (Android), App Icon (iOS)
- Launch screen / splash

### 5.2 App Store metadata
- Screenshots for all device sizes
- App description (EN + DE)
- Privacy policy page
- Age rating

### 5.3 iOS build & submission
- Xcode project configuration
- Signing, provisioning profiles
- TestFlight beta
- App Store Connect submission

### 5.4 Android build & submission
- Signing key
- Play Console setup
- Internal testing track
- Production release

### 5.5 PWA support for web
- Service worker for offline play
- Manifest with proper icons
- Add-to-homescreen prompt

---

## Phase 6: Future Ideas

- **Dungeon mode** — full roguelike (Phase 4)
- **Anakonda mode** — mobile phone classic with wrap-around and speed tiers
- **Worm mode** — Peter Trefonas style with ASCII art obstacles
- **Hyper-Wurm** — fast-paced German retro style
- **Seasonal events** — holiday-themed food/backgrounds
- **Achievements** — unlock modes, track milestones
- **Leaderboards** — global (requires backend)
- **Skins** — unlockable snake skins
- **Level editor** — user-created mazes
- **Haptic feedback** — vibration on eat/die (mobile only)
