import 'dart:math';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/slice_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/blade_styles.dart';
import '../theme/frenzy_art.dart';
import '../theme/frenzy_themes.dart';
import 'menu_screen.dart';

/// The play field: engine-driven canvas, swipe slicing, HUD, overlays.
class GameScreen extends StatefulWidget {
  final SliceAudio audio;
  final SliceSettings settings;
  final SliceMode mode;
  const GameScreen(
      {super.key,
      required this.audio,
      required this.settings,
      required this.mode});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _FloatingText {
  double x, y;
  final String text;
  final bool big;
  double age = 0;
  _FloatingText(
      {required this.x, required this.y, required this.text, required this.big});
}

class _TrailPoint {
  final Offset p;
  double age = 0;
  _TrailPoint(this.p);
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late SliceEngine _engine;
  final List<_FloatingText> _popups = [];
  final List<_TrailPoint> _trail = [];
  double _flash = 0; // bomb flash overlay 0..1
  double _shake = 0; // screen shake 0..1
  Offset _shakeOffset = Offset.zero;
  bool _overHandled = false;
  SliceEvent? _gameOverEvent;
  final _rand = Random();
  DateTime _lastDrain = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _newEngine();
    widget.audio.startGameMusic();
  }

  void _newEngine() {
    _engine = SliceEngine(
      mode: widget.mode,
      difficulty: widget.settings.difficulty,
      startBest: widget.settings.bestFor(widget.mode.id),
    );
    _engine.addListener(_onEngine);
    _popups.clear();
    _trail.clear();
    _flash = 0;
    _shake = 0;
    _overHandled = false;
    _gameOverEvent = null;
    _lastDrain = DateTime.now();
    _engine.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _engine.removeListener(_onEngine);
    _engine.dispose();
    widget.audio.startMenuMusic();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Freeze the engine when the app goes away mid-run.
      if (_engine.phase == SlicePhase.playing ||
          _engine.phase == SlicePhase.countdown) {
        _engine.setPaused(true);
      }
    }
  }

  void _onEngine() {
    if (!mounted) return;
    final now = DateTime.now();
    final dt = now.difference(_lastDrain).inMilliseconds / 1000.0;
    _lastDrain = now;

    // Age floating texts, trail and flash.
    for (final p in _popups) {
      p.age += dt;
      p.y -= dt * 0.12;
    }
    _popups.removeWhere((p) => p.age > 0.9);
    for (final t in _trail) {
      t.age += dt;
    }
    _trail.removeWhere((t) => t.age > 0.28);
    _flash = max(0.0, _flash - dt * 2.2);
    _shake = max(0.0, _shake - dt * 2.5);
    _shakeOffset = _shake > 0
        ? Offset((_rand.nextDouble() - 0.5) * 18 * _shake,
            (_rand.nextDouble() - 0.5) * 18 * _shake)
        : Offset.zero;

    // Drain engine events -> audio + feedback. No silent scoring.
    for (final e in _engine.drainEvents()) {
      switch (e.type) {
        case SliceEventType.sliced:
          widget.audio.slice();
          break;
        case SliceEventType.combo:
          widget.audio.combo(e.payload['n'] as int? ?? 3);
          break;
        case SliceEventType.bomb:
          widget.audio.bomb();
          _flash = 1.0;
          _shake = 1.0;
          final s = e.payload['strikes'] as int? ?? 0;
          _popups.add(_FloatingText(
              x: 0.5,
              y: 0.45,
              text: 'STRIKE $s!',
              big: true));
          break;
        case SliceEventType.miss:
          widget.audio.lifeLost();
          final l = e.payload['lives'] as int? ?? 0;
          _popups.add(_FloatingText(
              x: 0.5, y: 0.5, text: 'LIFE LOST — $l LEFT', big: true));
          break;
        case SliceEventType.countTick:
          widget.audio.countTick();
          break;
        case SliceEventType.go:
          widget.audio.countGo();
          break;
        case SliceEventType.gameOver:
          _onGameOver(e);
          break;
        case SliceEventType.popup:
          _popups.add(_FloatingText(
            x: (e.payload['x'] as num).toDouble(),
            y: (e.payload['y'] as num).toDouble(),
            text: e.payload['text'] as String? ?? '',
            big: e.payload['big'] as bool? ?? false,
          ));
          break;
      }
    }
    setState(() {});
  }

  Future<void> _onGameOver(SliceEvent e) async {
    widget.audio.gameOver();
    if (e.payload['isBest'] == true) {
      widget.audio.newBest();
    }
    _gameOverEvent = e;
    if (!_overHandled) {
      _overHandled = true;
      final score = e.payload['score'] as int? ?? 0;
      final sliced = e.payload['sliced'] as int? ?? 0;
      final combo = e.payload['combo'] as int? ?? 0;
      await widget.settings.recordGame(
        modeId: widget.mode.id,
        score: score,
        sliced: sliced,
        combo: combo,
      );
      _maybeAskReview();
    }
    setState(() {});
  }

  /// in_app_review at sensible moments: every 3rd game, never twice in a
  /// row. Graceful when not installed from Play (the call just no-ops).
  Future<void> _maybeAskReview() async {
    final g = widget.settings.gamesPlayed;
    if (g > 0 &&
        g % 3 == 0 &&
        widget.settings.reviewAskedAt < g) {
      try {
        await InAppReview.instance.requestReview();
        await widget.settings.markReviewAsked(g);
      } catch (_) {}
    }
  }

  void _share() {
    widget.audio.click();
    final score = _engine.score;
    SharePlus.instance.share(
      ShareParams(
        text:
            'I scored $score in Slice Frenzy (${widget.mode.name})! 🍉 Think you can slice better?\n$storeUrl',
        subject: 'Slice Frenzy',
      ),
    );
  }

  void _restart() {
    widget.audio.gameStart();
    _engine.removeListener(_onEngine);
    _engine.dispose();
    setState(() => _newEngine());
  }

  void _quit() {
    widget.audio.click();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.settings.theme;
    final blade = widget.settings.blade;
    final engine = _engine;
    return Scaffold(
      body: Stack(
        children: [
          Listener(
            onPointerDown: (d) => _pointer(d.localPosition, context),
            onPointerMove: (d) => _pointer(d.localPosition, context),
            onPointerUp: (_) => _trail.clear(),
            onPointerCancel: (_) => _trail.clear(),
            child: CustomPaint(
              size: Size.infinite,
              painter: _FieldPainter(
                engine: engine,
                theme: theme,
                blade: blade,
                popups: _popups,
                trail: _trail,
                flash: _flash,
                shakeOffset: _shakeOffset,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _Hud(
                  engine: engine,
                  theme: theme,
                  onPause: () {
                    widget.audio.click();
                    _engine.setPaused(true);
                  },
                ),
                const Spacer(),
              ],
            ),
          ),
          if (engine.phase == SlicePhase.countdown)
            _CountdownOverlay(n: engine.countdownN, theme: theme),
          if (engine.paused && engine.phase != SlicePhase.gameover)
            _PauseOverlay(
              theme: theme,
              onResume: () {
                widget.audio.click();
                _engine.setPaused(false);
              },
              onRestart: _restart,
              onQuit: _quit,
            ),
          if (engine.phase == SlicePhase.gameover && _gameOverEvent != null)
            _GameOverPanel(
              theme: theme,
              engine: engine,
              event: _gameOverEvent!,
              onAgain: _restart,
              onMenu: _quit,
              onShare: _share,
            ),
        ],
      ),
    );
  }

  void _pointer(Offset local, BuildContext context) {
    final size = MediaQuery.of(context).size;
    final norm = Offset(local.dx / size.width, local.dy / size.height);
    _trail.add(_TrailPoint(norm));
    if (_trail.length > 26) _trail.removeAt(0);
    if (_engine.phase == SlicePhase.playing && !_engine.paused) {
      _engine.sliceTrail([for (final t in _trail) t.p]);
    }
  }
}

// ------------------------------------------------------------------- HUD
class _Hud extends StatelessWidget {
  final SliceEngine engine;
  final FrenzyThemeDef theme;
  final VoidCallback onPause;
  const _Hud(
      {required this.engine, required this.theme, required this.onPause});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Chip(
            theme: theme,
            child: Column(
              children: [
                Text('SCORE', style: FrenzyText.label(9, theme)),
                Text('${engine.score}',
                    style: FrenzyText.display(24, theme)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: _StatusChip(engine: engine, theme: theme)),
          const SizedBox(width: 8),
          _Chip(
            theme: theme,
            child: IconButton(
              onPressed: onPause,
              icon: Icon(
                  engine.paused ? Icons.play_arrow : Icons.pause,
                  color: theme.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final FrenzyThemeDef theme;
  final Widget child;
  const _Chip({required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.card.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              offset: const Offset(0, 2),
              blurRadius: 6),
        ],
      ),
      child: child,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final SliceEngine engine;
  final FrenzyThemeDef theme;
  const _StatusChip({required this.engine, required this.theme});

  @override
  Widget build(BuildContext context) {
    final mode = engine.mode;
    Widget content;
    if (mode.durationSec > 0) {
      final frac = (engine.timeLeft / mode.durationSec).clamp(0.0, 1.0);
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${engine.timeLeft.ceil()}s',
                  style: FrenzyText.display(16, theme)),
              if (mode.strikeLimit > 0)
                Row(
                  children: List.generate(
                    mode.strikeLimit,
                    (i) => Icon(
                      i < engine.strikes
                          ? Icons.local_fire_department
                          : Icons.local_fire_department_outlined,
                      size: 18,
                      color: i < engine.strikes
                          ? const Color(0xFFD32F2F)
                          : theme.ink.withValues(alpha: 0.35),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 7,
              backgroundColor: theme.ink.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(theme.accent),
            ),
          ),
        ],
      );
    } else {
      // Endless: lives as hearts.
      content = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          mode.lives,
          (i) => Icon(
            i < engine.lives ? Icons.favorite : Icons.favorite_border,
            size: 22,
            color: i < engine.lives
                ? const Color(0xFFE53935)
                : theme.ink.withValues(alpha: 0.3),
          ),
        ),
      );
    }
    return _Chip(theme: theme, child: content);
  }
}

// -------------------------------------------------------------- overlays
class _CountdownOverlay extends StatelessWidget {
  final int n;
  final FrenzyThemeDef theme;
  const _CountdownOverlay({required this.n, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('$n',
          style: FrenzyText.display(120, theme).copyWith(
              color: theme.accent,
              shadows: [
                Shadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    offset: const Offset(0, 6),
                    blurRadius: 12),
              ])),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  final FrenzyThemeDef theme;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;
  const _PauseOverlay(
      {required this.theme,
      required this.onResume,
      required this.onRestart,
      required this.onQuit});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.card,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Paused', style: FrenzyText.display(34, theme)),
              const SizedBox(height: 6),
              Text('The fruit can wait.',
                  style: FrenzyText.body(14, theme)),
              const SizedBox(height: 20),
              _OverlayButton(
                  theme: theme,
                  label: 'Resume',
                  icon: Icons.play_arrow,
                  onTap: onResume),
              const SizedBox(height: 10),
              _OverlayButton(
                  theme: theme,
                  label: 'Restart',
                  icon: Icons.refresh,
                  onTap: onRestart,
                  filled: false),
              const SizedBox(height: 10),
              _OverlayButton(
                  theme: theme,
                  label: 'Quit to menu',
                  icon: Icons.home,
                  onTap: onQuit,
                  filled: false),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameOverPanel extends StatelessWidget {
  final FrenzyThemeDef theme;
  final SliceEngine engine;
  final SliceEvent event;
  final VoidCallback onAgain;
  final VoidCallback onMenu;
  final VoidCallback onShare;
  const _GameOverPanel({
    required this.theme,
    required this.engine,
    required this.event,
    required this.onAgain,
    required this.onMenu,
    required this.onShare,
  });

  String get _title {
    switch (GameOverReason.values[event.payload['reason'] as int? ?? 0]) {
      case GameOverReason.time:
        return "Time's up!";
      case GameOverReason.strikes:
        return 'Boom! Too many strikes';
      case GameOverReason.bomb:
        return 'BOOM! Bomb sliced!';
      case GameOverReason.lives:
        return 'Out of lives!';
    }
  }

  @override
  Widget build(BuildContext context) {
    final score = event.payload['score'] as int? ?? 0;
    final sliced = event.payload['sliced'] as int? ?? 0;
    final combo = event.payload['combo'] as int? ?? 0;
    final isBest = event.payload['isBest'] == true;
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(28),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.card,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  offset: const Offset(0, 12),
                  blurRadius: 28),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_title,
                  style: FrenzyText.display(26, theme),
                  textAlign: TextAlign.center),
              if (isBest) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('NEW BEST!',
                      style: FrenzyText.onAccent(14, theme)),
                ),
              ],
              const SizedBox(height: 12),
              Text('$score', style: FrenzyText.display(64, theme)),
              Text('sliced $sliced fruit · best combo x$combo',
                  style: FrenzyText.body(13, theme).copyWith(
                      color: theme.ink.withValues(alpha: 0.65))),
              const SizedBox(height: 20),
              _OverlayButton(
                  theme: theme,
                  label: 'Slice again',
                  icon: Icons.refresh,
                  onTap: onAgain),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: _OverlayButton(
                          theme: theme,
                          label: 'Menu',
                          icon: Icons.home,
                          onTap: onMenu,
                          filled: false)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _OverlayButton(
                          theme: theme,
                          label: 'Share',
                          icon: Icons.share,
                          onTap: onShare,
                          filled: false)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  final FrenzyThemeDef theme;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  const _OverlayButton({
    required this.theme,
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: filled ? theme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: filled
              ? null
              : Border.all(color: theme.ink.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: filled ? theme.accentInk : theme.ink, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: filled
                    ? FrenzyText.onAccent(16, theme)
                    : FrenzyText.label(16, theme)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- painter
class _FieldPainter extends CustomPainter {
  final SliceEngine engine;
  final FrenzyThemeDef theme;
  final BladeStyle blade;
  final List<_FloatingText> popups;
  final List<_TrailPoint> trail;
  final double flash;
  final Offset shakeOffset;

  _FieldPainter({
    required this.engine,
    required this.theme,
    required this.blade,
    required this.popups,
    required this.trail,
    required this.flash,
    required this.shakeOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(shakeOffset.dx, shakeOffset.dy);

    // Sky.
    final sky = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [theme.skyTop, theme.skyBottom],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    // Wooden crate along the bottom.
    final crateH = size.height * 0.13;
    final crateTop = size.height - crateH;
    final cratePaint = Paint()..color = theme.crate;
    canvas.drawRect(Rect.fromLTWH(0, crateTop, size.width, crateH), cratePaint);
    // Plank lines.
    final plank = Paint()
      ..color = theme.crateDark
      ..strokeWidth = 3;
    for (int i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, crateTop), Offset(x, size.height), plank);
    }
    canvas.drawRect(
        Rect.fromLTWH(0, crateTop, size.width, 6),
        Paint()..color = theme.crateDark);

    // Juice particles (behind fruit).
    for (final p in engine.particles) {
      final look = FruitLooks.all[p.kind]!;
      final a = (1 - p.age / p.life).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size * a,
        Paint()..color = look.juice.withValues(alpha: 0.85 * a),
      );
    }

    // Items.
    for (final it in engine.items) {
      _drawItem(canvas, size, it);
    }

    // Swipe trail (blade).
    if (trail.length > 1) {
      for (int i = 1; i < trail.length; i++) {
        final a = trail[i - 1];
        final b = trail[i];
        final alpha = (1 - b.age / 0.28).clamp(0.0, 1.0);
        final wScale = size.width / 400;
        // Outer stroke.
        canvas.drawLine(
          Offset(a.p.dx * size.width, a.p.dy * size.height),
          Offset(b.p.dx * size.width, b.p.dy * size.height),
          Paint()
            ..color = blade.color.withValues(alpha: 0.75 * alpha)
            ..strokeWidth = blade.width * wScale
            ..strokeCap = StrokeCap.round,
        );
        // Bright core.
        canvas.drawLine(
          Offset(a.p.dx * size.width, a.p.dy * size.height),
          Offset(b.p.dx * size.width, b.p.dy * size.height),
          Paint()
            ..color = blade.edge.withValues(alpha: 0.9 * alpha)
            ..strokeWidth = blade.width * wScale * 0.45
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // Floating score popups.
    for (final p in popups) {
      final a = (1 - p.age / 0.9).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: p.text,
          style: TextStyle(
            fontSize: p.big ? 30 : 20,
            fontWeight: FontWeight.w900,
            color: (p.big ? theme.accent : theme.ink)
                .withValues(alpha: a),
            shadows: [
              Shadow(
                  color: Colors.black.withValues(alpha: 0.3 * a),
                  offset: const Offset(0, 2),
                  blurRadius: 4),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas,
          Offset(p.x * size.width - tp.width / 2,
              p.y * size.height - tp.height / 2));
    }

    // Bomb flash.
    if (flash > 0) {
      canvas.drawRect(
          Offset.zero & size,
          Paint()
            ..color = const Color(0xFFFF3D00).withValues(alpha: 0.35 * flash));
    }
    canvas.restore();
  }

  void _drawItem(Canvas canvas, Size size, FlyItem it) {
    final look = FruitLooks.all[it.kind]!;
    final c = Offset(it.x * size.width, it.y * size.height);
    final r = it.radius * size.width;

    if (!it.sliced) {
      _drawWhole(canvas, c, r, it.angle, it.kind, look);
      return;
    }
    if (it.slicedAge > 0.7) return;
    final a = (1 - it.slicedAge / 0.7).clamp(0.0, 1.0);
    // Two halves drift apart.
    _drawHalf(
        canvas,
        Offset((it.x + it.h1x) * size.width, (it.y + it.h1y) * size.height),
        r,
        it.angle + it.h1a,
        look,
        true,
        a);
    _drawHalf(
        canvas,
        Offset((it.x + it.h2x) * size.width, (it.y + it.h2y) * size.height),
        r,
        it.angle + it.h2a,
        look,
        false,
        a);
  }

  void _drawWhole(
      Canvas canvas, Offset c, double r, double angle, FruitKind kind, FruitLook look) {
    // Soft drop shadow.
    canvas.drawCircle(
        c + Offset(r * 0.15, r * 0.25),
        r * 0.95,
        Paint()..color = Colors.black.withValues(alpha: 0.18));
    if (kind == FruitKind.bomb) {
      // Bomb body.
      canvas.drawCircle(c, r, Paint()..color = look.rind);
      canvas.drawCircle(c, r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.12
            ..color = look.rindDark);
      // Glossy highlight.
      canvas.drawArc(
          Rect.fromCircle(center: c, radius: r * 0.62),
          -2.4,
          1.1,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.14
            ..strokeCap = StrokeCap.round
            ..color = Colors.white.withValues(alpha: 0.5));
      // Fuse + spark.
      final fuseEnd = c + Offset(r * 0.3, -r * 1.15);
      canvas.drawLine(c + Offset(0, -r * 0.8), fuseEnd,
          Paint()
            ..color = const Color(0xFF8D6E63)
            ..strokeWidth = r * 0.12
            ..strokeCap = StrokeCap.round);
      canvas.drawCircle(
          fuseEnd, r * 0.22, Paint()..color = const Color(0xFFFFC107));
      canvas.drawCircle(fuseEnd, r * 0.11,
          Paint()..color = const Color(0xFFFFF176));
      // Skull-ish warning dot.
      canvas.drawCircle(c + Offset(0, r * 0.1), r * 0.16,
          Paint()..color = const Color(0xFFFF5252));
      return;
    }
    // Rind.
    canvas.drawCircle(c, r, Paint()..color = look.rind);
    if (look.striped) {
      // Watermelon stripes.
      for (int i = -1; i <= 1; i++) {
        canvas.drawArc(
            Rect.fromCircle(center: c, radius: r * 0.82),
            angle + i * 0.7 - 0.25,
            0.5,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = r * 0.16
              ..strokeCap = StrokeCap.round
              ..color = look.rindDark);
      }
    }
    // Rim + gloss.
    canvas.drawCircle(c, r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.1
          ..color = look.rindDark);
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r * 0.68),
        -2.5,
        1.2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.13
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.55));
  }

  void _drawHalf(Canvas canvas, Offset c, double r, double angle,
      FruitLook look, bool left, double alpha) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle + (left ? -0.5 : 0.5));
    final rect = Rect.fromCircle(center: Offset.zero, radius: r);
    // Flesh half-disc.
    final path = Path()
      ..moveTo(0, 0)
      ..arcTo(rect, left ? pi / 2 : -pi / 2, pi, false)
      ..close();
    canvas.drawPath(
        path, Paint()..color = look.flesh.withValues(alpha: alpha));
    // Rind rim along the curved edge.
    canvas.drawArc(
        rect,
        left ? pi / 2 : -pi / 2,
        pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.22
          ..strokeCap = StrokeCap.round
          ..color = look.rind.withValues(alpha: alpha));
    // Seeds.
    final seedPaint = Paint()..color = look.seed.withValues(alpha: alpha);
    for (final o in [Offset(-r * 0.35, 0), Offset(r * 0.1, -r * 0.15), Offset(r * 0.05, r * 0.3)]) {
      canvas.drawCircle(o, r * 0.09, seedPaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FieldPainter old) => true;
}
