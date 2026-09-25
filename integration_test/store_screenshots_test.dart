// App Store screenshots, rendered from the real app.
//
// Runs as an integration test on macOS (see .github/workflows/
// store-screenshots.yml). For each device profile it sets the view to that
// device's logical size, pixel ratio and safe-area insets, drives the app
// with real taps and key presses, and captures the composited frame at the
// device's native resolution. Nothing is mocked: the menu, games and text
// are the app's own rendering.
//
// Output: <systemTemp>/store_screenshots/<device>/<locale>/<nn>_<scene>.png;
// the directory is printed as a SHOTS_DIR= line for the workflow to collect.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:naga/generated/l10n.dart';
import 'package:naga/main.dart';
import 'package:naga/services/achievements_service.dart';
import 'package:naga/services/audio_service.dart';
import 'package:naga/services/high_score_service.dart';
import 'package:naga/services/settings_service.dart';
import 'package:naga/ui/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Device {
  final String name;
  final Size logical;
  final double ratio;
  final double top, bottom;
  const Device(this.name, this.logical, this.ratio, {this.top = 0, this.bottom = 0});
}

// App Store Connect display types: APP_IPHONE_67 (1320x2868),
// APP_IPAD_PRO_3GEN_129 (2064x2752) and APP_DESKTOP (2880x1800).
const devices = [
  Device('iphone_69', Size(440, 956), 3, top: 62, bottom: 34),
  Device('ipad_13', Size(1032, 1376), 2, top: 24, bottom: 20),
  Device('mac', Size(1440, 900), 2),
];
const locales = ['en', 'de'];

final _frame = GlobalKey();

Future<void> hold(WidgetTester tester, Duration duration) async {
  // Real time passes in the live binding; looping animations never settle,
  // so pump fixed steps instead of pumpAndSettle.
  final end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> steer(WidgetTester tester, List<(LogicalKeyboardKey, int)> moves) async {
  for (final (key, ms) in moves) {
    await tester.sendKeyEvent(key);
    await hold(tester, Duration(milliseconds: ms));
  }
}

Future<void> capture(WidgetTester tester, Device device, String path) async {
  await tester.pump();
  final boundary = _frame.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: device.ratio);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File(path)..createSync(recursive: true);
  await file.writeAsBytes(png!.buffer.asUint8List());
  debugPrint('SHOT $path ${(device.logical * device.ratio)}');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final outDir = '${Directory.systemTemp.path}/store_screenshots';

  testWidgets('store screenshots', (tester) async {
    final settings = await SettingsService.instance();
    final scores = await HighScoreService.instance();
    final achievements = await AchievementsService.instance();
    final audio = AudioService.silent();
    debugPrint('SHOTS_DIR=$outDir');

    for (final device in devices) {
      tester.view.physicalSize = device.logical * device.ratio;
      tester.view.devicePixelRatio = device.ratio;
      tester.view.padding = FakeViewPadding(
        top: device.top * device.ratio, bottom: device.bottom * device.ratio);
      tester.view.viewPadding = tester.view.padding;

      for (final locale in locales) {
        var n = 0;
        String shot(String scene) =>
            '$outDir/${device.name}/$locale/${(++n).toString().padLeft(2, '0')}_$scene.png';

        // A fresh app per scene: first-launch menu state, chosen language.
        Future<S> launch() async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          await settings.setLocale(locale);
          await tester.pumpWidget(RepaintBoundary(
            key: _frame,
            child: NagaApp(
              key: UniqueKey(),
              settingsService: settings,
              highScoreService: scores,
              audioService: audio,
              achievementsService: achievements,
            ),
          ));
          await hold(tester, const Duration(milliseconds: 1500));
          return S.of(tester.element(find.byType(HomeScreen)))!;
        }

        // Opens a mode from the menu by its label, expanding its section.
        Future<void> open(String label, {String? section}) async {
          if (section != null) {
            final header = find.text(section);
            await tester.ensureVisible(header);
            await tester.tap(header);
            await hold(tester, const Duration(milliseconds: 400));
          }
          final entry = find.text(label.toUpperCase());
          await tester.ensureVisible(entry);
          await hold(tester, const Duration(milliseconds: 300));
          await tester.tap(entry);
          await hold(tester, const Duration(milliseconds: 1200));
        }

        const up = LogicalKeyboardKey.arrowUp, down = LogicalKeyboardKey.arrowDown;
        const left = LogicalKeyboardKey.arrowLeft, right = LogicalKeyboardKey.arrowRight;

        // 1. The menu: sections, counts, the daily challenge first.
        var s = await launch();
        await tester.tap(find.text('CROSSOVER'));
        await hold(tester, const Duration(milliseconds: 600));
        await capture(tester, device, shot('menu'));

        // 2. Daily Serpent: today's rock layout.
        s = await launch();
        await open(s.daily);
        await steer(tester, [(up, 700), (left, 500)]);
        await capture(tester, device, shot('daily'));

        // 3. Territory: claim land against two AI rivals.
        s = await launch();
        await open(s.territory, section: 'ACTION');
        await steer(tester, [(up, 700), (right, 700), (down, 700), (left, 500), (up, 1800)]);
        await capture(tester, device, shot('territory'));

        // 4. Ouroboros: fireflies you can only catch with a loop.
        s = await launch();
        await open(s.ouroboros, section: 'ACTION');
        await steer(tester, [(up, 600), (left, 600), (down, 400)]);
        await capture(tester, device, shot('ouroboros'));

        // 5. Dungeon: the turn-based roguelike.
        s = await launch();
        await open(s.dungeon, section: 'ADVENTURE');
        for (final key in [right, right, up, up, right, down]) {
          await steer(tester, [(key, 250)]);
        }
        await capture(tester, device, shot('dungeon'));

        // 6. Nightfall: only the lantern lights the board.
        s = await launch();
        await open(s.nightfall);
        await steer(tester, [(up, 700)]);
        await capture(tester, device, shot('nightfall'));

        // 7. Maze Hunter: a maze chase with ghosts.
        s = await launch();
        await open(s.mazeHunter, section: 'CROSSOVER');
        await steer(tester, [(up, 900)]);
        await capture(tester, device, shot('maze_hunter'));

        // 8. ASCII: a terminal drawn in real text.
        s = await launch();
        await open(s.ascii, section: 'LEGACY');
        await steer(tester, [(up, 800), (left, 500)]);
        await capture(tester, device, shot('ascii'));
      }
    }
    tester.view.reset();
  }, timeout: const Timeout(Duration(minutes: 20)));
}
