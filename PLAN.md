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

### 19 Game Modes

| Category | Modes | Status |
|----------|-------|--------|
| Classic (3) | Classic, Arcade, Zen | Polished |
| Crossover (4) | Maze Hunter, Trail, Fangs, Venom | Fixed (wide corridors, snake paddle, Space bombs) |
| Action (3) | Pit, Swarm, Rush | Fixed (spiked enemies, grace period, 20% obstacles) |
| Legacy (4) | Snake II, ASCII, CGA, Nibbles | Fixed (CGA scanlines, QBasic-accurate Nibbles) |
| Minigames (2) | Stampede, Naga Dive | New — animal racing + underwater Flappy Bird |
| Adventure (1) | Dungeon | Rewritten as turn-based roguelike (with legend) |
| Multiplayer (2) | Duel, VS AI | Working |

### Deployments
- Web: https://naga-game.vercel.app
- GitHub: https://github.com/CrispStrobe/naga (private)
- CI/CD: GitHub Actions → WASM build → Vercel prod deploy on push to main

---

## Performance Optimization (Complete)

### High Impact
- [x] 1. Score ValueNotifier — stop setState() rebuilding entire GameScreen on score change
- [x] 2. Cache grid board — render checkerboard/grid once to offscreen image, blit each frame
- [x] 3. Snake blur optimization — only glow head segment, or cache glow layer

### Medium Impact
- [x] 4. O(1) collision detection — replace Snake.occupies() linear scan with Set<int>
- [x] 5. Cache Paint/TextPainter objects — stop allocating in render loops
- [x] 6. Food/PowerUp glow caching — pre-render blur effect instead of computing per frame
- [x] 7. AudioPlayer pooling — reuse players for SFX instead of creating new ones

### Low Impact (Easy Wins)
- [x] 8. Home animation RepaintBoundary — avoid widget rebuilds for snake animation
- [x] 9. Force CanvasKit renderer — explicit renderer selection in web/index.html
- [x] 10. Asset pre-loading — pre-load audio assets during home screen

### Build
- [x] 11. WASM compilation — `flutter build web --wasm` deployed with COOP/COEP headers in vercel.json. Requires `flutter clean` before build to regenerate plugin registrant.
- [x] 12. About dialog — shows version, git commit hash, and build mode (wasm/profile) via --dart-define

---

## Web Optimization (Next)

### Loading & First Paint
- [ ] Lightweight HTML splash screen — show branding before WASM loads (Flutter WASM takes 2-5s)
- [ ] Loading progress indicator — show WASM download percentage via Flutter's loader
- [ ] Verify Brotli compression — ensure `.wasm` files are served with `content-encoding: br`
- [ ] Immutable cache headers — add long `max-age` + `immutable` for hashed assets (`main.dart.wasm`, `*.js`)

### Asset Optimization
- [ ] Compress OGG audio files — audit bitrate, mono where stereo isn't needed
- [ ] Optimize PNG assets — run through `pngquant` / `oxipng`
- [ ] Lazy-load audio — defer music loading until game mode selection (not app start)

### SEO & Social Sharing
- [ ] Open Graph meta tags — `og:title`, `og:description`, `og:image` in `index.html`
- [ ] Twitter Card meta tags — preview card for link sharing
- [ ] Structured data — `WebApplication` schema for search engines
- [ ] Generate social preview image — screenshot of home screen at 1200x630

### PWA & Installability
- [ ] Improve `manifest.json` — add screenshots, categories, shortcuts to game modes
- [ ] Tune service worker — cache-first for assets, network-first for index
- [ ] App-like viewport — ensure no overscroll bounce, full-screen on mobile

### Responsive & Mobile UX
- [ ] Touch gesture controls — swipe to change direction (alternative to d-pad)
- [ ] Responsive layout — adapt UI for small phones vs tablets vs desktop
- [ ] Prevent accidental navigation — disable pull-to-refresh, back gesture during gameplay

### Code & Build
- [ ] Tree-shake unused Flame components — audit imports
- [ ] Deferred loading — split game modes into deferred libraries (load on demand)
- [ ] Profile WASM performance — identify hot loops with Chrome DevTools

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
