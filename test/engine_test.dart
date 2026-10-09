import 'dart:ui' show Offset;
import 'package:flutter_test/flutter_test.dart';
import 'package:slicefrenzy/engine/slice_engine.dart';
import 'package:slicefrenzy/theme/frenzy_art.dart';

FlyItem _fruit(double x, double y) => FlyItem(
      id: 1,
      kind: FruitKind.watermelon,
      x: x,
      y: y,
      vx: 0,
      vy: 0,
      angle: 0,
      spin: 0,
      radius: 0.1,
    );

void main() {
  test('countdown always reaches playing (no stuck countdown)', () async {
    final e = SliceEngine(
        mode: SliceMode.byId('classic'), difficulty: 1);
    e.start();
    expect(e.phase, SlicePhase.countdown);
    await Future.delayed(const Duration(milliseconds: 2600));
    expect(e.phase, SlicePhase.playing);
    e.dispose();
  });

  test('swipe slices fruit: score +1, halves, no silent scoring', () async {
    final e = SliceEngine(
        mode: SliceMode.byId('classic'), difficulty: 1);
    e.start();
    await Future.delayed(const Duration(milliseconds: 2600));
    e.items.add(_fruit(0.5, 0.5));
    e.sliceTrail([const Offset(0.3, 0.5), const Offset(0.7, 0.5)]);
    expect(e.score, 1);
    expect(e.items.first.sliced, isTrue);
    final types = e.drainEvents().map((ev) => ev.type).toSet();
    expect(types, contains(SliceEventType.sliced));
    expect(types, contains(SliceEventType.popup));
    e.dispose();
  });

  test('3-fruit swipe scores a combo bonus', () async {
    final e = SliceEngine(
        mode: SliceMode.byId('classic'), difficulty: 1);
    e.start();
    await Future.delayed(const Duration(milliseconds: 2600));
    e.items.addAll([_fruit(0.3, 0.5), _fruit(0.5, 0.5), _fruit(0.7, 0.5)]);
    e.sliceTrail([const Offset(0.1, 0.5), const Offset(0.9, 0.5)]);
    expect(e.score, 6); // 3 fruit + 3 combo bonus
    expect(e.bestCombo, 3);
    e.dispose();
  });

  test('bomb slice registers a strike, not a crash', () async {
    final e = SliceEngine(
        mode: SliceMode.byId('classic'), difficulty: 1);
    e.start();
    await Future.delayed(const Duration(milliseconds: 2600));
    e.items.add(FlyItem(
        id: 9,
        kind: FruitKind.bomb,
        x: 0.5,
        y: 0.5,
        vx: 0,
        vy: 0,
        angle: 0,
        spin: 0,
        radius: 0.1));
    e.sliceTrail([const Offset(0.3, 0.5), const Offset(0.7, 0.5)]);
    expect(e.strikes, 1);
    expect(e.phase, SlicePhase.playing); // still alive after 1 strike
    e.dispose();
  });

  test('pause/resume keeps the run alive', () async {
    final e = SliceEngine(
        mode: SliceMode.byId('classic'), difficulty: 1);
    e.start();
    await Future.delayed(const Duration(milliseconds: 2600));
    e.setPaused(true);
    expect(e.paused, isTrue);
    final s = e.score;
    await Future.delayed(const Duration(milliseconds: 300));
    e.setPaused(false);
    expect(e.paused, isFalse);
    expect(e.phase, SlicePhase.playing);
    expect(e.score, s);
    e.dispose();
  });

  test('timer expiry ends the run with a game-over event', () async {
    final e = SliceEngine(
        mode: SliceMode.byId('blitz'), difficulty: 1);
    e.start();
    await Future.delayed(const Duration(milliseconds: 2600));
    e.timeLeft = 0.05; // fast-forward to the end
    await Future.delayed(const Duration(milliseconds: 300));
    expect(e.phase, SlicePhase.gameover);
    final types = e.drainEvents().map((ev) => ev.type).toSet();
    expect(types, contains(SliceEventType.gameOver));
    e.dispose();
  });
}
