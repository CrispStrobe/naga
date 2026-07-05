# Naga — Development Plan

## Current State (2026-07-05)

### Complete
- [x] Flutter + Flame, cross-platform (iOS, Android, Web)
- [x] i18n (EN + DE), About screen (AGPL-3.0)
- [x] Settings: grid size, wall behavior, lives, controls, audio, difficulty, start speed
- [x] Local high scores, audio (OGG music + SFX per mode)
- [x] D-pad controls, game pause, input lag reduction
- [x] Power-up/buff system (5 types, visual indicators)
- [x] Smooth snake rendering, reactive food, checkerboard boards
- [x] Home screen animated snake (cycling mode styles)
- [x] App icon + splash screen (all platforms)
- [x] PWA manifest, privacy policy, App Store metadata (EN/DE)
- [x] Release build fix

### 17 Game Modes

| Category | Modes |
|----------|-------|
| Classic (3) | Classic, Arcade, Zen |
| Crossover (4) | Maze Hunter, Trail, Fangs, Venom |
| Action (3) | Pit, Swarm, Rush |
| Legacy (4) | Snake II, ASCII, CGA, Nibbles |
| Adventure (1) | Dungeon |
| Multiplayer (2) | Duel (local 2P), VS AI (4 difficulty levels) |

### Deployments
- Web: https://web-ten-ebon-14.vercel.app
- GitHub: https://github.com/CrispStrobe/naga (private)

---

## Phases 1-5: DONE

---

## Phase 6: Polish & Future (remaining)

### 6.1 Haptic feedback
- Vibration on eat/die/power-up (mobile only, HapticFeedback.lightImpact)

### 6.2 Tutorial/onboarding
- First-launch animated tutorial showing controls
- Mode descriptions on first play

### 6.3 Achievements system
- Local achievements (SharedPreferences)
- Examples: "Eat 100 food", "Clear 5 dungeon rooms", "Win a Duel", "Survive 60s in Rush"

### 6.4 More retro modes
- Anakonda, Worm, Hyper-Wurm (as requested)

### 6.5 Online multiplayer
- WebSocket server, matchmaking

### 6.6 iOS/Android submission
- Requires developer accounts (Apple + Google)
- Signing keys, TestFlight, Play Console

### 6.7 Skins & customization
- Unlockable snake skins
- Custom color themes

### 6.8 Level editor
- User-created mazes, shareable via URL

### 6.9 Accessibility
- High contrast mode
- Screen reader hints
- Reduced motion option
