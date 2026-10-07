import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

/// Slice Frenzy — swipe to slice flying fruit, dodge the bombs. 🍉
class SliceFrenzyScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;

  const SliceFrenzyScreen({super.key, required this.players, required this.callbacks});

  @override
  State<SliceFrenzyScreen> createState() => _SliceFrenzyScreenState();
}

class _Fruit {
  Offset pos;
  Offset vel;
  double r;
  int kind; // 0 watermelon, 1 orange, 2 berry, 3 coconut, 4 bomb
  double rot;
  double rotVel;
  bool sliced = false;
  _Fruit(this.pos, this.vel, this.r, this.kind, this.rot, this.rotVel);
}

class _Half {
  Offset pos;
  Offset vel;
  double rot;
  double rotVel;
  int kind;
  bool left;
  double life = 1.0;
  _Half(this.pos, this.vel, this.rot, this.rotVel, this.kind, this.left);
}

class _Particle {
  Offset pos;
  Offset vel;
  Color color;
  double life = 1.0;
  _Particle(this.pos, this.vel, this.color);
}

class _TrailPt {
  Offset p;
  double t;
  _TrailPt(this.p, this.t);
}

class _SliceFrenzyScreenState extends State<SliceFrenzyScreen> {
  static const _bestKey = 'slicefrenzy_best';

  bool? zen; // null = choosing mode
  final _rand = Random();
  final List<_Fruit> fruits = [];
  final List<_Half> halves = [];
  final List<_Particle> parts = [];
  final List<_TrailPt> trail = [];
  Ticker? _ticker;
  double _lastSec = 0;
  double elapsed = 0;
  double _spawnAcc = 0;
  int strikes = 0;
  int swipeCount = 0;
  int comboPop = 0;
  double comboT = 0;
  double flashT = 0;
  bool over = false;
  int best = 0;
  Size _size = Size.zero;

  double get duration => zen == true ? 90 : 60;
  int get score => widget.players[0].score;

  @override
  void initState() {
    super.initState();
    _loadBest();
  }

  Future<void> _loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => best = prefs.getInt(_bestKey) ?? 0);
  }

  void _start(bool zenMode) {
    setState(() {
      zen = zenMode;
      fruits.clear();
      halves.clear();
      parts.clear();
      trail.clear();
      elapsed = 0;
      _spawnAcc = 0;
      strikes = 0;
      swipeCount = 0;
      over = false;
      widget.players[0].score = 0;
    });
    widget.callbacks.refreshHud();
    _lastSec = 0;
    _ticker?.dispose();
    _ticker = Ticker(_tick)..start();
    Sfx.click();
  }

  void _tick(Duration d) {
    final sec = d.inMicroseconds / 1e6;
    final dt = min(0.05, _lastSec == 0 ? 0.016 : sec - _lastSec);
    _lastSec = sec;
    if (over || !mounted) return;
    setState(() {
      elapsed += dt;
      if (flashT > 0) flashT -= dt;
      if (comboT > 0) comboT -= dt;
      _spawnAcc += dt;
      final interval = zen == true ? 0.85 : max(0.32, 0.75 - elapsed * 0.008);
      if (_spawnAcc >= interval) {
        _spawnAcc = 0;
        _spawn();
      }
      const g = 1500.0;
      for (final f in fruits) {
        f.pos += f.vel * dt;
        f.vel = Offset(f.vel.dx, f.vel.dy + g * dt);
        f.rot += f.rotVel * dt;
      }
      fruits.removeWhere((f) => f.sliced || f.pos.dy > _size.height + 120);
      for (final h in halves) {
        h.pos += h.vel * dt;
        h.vel = Offset(h.vel.dx, h.vel.dy + g * dt);
        h.rot += h.rotVel * dt;
        h.life -= dt * 1.4;
      }
      halves.removeWhere((h) => h.life <= 0);
      for (final p in parts) {
        p.pos += p.vel * dt;
        p.vel = Offset(p.vel.dx, p.vel.dy + g * 0.6 * dt);
        p.life -= dt * 2.2;
      }
      parts.removeWhere((p) => p.life <= 0);
      trail.removeWhere((t) => elapsed - t.t > 0.25);
      if (elapsed >= duration) {
        _gameOver('Time! ⏰');
      }
    });
  }

  void _spawn() {
    final w = _size.width;
    if (w <= 0) return;
    final isBomb = zen != true && _rand.nextDouble() < 0.14;
    final kind = isBomb ? 4 : _rand.nextInt(4);
    final x = w * 0.12 + _rand.nextDouble() * w * 0.76;
    final vx = (_rand.nextDouble() - 0.5) * 320;
    final vy = -(880 + _rand.nextDouble() * 420);
    fruits.add(_Fruit(
      Offset(x, _size.height + 70),
      Offset(vx, vy),
      isBomb ? 38 : 34 + _rand.nextDouble() * 14,
      kind,
      _rand.nextDouble() * pi * 2,
      (_rand.nextDouble() - 0.5) * 6,
    ));
  }

  void _onPan(Offset a, Offset b) {
    if (over || zen == null) return;
    trail.add(_TrailPt(b, elapsed));
    for (final f in fruits) {
      if (f.sliced) continue;
      if (_distToSeg(f.pos, a, b) < f.r + 8) _slice(f);
    }
  }

  double _distToSeg(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final t = ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / max(1, ab.distanceSquared);
    final c = t.clamp(0.0, 1.0);
    return (p - (a + ab * c)).distance;
  }

  void _slice(_Fruit f) {
    f.sliced = true;
    swipeCount++;
    if (f.kind == 4) {
      // bomb!
      strikes++;
      flashT = 0.35;
      Sfx.lose();
      for (int i = 0; i < 26; i++) {
        parts.add(_Particle(f.pos, Offset((_rand.nextDouble() - 0.5) * 700, -_rand.nextDouble() * 700), Colors.orange));
      }
      setState(() {});
      if (strikes >= 3) {
        _gameOver('Kaboom! 💥');
      }
      return;
    }
    Sfx.move();
    final juice = _fruitColor(f.kind);
    final dir = _rand.nextDouble() * pi * 2;
    halves.add(_Half(f.pos, f.vel + Offset(cos(dir) * 260, sin(dir) * 260 - 120), f.rot, 7, f.kind, true));
    halves.add(_Half(f.pos, f.vel + Offset(cos(dir + pi) * 260, sin(dir + pi) * 260 - 120), f.rot, -7, f.kind, false));
    for (int i = 0; i < 12; i++) {
      parts.add(_Particle(f.pos, Offset((_rand.nextDouble() - 0.5) * 520, -_rand.nextDouble() * 480), juice));
    }
    widget.players[0].score += 10;
    widget.callbacks.refreshHud();
  }

  void _endSwipe() {
    if (swipeCount >= 3) {
      final bonus = (swipeCount - 2) * 20;
      widget.players[0].score += bonus;
      comboPop = swipeCount;
      comboT = 1.2;
      Sfx.win();
      widget.callbacks.refreshHud();
    }
    swipeCount = 0;
  }

  Future<void> _gameOver(String reason) async {
    if (over) return;
    over = true;
    _ticker?.stop();
    final s = score;
    final isBest = s > best;
    if (isBest) {
      best = s;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_bestKey, best);
    }
    if (!mounted) return;
    widget.callbacks.finish(
      headline: '$reason You sliced $s! 🍉',
      subline: isBest ? 'NEW BEST! You absolute fruit ninja 🏆' : 'Best: $best — slice again?',
    );
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  Color _fruitColor(int kind) {
    switch (kind) {
      case 0: return const Color(0xFF3FBF5A);
      case 1: return const Color(0xFFFF9F2E);
      case 2: return const Color(0xFF9B5BD6);
      case 3: return const Color(0xFFB07B4F);
      default: return const Color(0xFF2B2B33);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.of(context).theme;
    if (zen == null) return _modeChooser(theme);
    _size = MediaQuery.of(context).size;
    final left = max(0, (duration - elapsed).ceil());
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) {
            trail.clear();
            trail.add(_TrailPt(d.localPosition, elapsed));
          },
          onPanUpdate: (d) {
            final prev = trail.isEmpty ? d.localPosition : trail.last.p;
            _onPan(prev, d.localPosition);
          },
          onPanEnd: (_) => _endSwipe(),
          child: CustomPaint(
            size: Size.infinite,
            painter: _SlicePainter(
              fruits: fruits,
              halves: halves,
              parts: parts,
              trail: trail,
              flashT: flashT,
              fruitColor: _fruitColor,
            ),
          ),
        ),
        Positioned(
          top: 8, left: 12, right: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('🍉 $score', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: theme.text)),
              Text('⏱ $left', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: theme.muted)),
              if (zen != true)
                Text('💥 ${'✖' * strikes}${'·' * (3 - strikes)}',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: theme.text)),
            ],
          ),
        ),
        if (comboT > 0)
          Center(
            child: Opacity(
              opacity: (comboT / 1.2).clamp(0.0, 1.0),
              child: Text('COMBO x$comboPop! 🔥',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: theme.accent)),
            ),
          ),
        Positioned(
          bottom: 10, left: 0, right: 0,
          child: Center(
            child: Text(zen == true ? 'zen mode — just vibes 🧘' : 'slice fast, dodge bombs!',
                style: TextStyle(color: theme.muted, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _modeChooser(GameTheme theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Pick your slice style', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: theme.text)),
            const SizedBox(height: 20),
            WajihaButton(label: 'Classic — 60s, bombs live here', emoji: '🍉', onTap: () => _start(false), primary: true),
            const SizedBox(height: 12),
            WajihaButton(label: 'Zen — 90s, zero bombs, pure chill', emoji: '🧘', onTap: () => _start(true)),
            const SizedBox(height: 16),
            Text('Best: $best', style: TextStyle(color: theme.muted, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _SlicePainter extends CustomPainter {
  final List<_Fruit> fruits;
  final List<_Half> halves;
  final List<_Particle> parts;
  final List<_TrailPt> trail;
  final double flashT;
  final Color Function(int) fruitColor;

  _SlicePainter({required this.fruits, required this.halves, required this.parts, required this.trail, required this.flashT, required this.fruitColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (flashT > 0) {
      canvas.drawRect(Offset.zero & size, Paint()..color = Colors.red.withValues(alpha: flashT * 1.4));
    }
    for (final p in parts) {
      canvas.drawCircle(p.pos, 5 * p.life.clamp(0.0, 1.0) + 1,
          Paint()..color = p.color.withValues(alpha: p.life.clamp(0.0, 1.0)));
    }
    for (final h in halves) {
      final paint = Paint()..color = fruitColor(h.kind).withValues(alpha: h.life.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(h.pos.dx, h.pos.dy);
      canvas.rotate(h.rot);
      final start = h.left ? -pi / 2 : pi / 2;
      canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: 34), start, pi, true, paint);
      canvas.restore();
    }
    for (final f in fruits) {
      _drawFruit(canvas, f);
    }
    // swipe trail
    for (int i = 1; i < trail.length; i++) {
      final a = trail[i - 1].p;
      final b = trail[i].p;
      canvas.drawLine(a, b, Paint()..color = Colors.white.withValues(alpha: 0.9)..strokeWidth = 7..strokeCap = StrokeCap.round);
    }
  }

  void _drawFruit(Canvas canvas, _Fruit f) {
    canvas.save();
    canvas.translate(f.pos.dx, f.pos.dy);
    canvas.rotate(f.rot * 0.15);
    final body = Paint()..color = fruitColor(f.kind);
    canvas.drawCircle(Offset.zero, f.r, body);
    if (f.kind == 4) {
      // bomb: fuse + spark
      canvas.drawLine(const Offset(0, -38), const Offset(14, -52), Paint()..color = Colors.brown..strokeWidth = 5);
      canvas.drawCircle(const Offset(16, -54), 7, Paint()..color = Colors.yellow);
      canvas.drawCircle(const Offset(16, -54), 3, Paint()..color = Colors.orange);
      canvas.drawCircle(const Offset(-8, -6), 9, Paint()..color = Colors.white);
      canvas.drawCircle(const Offset(8, -6), 9, Paint()..color = Colors.white);
      canvas.drawCircle(const Offset(-8, -6), 4, Paint()..color = Colors.black);
      canvas.drawCircle(const Offset(8, -6), 4, Paint()..color = Colors.black);
    } else {
      if (f.kind == 0) {
        for (int i = -1; i <= 1; i++) {
          canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: f.r * 0.72), i * 0.5 - 0.25, 0.5,
              false, Paint()..color = Colors.green.shade800..strokeWidth = 4..style = PaintingStyle.stroke);
        }
      }
      // cute face
      canvas.drawCircle(const Offset(-10, -6), 6, Paint()..color = Colors.white);
      canvas.drawCircle(const Offset(10, -6), 6, Paint()..color = Colors.white);
      canvas.drawCircle(const Offset(-10, -6), 2.8, Paint()..color = Colors.black);
      canvas.drawCircle(const Offset(10, -6), 2.8, Paint()..color = Colors.black);
      canvas.drawArc(Rect.fromCircle(center: const Offset(0, 6), radius: 10), 0.3, pi - 0.6, false,
          Paint()..color = Colors.black87..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
      // shine
      canvas.drawCircle(Offset(-f.r * 0.35, -f.r * 0.4), 6, Paint()..color = Colors.white.withValues(alpha: 0.5));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SlicePainter old) => true;
}
