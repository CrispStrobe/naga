import 'package:flutter/material.dart';

/// Shared bright tropical "Naga habitat" palette.
///
/// One place for the app's colors so re-theming is a one-file edit.
/// Backgrounds are bright mid-tones (not pastels) so vivid gameplay
/// elements keep their contrast. Classic/ASCII/CGA/Nibbles/Snake II keep
/// their intentionally retro palettes and do not use this file.
class NagaPalette {
  NagaPalette._();

  // ── Habitat backgrounds ────────────────────────────────────────────
  static const canopyGreen = Color(0xFF2E7D32); // lush jungle canopy
  static const leafGreen = Color(0xFF43A047); // sunlit foliage
  static const lagoonTeal = Color(0xFF00897B); // warm lagoon water
  static const deepLagoon = Color(0xFF00796B); // deeper lagoon
  static const riverBlue = Color(0xFF0288D1); // tropical river
  static const mangoYellow = Color(0xFFFFB300); // golden savanna
  static const terracotta = Color(0xFFE64A19); // sun-baked clay
  static const orchidPurple = Color(0xFF7B1FA2); // orchid grove
  static const templeBrown = Color(0xFF8D6E63); // sunlit temple stone
  static const lotusPond = Color(0xFFB2DFDB); // pale zen water
  static const cyanReef = Color(0xFF00838F); // bright reef teal

  // ── Creatures & food accents ───────────────────────────────────────
  static const nagaGreen = Color(0xFF00E676); // the Naga itself
  static const parrotLime = Color(0xFF76FF03);
  static const parrotCyan = Color(0xFF00E5FF);
  static const sunGold = Color(0xFFFFD740);
  static const appleRed = Color(0xFFE53935);
  static const dangerRed = Color(0xFFFF1744);
  static const flowerPink = Color(0xFFFF80AB);
  static const berryMagenta = Color(0xFFE040FB);
  static const emberOrange = Color(0xFFFF6D00);

  // ── Menu / chrome ──────────────────────────────────────────────────
  static const menuBackground = Color(0xFFF1F8E9); // meadow white-green
  static const menuDeepGreen = Color(0xFF2E7D32);
  static const menuAccentOrange = Color(0xFFE65100);
  static const menuCardGreen = Color(0xFF66BB6A);
}
