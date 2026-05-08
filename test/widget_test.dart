import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:signspeak/services/gemini_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('signspeak/gemini_nano');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('cleanSignTokens normalizes labels and removes duplicates', () {
    expect(
      GeminiService.cleanSignTokens([
        ' water ',
        'WATER',
        'thank you',
        'THANK_YOU',
        'none',
        '',
        'help-please',
      ]),
      ['WATER', 'THANK_YOU', 'HELP_PLEASE'],
    );
  });

  test('completeSentence falls back when Gemini Nano is unavailable', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isAvailable') return false;
      throw PlatformException(code: 'NANO_UNAVAILABLE');
    });

    final service = GeminiService(channel: channel);
    await service.initialize();

    expect(service.isOnDevice, isFalse);
    expect(
      await service.completeSentence(['WATER', 'WATER', 'PLEASE']),
      'Could I have some water, please?',
    );
  });

  test('completeSentence sends only cleaned tokens to Gemini Nano', () async {
    String? prompt;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isAvailable') return true;
      if (call.method == 'completeSentence') {
        prompt = (call.arguments as Map)['prompt'] as String?;
        return 'I need some water, please.';
      }
      return null;
    });

    final service = GeminiService(channel: channel);
    await service.initialize();

    final sentence = await service.completeSentence(
      ['water', 'WATER', 'please'],
    );

    expect(sentence, 'I need some water, please.');
    expect(prompt, contains('WATER PLEASE'));
    expect(prompt, isNot(contains('WATER WATER')));
    expect(service.isOnDevice, isTrue);
  });
}
