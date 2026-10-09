import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/blade_styles.dart';
import '../theme/frenzy_art.dart';
import '../theme/frenzy_themes.dart';

/// Customize: 12 themes, custom theme creator (Pro), 10 blade styles, and
/// the custom blade creator (Pro).
class CustomizeScreen extends StatefulWidget {
  final SliceAudio audio;
  final SliceSettings settings;
  final VoidCallback onPro;
  const CustomizeScreen(
      {super.key,
      required this.audio,
      required this.settings,
      required this.onPro});

  @override
  State<CustomizeScreen> createState() => _CustomizeScreenState();
}

class _CustomizeScreenState extends State<CustomizeScreen> {
  Color _draftColor = const Color(0xFFE53935);
  double _draftWidth = 13.0;
  bool _editingCustom = false;

  // Custom theme creator drafts.
  static const _slotKeys = ['skyTop', 'skyBottom', 'crate', 'accent'];
  late Map<String, Color> _themeDrafts;
  int _themeSlot = 0;
  bool _editingTheme = false;

  @override
  void initState() {
    super.initState();
    _draftColor = Color(widget.settings.customBladeColor);
    _draftWidth = widget.settings.customBladeWidth;
    final saved = widget.settings.customThemeColors;
    _themeDrafts = {
      'skyTop': Color(saved?['skyTop'] ?? 0xFFFFF8E7),
      'skyBottom': Color(saved?['skyBottom'] ?? 0xFFFFE3B3),
      'crate': Color(saved?['crate'] ?? 0xFF8A5A33),
      'accent': Color(saved?['accent'] ?? 0xFFC0392B),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.settings.theme;
    final settings = widget.settings;
    return Scaffold(
      appBar: AppBar(
        title: Text('Customize', style: FrenzyText.display(22, theme)),
        backgroundColor: theme.card,
        foregroundColor: theme.ink,
        elevation: 1,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.skyTop, theme.skyBottom],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text('MARKET THEMES', style: FrenzyText.label(13, theme)),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.82),
              itemCount: FrenzyThemes.all.length,
              itemBuilder: (_, i) {
                final t = FrenzyThemes.all[i];
                final locked = t.isPro && !settings.isPro;
                final selected = settings.themeId == t.id;
                return GestureDetector(
                  onTap: () {
                    widget.audio.click();
                    if (locked) {
                      widget.onPro();
                      return;
                    }
                    settings.setTheme(t.id);
                    setState(() {});
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: selected
                          ? Border.all(color: theme.accent, width: 3)
                          : Border.all(
                              color: theme.ink.withValues(alpha: 0.12)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            offset: const Offset(0, 2),
                            blurRadius: 6),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Column(
                            children: [
                              Expanded(
                                  flex: 3,
                                  child: Container(
                                      color: t.skyBottom)),
                              Expanded(
                                  flex: 2,
                                  child: Container(color: t.crate)),
                            ],
                          ),
                          if (locked)
                            Container(
                                color: Colors.black.withValues(alpha: 0.45),
                                child: const Icon(Icons.lock,
                                    color: Colors.white)),
                          Positioned(
                            bottom: 4,
                            left: 4,
                            right: 4,
                            child: Text(t.name,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                          color: Colors.black54,
                                          blurRadius: 3)
                                    ])),
                          ),
                          if (selected)
                            const Positioned(
                              top: 4,
                              right: 4,
                              child: Icon(Icons.check_circle,
                                  color: Colors.white, size: 20),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text('MY MARKET THEME', style: FrenzyText.label(13, theme)),
            const SizedBox(height: 8),
            _CustomThemeCard(
              theme: theme,
              settings: settings,
              editing: _editingTheme,
              selected: settings.themeId == 'my_theme',
              slot: _themeSlot,
              drafts: _themeDrafts,
              onTap: () {
                widget.audio.click();
                if (!settings.isPro) {
                  widget.onPro();
                  return;
                }
                setState(() => _editingTheme = true);
              },
              onSlot: (i) => setState(() => _themeSlot = i),
              onColor: (c) =>
                  setState(() => _themeDrafts[_slotKeys[_themeSlot]] = c),
              onSave: () async {
                widget.audio.click();
                await settings.setCustomTheme({
                  for (final k in _slotKeys) k: _themeDrafts[k]!.toARGB32(),
                });
                setState(() => _editingTheme = false);
              },
              onCancel: () => setState(() => _editingTheme = false),
            ),
            const SizedBox(height: 20),
            Text('BLADES', style: FrenzyText.label(13, theme)),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.6),
              itemCount: BladeStyles.all.length + 1, // + custom creator
              itemBuilder: (_, i) {
                if (i == BladeStyles.all.length) {
                  return _CustomBladeCard(
                    theme: theme,
                    settings: settings,
                    selected: settings.bladeId == 'custom',
                    editing: _editingCustom,
                    draftColor: _draftColor,
                    draftWidth: _draftWidth,
                    onTap: () {
                      widget.audio.click();
                      if (!settings.isPro) {
                        widget.onPro();
                        return;
                      }
                      setState(
                          () => _editingCustom = !_editingCustom);
                    },
                    onColor: (c) => setState(() => _draftColor = c),
                    onWidth: (w) => setState(() => _draftWidth = w),
                    onSave: () async {
                      widget.audio.click();
                      await settings.setCustomBlade(
                          _draftColor, _draftWidth);
                      setState(() => _editingCustom = false);
                    },
                  );
                }
                final b = BladeStyles.all[i];
                final locked = b.isPro && !settings.isPro;
                final selected = settings.bladeId == b.id;
                return GestureDetector(
                  onTap: () {
                    widget.audio.click();
                    if (locked) {
                      widget.onPro();
                      return;
                    }
                    settings.setBlade(b.id);
                    setState(() => _editingCustom = false);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.card,
                      borderRadius: BorderRadius.circular(14),
                      border: selected
                          ? Border.all(color: theme.accent, width: 3)
                          : Border.all(
                              color: theme.ink.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: locked
                                ? theme.ink.withValues(alpha: 0.15)
                                : b.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: locked
                                    ? Colors.transparent
                                    : b.edge,
                                width: 3),
                          ),
                          child: locked
                              ? const Icon(Icons.lock,
                                  size: 18, color: Colors.white70)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(b.name,
                              style: FrenzyText.body(13, theme)),
                        ),
                        if (selected)
                          Icon(Icons.check_circle,
                              color: theme.accent, size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _CustomBladeCard extends StatelessWidget {
  final FrenzyThemeDef theme;
  final SliceSettings settings;
  final bool selected;
  final bool editing;
  final Color draftColor;
  final double draftWidth;
  final VoidCallback onTap;
  final ValueChanged<Color> onColor;
  final ValueChanged<double> onWidth;
  final VoidCallback onSave;
  const _CustomBladeCard({
    required this.theme,
    required this.settings,
    required this.selected,
    required this.editing,
    required this.draftColor,
    required this.draftWidth,
    required this.onTap,
    required this.onColor,
    required this.onWidth,
    required this.onSave,
  });

  static const _swatches = [
    Color(0xFFE53935),
    Color(0xFFFFA000),
    Color(0xFF7CB342),
    Color(0xFF0288D1),
    Color(0xFF3949AB),
    Color(0xFF6A1B9A),
    Color(0xFFC2185B),
    Color(0xFFE64A19),
    Color(0xFF5D4037),
    Color(0xFF546E7A),
    Color(0xFF00897B),
    Color(0xFF212121),
  ];

  @override
  Widget build(BuildContext context) {
    final locked = !settings.isPro;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.card,
          borderRadius: BorderRadius.circular(14),
          border: selected
              ? Border.all(color: theme.accent, width: 3)
              : Border.all(color: theme.ink.withValues(alpha: 0.12)),
        ),
        child: editing
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('MY BLADE', style: FrenzyText.label(11, theme)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _swatches
                        .map((c) => GestureDetector(
                              onTap: () => onColor(c),
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: c == draftColor
                                          ? theme.accent
                                          : Colors.transparent,
                                      width: 3),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  Row(
                    children: [
                      Text('Width',
                          style: FrenzyText.body(11, theme)),
                      Expanded(
                        child: Slider(
                          value: draftWidth,
                          min: 8,
                          max: 22,
                          activeColor: theme.accent,
                          onChanged: onWidth,
                        ),
                      ),
                    ],
                  ),
                  // Live preview stroke.
                  Container(
                    height: 18,
                    alignment: Alignment.center,
                    child: Container(
                      height: draftWidth / 2.2,
                      decoration: BoxDecoration(
                        color: draftColor,
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: theme.accent,
                          foregroundColor: theme.accentInk),
                      onPressed: onSave,
                      child: const Text('Use this blade'),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: locked
                          ? theme.ink.withValues(alpha: 0.15)
                          : Color(settings.customBladeColor),
                      border: Border.all(
                          color: theme.ink.withValues(alpha: 0.2)),
                    ),
                    child: locked
                        ? const Icon(Icons.lock,
                            size: 18, color: Colors.white70)
                        : const Icon(Icons.brush,
                            size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Custom blade',
                            style: FrenzyText.body(13, theme)),
                        Text(
                            locked
                                ? 'PRO — design your own'
                                : 'Tap to design',
                            style: FrenzyText.body(11, theme).copyWith(
                                color: theme.ink
                                    .withValues(alpha: 0.55))),
                      ],
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle,
                        color: theme.accent, size: 20),
                ],
              ),
      ),
    );
  }
}

/// Custom theme creator (Pro): pick the 4 core market colors; the rest of
/// the palette is derived for a cohesive physical look. Persisted as ONE
/// order-preserving JSON string via setString.
class _CustomThemeCard extends StatelessWidget {
  final FrenzyThemeDef theme;
  final SliceSettings settings;
  final bool editing;
  final bool selected;
  final int slot;
  final Map<String, Color> drafts;
  final VoidCallback onTap;
  final ValueChanged<int> onSlot;
  final ValueChanged<Color> onColor;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _CustomThemeCard({
    required this.theme,
    required this.settings,
    required this.editing,
    required this.selected,
    required this.slot,
    required this.drafts,
    required this.onTap,
    required this.onSlot,
    required this.onColor,
    required this.onSave,
    required this.onCancel,
  });

  static const _slotKeys = ['skyTop', 'skyBottom', 'crate', 'accent'];
  static const _slotLabels = ['Sky top', 'Sky bottom', 'Crate', 'Accent'];

  static const _swatches = [
    Color(0xFFFFF8E7),
    Color(0xFFFFE3B3),
    Color(0xFFFFF0B3),
    Color(0xFFF8DDE7),
    Color(0xFFCDEEDC),
    Color(0xFFF3D9AE),
    Color(0xFFDDEECB),
    Color(0xFFF9C89B),
    Color(0xFFC0392B),
    Color(0xFFE67E22),
    Color(0xFFAD1457),
    Color(0xFF1B7A4D),
    Color(0xFF8A5A33),
    Color(0xFF6E4A2F),
    Color(0xFF7C5A35),
    Color(0xFF5D4037),
    Color(0xFFB8860B),
    Color(0xFF3949AB),
    Color(0xFF558B2F),
    Color(0xFF212121),
  ];

  Widget _preview({double height = 44}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.ink.withValues(alpha: 0.15)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [drafts['skyTop']!, drafts['skyBottom']!],
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: drafts['accent'],
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.7),
                            width: 2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(flex: 1, child: Container(color: drafts['crate'])),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locked = !settings.isPro;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(16),
        border: selected
            ? Border.all(color: theme.accent, width: 3)
            : Border.all(color: theme.ink.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              offset: const Offset(0, 3),
              blurRadius: 8),
        ],
      ),
      child: editing
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DESIGN YOUR MARKET',
                    style: FrenzyText.label(11, theme)),
                const SizedBox(height: 10),
                _preview(height: 64),
                const SizedBox(height: 12),
                // Slot picker: which color are we painting?
                Row(
                  children: List.generate(4, (i) {
                    final active = slot == i;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onSlot(i),
                        child: Container(
                          margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: active
                                ? theme.accent.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: active
                                    ? theme.accent
                                    : theme.ink.withValues(alpha: 0.15),
                                width: active ? 2 : 1),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: drafts[_slotKeys[i]],
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: theme.ink
                                          .withValues(alpha: 0.25)),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(_slotLabels[i],
                                  style: FrenzyText.body(10, theme)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _swatches
                      .map((c) => GestureDetector(
                            onTap: () => onColor(c),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color:
                                        c == drafts[_slotKeys[slot]]
                                            ? theme.accent
                                            : theme.ink
                                                .withValues(alpha: 0.2),
                                    width: c == drafts[_slotKeys[slot]]
                                        ? 3
                                        : 1),
                              ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: onCancel,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: theme.ink.withValues(alpha: 0.25)),
                          ),
                          child: Center(
                              child: Text('Cancel',
                                  style: FrenzyText.label(14, theme))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: theme.accent,
                            foregroundColor: theme.accentInk,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        onPressed: onSave,
                        child: const Text('Use this theme'),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : GestureDetector(
              onTap: onTap,
              child: Row(
                children: [
                  SizedBox(width: 72, child: _preview()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Custom theme',
                            style: FrenzyText.body(14, theme)),
                        Text(
                            locked
                                ? 'PRO — design your own market'
                                : settings.hasCustomTheme
                                    ? 'My Market — tap to edit'
                                    : 'Tap to design your market',
                            style: FrenzyText.body(12, theme).copyWith(
                                color:
                                    theme.ink.withValues(alpha: 0.55))),
                      ],
                    ),
                  ),
                  if (locked)
                    const Icon(Icons.lock,
                        size: 20, color: Colors.black38)
                  else
                    Icon(Icons.brush,
                        size: 20,
                        color: theme.ink.withValues(alpha: 0.5)),
                  if (selected && !locked) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.check_circle,
                        color: theme.accent, size: 20),
                  ],
                ],
              ),
            ),
    );
  }
}
