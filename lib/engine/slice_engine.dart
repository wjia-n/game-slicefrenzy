import 'dart:async';
import 'dart:math';
import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart';
import '../theme/frenzy_art.dart';

/// Engine-owned phases. The engine (never UI timers) owns all phase
/// transitions; a watchdog recovers any phase found without a live driver.
enum SlicePhase { idle, countdown, playing, gameover }

/// Game over reasons — always explicit, never silent.
enum GameOverReason { time, strikes, bomb, lives }

/// Game modes. See RULES.md §2/§8.
@immutable
class SliceMode {
  final String id;
  final String name;
  final String blurb;
  final int durationSec; // 0 = untimed (endless)
  final bool bombs;
  final int strikeLimit; // classic/blitz
  final int lives; // endless
  final bool isPro;

  const SliceMode({
    required this.id,
    required this.name,
    required this.blurb,
    required this.durationSec,
    required this.bombs,
    required this.strikeLimit,
    required this.lives,
    this.isPro = false,
  });

  static const List<SliceMode> all = [
    SliceMode(
      id: 'classic',
      name: 'Classic',
      blurb: '60 seconds. Bombs live here — 3 strikes and you\'re out.',
      durationSec: 60,
      bombs: true,
      strikeLimit: 3,
      lives: 0,
    ),
    SliceMode(
      id: 'zen',
      name: 'Zen',
      blurb: '90 seconds. No bombs. Pure, juicy flow.',
      durationSec: 90,
      bombs: false,
      strikeLimit: 0,
      lives: 0,
    ),
    SliceMode(
      id: 'blitz',
      name: 'Blitz',
      blurb: '30 seconds. Double-speed chaos — how much can you slice?',
      durationSec: 30,
      bombs: true,
      strikeLimit: 3,
      lives: 0,
    ),
    SliceMode(
      id: 'endless',
      name: 'Endless',
      blurb: 'No clock. 3 lives — drop a fruit, lose one. One bomb ends it all.',
      durationSec: 0,
      bombs: true,
      strikeLimit: 0,
      lives: 3,
      isPro: true,
    ),
  ];

  static SliceMode byId(String id) {
    for (final m in all) {
      if (m.id == id) return m;
    }
    return all[0];
  }
}

/// Difficulty tiers: clear progression in speed + complexity.
class SliceDifficulty {
  final double spawnInterval; // seconds between spawns
  final double bombChance;
  final double speed; // velocity multiplier
  final double volleyChance; // chance to launch 2-3 at once

  const SliceDifficulty({
    required this.spawnInterval,
    required this.bombChance,
    required this.speed,
    required this.volleyChance,
  });

  static const List<SliceDifficulty> tiers = [
    SliceDifficulty(
        spawnInterval: 1.15, bombChance: 0.07, speed: 0.85, volleyChance: 0.0),
    SliceDifficulty(
        spawnInterval: 0.85, bombChance: 0.14, speed: 1.15, volleyChance: 0.12),
    SliceDifficulty(
        spawnInterval: 0.60, bombChance: 0.20, speed: 1.45, volleyChance: 0.35),
  ];

  static const names = ['Easy', 'Normal', 'Hard'];
}

/// A flying (or sliced) item. Coordinates are normalized 0..1 (y=1 is bottom).
class FlyItem {
  final int id;
  final FruitKind kind;
  double x, y, vx, vy, angle, spin;
  final double radius;
  bool sliced = false;
  double slicedAge = 0; // seconds since sliced
  // Half separation animation: each half drifts with its own velocity.
  double h1x = 0, h1y = 0, h1vx = 0, h1vy = 0, h1a = 0;
  double h2x = 0, h2y = 0, h2vx = 0, h2vy = 0, h2a = 0;
  bool counted = false; // miss already registered

  FlyItem({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.angle,
    required this.spin,
    required this.radius,
  });
}

/// A juice droplet particle from a slice.
class JuiceParticle {
  double x, y, vx, vy, age, life;
  final double size;
  final FruitKind kind;
  JuiceParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.size,
    required this.kind,
  }) : age = 0;
}

/// Events the UI drains each frame to drive audio + floating feedback.
/// Every scoring action emits an event — no silent scoring.
enum SliceEventType {
  sliced, // a fruit was sliced (payload: kind, x, y, comboCount)
  combo, // 3+ fruit in one swipe (payload: comboCount)
  bomb, // bomb sliced (payload: strikesUsed, gameOver)
  miss, // fruit fell unsliced in endless (payload: livesLeft)
  countTick, // countdown number (payload: n)
  go,
  gameOver, // (payload: reason, score, isBest)
  popup, // floating text (payload: x, y, text, big)
}

class SliceEvent {
  final SliceEventType type;
  final Map<String, dynamic> payload;
  SliceEvent(this.type, [this.payload = const {}]);
}

/// Slice Frenzy engine: owns ALL state, phases and transitions.
/// UI renders and forwards swipes; it never drives the game clock.
///
/// Stuck states are impossible by construction:
/// - One internal tick timer drives physics, spawning, countdown and timer.
/// - A watchdog (2s) restarts the tick if it ever dies mid-phase and
///   re-emits any missing terminal event.
/// - Pause freezes everything; resume re-arms the current phase.
class SliceEngine extends ChangeNotifier {
  final SliceMode mode;
  final int difficulty; // 0 easy, 1 normal, 2 hard
  final int startBest; // best score for this mode, for new-best detection

  SlicePhase phase = SlicePhase.idle;
  bool paused = false;

  final List<FlyItem> items = [];
  final List<JuiceParticle> particles = [];

  int score = 0;
  int slicedCount = 0;
  int bestCombo = 0;
  int strikes = 0;
  int lives = 0;
  double timeLeft = 0;
  int countdownN = 3;
  double _countdownLeft = 0;

  GameOverReason? overReason;
  bool isBest = false;

  final List<SliceEvent> _events = [];
  final _rand = Random();
  int _nextId = 1;
  double _spawnAcc = 0;
  bool _gameOverEmitted = false;
  bool _disposed = false;

  Timer? _tick;
  Timer? _watchdog;

  SliceDifficulty get _diff =>
      SliceDifficulty.tiers[difficulty.clamp(0, 2)];

  static const _fruitPool = [
    FruitKind.watermelon,
    FruitKind.orange,
    FruitKind.apple,
    FruitKind.kiwi,
    FruitKind.lemon,
    FruitKind.plum,
    FruitKind.coconut,
  ];

  SliceEngine({
    required this.mode,
    required this.difficulty,
    this.startBest = 0,
  }) {
    lives = mode.lives;
    timeLeft = mode.durationSec.toDouble();
    _watchdog = Timer.periodic(const Duration(seconds: 2), (_) => _recover());
  }

  @override
  void dispose() {
    _disposed = true;
    _tick?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  /// Drain events since the last call. UI calls this in its engine listener.
  List<SliceEvent> drainEvents() {
    if (_events.isEmpty) return const [];
    final out = List<SliceEvent>.of(_events);
    _events.clear();
    return out;
  }

  // ------------------------------------------------------------ lifecycle
  /// Start a run: idle -> countdown -> playing. Safe to call once.
  void start() {
    if (_disposed || phase != SlicePhase.idle) return;
    phase = SlicePhase.countdown;
    countdownN = 3;
    _countdownLeft = 0.75;
    _events.add(SliceEvent(SliceEventType.countTick, {'n': 3}));
    _startTick();
    notifyListeners();
  }

  void _startTick() {
    if (_disposed || paused) return;
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 16), (_) => _step());
  }

  /// Pause: freeze the tick timer. Resume re-arms the current phase.
  void setPaused(bool v) {
    if (paused == v || _disposed) return;
    paused = v;
    if (v) {
      _tick?.cancel();
      _tick = null;
    } else {
      _recover(); // re-arm the current phase
    }
    notifyListeners();
  }

  /// Watchdog: the tick must be alive in countdown/playing; the game-over
  /// event must exist in gameover. Recovers anything that died silently.
  void _recover() {
    if (_disposed || paused) return;
    final tickAlive = _tick != null && _tick!.isActive;
    if ((phase == SlicePhase.countdown || phase == SlicePhase.playing) &&
        !tickAlive) {
      _startTick();
    }
    if (phase == SlicePhase.gameover && !_gameOverEmitted) {
      _emitGameOver();
    }
    // A countdown that somehow has no time left but never advanced.
    if (phase == SlicePhase.countdown && _countdownLeft <= 0) {
      _advanceCountdown();
    }
  }

  // ----------------------------------------------------------------- step
  void _step() {
    if (_disposed || paused) return;
    const dt = 1 / 60;

    if (phase == SlicePhase.countdown) {
      _countdownLeft -= dt;
      if (_countdownLeft <= 0) _advanceCountdown();
      notifyListeners();
      return;
    }
    if (phase != SlicePhase.playing) return;

    // Clock.
    if (mode.durationSec > 0) {
      timeLeft -= dt;
      if (timeLeft <= 0) {
        timeLeft = 0;
        _finish(GameOverReason.time);
        notifyListeners();
        return;
      }
    }

    // Spawning.
    _spawnAcc += dt;
    var interval = _diff.spawnInterval;
    // Endless ramps up over time: faster as you survive.
    if (mode.id == 'endless') {
      interval = (_diff.spawnInterval * (1 - (slicedCount / 400).clamp(0.0, 0.45)))
          .clamp(0.35, _diff.spawnInterval);
    }
    if (_spawnAcc >= interval) {
      _spawnAcc = 0;
      _spawnVolley();
    }

    // Physics.
    const g = 1.9;
    for (final it in items) {
      if (!it.sliced) {
        it.vy += g * dt;
        it.x += it.vx * dt;
        it.y += it.vy * dt;
        it.angle += it.spin * dt;
        if (it.y > 1.18 && !it.counted) {
          it.counted = true;
          _onMiss(it);
        }
      } else {
        it.slicedAge += dt;
        for (final half in [0, 1]) {
          final hx = half == 0;
          if (hx) {
            it.h1vy += g * dt;
            it.h1x += it.h1vx * dt;
            it.h1y += it.h1vy * dt;
            it.h1a += it.spin * 2 * dt;
          } else {
            it.h2vy += g * dt;
            it.h2x += it.h2vx * dt;
            it.h2y += it.h2vy * dt;
            it.h2a += it.spin * 2 * dt;
          }
        }
      }
    }
    items.removeWhere((it) =>
        (it.sliced && it.slicedAge > 0.7) ||
        (it.counted && it.y > 1.3) ||
        it.x < -0.3 ||
        it.x > 1.3);

    // Particles.
    for (final p in particles) {
      p.age += dt;
      p.vy += g * 0.8 * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
    }
    particles.removeWhere((p) => p.age > p.life);

    notifyListeners();
  }

  void _advanceCountdown() {
    countdownN--;
    if (countdownN > 0) {
      _countdownLeft = 0.75;
      _events.add(SliceEvent(SliceEventType.countTick, {'n': countdownN}));
    } else {
      phase = SlicePhase.playing;
      _events.add(SliceEvent(SliceEventType.go));
    }
  }

  void _spawnVolley() {
    final r = _rand.nextDouble();
    final n = r < _diff.volleyChance ? (2 + _rand.nextInt(2)) : 1;
    for (int i = 0; i < n; i++) {
      _spawnOne();
    }
  }

  void _spawnOne() {
    final isBomb =
        mode.bombs && _rand.nextDouble() < _diff.bombChance * (mode.id == 'blitz' ? 1.4 : 1.0);
    final kind = isBomb
        ? FruitKind.bomb
        : _fruitPool[_rand.nextInt(_fruitPool.length)];
    final look = FruitLooks.all[kind]!;
    final speed = _diff.speed * (0.9 + _rand.nextDouble() * 0.25);
    items.add(FlyItem(
      id: _nextId++,
      kind: kind,
      x: 0.12 + _rand.nextDouble() * 0.76,
      y: 1.08,
      vx: (_rand.nextDouble() - 0.5) * 0.5,
      vy: -1.45 * speed,
      angle: _rand.nextDouble() * 6.28,
      spin: (_rand.nextDouble() - 0.5) * 6,
      radius: 0.055 * look.radius,
    ));
  }

  // ---------------------------------------------------------------- swipe
  /// Test a swipe trail (normalized points) against whole items.
  /// Slices are atomic per call; combos count fruit sliced in ONE swipe.
  void sliceTrail(List<Offset> pts) {
    if (_disposed || paused || phase != SlicePhase.playing || pts.length < 2) {
      return;
    }
    final hit = <FlyItem>[];
    for (int s = 0; s < pts.length - 1; s++) {
      final a = pts[s];
      final b = pts[s + 1];
      for (final it in items) {
        if (it.sliced) continue;
        if (hit.contains(it)) continue;
        if (_segDist(a, b, Offset(it.x, it.y)) < it.radius) {
          hit.add(it);
        }
      }
    }
    if (hit.isEmpty) return;

    var fruitThisSwipe = 0;
    for (final it in hit) {
      if (it.kind == FruitKind.bomb) {
        _sliceBomb(it);
      } else {
        _sliceFruit(it);
        fruitThisSwipe++;
      }
    }
    if (fruitThisSwipe >= 3) {
      // Combo: bonus points equal to the combo size, announced loudly.
      score += fruitThisSwipe;
      bestCombo = max(bestCombo, fruitThisSwipe);
      final cx = hit.map((e) => e.x).reduce((a, b) => a + b) / hit.length;
      final cy = hit.map((e) => e.y).reduce((a, b) => a + b) / hit.length;
      _events.add(SliceEvent(SliceEventType.combo, {'n': fruitThisSwipe}));
      _events.add(SliceEvent(SliceEventType.popup, {
        'x': cx,
        'y': cy,
        'text': 'COMBO x$fruitThisSwipe! +$fruitThisSwipe',
        'big': true,
      }));
    }
    notifyListeners();
  }

  double _segDist(Offset a, Offset b, Offset p) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final len2 = dx * dx + dy * dy;
    double t = len2 == 0 ? 0 : ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / len2;
    t = t.clamp(0.0, 1.0);
    final cx = a.dx + t * dx;
    final cy = a.dy + t * dy;
    return sqrt((p.dx - cx) * (p.dx - cx) + (p.dy - cy) * (p.dy - cy));
  }

  void _sliceFruit(FlyItem it) {
    it.sliced = true;
    it.slicedAge = 0;
    // Halves fly apart perpendicular-ish to motion.
    final kick = 0.35 + _rand.nextDouble() * 0.25;
    it.h1vx = it.vx - kick;
    it.h1vy = it.vy - 0.4;
    it.h2vx = it.vx + kick;
    it.h2vy = it.vy - 0.4;
    score += 1;
    slicedCount++;
    // Juice splash particles (tinted by the fruit kind they carry).
    for (int i = 0; i < 7; i++) {
      final a = _rand.nextDouble() * 6.28;
      final sp = 0.25 + _rand.nextDouble() * 0.5;
      particles.add(JuiceParticle(
        x: it.x,
        y: it.y,
        vx: cos(a) * sp,
        vy: sin(a) * sp - 0.25,
        life: 0.45 + _rand.nextDouble() * 0.25,
        size: 2.5 + _rand.nextDouble() * 3.5,
        kind: it.kind,
      ));
    }
    _events.add(SliceEvent(SliceEventType.sliced, {
      'kind': it.kind.index,
      'x': it.x,
      'y': it.y,
    }));
    _events.add(SliceEvent(SliceEventType.popup, {
      'x': it.x,
      'y': it.y - 0.03,
      'text': '+1',
      'big': false,
    }));
  }

  void _sliceBomb(FlyItem it) {
    it.sliced = true;
    it.slicedAge = 99; // bomb vanishes instantly (explosion flash instead)
    if (mode.id == 'endless' || mode.strikeLimit == 0) {
      _events.add(SliceEvent(SliceEventType.bomb,
          {'strikes': strikes, 'gameOver': true}));
      _finish(GameOverReason.bomb);
    } else {
      strikes++;
      final dead = strikes >= mode.strikeLimit;
      _events.add(SliceEvent(SliceEventType.bomb,
          {'strikes': strikes, 'gameOver': dead}));
      if (dead) {
        _finish(GameOverReason.strikes);
      }
    }
  }

  void _onMiss(FlyItem it) {
    if (it.kind == FruitKind.bomb || it.sliced) return; // bombs just fall
    if (mode.id == 'endless') {
      lives--;
      _events.add(SliceEvent(SliceEventType.miss, {'lives': lives}));
      if (lives <= 0) {
        _finish(GameOverReason.lives);
      }
    }
    // Timed modes: misses cost nothing — the clock is the pressure.
  }

  // -------------------------------------------------------------- finish
  void _finish(GameOverReason reason) {
    if (phase == SlicePhase.gameover) return;
    phase = SlicePhase.gameover;
    overReason = reason;
    isBest = score > startBest;
    _tick?.cancel();
    _tick = null;
    _emitGameOver();
  }

  void _emitGameOver() {
    if (_gameOverEmitted) return;
    _gameOverEmitted = true;
    _events.add(SliceEvent(SliceEventType.gameOver, {
      'reason': overReason?.index ?? 0,
      'score': score,
      'isBest': isBest,
      'sliced': slicedCount,
      'combo': bestCombo,
    }));
  }

  /// Quit to menu mid-run. Engine settles to gameover with reason 'time'
  /// semantics only if a run was live — otherwise it just idles.
  void quit() {
    _tick?.cancel();
    _tick = null;
    phase = SlicePhase.idle;
    items.clear();
    particles.clear();
    notifyListeners();
  }
}
