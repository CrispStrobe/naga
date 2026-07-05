# Naga — Development Plan

## Current State (2026-07-05)

### Done
- [x] Flutter + Flame project scaffold, cross-platform (iOS, Android, Web)
- [x] i18n (EN + DE) with Flutter gen-l10n, class `S`
- [x] About screen (AGPL-3.0, mirrors CrispSudoku pattern)
- [x] Settings: grid size, wall behavior, lives, control type, audio toggles
- [x] Local high scores per mode (SharedPreferences)
- [x] Audio service with per-mode music (OGG) + SFX, toggles in settings
- [x] Generated chiptune music (10+ tracks) and SFX (5 sounds) via CrispAudio synth
- [x] Virtual d-pad controls (toggle in-game or via settings)
- [x] Input lag reduction (early tick trigger on direction change)
- [x] Release build fix (nullable singletons, bounds-checked enum indexing)
- [x] Vercel web deployment (https://web-ten-ebon-14.vercel.app)
- [x] GitHub repo (private, https://github.com/CrispStrobe/naga)
- [x] Game pause (pause button + overlay, all modes)
- [x] Power-up/buff system (Speed, Shield, Magnet, Slow, Shrink)
- [x] Visual upgrades: smooth snake, reactive food, checkerboard, per-mode boards

### Game Modes — 15 total (+ Dungeon in progress)

**Classic (3):** Classic, Arcade, Zen
**Crossover (4):** Maze Hunter, Trail, Fangs, Venom
**Action (3):** Pit, Swarm, Rush
**Legacy (4):** Snake II, ASCII, CGA, Nibbles
**Multiplayer (1):** Duel (local 2-player)
**In progress:** Dungeon (roguelike crawler)

---

## Phase 1: ~~Wire Retro Modes + Chain-Link Snake~~ DONE
## Phase 2: ~~Polish & Gameplay Quality~~ DONE
## Phase 3: ~~Multiplayer~~ DONE (Duel mode)

---

## Phase 4: Dungeon Mode (IN PROGRESS)
- Procedurally generated rooms with corridors
- Monsters, collectibles (coins, potions, weapons), traps
- Room progression with scaling difficulty
- Snake segments = HP, lose segments on damage

## Phase 5: App Store Preparation

### 5.1 App icon and splash screen
- Design Naga snake logo
- Adaptive icon (Android), App Icon (iOS)
- Launch screen / splash

### 5.2 App Store metadata
- Screenshots for all device sizes (automated via Playwright/integration tests)
- App description (EN + DE)
- Privacy policy page
- Age rating

### 5.3 iOS build & submission
- Xcode project configuration
- Signing, provisioning profiles
- TestFlight beta → App Store Connect

### 5.4 Android build & submission
- Signing key
- Play Console → Internal testing → Production

### 5.5 PWA support for web
- Service worker for offline play
- Manifest with proper icons
- Add-to-homescreen prompt

---

## Phase 6: Future Ideas (prioritized)

1. **Online multiplayer** — WebSocket server, matchmaking, lobbies
2. **Achievements** — unlock modes, track milestones (local + Game Center/Play Games)
3. **Haptic feedback** — vibration on eat/die (mobile only)
4. **Skins** — unlockable snake skins per mode
5. **Level editor** — user-created mazes (share via URL/QR)
6. **Seasonal events** — holiday-themed food/backgrounds
7. **Leaderboards** — global (requires backend)
8. **More retro modes** — Anakonda, Worm, Hyper-Wurm
9. **Tutorial/onboarding** — animated intro for first-time players
10. **Accessibility** — high contrast mode, screen reader hints
