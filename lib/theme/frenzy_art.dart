import 'package:flutter/material.dart';
import 'frenzy_themes.dart';

/// Shared text styles for the Slice Frenzy art direction: chunky, readable,
/// physical. Pair with theme colors — never neon.
class FrenzyText {
  static TextStyle display(double size, FrenzyThemeDef t) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: t.ink,
        letterSpacing: 0.5,
        shadows: [
          Shadow(
              color: Colors.black.withValues(alpha: 0.18),
              offset: const Offset(0, 2),
              blurRadius: 3),
        ],
      );

  static TextStyle label(double size, FrenzyThemeDef t) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: t.ink.withValues(alpha: 0.75),
        letterSpacing: 1.2,
      );

  static TextStyle body(double size, FrenzyThemeDef t) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: t.ink,
      );

  static TextStyle onAccent(double size, FrenzyThemeDef t) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: t.accentInk,
        letterSpacing: 0.6,
      );
}

/// Physical fruit catalog. Each fruit has a rind (outside), flesh (inside
/// when sliced) and juice color. Bombs are round and black with a fuse.
enum FruitKind { watermelon, orange, apple, kiwi, lemon, plum, coconut, bomb }

@immutable
class FruitLook {
  final Color rind;
  final Color rindDark;
  final Color flesh;
  final Color fleshLight;
  final Color juice;
  final Color seed;
  final bool striped; // watermelon rind stripes
  final double radius; // relative size factor

  const FruitLook({
    required this.rind,
    required this.rindDark,
    required this.flesh,
    required this.fleshLight,
    required this.juice,
    required this.seed,
    this.striped = false,
    this.radius = 1.0,
  });
}

class FruitLooks {
  static const Map<FruitKind, FruitLook> all = {
    FruitKind.watermelon: FruitLook(
      rind: Color(0xFF2E7D32),
      rindDark: Color(0xFF1B5E20),
      flesh: Color(0xFFE53935),
      fleshLight: Color(0xFFFF8A80),
      juice: Color(0xFFFF5252),
      seed: Color(0xFF212121),
      striped: true,
      radius: 1.25,
    ),
    FruitKind.orange: FruitLook(
      rind: Color(0xFFF57C00),
      rindDark: Color(0xFFE65100),
      flesh: Color(0xFFFFB74D),
      fleshLight: Color(0xFFFFE0B2),
      juice: Color(0xFFFF9800),
      seed: Color(0xFFFFF3E0),
      radius: 1.0,
    ),
    FruitKind.apple: FruitLook(
      rind: Color(0xFFC62828),
      rindDark: Color(0xFF8E0000),
      flesh: Color(0xFFFFF8E1),
      fleshLight: Color(0xFFFFFFFF),
      juice: Color(0xFFFFCDD2),
      seed: Color(0xFF4E342E),
      radius: 1.0,
    ),
    FruitKind.kiwi: FruitLook(
      rind: Color(0xFF6D4C41),
      rindDark: Color(0xFF4E342E),
      flesh: Color(0xFF9CCC65),
      fleshLight: Color(0xFFDCE775),
      juice: Color(0xFF8BC34A),
      seed: Color(0xFF33691E),
      radius: 0.85,
    ),
    FruitKind.lemon: FruitLook(
      rind: Color(0xFFFDD835),
      rindDark: Color(0xFFF9A825),
      flesh: Color(0xFFFFF176),
      fleshLight: Color(0xFFFFFDE7),
      juice: Color(0xFFFFEB3B),
      seed: Color(0xFFFFF9C4),
      radius: 0.9,
    ),
    FruitKind.plum: FruitLook(
      rind: Color(0xFF6A1B9A),
      rindDark: Color(0xFF4A148C),
      flesh: Color(0xFFFFD54F),
      fleshLight: Color(0xFFFFF3C4),
      juice: Color(0xFFCE93D8),
      seed: Color(0xFF3E2723),
      radius: 0.9,
    ),
    FruitKind.coconut: FruitLook(
      rind: Color(0xFF795548),
      rindDark: Color(0xFF4E342E),
      flesh: Color(0xFFFFFBF5),
      fleshLight: Color(0xFFFFFFFF),
      juice: Color(0xFFD7CCC8),
      seed: Color(0xFF3E2723),
      radius: 1.15,
    ),
    FruitKind.bomb: FruitLook(
      rind: Color(0xFF212121),
      rindDark: Color(0xFF000000),
      flesh: Color(0xFFFF6F00),
      fleshLight: Color(0xFFFFB74D),
      juice: Color(0xFFFF6F00),
      seed: Color(0xFF212121),
      radius: 1.1,
    ),
  };
}
