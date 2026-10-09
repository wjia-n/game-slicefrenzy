import 'package:flutter/material.dart';

/// A blade: the swipe trail's look. Physical brush-stroke trails, no neon.
@immutable
class BladeStyle {
  final String id;
  final String name;
  final bool isPro;
  final Color color;
  final Color edge; // brighter core of the stroke
  final double width; // logical px at 360pt reference

  const BladeStyle({
    required this.id,
    required this.name,
    required this.isPro,
    required this.color,
    required this.edge,
    required this.width,
  });
}

/// 10 blade styles. First 5 free; rest need Pro.
class BladeStyles {
  static const List<BladeStyle> all = [
    BladeStyle(
        id: 'silver',
        name: 'Silver Slash',
        isPro: false,
        color: Color(0xFFB0BEC5),
        edge: Color(0xFFECEFF1),
        width: 14),
    BladeStyle(
        id: 'strawberry',
        name: 'Strawberry',
        isPro: false,
        color: Color(0xFFE53935),
        edge: Color(0xFFFFCDD2),
        width: 13),
    BladeStyle(
        id: 'lime',
        name: 'Lime Zest',
        isPro: false,
        color: Color(0xFF7CB342),
        edge: Color(0xFFDCEDC8),
        width: 13),
    BladeStyle(
        id: 'honey',
        name: 'Honey Gold',
        isPro: false,
        color: Color(0xFFFFA000),
        edge: Color(0xFFFFECB3),
        width: 13),
    BladeStyle(
        id: 'blueberry',
        name: 'Blueberry',
        isPro: false,
        color: Color(0xFF3949AB),
        edge: Color(0xFFC5CAE9),
        width: 13),
    BladeStyle(
        id: 'cherry',
        name: 'Cherry Blast',
        isPro: true,
        color: Color(0xFFC2185B),
        edge: Color(0xFFF8BBD0),
        width: 14),
    BladeStyle(
        id: 'frost',
        name: 'Frost Edge',
        isPro: true,
        color: Color(0xFF0288D1),
        edge: Color(0xFFB3E5FC),
        width: 12),
    BladeStyle(
        id: 'ember',
        name: 'Ember Cut',
        isPro: true,
        color: Color(0xFFE64A19),
        edge: Color(0xFFFFCCBC),
        width: 15),
    BladeStyle(
        id: 'plum',
        name: 'Plum Slice',
        isPro: true,
        color: Color(0xFF6A1B9A),
        edge: Color(0xFFE1BEE7),
        width: 14),
    BladeStyle(
        id: 'cocoa',
        name: 'Cocoa',
        isPro: true,
        color: Color(0xFF5D4037),
        edge: Color(0xFFD7CCC8),
        width: 15),
  ];

  static BladeStyle byId(String id) {
    for (final b in all) {
      if (b.id == id) return b;
    }
    return all[0];
  }

  static bool isProBlade(String id) => byId(id).isPro;
  static String sanitize(String? id) => byId(id ?? '').id;

  /// Custom blade creator (Pro): user picks a color; width slider 8..22.
  static BladeStyle custom(Color color, double width) => BladeStyle(
        id: 'custom',
        name: 'My Blade',
        isPro: true,
        color: color,
        edge: _lighten(color),
        width: width,
      );

  static Color _lighten(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + 0.35).clamp(0.0, 1.0)).toColor();
  }
}
