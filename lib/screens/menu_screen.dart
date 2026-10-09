import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/slice_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/frenzy_art.dart';
import '../theme/frenzy_themes.dart';
import 'customize_screen.dart';
import 'game_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';

const storeUrl =
    'https://play.google.com/store/apps/details?id=com.gameswajiha.slicefrenzy';

class MenuScreen extends StatefulWidget {
  final SliceAudio audio;
  final SliceSettings settings;
  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  late SliceMode _mode;
  late final StoreService _store;

  @override
  void initState() {
    super.initState();
    _mode = SliceMode.all.first;
    _store = StoreService();
    _store.init();
    _store.proPurchased.addListener(_onProPurchased);
    widget.audio.startMenuMusic();
  }

  @override
  void dispose() {
    _store.proPurchased.removeListener(_onProPurchased);
    _store.dispose();
    super.dispose();
  }

  void _onProPurchased() {
    if (_store.proPurchased.value) {
      widget.settings.setPro(true);
      _store.proPurchased.value = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PRO unlocked — enjoy!')),
        );
      }
    }
  }

  void _play() {
    widget.audio.gameStart();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          audio: widget.audio,
          settings: widget.settings,
          mode: _mode,
        ),
      ),
    );
  }

  void _share() {
    widget.audio.click();
    SharePlus.instance.share(
      ShareParams(
        text:
            'I\'m slicing fruit in Slice Frenzy — can you beat my score? 🍉\n$storeUrl',
        subject: 'Slice Frenzy',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final theme = settings.theme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.skyTop, theme.skyBottom],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset('assets/slice_logo.png',
                        width: 74, height: 74, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Slice Frenzy',
                            style: FrenzyText.display(32, theme)),
                        GestureDetector(
                          onTap: () => _rename(context),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(settings.profileName,
                                  style: FrenzyText.label(15, theme)),
                              const SizedBox(width: 6),
                              Icon(Icons.edit,
                                  size: 14,
                                  color:
                                      theme.ink.withValues(alpha: 0.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Share',
                    onPressed: _share,
                    icon: Icon(Icons.share, color: theme.ink),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _BestStrip(settings: settings, theme: theme),
              const SizedBox(height: 16),
              Text('CHOOSE YOUR CHAOS',
                  style: FrenzyText.label(13, theme)),
              const SizedBox(height: 8),
              ...SliceMode.all.map((m) => _ModeCard(
                    mode: m,
                    theme: theme,
                    selected: _mode.id == m.id,
                    best: settings.bestFor(m.id),
                    locked: m.isPro && !settings.isPro,
                    onTap: () {
                      widget.audio.click();
                      if (m.isPro && !settings.isPro) {
                        _goPro();
                        return;
                      }
                      setState(() => _mode = m);
                    },
                  )),
              const SizedBox(height: 16),
              Text('DIFFICULTY', style: FrenzyText.label(13, theme)),
              const SizedBox(height: 8),
              _DifficultyRow(
                theme: theme,
                settings: settings,
                onPick: (d) => settings.setDifficulty(d),
                onPro: _goPro,
              ),
              const SizedBox(height: 20),
              _BigButton(
                theme: theme,
                label: 'SLICE IT!',
                icon: Icons.play_arrow,
                onTap: _play,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _SmallButton(
                          theme: theme,
                          label: 'Customize',
                          icon: Icons.palette,
                          onTap: () {
                            widget.audio.click();
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => CustomizeScreen(
                                    audio: widget.audio,
                                    settings: settings,
                                    onPro: _goPro)));
                          })),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _SmallButton(
                          theme: theme,
                          label: 'Settings',
                          icon: Icons.settings,
                          onTap: () {
                            widget.audio.click();
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => SettingsScreen(
                                    audio: widget.audio,
                                    settings: settings)));
                          })),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _SmallButton(
                          theme: theme,
                          label: settings.isPro ? 'PRO ✓' : 'Go PRO',
                          icon: Icons.star,
                          highlight: !settings.isPro,
                          onTap: _goPro)),
                ],
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  'Made with juice by WAJIHA',
                  style: FrenzyText.label(11, theme)
                      .copyWith(color: theme.ink.withValues(alpha: 0.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goPro() {
    widget.audio.click();
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProScreen(
            audio: widget.audio, settings: widget.settings, store: _store)));
  }

  Future<void> _rename(BuildContext context) async {
    widget.audio.click();
    final settings = widget.settings;
    final theme = settings.theme;
    final ctrl = TextEditingController(text: settings.profileName);
    final focus = FocusNode();
    // Master rule: save on EVERY keystroke via a single order-preserving
    // JSON string (never setStringList), and commit when focus is lost.
    ctrl.addListener(() {
      settings.setProfileName(ctrl.text);
    });
    focus.addListener(() {
      if (!focus.hasFocus) settings.setProfileName(ctrl.text);
    });
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.card,
        title: Text('Your slicer name', style: FrenzyText.label(16, theme)),
        content: TextField(
          controller: ctrl,
          focusNode: focus,
          maxLength: 18,
          autofocus: true,
          style: FrenzyText.body(16, theme),
          decoration: const InputDecoration(hintText: 'e.g. Juice Ninja'),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: theme.accent,
                foregroundColor: theme.accentInk),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    // Final commit in case the dialog closed without a focus change.
    await settings.setProfileName(ctrl.text);
    ctrl.dispose();
    focus.dispose();
  }
}

class _BestStrip extends StatelessWidget {
  final SliceSettings settings;
  final FrenzyThemeDef theme;
  const _BestStrip({required this.settings, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              offset: const Offset(0, 3),
              blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: SliceMode.all
            .map((m) => Column(
                  children: [
                    Text(m.name, style: FrenzyText.label(10, theme)),
                    Text('${settings.bestFor(m.id)}',
                        style: FrenzyText.display(18, theme)),
                  ],
                ))
            .toList(),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final SliceMode mode;
  final FrenzyThemeDef theme;
  final bool selected;
  final int best;
  final bool locked;
  final VoidCallback onTap;
  const _ModeCard({
    required this.mode,
    required this.theme,
    required this.selected,
    required this.best,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? theme.accent : theme.card,
          borderRadius: BorderRadius.circular(16),
          border: selected
              ? null
              : Border.all(color: theme.ink.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                offset: const Offset(0, 3),
                blurRadius: 8),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(mode.name,
                          style: (selected
                                  ? FrenzyText.onAccent(18, theme)
                                  : FrenzyText.display(18, theme))),
                      if (locked) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.lock,
                            size: 16,
                            color: selected
                                ? theme.accentInk
                                : theme.ink.withValues(alpha: 0.5)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(mode.blurb,
                      style: (selected
                              ? FrenzyText.body(12, theme)
                              : FrenzyText.body(12, theme))
                          .copyWith(
                              color: selected
                                  ? theme.accentInk.withValues(alpha: 0.9)
                                  : theme.ink.withValues(alpha: 0.65))),
                ],
              ),
            ),
            Column(
              children: [
                Text('BEST',
                    style: FrenzyText.label(9, theme).copyWith(
                        color: selected
                            ? theme.accentInk.withValues(alpha: 0.8)
                            : theme.ink.withValues(alpha: 0.5))),
                Text('$best',
                    style: (selected
                            ? FrenzyText.onAccent(22, theme)
                            : FrenzyText.display(22, theme))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyRow extends StatelessWidget {
  final FrenzyThemeDef theme;
  final SliceSettings settings;
  final ValueChanged<int> onPick;
  final VoidCallback onPro;
  const _DifficultyRow(
      {required this.theme,
      required this.settings,
      required this.onPick,
      required this.onPro});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        final locked = i == 2 && !settings.isPro;
        final selected = settings.difficulty == i;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              if (locked) {
                onPro();
                return;
              }
              onPick(i);
            },
            child: Container(
              margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected ? theme.accent : theme.card,
                borderRadius: BorderRadius.circular(12),
                border: selected
                    ? null
                    : Border.all(
                        color: theme.ink.withValues(alpha: 0.12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(SliceDifficulty.names[i],
                      style: selected
                          ? FrenzyText.onAccent(14, theme)
                          : FrenzyText.body(14, theme)),
                  if (locked)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(Icons.lock,
                          size: 13,
                          color: selected
                              ? theme.accentInk
                              : theme.ink.withValues(alpha: 0.5)),
                    ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _BigButton extends StatelessWidget {
  final FrenzyThemeDef theme;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _BigButton(
      {required this.theme,
      required this.label,
      required this.icon,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: theme.accent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: theme.accent.withValues(alpha: 0.4),
                offset: const Offset(0, 6),
                blurRadius: 14),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: theme.accentInk, size: 26),
            const SizedBox(width: 8),
            Text(label, style: FrenzyText.onAccent(22, theme)),
          ],
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final FrenzyThemeDef theme;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlight;
  const _SmallButton(
      {required this.theme,
      required this.label,
      required this.icon,
      required this.onTap,
      this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: highlight ? theme.accent : theme.card,
          borderRadius: BorderRadius.circular(14),
          border: highlight
              ? null
              : Border.all(color: theme.ink.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: highlight
                    ? theme.accentInk
                    : theme.ink.withValues(alpha: 0.8),
                size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: (highlight
                        ? FrenzyText.onAccent(12, theme)
                        : FrenzyText.label(12, theme))),
          ],
        ),
      ),
    );
  }
}
