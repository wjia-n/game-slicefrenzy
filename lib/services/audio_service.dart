import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Procedural audio for Slice Frenzy — all sounds synthesized in code as WAV
/// bytes. No asset files. Juicy, physical, fruit-stand sounds: wet slice
/// splatters, blade whooshes, bomb booms, combo chimes.
///
/// Reliability design (every call is safe to repeat and safe to overlap):
/// - Music clips are synthesized ONCE and cached; starting music never blocks
///   the UI thread after the first build.
/// - A [_musicGen] generation counter serializes track changes: every
///   start/stop bumps the generation, in-flight work from an older request
///   aborts, and the LATEST request always wins. Overlapping calls (menu in/out,
///   pause/resume, toggles) can never swallow a start or leave the player
///   half-started — music is app-scoped and never silently dies.
/// - Lifecycle uses pause()/resume() so an interruption (call, backgrounding)
///   resumes exactly where it left off instead of restarting or dying.
/// - Every public method catches player errors; audio can never crash the app.
class SliceAudio {
  static const int _rate = 22050;
  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  final _rand = Random();

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;

  // Cache synthesized clips so we only build them once.
  final Map<String, Uint8List> _cache = {};

  // Music state machine. [_musicGen] is bumped by every start/stop request;
  // async work checks it still owns the latest generation before touching
  // the player, so overlapping requests can never desync the music.
  int _musicGen = 0;
  bool _musicBusy = false;
  String? _currentTrack; // 'menu' | 'game' | null
  bool _pausedByLifecycle = false;
  bool _disposed = false;

  SliceAudio() {
    _music.setReleaseMode(ReleaseMode.loop);
  }

  void configure(
      {required bool musicOn, required bool sfxOn, required double volume}) {
    this.musicOn = musicOn;
    this.sfxOn = sfxOn;
    this.volume = volume.clamp(0.0, 1.0);
    _music.setVolume(musicOn ? this.volume * 0.5 : 0.0);
    _sfx.setVolume(sfxOn ? this.volume : 0.0);
    if (!musicOn) {
      stopMusic();
    }
  }

  /// Pre-build music clips off the critical path. Safe to call any time.
  Future<void> prewarm() async {
    if (_disposed) return;
    await Future(() {});
    _menuBytes();
    _gameBytes();
  }

  // ---------------------------------------------------------- WAV synthesis
  Uint8List _wav(List<double> samples) {
    final n = samples.length;
    final data = ByteData(44 + n * 2);
    void writeStr(int o, String s) {
      for (int i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, _rate, Endian.little);
    data.setUint32(28, _rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (int i = 0; i < n; i++) {
      final v = samples[i].clamp(-1.0, 1.0);
      data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  double _env(int i, int n, {double attack = 0.02}) {
    final t = i / n;
    final a = (t / attack).clamp(0.0, 1.0);
    final d = pow(1 - t, 2.2).toDouble();
    return a * d;
  }

  List<double> _tone(double freq, double secs,
      {double freqEnd = 0, double attack = 0.02, double harmonics = 0.25}) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final f = freqEnd > 0 ? freq + (freqEnd - freq) * (i / n) : freq;
      final ph = 2 * pi * f * t;
      out[i] = _env(i, n, attack: attack) *
          (sin(ph) + harmonics * sin(2 * ph) + harmonics * 0.5 * sin(3 * ph));
    }
    return out;
  }

  List<double> _noiseBurst(double secs, double decay,
      {double brightness = 0.5}) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    double prev = 0;
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final raw = _rand.nextDouble() * 2 - 1;
      // Simple low-pass for "wet" splatter character.
      prev = prev * (1 - brightness) + raw * brightness;
      out[i] = _env(i, n, attack: 0.004) * prev * exp(-t * decay);
    }
    return out;
  }

  List<double> _slice() {
    // Juicy slice: fast blade whoosh + wet splatter.
    final n = (_rate * 0.28).round();
    final out = List<double>.filled(n, 0);
    final whoosh = _tone(2400, 0.28, freqEnd: 500, attack: 0.01);
    final splat = _noiseBurst(0.28, 22, brightness: 0.7);
    for (int i = 0; i < n; i++) {
      out[i] = whoosh[i] * 0.35 + splat[i] * 0.9;
    }
    return out;
  }

  List<double> _splat() {
    // Heavy fruit splat on the crate.
    final n = (_rate * 0.22).round();
    final out = List<double>.filled(n, 0);
    final thump = _tone(180, 0.22, freqEnd: 70, attack: 0.004);
    final wet = _noiseBurst(0.22, 30, brightness: 0.6);
    for (int i = 0; i < n; i++) {
      out[i] = thump[i] * 0.6 + wet[i] * 0.5;
    }
    return out;
  }

  List<double> _boom() {
    // Bomb: deep thump + crackling noise tail.
    final n = (_rate * 0.8).round();
    final out = List<double>.filled(n, 0);
    final thump = _tone(90, 0.8, freqEnd: 30, attack: 0.003);
    final crackle = _noiseBurst(0.8, 6, brightness: 0.9);
    for (int i = 0; i < n; i++) {
      out[i] = thump[i] * 1.0 + crackle[i] * 0.7;
    }
    return out;
  }

  List<double> _arp(List<double> freqs, double noteSecs, double gapSecs) {
    final out = <double>[];
    for (final f in freqs) {
      out.addAll(_tone(f, noteSecs, harmonics: 0.2));
      out.addAll(List<double>.filled((_rate * gapSecs).round(), 0));
    }
    return out;
  }

  List<double> _pluckMelody(
      List<double> freqs, double secs, List<double> onsets) {
    // Bouncy kalimba-like plucks with fast decay.
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (final pair in Iterable.generate(freqs.length, (i) => i)) {
      final start = (_rate * onsets[pair]).round();
      final len = (_rate * 0.55).round();
      final f = freqs[pair];
      for (int i = 0; i < len && start + i < n; i++) {
        final t = i / _rate;
        out[start + i] += (sin(2 * pi * f * t) + 0.4 * sin(4 * pi * f * t)) *
            exp(-t * 7) *
            0.35;
      }
    }
    return out;
  }

  List<double> _drumLoop(double secs, double bpm) {
    // Kick + shaker pattern for the game track.
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    final beat = 60 / bpm;
    final kicks = (secs / beat).floor();
    for (int k = 0; k < kicks; k++) {
      final start = (_rate * k * beat).round();
      final len = (_rate * 0.18).round();
      for (int i = 0; i < len && start + i < n; i++) {
        final t = i / _rate;
        out[start + i] += sin(2 * pi * (110 - 60 * t) * t) * exp(-t * 18) * 0.5;
      }
      // Shaker on off-beats.
      final sStart = (_rate * (k * beat + beat / 2)).round();
      final sLen = (_rate * 0.08).round();
      for (int i = 0; i < sLen && sStart + i < n; i++) {
        final t = i / _rate;
        out[sStart + i] +=
            (_rand.nextDouble() * 2 - 1) * exp(-t * 60) * 0.18;
      }
    }
    return out;
  }

  Uint8List _clip(String key, List<double> Function() build) =>
      _cache.putIfAbsent(key, () => _wav(build()));

  Uint8List _menuBytes() => _clip('music_menu', () {
        // Sunny market-morning loop: bouncy pluck melody, 12s.
        final melody = _pluckMelody(
          [523.25, 587.33, 659.25, 783.99, 659.25, 587.33, 523.25, 440.0],
          12.0,
          [0.0, 0.7, 1.4, 2.1, 3.5, 4.2, 4.9, 6.3],
        );
        final soft = _pluckMelody(
          [261.63, 329.63, 392.0, 329.63],
          12.0,
          [0.0, 2.8, 5.6, 8.4],
        );
        for (int i = 0; i < melody.length; i++) {
          melody[i] += soft[i] * 0.5;
        }
        return melody;
      });

  Uint8List _gameBytes() => _clip('music_game', () {
        // Driving slice-time loop: drums + punchy plucks, 12s.
        final drums = _drumLoop(12.0, 132);
        final plucks = _pluckMelody(
          [392.0, 440.0, 523.25, 587.33, 523.25, 440.0],
          12.0,
          [0.0, 0.9, 1.8, 2.7, 3.6, 4.5],
        );
        for (int i = 0; i < drums.length; i++) {
          drums[i] += plucks[i] * 0.9;
        }
        return drums;
      });

  // ------------------------------------------------------------------ SFX
  Future<void> _play(Uint8List bytes) async {
    if (!sfxOn || _disposed) return;
    try {
      await _sfx.play(BytesSource(bytes));
    } catch (_) {}
  }

  Future<void> click() => _play(_clip('click', () => _tone(1150, 0.06)));
  Future<void> slice() => _play(_clip('slice', _slice));
  Future<void> splat() => _play(_clip('splat', _splat));
  Future<void> bomb() => _play(_clip('bomb', _boom));
  Future<void> combo(int n) => _play(_clip('combo$n', () {
        // Higher combos chime higher.
        final base = 660.0 + (n.clamp(3, 8) - 3) * 90.0;
        return _arp([base, base * 1.25, base * 1.5], 0.09, 0.02);
      }));
  Future<void> strike() => _play(
      _clip('strike', () => _tone(140, 0.3, freqEnd: 90, harmonics: 0.6)));
  Future<void> countTick() => _play(_clip('tick', () => _tone(880, 0.08)));
  Future<void> countGo() => _play(_clip('go', () => _tone(1320, 0.22)));
  Future<void> gameStart() =>
      _play(_clip('start', () => _tone(420, 0.32, freqEnd: 840)));
  Future<void> gameOver() => _play(
      _clip('over', () => _arp([392.0, 329.63, 261.63, 196.0], 0.22, 0.04)));
  Future<void> newBest() => _play(_clip(
      'best', () => _arp([523.25, 659.25, 783.99, 1046.5, 1318.5], 0.14, 0.03)));
  Future<void> lifeLost() =>
      _play(_clip('life', () => _tone(330, 0.25, freqEnd: 180)));

  // ----------------------------------------------------------------- music
  /// Start (or keep) a music track. Generation-serialized: the latest request
  /// always wins; a start issued while an older one is in flight is never
  /// dropped. Re-requesting the current track just ensures it is audible.
  Future<void> _startTrack(String track, Uint8List Function() bytes) async {
    if (_disposed) return;
    final gen = ++_musicGen;
    if (_currentTrack == track && !_pausedByLifecycle) {
      // Already on this track — make sure it is actually audible.
      try {
        await _music.resume();
      } catch (_) {}
      return;
    }
    // Wait for any in-flight op, then bail if superseded meanwhile.
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (gen != _musicGen || _disposed || !musicOn) return;
    _musicBusy = true;
    try {
      await _music.stop();
      if (gen != _musicGen || _disposed || !musicOn) return;
      _currentTrack = track;
      _pausedByLifecycle = false;
      await _music.play(BytesSource(bytes()));
    } catch (_) {
      if (gen == _musicGen) _currentTrack = null;
    } finally {
      _musicBusy = false;
    }
  }

  Future<void> startMenuMusic() => _startTrack('menu', _menuBytes);
  Future<void> startGameMusic() => _startTrack('game', _gameBytes);

  /// App-scoped stop: cancels any pending start, then stops. Used only when
  /// the user turns music OFF — never on screen navigation.
  Future<void> stopMusic() async {
    ++_musicGen; // cancel any in-flight start
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (_disposed) return;
    try {
      await _music.stop();
    } catch (_) {}
    _currentTrack = null;
    _pausedByLifecycle = false;
  }

  /// App went to background / interruption: pause (not stop) so we resume
  /// exactly where it left off.
  Future<void> onAppPaused() async {
    if (_disposed || _currentTrack == null) return;
    try {
      await _music.pause();
      _pausedByLifecycle = true;
    } catch (_) {}
  }

  /// App came back: resume only if we paused it and music is still wanted.
  Future<void> onAppResumed() async {
    if (_disposed || !musicOn || !_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    try {
      await _music.resume();
    } catch (_) {
      // Resume failed (e.g. player was released) — restart the track.
      final track = _currentTrack;
      _currentTrack = null;
      if (track == 'menu') {
        await startMenuMusic();
      } else if (track == 'game') {
        await startGameMusic();
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _sfx.dispose();
      await _music.dispose();
    } catch (_) {}
  }
}
