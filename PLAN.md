# Naga — Development Plan

## Current State (2026-07-05)

### Complete
- [x] Flutter + Flame, cross-platform (iOS, Android, Web)
- [x] i18n (EN + DE), About screen (AGPL-3.0)
- [x] Settings: grid size, wall behavior, lives, controls, audio, difficulty, start speed
- [x] Local high scores, 10 achievements
- [x] Audio (OGG music per mode + SFX), toggleable
- [x] D-pad controls, game pause (Esc/P + button), direction queue (4 inputs)
- [x] Power-up/buff system (Speed, Shield, Magnet, Slow, Shrink)
- [x] Smooth snake rendering, reactive food, per-mode board styles
- [x] Home screen animated snake (cycling mode styles)
- [x] App icon + splash screen (all platforms)
- [x] PWA manifest, privacy policy, App Store metadata (EN/DE)
- [x] AI opponents with BFS + tail-reachability (4 difficulty levels)
- [x] Haptic feedback on eat/die
- [x] Start speed setting wired into gameplay
- [x] Release build fix

### 17 Game Modes

| Category | Modes | Status |
|----------|-------|--------|
| Classic (3) | Classic, Arcade, Zen | Polished |
| Crossover (4) | Maze Hunter, Trail, Fangs, Venom | Fixed (wide corridors, snake paddle, Space bombs) |
| Action (3) | Pit, Swarm, Rush | Fixed (eat enemies, slower scroll) |
| Legacy (4) | Snake II, ASCII, CGA, Nibbles | Fixed (CGA scanlines, QBasic-accurate Nibbles) |
| Adventure (1) | Dungeon | Rewritten as turn-based roguelike |
| Multiplayer (2) | Duel, VS AI | Working |

### Deployments
- Web: https://web-ten-ebon-14.vercel.app
- GitHub: https://github.com/CrispStrobe/naga (private)

---

## Remaining (Future)

### Polish
- [ ] Online multiplayer (WebSocket server)
- [ ] More retro modes (Anakonda, Worm, Hyper-Wurm)
- [ ] Skins / unlockable snake appearances
- [ ] Level editor (user-created mazes, shareable)
- [ ] Tutorial / onboarding for first-time players
- [ ] Accessibility (high contrast, reduced motion)

### App Store
- [ ] iOS: Xcode config, signing, TestFlight, submission
- [ ] Android: signing key, Play Console, submission
- [ ] Requires developer accounts (Apple + Google)
