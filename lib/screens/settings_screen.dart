import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/frenzy_art.dart';
import '../theme/frenzy_themes.dart';

/// Settings: profile name, audio toggles + volume, stats, reset.
class SettingsScreen extends StatelessWidget {
  final SliceAudio audio;
  final SliceSettings settings;
  const SettingsScreen(
      {super.key, required this.audio, required this.settings});

  @override
  Widget build(BuildContext context) {
    final theme = settings.theme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: FrenzyText.display(22, theme)),
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
            _Section(
              theme: theme,
              title: 'Slicer profile',
              children: [
                ListTile(
                  title: Text('Display name',
                      style: FrenzyText.body(15, theme)),
                  subtitle: Text(settings.profileName,
                      style: FrenzyText.label(13, theme)),
                  trailing: const Icon(Icons.edit),
                  onTap: () => _rename(context),
                ),
              ],
            ),
            _Section(
              theme: theme,
              title: 'Audio',
              children: [
                SwitchListTile(
                  title: Text('Music', style: FrenzyText.body(15, theme)),
                  value: settings.musicOn,
                  activeThumbColor: theme.accent,
                  onChanged: (v) async {
                    audio.click();
                    await settings.setMusic(v);
                    audio.configure(
                        musicOn: settings.musicOn,
                        sfxOn: settings.sfxOn,
                        volume: settings.volume);
                    if (v) {
                      audio.startMenuMusic();
                    }
                  },
                ),
                SwitchListTile(
                  title: Text('Sound effects',
                      style: FrenzyText.body(15, theme)),
                  value: settings.sfxOn,
                  activeThumbColor: theme.accent,
                  onChanged: (v) async {
                    await settings.setSfx(v);
                    audio.configure(
                        musicOn: settings.musicOn,
                        sfxOn: settings.sfxOn,
                        volume: settings.volume);
                    if (v) audio.click();
                  },
                ),
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(
                    children: [
                      Icon(Icons.volume_up, color: theme.ink),
                      Expanded(
                        child: Slider(
                          value: settings.volume,
                          activeColor: theme.accent,
                          onChanged: (v) {
                            settings.setVolume(v);
                            audio.configure(
                                musicOn: settings.musicOn,
                                sfxOn: settings.sfxOn,
                                volume: settings.volume);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _Section(
              theme: theme,
              title: 'Lifetime stats',
              children: [
                _Stat(theme, 'Games played', '${settings.gamesPlayed}'),
                _Stat(theme, 'Fruit sliced', '${settings.totalSliced}'),
                _Stat(theme, 'Best combo', 'x${settings.bestCombo}'),
                ListTile(
                  title: Text('Reset stats',
                      style: FrenzyText.body(15, theme)
                          .copyWith(color: const Color(0xFFC62828))),
                  trailing: const Icon(Icons.delete_outline,
                      color: Color(0xFFC62828)),
                  onTap: () async {
                    audio.click();
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: theme.card,
                        title: Text('Reset all stats?',
                            style: FrenzyText.label(16, theme)),
                        content: Text(
                            'Best scores and lifetime stats go back to zero.',
                            style: FrenzyText.body(14, theme)),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text('Keep',
                                  style:
                                      FrenzyText.body(14, theme))),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Reset',
                                  style: TextStyle(
                                      color: Color(0xFFC62828)))),
                        ],
                      ),
                    );
                    if (ok == true) settings.resetStats();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Text('Slice Frenzy v2.0 · by WAJIHA',
                  style: FrenzyText.label(11, theme).copyWith(
                      color: theme.ink.withValues(alpha: 0.5))),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context) async {
    audio.click();
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

class _Section extends StatelessWidget {
  final FrenzyThemeDef theme;
  final String title;
  final List<Widget> children;
  const _Section(
      {required this.theme, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              offset: const Offset(0, 3),
              blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child:
                Text(title.toUpperCase(), style: FrenzyText.label(12, theme)),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final FrenzyThemeDef theme;
  final String label;
  final String value;
  const _Stat(this.theme, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: FrenzyText.body(15, theme)),
      trailing: Text(value, style: FrenzyText.display(17, theme)),
    );
  }
}
