import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/frenzy_themes.dart';
import '../theme/blade_styles.dart';

/// Persisted settings + stats for Slice Frenzy. Survives app restarts.
///
/// Profile: the player's display name is stored as ONE JSON string
/// (`slicefrenzy_player_names_json`). Android's SharedPreferences stores
/// StringLists as an unordered StringSet, so ordered data must NEVER use a
/// StringList — legacy keys are read once for migration and then deleted.
class SliceSettings extends ChangeNotifier {
  static const _kMusic = 'sf_music_on';
  static const _kSfx = 'sf_sfx_on';
  static const _kVolume = 'sf_volume';
  // Profile: ONE order-preserving JSON string via setString — never
  // setStringList (Android backs it with an unordered StringSet and names
  // come back scrambled). Migration chain:
  //   slicefrenzy_player_names_json <- sf_profile_json <- sf_player_names
  static const _kProfileJson = 'slicefrenzy_player_names_json'; // {"name": "..."}
  static const _kLegacyProfileJson = 'sf_profile_json';
  static const _kLegacyNames = 'sf_player_names'; // legacy unordered key
  static const _kLegacyTheme = 'wajiha_theme_id'; // legacy shell theme key
  static const _kTheme = 'sf_theme_id';
  static const _kCustomTheme = 'slicefrenzy_custom_theme_json';
  static const _kBlade = 'sf_blade_id';
  static const _kBladeColor = 'sf_blade_color'; // custom blade ARGB
  static const _kBladeWidth = 'sf_blade_width'; // custom blade width
  static const _kDifficulty = 'sf_difficulty'; // 0 easy, 1 normal, 2 hard
  static const _kIsPro = 'sf_is_pro';
  static const _kBestScores = 'sf_best_scores'; // JSON map modeId -> int
  static const _kTotalSliced = 'sf_total_sliced';
  static const _kGames = 'sf_games_played';
  static const _kBestCombo = 'sf_best_combo';
  static const _kReviewAsked = 'sf_review_asked';

  static const defaultName = 'Slicer';

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  String profileName = defaultName;
  String themeId = 'orchard_dawn';
  Map<String, int>? customThemeColors; // null until the creator is used (Pro)
  String bladeId = 'silver';
  int customBladeColor = 0xFFE53935;
  double customBladeWidth = 13.0;
  int difficulty = 1; // normal default
  bool isPro = false;
  Map<String, int> bestScores = {};
  int totalSliced = 0;
  int gamesPlayed = 0;
  int bestCombo = 0;
  int reviewAskedAt = 0;

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = (p.getDouble(_kVolume) ?? 0.8).clamp(0.0, 1.0);

    // Profile name: prefer the order-safe JSON key; migrate legacy keys once.
    profileName = _decodeProfile(p.getString(_kProfileJson));
    if (p.getString(_kProfileJson) == null) {
      profileName = _decodeProfile(p.getString(_kLegacyProfileJson));
      if (p.getString(_kLegacyProfileJson) == null) {
        final legacy = p.getStringList(_kLegacyNames);
        if (legacy != null && legacy.isNotEmpty) {
          final n = legacy.first.trim();
          if (n.isNotEmpty) profileName = n;
        }
      }
    }

    themeId = p.getString(_kTheme) ??
        FrenzyThemes.sanitize(p.getString(_kLegacyTheme));
    themeId = FrenzyThemes.sanitize(themeId);
    customThemeColors = _decodeColors(p.getString(_kCustomTheme));
    if (themeId == 'my_theme' && customThemeColors == null) {
      themeId = 'orchard_dawn'; // custom data missing — fall back safely
    }
    bladeId = BladeStyles.sanitize(p.getString(_kBlade));
    customBladeColor = p.getInt(_kBladeColor) ?? 0xFFE53935;
    customBladeWidth = (p.getDouble(_kBladeWidth) ?? 13.0).clamp(8.0, 22.0);
    difficulty = (p.getInt(_kDifficulty) ?? 1).clamp(0, 2);
    isPro = p.getBool(_kIsPro) ?? false;
    bestScores = _decodeBest(p.getString(_kBestScores));
    totalSliced = p.getInt(_kTotalSliced) ?? 0;
    gamesPlayed = p.getInt(_kGames) ?? 0;
    bestCombo = p.getInt(_kBestCombo) ?? 0;
    reviewAskedAt = p.getInt(_kReviewAsked) ?? 0;
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  static String _decodeProfile(String? raw) {
    if (raw == null) return defaultName;
    try {
      final d = jsonDecode(raw);
      if (d is Map && d['name'] is String) {
        final n = (d['name'] as String).trim();
        if (n.isNotEmpty) return n.length > 18 ? n.substring(0, 18) : n;
      }
    } catch (_) {}
    return defaultName;
  }

  static String encodeProfile(String name) =>
      jsonEncode({'name': name.trim().isEmpty ? defaultName : name.trim()});

  static Map<String, int> _decodeBest(String? raw) {
    final out = <String, int>{};
    if (raw == null) return out;
    try {
      final d = jsonDecode(raw);
      if (d is Map) {
        d.forEach((k, v) {
          if (k is String && v is int && v >= 0) out[k] = v;
        });
      }
    } catch (_) {}
    return out;
  }

  /// Custom theme colors: exactly the 4 keys the creator writes
  /// (skyTop, skyBottom, crate, accent) as ARGB ints. Anything else is
  /// treated as corrupt and dropped.
  static Map<String, int>? _decodeColors(String? raw) {
    if (raw == null) return null;
    try {
      final d = jsonDecode(raw);
      if (d is! Map) return null;
      const keys = ['skyTop', 'skyBottom', 'crate', 'accent'];
      final out = <String, int>{};
      for (final k in keys) {
        final v = d[k];
        if (v is! int) return null;
        out[k] = v;
      }
      return out;
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setString(_kProfileJson, encodeProfile(profileName));
    await p.remove(_kLegacyProfileJson); // drop legacy keys for good
    await p.remove(_kLegacyNames); // the unordered StringList key
    await p.remove(_kLegacyTheme);
    await p.setString(_kTheme, themeId);
    if (customThemeColors == null) {
      await p.remove(_kCustomTheme);
    } else {
      await p.setString(_kCustomTheme, jsonEncode(customThemeColors));
    }
    await p.setString(_kBlade, bladeId);
    await p.setInt(_kBladeColor, customBladeColor);
    await p.setDouble(_kBladeWidth, customBladeWidth);
    await p.setInt(_kDifficulty, difficulty);
    await p.setBool(_kIsPro, isPro);
    await p.setString(_kBestScores, jsonEncode(bestScores));
    await p.setInt(_kTotalSliced, totalSliced);
    await p.setInt(_kGames, gamesPlayed);
    await p.setInt(_kBestCombo, bestCombo);
    await p.setInt(_kReviewAsked, reviewAskedAt);
  }

  /// Free-tier limits: clamp pro-only choices back when not Pro.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (FrenzyThemes.isProTheme(themeId)) {
      themeId = 'orchard_dawn';
      changed = true;
    }
    if (bladeId == 'custom' || BladeStyles.isProBlade(bladeId)) {
      bladeId = 'silver';
      changed = true;
    }
    if (difficulty > 1) {
      difficulty = 1;
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  int bestFor(String modeId) => bestScores[modeId] ?? 0;

  /// The active theme: the custom "My Market" theme when the creator was
  /// used, otherwise the catalog theme. Always returns a valid theme.
  FrenzyThemeDef get theme {
    if (themeId == 'my_theme' && customThemeColors != null) {
      return FrenzyThemes.myTheme(customThemeColors!);
    }
    return FrenzyThemes.byId(themeId);
  }

  bool get hasCustomTheme => customThemeColors != null;

  Future<void> recordGame({
    required String modeId,
    required int score,
    required int sliced,
    required int combo,
  }) async {
    gamesPlayed++;
    totalSliced += sliced;
    if (combo > bestCombo) bestCombo = combo;
    if (score > bestFor(modeId)) bestScores[modeId] = score;
    notifyListeners();
    await _save();
  }

  Future<void> markReviewAsked(int games) async {
    reviewAskedAt = games;
    await _save();
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setProfileName(String name) async {
    final clean = name.trim();
    profileName = clean.isEmpty ? defaultName : clean.substring(0, clean.length > 18 ? 18 : clean.length);
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    if (!isPro && FrenzyThemes.isProTheme(id)) return;
    themeId = FrenzyThemes.sanitize(id);
    notifyListeners();
    await _save();
  }

  /// Custom theme creator (Pro): user picks the 4 core colors; the rest of
  /// the palette is derived for a cohesive physical look. Persisted as ONE
  /// order-preserving JSON string.
  Future<void> setCustomTheme(Map<String, int> colors) async {
    if (!isPro) return;
    customThemeColors = Map<String, int>.from(colors);
    themeId = 'my_theme';
    notifyListeners();
    await _save();
  }

  Future<void> clearCustomTheme() async {
    customThemeColors = null;
    if (themeId == 'my_theme') themeId = 'orchard_dawn';
    notifyListeners();
    await _save();
  }

  Future<void> setBlade(String id) async {
    if (!isPro && (id == 'custom' || BladeStyles.isProBlade(id))) return;
    bladeId = BladeStyles.sanitize(id);
    notifyListeners();
    await _save();
  }

  Future<void> setCustomBlade(Color color, double width) async {
    if (!isPro) return; // custom blade creator is a Pro feature
    customBladeColor = color.toARGB32();
    customBladeWidth = width.clamp(8.0, 22.0);
    bladeId = 'custom';
    notifyListeners();
    await _save();
  }

  BladeStyle get blade =>
      bladeId == 'custom' && isPro
          ? BladeStyles.custom(Color(customBladeColor), customBladeWidth)
          : BladeStyles.byId(bladeId);

  Future<void> setDifficulty(int d) async {
    d = d.clamp(0, 2);
    if (!isPro && d > 1) return; // Hard is a Pro feature
    difficulty = d;
    notifyListeners();
    await _save();
  }

  Future<void> resetStats() async {
    bestScores = {};
    totalSliced = 0;
    gamesPlayed = 0;
    bestCombo = 0;
    reviewAskedAt = 0;
    notifyListeners();
    await _save();
  }
}
