import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/frenzy_art.dart';
import '../theme/frenzy_themes.dart';
import 'menu_screen.dart';

/// Single launch splash in two beats:
/// 1. Company moment — the official WAJIHA logo, full screen.
/// 2. Game splash — logo + name, animated loading line, "Credits: WAJIHA".
class SplashScreen extends StatefulWidget {
  final SliceAudio audio;
  final SliceSettings settings;
  const SplashScreen({super.key, required this.audio, required this.settings});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loader;
  late final AnimationController _companyFade;
  bool _showGame = false;

  @override
  void initState() {
    super.initState();
    _loader = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _companyFade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _run();
  }

  Future<void> _run() async {
    // Pre-warm audio while the splash shows, then start menu music.
    widget.audio.prewarm();
    widget.audio.startMenuMusic();
    // Beat 1: company moment.
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    // Beat 2: fade to the game splash and run the loading line.
    _companyFade.forward();
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    setState(() => _showGame = true);
    _loader.forward();
    await Future.delayed(const Duration(milliseconds: 1900));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MenuScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loader.dispose();
    _companyFade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.settings.theme;
    if (!_showGame) {
      return _CompanyMoment(fade: _companyFade);
    }
    return Scaffold(
      backgroundColor: const Color(0xFFFFF6E3),
      body: _GameSplash(theme: theme, loader: _loader),
    );
  }
}

/// Beat 1: the official WAJIHA company logo (winged W), copied unchanged
/// into assets — never redrawn or altered.
class _CompanyMoment extends StatelessWidget {
  final AnimationController fade;
  const _CompanyMoment({required this.fade});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101418),
      body: FadeTransition(
        opacity: Tween<double>(begin: 1.0, end: 0.0).animate(fade),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/wajiha_logo.png',
                width: 170,
                height: 170,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 18),
              const Text(
                'WAJIHA',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFF5F7FA),
                  letterSpacing: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Game splash: logo + name + animated loading line + "Credits: WAJIHA".
class _GameSplash extends StatelessWidget {
  final FrenzyThemeDef theme;
  final AnimationController loader;
  const _GameSplash({required this.theme, required this.loader});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [theme.skyTop, theme.skyBottom],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: theme.accent, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    offset: const Offset(0, 10),
                    blurRadius: 24,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/slice_logo.png', fit: BoxFit.cover),
            ),
            const SizedBox(height: 22),
            Text('Slice Frenzy', style: FrenzyText.display(46, theme)),
            const SizedBox(height: 6),
            Text(
              'SWIPE. SLICE. JUICE EVERYWHERE.',
              style: FrenzyText.label(13, theme),
            ),
            const SizedBox(height: 30),
            // Animated loading line.
            SizedBox(
              width: 220,
              child: AnimatedBuilder(
                animation: loader,
                builder: (_, _) => Column(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.black.withValues(alpha: 0.15),
                        border: Border.all(
                            color: theme.accent.withValues(alpha: 0.5)),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: loader.value.clamp(0.02, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: theme.accent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      loader.value < 1 ? 'Sharpening the blade…' : 'Ready!',
                      style: FrenzyText.body(13, theme).copyWith(
                          color: theme.ink.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 44),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/wajiha_logo.png',
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
                Text(
                  'Credits: WAJIHA',
                  style: FrenzyText.label(14, theme),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
