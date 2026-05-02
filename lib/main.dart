import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models/app_state.dart';
import 'screens/translate_screen.dart';
import 'screens/history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Request camera permission before launching
  await Permission.camera.request();

  runApp(
    const ProviderScope(
      child: SignSpeakApp(),
    ),
  );
}

class SignSpeakApp extends StatelessWidget {
  const SignSpeakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SignSpeak',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080810),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF22D3A0),
          secondary: Color(0xFFA78BFA),
          surface: Color(0xFF0F0F1A),
        ),
        fontFamily: 'SF Pro Display', // Falls back to system sans
      ),
      home: const _InitWrapper(),
    );
  }
}

/// Initializes all services before showing the main UI
class _InitWrapper extends ConsumerStatefulWidget {
  const _InitWrapper();

  @override
  ConsumerState<_InitWrapper> createState() => _InitWrapperState();
}

class _InitWrapperState extends ConsumerState<_InitWrapper> {
  bool _ready = false;
  String _status = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      setState(() => _status = 'Loading MediaPipe...');
      final gestureService = ref.read(gestureServiceProvider);
      await gestureService.initialize();

      setState(() => _status = 'Loading Gemini Nano...');
      final geminiService = ref.read(geminiServiceProvider);
      await geminiService.initialize();

      // Tell state whether Gemini is on-device or fallback
      ref.read(appStateProvider.notifier).setGeminiAvailable(
            geminiService.isOnDevice,
          );

      setState(() => _status = 'Initializing TTS...');
      final ttsService = ref.read(ttsServiceProvider);
      await ttsService.initialize();

      setState(() => _ready = true);
    } catch (e) {
      setState(() => _status = 'Error: $e\nTap to retry');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Scaffold(
        backgroundColor: const Color(0xFF080810),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'SignSpeak',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF22D3A0),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF22D3A0),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _status,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white38,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const _MainShell();
  }
}

/// Bottom nav shell
class _MainShell extends StatefulWidget {
  const _MainShell();

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _index = 0;

  static const _screens = [
    TranslateScreen(),
    HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080810),
      body: _screens[_index],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0x12FFFFFF), width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          backgroundColor: const Color(0xFF080810),
          selectedItemColor: const Color(0xFF22D3A0),
          unselectedItemColor: Colors.white24,
          selectedLabelStyle: const TextStyle(
              fontSize: 10, fontFamily: 'monospace'),
          unselectedLabelStyle: const TextStyle(
              fontSize: 10, fontFamily: 'monospace'),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.sign_language_rounded),
              label: 'Translate',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              label: 'History',
            ),
          ],
        ),
      ),
    );
  }
}
