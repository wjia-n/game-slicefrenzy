import 'package:flutter/material.dart';

/// A Slice Frenzy visual theme: warm, physical, market-stand art direction.
/// No neon, no cyberpunk — fruit-stall wood, canvas, warm sunlight.
@immutable
class FrenzyThemeDef {
  final String id;
  final String name;
  final bool isPro;
  final Color skyTop;
  final Color skyBottom;
  final Color crate; // wooden crate along the bottom of the play field
  final Color crateDark;
  final Color accent; // HUD chips, buttons
  final Color accentInk; // text on accent
  final Color juice; // splash tint when fruit is sliced
  final Color card; // menu card background
  final Color ink; // primary text

  const FrenzyThemeDef({
    required this.id,
    required this.name,
    required this.isPro,
    required this.skyTop,
    required this.skyBottom,
    required this.crate,
    required this.crateDark,
    required this.accent,
    required this.accentInk,
    required this.juice,
    required this.card,
    required this.ink,
  });
}

/// 12 themes. The first 8 are free; the last 4 need Pro.
class FrenzyThemes {
  static const List<FrenzyThemeDef> all = [
    FrenzyThemeDef(
      id: 'orchard_dawn',
      name: 'Orchard Dawn',
      isPro: false,
      skyTop: Color(0xFFFFF8E7),
      skyBottom: Color(0xFFFFE3B3),
      crate: Color(0xFF8A5A33),
      crateDark: Color(0xFF5F3A1E),
      accent: Color(0xFFC0392B),
      accentInk: Color(0xFFFFF6E9),
      juice: Color(0xFFFF6B6B),
      card: Color(0xFFFFFBF0),
      ink: Color(0xFF3A2415),
    ),
    FrenzyThemeDef(
      id: 'citrus_grove',
      name: 'Citrus Grove',
      isPro: false,
      skyTop: Color(0xFFFFFDE7),
      skyBottom: Color(0xFFFFF0B3),
      crate: Color(0xFF7A5C2E),
      crateDark: Color(0xFF54401F),
      accent: Color(0xFFE67E22),
      accentInk: Color(0xFFFFFBF0),
      juice: Color(0xFFFFB74D),
      card: Color(0xFFFFFEF5),
      ink: Color(0xFF3D2C10),
    ),
    FrenzyThemeDef(
      id: 'berry_patch',
      name: 'Berry Patch',
      isPro: false,
      skyTop: Color(0xFFFDF2F8),
      skyBottom: Color(0xFFF8DDE7),
      crate: Color(0xFF6E4A2F),
      crateDark: Color(0xFF4C3220),
      accent: Color(0xFFAD1457),
      accentInk: Color(0xFFFFF0F5),
      juice: Color(0xFFEC407A),
      card: Color(0xFFFFFBFD),
      ink: Color(0xFF401A2A),
    ),
    FrenzyThemeDef(
      id: 'harvest_gold',
      name: 'Harvest Gold',
      isPro: false,
      skyTop: Color(0xFFFFF9EC),
      skyBottom: Color(0xFFFCE8B2),
      crate: Color(0xFF96692F),
      crateDark: Color(0xFF6B4720),
      accent: Color(0xFFB8860B),
      accentInk: Color(0xFFFFFAEF),
      juice: Color(0xFFF9A825),
      card: Color(0xFFFFFDF4),
      ink: Color(0xFF402D0E),
    ),
    FrenzyThemeDef(
      id: 'cherrywood',
      name: 'Cherrywood',
      isPro: false,
      skyTop: Color(0xFFFBE9E7),
      skyBottom: Color(0xFFF5CFC6),
      crate: Color(0xFF7B3F2A),
      crateDark: Color(0xFF572A1C),
      accent: Color(0xFF8E2A1B),
      accentInk: Color(0xFFFFF1EC),
      juice: Color(0xFFD84315),
      card: Color(0xFFFFF7F3),
      ink: Color(0xFF3E1C12),
    ),
    FrenzyThemeDef(
      id: 'tropical_noon',
      name: 'Tropical Noon',
      isPro: false,
      skyTop: Color(0xFFE8F8F0),
      skyBottom: Color(0xFFCDEEDC),
      crate: Color(0xFF7C5A35),
      crateDark: Color(0xFF574023),
      accent: Color(0xFF1B7A4D),
      accentInk: Color(0xFFF0FBF4),
      juice: Color(0xFF66BB6A),
      card: Color(0xFFF7FDF8),
      ink: Color(0xFF173A24),
    ),
    FrenzyThemeDef(
      id: 'autumn_press',
      name: 'Autumn Press',
      isPro: false,
      skyTop: Color(0xFFFDF3E3),
      skyBottom: Color(0xFFF3D9AE),
      crate: Color(0xFF8C5B2E),
      crateDark: Color(0xFF65401E),
      accent: Color(0xFFA64B00),
      accentInk: Color(0xFFFFF6E8),
      juice: Color(0xFFE65100),
      card: Color(0xFFFFFAF0),
      ink: Color(0xFF40260D),
    ),
    FrenzyThemeDef(
      id: 'garden_party',
      name: 'Garden Party',
      isPro: false,
      skyTop: Color(0xFFF3F9EC),
      skyBottom: Color(0xFFDDEECB),
      crate: Color(0xFF86935A),
      crateDark: Color(0xFF5E6839),
      accent: Color(0xFF558B2F),
      accentInk: Color(0xFFF4FAEC),
      juice: Color(0xFF9CCC65),
      card: Color(0xFFFAFDF3),
      ink: Color(0xFF26331A),
    ),
    FrenzyThemeDef(
      id: 'desert_bloom',
      name: 'Desert Bloom',
      isPro: true,
      skyTop: Color(0xFFFFF3E0),
      skyBottom: Color(0xFFF9C89B),
      crate: Color(0xFF8D5A3B),
      crateDark: Color(0xFF63402A),
      accent: Color(0xFFBF360C),
      accentInk: Color(0xFFFFF3E6),
      juice: Color(0xFFFF7043),
      card: Color(0xFFFFFAF2),
      ink: Color(0xFF42220E),
    ),
    FrenzyThemeDef(
      id: 'twilight_market',
      name: 'Twilight Market',
      isPro: true,
      skyTop: Color(0xFF3E2A4E),
      skyBottom: Color(0xFF6B4A5E),
      crate: Color(0xFF5A3A28),
      crateDark: Color(0xFF3C2619),
      accent: Color(0xFFFFB300),
      accentInk: Color(0xFF3A2410),
      juice: Color(0xFFFF8F00),
      card: Color(0xFF4A3456),
      ink: Color(0xFFFFF3E0),
    ),
    FrenzyThemeDef(
      id: 'vineyard_dusk',
      name: 'Vineyard Dusk',
      isPro: true,
      skyTop: Color(0xFFF3E5F5),
      skyBottom: Color(0xFFD7B8DE),
      crate: Color(0xFF6D4C41),
      crateDark: Color(0xFF4A332B),
      accent: Color(0xFF6A1B9A),
      accentInk: Color(0xFFF9F0FF),
      juice: Color(0xFFAB47BC),
      card: Color(0xFFFBF4FD),
      ink: Color(0xFF38184A),
    ),
    FrenzyThemeDef(
      id: 'frost_harvest',
      name: 'Frost Harvest',
      isPro: true,
      skyTop: Color(0xFFEAF6FB),
      skyBottom: Color(0xFFCBE4F0),
      crate: Color(0xFF6E7B8B),
      crateDark: Color(0xFF4C5560),
      accent: Color(0xFF1565C0),
      accentInk: Color(0xFFEAF4FD),
      juice: Color(0xFF4FC3F7),
      card: Color(0xFFF6FBFE),
      ink: Color(0xFF1E3A52),
    ),
  ];

  static FrenzyThemeDef byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return all[0];
  }

  static bool isProTheme(String id) =>
      id == 'my_theme' ? true : byId(id).isPro;

  /// Migration: the legacy shell stored ids like 'comicBurst'; none map to
  /// the new catalog, so unknown ids fall back to orchard_dawn. 'my_theme'
  /// (the custom creator theme) is kept as-is.
  static String sanitize(String? id) =>
      id == 'my_theme' ? 'my_theme' : byId(id ?? '').id;

  /// Custom theme creator (Pro): builds a full theme from the 4 user-picked
  /// core colors; the rest of the palette is derived for a cohesive look.
  static FrenzyThemeDef myTheme(Map<String, int> c) {
    final skyTop = Color(c['skyTop']!);
    final skyBottom = Color(c['skyBottom']!);
    final crate = Color(c['crate']!);
    final accent = Color(c['accent']!);
    return FrenzyThemeDef(
      id: 'my_theme',
      name: 'My Market',
      isPro: true,
      skyTop: skyTop,
      skyBottom: skyBottom,
      crate: crate,
      crateDark: _shade(crate, 0.65),
      accent: accent,
      accentInk: _inkOn(accent),
      juice: accent,
      card: _tint(skyBottom, 0.75),
      ink: const Color(0xFF3A2415),
    );
  }

  static Color _shade(Color c, double f) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness * f).clamp(0.0, 1.0)).toColor();
  }

  static Color _tint(Color c, double f) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + (1 - hsl.lightness) * f).clamp(0.0, 1.0)).toColor();
  }

  /// Readable text on a colored accent: dark ink on light accents, white-ish
  /// on dark ones.
  static Color _inkOn(Color c) {
    final lum = (0.299 * c.red + 0.587 * c.green + 0.114 * c.blue) / 255;
    return lum > 0.55 ? const Color(0xFF3A2415) : const Color(0xFFFFFBF0);
  }
}
