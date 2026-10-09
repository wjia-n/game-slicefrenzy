import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slicefrenzy/theme/frenzy_themes.dart';
import 'package:slicefrenzy/services/settings_service.dart';

void main() {
  test('custom theme factory builds a valid theme from 4 colors', () {
    final t = FrenzyThemes.myTheme({
      'skyTop': 0xFFFF0000,
      'skyBottom': 0xFF00FF00,
      'crate': 0xFF0000FF,
      'accent': 0xFFFFFF00,
    });
    expect(t.id, 'my_theme');
    expect(t.name, 'My Market');
    expect(t.isPro, isTrue);
    expect(t.skyTop, const Color(0xFFFF0000));
    expect(t.skyBottom, const Color(0xFF00FF00));
    expect(t.crate, const Color(0xFF0000FF));
    expect(t.accent, const Color(0xFFFFFF00));
  });

  test('my_theme is pro-gated and survives sanitize', () {
    expect(FrenzyThemes.isProTheme('my_theme'), isTrue);
    expect(FrenzyThemes.sanitize('my_theme'), 'my_theme');
    expect(FrenzyThemes.sanitize('orchard_dawn'), 'orchard_dawn');
    // Unknown ids still fall back to the default.
    expect(FrenzyThemes.sanitize('nope'), 'orchard_dawn');
    expect(FrenzyThemes.sanitize(null), 'orchard_dawn');
  });

  test('profile JSON key uses the mandated order-preserving key', () {
    // The name list must live under slicefrenzy_player_names_json as ONE
    // JSON string via setString — never a StringList.
    expect(
      SliceSettings.encodeProfile('Juice Ninja'),
      '{"name":"Juice Ninja"}',
    );
  });
}
