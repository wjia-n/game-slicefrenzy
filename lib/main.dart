import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'services/audio_service.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final settings = SliceSettings();
  await settings.load();
  final audio = SliceAudio();
  audio.configure(
    musicOn: settings.musicOn,
    sfxOn: settings.sfxOn,
    volume: settings.volume,
  );
  runApp(SliceFrenzyApp(settings: settings, audio: audio));
}

class SliceFrenzyApp extends StatefulWidget {
  final SliceSettings settings;
  final SliceAudio audio;
  const SliceFrenzyApp({super.key, required this.settings, required this.audio});

  @override
  State<SliceFrenzyApp> createState() => _SliceFrenzyAppState();
}

class _SliceFrenzyAppState extends State<SliceFrenzyApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.audio.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause (not stop) on interruption so music resumes exactly where it
    // left off; the game screen additionally freezes its engine.
    if (state == AppLifecycleState.paused) {
      widget.audio.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (_, _) => MaterialApp(
        title: 'Slice Frenzy',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFC0392B)),
        ),
        home: SplashScreen(audio: widget.audio, settings: widget.settings),
      ),
    );
  }
}
