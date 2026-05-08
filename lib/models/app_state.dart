import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gesture_service.dart';
import '../services/gemini_service.dart';
import '../services/tts_service.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class SignToken {
  final String sign;
  final DateTime timestamp;
  final bool isGemini; // true = Gemini-generated filler word

  const SignToken({
    required this.sign,
    required this.timestamp,
    this.isGemini = false,
  });
}

class SentenceEntry {
  final List<SignToken> tokens;
  final String sentence;
  final DateTime timestamp;

  const SentenceEntry({
    required this.tokens,
    required this.sentence,
    required this.timestamp,
  });
}

// ─── Main App State ───────────────────────────────────────────────────────────

class AppStateNotifier extends StateNotifier<AppState> {
  final GestureService _gestureService;
  final GeminiService _geminiService;
  final TtsService _ttsService;

  Timer? _pauseTimer;
  String? _lastGesture;
  DateTime? _lastGestureTime;

  // How long (ms) of signing pause triggers sentence completion
  static const int _pauseThresholdMs = 2000;
  // Debounce — don't add same sign twice in a row within this window
  static const int _debouncMs = 800;

  AppStateNotifier({
    required GestureService gestureService,
    required GeminiService geminiService,
    required TtsService ttsService,
  })  : _gestureService = gestureService,
        _geminiService = geminiService,
        _ttsService = ttsService,
        super(const AppState()) {
    _gestureService.onGestureDetected = _onGesture;
  }

  void _onGesture(String gesture, double confidence) {
    final now = DateTime.now();

    // Debounce — ignore if same sign within window
    if (_lastGesture == gesture &&
        _lastGestureTime != null &&
        now.difference(_lastGestureTime!).inMilliseconds < _debouncMs) {
      return;
    }

    _lastGesture = gesture;
    _lastGestureTime = now;

    // Map placeholders to actual values
    String displayGesture = gesture;
    final lower = gesture.toLowerCase();
    if (lower == 'sign_speak') {
      displayGesture = 'SIGN SPEAK';
    } else if (lower == 'name') {
      displayGesture = 'NOOR';
    } else {
      displayGesture = gesture.toUpperCase();
    }

    // Add token to buffer
    final token = SignToken(sign: displayGesture, timestamp: now);
    state = state.copyWith(
      currentTokens: [...state.currentTokens, token],
      currentGesture: displayGesture,
      confidence: confidence,
    );

    // Reset pause timer
    _pauseTimer?.cancel();
    _pauseTimer = Timer(
      const Duration(milliseconds: _pauseThresholdMs),
      _triggerCompletion,
    );
  }

  Future<void> _triggerCompletion() async {
    if (state.currentTokens.isEmpty) return;

    final tokens = state.currentTokens.map((t) => t.sign).toList();
    state = state.copyWith(isProcessing: true);

    try {
      final sentence = await _geminiService.completeSentence(tokens, language: state.selectedLanguage);
      if (sentence.isNotEmpty) {
        final entry = SentenceEntry(
          tokens: state.currentTokens,
          sentence: sentence,
          timestamp: DateTime.now(),
        );

        state = state.copyWith(
          currentSentence: sentence,
          history: [entry, ...state.history],
          currentTokens: [],
          isProcessing: false,
        );

        // Auto-speak
        if (state.autoSpeak) {
          await _ttsService.speak(sentence);
        }
      }
    } catch (_) {
      state = state.copyWith(isProcessing: false);
    }
  }

  Future<void> speakCurrent() async {
    if (state.currentSentence.isNotEmpty) {
      await _ttsService.speak(state.currentSentence);
    }
  }

  Future<void> speakEntry(SentenceEntry entry) async {
    await _ttsService.speak(entry.sentence);
  }

  void clearTokens() {
    _pauseTimer?.cancel();
    state = state.copyWith(currentTokens: [], currentGesture: null);
  }

  void clearHistory() {
    state = state.copyWith(history: []);
  }

  void toggleAutoSpeak() {
    state = state.copyWith(autoSpeak: !state.autoSpeak);
  }

  void setLanguage(String language) {
    state = state.copyWith(selectedLanguage: language);
    _ttsService.setLanguage(language);
  }

  void setGeminiAvailable(bool v) {
    state = state.copyWith(geminiOnDevice: v);
  }

  @override
  void dispose() {
    _pauseTimer?.cancel();
    super.dispose();
  }
}

// ─── Immutable state ──────────────────────────────────────────────────────────

class AppState {
  final List<SignToken> currentTokens;
  final String currentSentence;
  final List<SentenceEntry> history;
  final String? currentGesture;
  final double confidence;
  final bool isProcessing;
  final bool autoSpeak;
  final bool geminiOnDevice;
  final String selectedLanguage;

  const AppState({
    this.currentTokens = const [],
    this.currentSentence = '',
    this.history = const [],
    this.currentGesture,
    this.confidence = 0.0,
    this.isProcessing = false,
    this.autoSpeak = true,
    this.geminiOnDevice = false,
    this.selectedLanguage = 'English',
  });

  AppState copyWith({
    List<SignToken>? currentTokens,
    String? currentSentence,
    List<SentenceEntry>? history,
    String? currentGesture,
    double? confidence,
    bool? isProcessing,
    bool? autoSpeak,
    bool? geminiOnDevice,
    String? selectedLanguage,
  }) {
    return AppState(
      currentTokens: currentTokens ?? this.currentTokens,
      currentSentence: currentSentence ?? this.currentSentence,
      history: history ?? this.history,
      currentGesture: currentGesture ?? this.currentGesture,
      confidence: confidence ?? this.confidence,
      isProcessing: isProcessing ?? this.isProcessing,
      autoSpeak: autoSpeak ?? this.autoSpeak,
      geminiOnDevice: geminiOnDevice ?? this.geminiOnDevice,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
    );
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final gestureServiceProvider = Provider((ref) => GestureService());
final geminiServiceProvider = Provider((ref) => GeminiService());
final ttsServiceProvider = Provider((ref) => TtsService());

final appStateProvider =
    StateNotifierProvider<AppStateNotifier, AppState>((ref) {
  return AppStateNotifier(
    gestureService: ref.watch(gestureServiceProvider),
    geminiService: ref.watch(geminiServiceProvider),
    ttsService: ref.watch(ttsServiceProvider),
  );
});
