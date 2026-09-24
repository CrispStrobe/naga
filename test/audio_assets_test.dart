import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:naga/modes/arcade_mode.dart';
import 'package:naga/modes/ascii_mode.dart';
import 'package:naga/modes/cga_mode.dart';
import 'package:naga/modes/daily_mode.dart';
import 'package:naga/modes/classic_mode.dart';
import 'package:naga/modes/dungeon_mode.dart';
import 'package:naga/modes/fangs_mode.dart';
import 'package:naga/modes/maze_mode.dart';
import 'package:naga/modes/multiplayer_mode.dart';
import 'package:naga/modes/naga_dive_mode.dart';
import 'package:naga/modes/nibbles_mode.dart';
import 'package:naga/modes/ouroboros_mode.dart';
import 'package:naga/modes/nightfall_mode.dart';
import 'package:naga/modes/pit_mode.dart';
import 'package:naga/modes/portals_mode.dart';
import 'package:naga/modes/rush_mode.dart';
import 'package:naga/modes/shed_mode.dart';
import 'package:naga/modes/snake2_mode.dart';
import 'package:naga/modes/stampede_mode.dart';
import 'package:naga/modes/swarm_mode.dart';
import 'package:naga/modes/trail_mode.dart';
import 'package:naga/modes/venom_mode.dart';
import 'package:naga/modes/vs_ai_mode.dart';
import 'package:naga/modes/zen_mode.dart';
import 'package:naga/services/audio_service.dart';

void main() {
  test('every advertised music and sound asset exists under assets/', () {
    final paths = AudioService.assetPaths.toSet();
    expect(paths, hasLength(15));
    for (final path in paths) {
      expect(path, startsWith('audio/'));
      expect(File('assets/$path').existsSync(), isTrue, reason: path);
    }
    expect(paths, containsAll([
      AudioService.sfxEat,
      AudioService.sfxDie,
      AudioService.sfxPowerUp,
      AudioService.sfxLevelUp,
      AudioService.sfxClick,
    ]));
  });

  test('every mode has a music track', () {
    final modes = [
      ClassicMode(), ArcadeMode(), ZenMode(), MazeMode(), TrailMode(),
      FangsMode(), VenomMode(), PitMode(), SwarmMode(), RushMode(),
      Snake2Mode(), AsciiMode(), CgaMode(), NibblesMode(), MultiplayerMode(),
      DungeonMode(), StampedeMode(), NagaDiveMode(), VsAiMode(),
      VsAiSplitMode(), DailyMode(DateTime(2026)), ShedMode(), NightfallMode(), PortalsMode(), OuroborosMode(),
    ];
    for (final mode in modes) {
      expect(AudioService.trackForMode(mode.name), isNotNull, reason: mode.name);
    }
  });
}
