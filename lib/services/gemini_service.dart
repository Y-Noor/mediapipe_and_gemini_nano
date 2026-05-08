import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  GenerativeModel? _model;
  ChatSession? _chat;
  bool _isAvailable = false;

  // ── PASTE YOUR FREE API KEY FROM https://aistudio.google.com ──
  static const String _apiKey = 'YOUR_API_KEY_HERE';

  static const String _systemPrompt =
      'You are a sign language interpreter. Convert ASL sign tokens into '
      'natural fluent English sentences. Rules: ASL omits articles and '
      'auxiliaries so you must add them. Output ONLY the final sentence, '
      'nothing else. Keep it under 15 words.\nRemove duplicates from the'
      'tokens before generating the sentence.\n\n'
      'Examples:\n'
      'WATER NEED → I need some water please.\n'
      'NAME MY JOHN → My name is John.\n'
      'HELP ME PLEASE → Could you please help me?\n'
      'THANK_YOU → Thank you.\n'
      'HELLO → Hello there!\n'
      'WHERE BATHROOM → Where is the bathroom?\n'

  Future<void> initialize() async {
    if (_apiKey == 'YOUR_API_KEY_HERE') {
      // No key set — use rule-based fallback only
      _isAvailable = false;
      return;
    }
    try {
      _model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
        systemInstruction: Content.system(_systemPrompt),
        generationConfig: GenerationConfig(
          maxOutputTokens: 50,
          temperature: 0.3,
        ),
      );
      _chat = _model!.startChat();
      _isAvailable = true;
    } catch (_) {
      _isAvailable = false;
    }
  }

  Future<String> completeSentence(List<String> tokens, {String language = 'English'}) async {
    if (tokens.isEmpty) return '';
    
    var input = tokens.join(' ');
    if (language != 'English') {
      input = '$input (Translate output to $language)';
    }

    if (_isAvailable && _chat != null) {
      try {
        final response = await _chat!.sendMessage(Content.text(input));
        return response.text?.trim() ?? _ruleBased(tokens);
      } catch (_) {
        return _ruleBased(tokens);
      }
    }
    return _ruleBased(tokens);
  }

  String _ruleBased(List<String> tokens) {
    if (tokens.isEmpty) return '';
    final lower = tokens.map((t) => t.toLowerCase()).toList();

    // Single token shortcuts
    if (tokens.length == 1) {
      const map = {
        'hello': 'Hello!',
        'thank_you': 'Thank you.',
        'yes': 'Yes.',
        'no': 'No.',
        'please': 'Please.',
        'sorry': 'I am sorry.',
        'help': 'I need help.',
        'stop': 'Please stop.',
        'what': 'What?',
        'where': 'Where?',
        'water': 'I need water.',
        'food': 'I need food.',
        'i_love_you': 'I love you.',
      };
      return map[lower.first] ?? '${_cap(lower.first)}.';
    }

    final hasSubject = lower.contains('i') || lower.contains('my') ||
        lower.contains('you') || lower.contains('we');
    final words = lower.map(_cap).join(' ');
    return hasSubject ? '$words.' : 'I ${words.toLowerCase()}.';
  }

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  void resetContext() {
    _chat = _model?.startChat();
  }

  bool get isOnDevice => false; // Gemini Flash is cloud; AICore TBD
  bool get isAvailable => _isAvailable;

  void dispose() {
    _model = null;
    _chat = null;
  }
}
