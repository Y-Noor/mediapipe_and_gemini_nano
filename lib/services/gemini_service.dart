import 'package:flutter/services.dart';

class GeminiService {
  GeminiService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'signspeak/gemini_nano';
  final MethodChannel _channel;

  bool _isOnDeviceAvailable = false;
  bool _canTryOnDevice = true;

  static const String _systemPrompt =
      'You are a sign language interpreter. Convert ASL sign tokens into '
      'natural fluent English sentences. Rules: ASL omits articles and '
      'auxiliaries so you must add them. Output ONLY the final sentence, '
      'nothing else. Keep it under 15 words.\n\n'
      'Examples:\n'
      'WATER NEED → I need some water please.\n'
      'NAME MY JOHN → My name is John.\n'
      'HELP ME PLEASE → Could you please help me?\n'
      'THANK_YOU → Thank you.\n'
      'HELLO → Hello there!\n'
      'WHERE BATHROOM → Where is the bathroom?\n';

  Future<void> initialize() async {
    try {
      _isOnDeviceAvailable =
          await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on PlatformException {
      _isOnDeviceAvailable = false;
    } on MissingPluginException {
      _isOnDeviceAvailable = false;
      _canTryOnDevice = false;
    }
  }

  Future<String> completeSentence(
    List<String> tokens, {
    String language = 'English',
  }) async {
    final cleanedTokens = cleanSignTokens(tokens);
    if (cleanedTokens.isEmpty) return '';

    if (_canTryOnDevice) {
      try {
        final response = await _channel.invokeMethod<String>(
          'completeSentence',
          {'prompt': _buildPrompt(cleanedTokens, language)},
        );
        final sentence = _sanitizeSentence(response);
        if (sentence.isNotEmpty) {
          _isOnDeviceAvailable = true;
          return sentence;
        }
      } on PlatformException {
        _canTryOnDevice = false;
        _isOnDeviceAvailable = false;
      } on MissingPluginException {
        _canTryOnDevice = false;
        _isOnDeviceAvailable = false;
      }
    }
    return _ruleBased(cleanedTokens);
  }

  String _ruleBased(List<String> tokens) {
    final cleanedTokens = cleanSignTokens(tokens);
    if (cleanedTokens.isEmpty) return '';
    final lower = cleanedTokens.map((t) => t.toLowerCase()).toList();

    // Single token shortcuts
    if (cleanedTokens.length == 1) {
      const map = {
        'hello': 'Hello!',
        'thank_you': 'Thank you.',
        'yes': 'Yes.',
        'no': 'No.',
        'please': 'Please.',
        'sorry': 'I am sorry.',
        'help': 'Could you please help me?',
        'stop': 'Please stop.',
        'what': 'What?',
        'where': 'Where?',
        'water': 'I need water.',
        'food': 'I need food.',
        'i_love_you': 'I love you.',
      };
      return map[lower.first] ?? '${_wordsFromToken(lower.first)}.';
    }

    if (lower.contains('help') && lower.contains('please')) {
      return 'Could you please help me?';
    }
    if (lower.contains('water') && lower.contains('please')) {
      return 'Could I have some water, please?';
    }
    if (lower.contains('food') && lower.contains('please')) {
      return 'Could I have some food, please?';
    }
    if (lower.contains('where') && lower.contains('bathroom')) {
      return 'Where is the bathroom?';
    }
    if (lower.contains('name') && lower.contains('my')) {
      final nameIndex = lower.indexWhere((token) =>
          token != 'name' && token != 'my' && token != 'is' && token != 'i');
      if (nameIndex != -1) {
        return 'My name is ${_wordsFromToken(lower[nameIndex])}.';
      }
    }

    final hasSubject = lower.contains('i') ||
        lower.contains('my') ||
        lower.contains('you') ||
        lower.contains('we');
    final words = lower.map(_wordsFromToken).join(' ');
    return hasSubject ? '$words.' : 'I ${words.toLowerCase()}.';
  }

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  String _wordsFromToken(String token) =>
      token.split('_').where((part) => part.isNotEmpty).map(_cap).join(' ');

  void resetContext() {
    if (_isOnDeviceAvailable) {
      _channel.invokeMethod<void>('resetContext');
    }
  }

  bool get isOnDevice => _isOnDeviceAvailable;
  bool get isAvailable => _isOnDeviceAvailable;

  void dispose() {
    if (_isOnDeviceAvailable) {
      _channel.invokeMethod<void>('close');
    }
  }

  static String normalizeSign(String sign) {
    final normalized = sign
        .trim()
        .replaceAll(RegExp(r'[\s-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .toUpperCase();
    if (normalized.isEmpty || normalized == 'NONE') return '';
    return normalized;
  }

  static List<String> cleanSignTokens(Iterable<String> tokens) {
    final seen = <String>{};
    final cleaned = <String>[];
    for (final token in tokens) {
      final normalized = normalizeSign(token);
      if (normalized.isEmpty || seen.contains(normalized)) continue;
      seen.add(normalized);
      cleaned.add(normalized);
    }
    return cleaned;
  }

  String _buildPrompt(List<String> tokens, String language) {
    final outputLanguage = language.trim().isEmpty ? 'English' : language.trim();
    return '$_systemPrompt'
        'Detected sign tokens, already deduplicated: ${tokens.join(' ')}\n'
        'Write one natural sentence in $outputLanguage. '
        'Add only necessary filler words, articles, and auxiliaries.';
  }

  String _sanitizeSentence(String? response) {
    if (response == null) return '';
    final trimmed = response.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.replaceAll(RegExp(r"""^["']|["']$"""), '').trim();
  }
}
