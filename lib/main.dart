import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const SliceFrenzyApp());

class SliceFrenzyApp extends StatelessWidget {
  const SliceFrenzyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      title: 'Slice Frenzy',
      tagline: 'Swipe like you mean it — fruit flies, bombs don\'t.',
      emoji: '🍉',
      slug: 'slicefrenzy',
      howToPlay:
          '• Swipe across flying fruit to slice it. Every slice scores!\n• NEVER slice a bomb — 3 strikes and you\'re toast. 💥\n• Slice 3+ fruit in one swipe for a COMBO bonus. 🔥\n• Classic: 60 seconds of chaos. Zen: 90 seconds, zero bombs.',
      playerOptions: const [1],
      supportsBots: false,
      gameBuilder: (ctx, players, cb) => SliceFrenzyScreen(players: players, callbacks: cb),
    );
  }
}
