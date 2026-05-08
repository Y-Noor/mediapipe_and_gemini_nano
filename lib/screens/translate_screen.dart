import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_state.dart';
import '../widgets/camera_view.dart';

class TranslateScreen extends ConsumerWidget {
  const TranslateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final notifier = ref.read(appStateProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF080810),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            _Header(
              geminiOnDevice: state.geminiOnDevice,
              autoSpeak: state.autoSpeak,
              onToggleAutoSpeak: notifier.toggleAutoSpeak,
            ),

            // ── Camera ──────────────────────────────────────────────
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: const CameraView(),
              ),
            ),

            // ── Gesture badge ───────────────────────────────────────
            _GestureBadge(
              gesture: state.currentGesture,
              confidence: state.confidence,
            ),
            const _AvailableGesturesStrip(),

            // ── Token strip ─────────────────────────────────────────
            _TokenStrip(
              tokens: state.currentTokens,
              onClear: notifier.clearTokens,
            ),

            // ── Sentence output ─────────────────────────────────────
            Expanded(
              flex: 3,
              child: _SentencePanel(
                sentence: state.currentSentence,
                isProcessing: state.isProcessing,
                onSpeak: notifier.speakCurrent,
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _AvailableGesturesStrip extends StatelessWidget {
  const _AvailableGesturesStrip();

  static const _fallback = <String>[
    'HELLO',
    'PLEASE',
    'YES',
    'NO',
    'THANK_YOU',
    'I_LOVE_YOU',
    'WATER',
    'WHAT',
    'WHERE',
    'STOP',
    'HELP',
  ];

  Future<List<String>> _loadGestures() async {
    try {
      final raw = await rootBundle.loadString('assets/models/gesture_labels.txt');
      final labels = raw
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty && e.toLowerCase() != 'none')
          .map((e) => e.toUpperCase())
          .toList();
      if (labels.isEmpty) return _fallback;
      return labels;
    } catch (_) {
      return _fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _loadGestures(),
      builder: (context, snap) {
        final gestures = snap.data ?? _fallback;
        return Container(
          height: 38,
          margin: const EdgeInsets.fromLTRB(16, 2, 16, 2),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: gestures.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0x10FFFFFF),
                border: Border.all(color: const Color(0x18FFFFFF), width: 0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                gestures[i],
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white60,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool geminiOnDevice;
  final bool autoSpeak;
  final VoidCallback onToggleAutoSpeak;

  const _Header({
    required this.geminiOnDevice,
    required this.autoSpeak,
    required this.onToggleAutoSpeak,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
      child: Row(
        children: [
          const Text(
            'Sign',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const Text(
            'Speak',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF22D3A0),
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          // On-device badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x1522D3A0),
              border: Border.all(color: const Color(0x4022D3A0), width: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22D3A0),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  geminiOnDevice ? 'On-device' : 'Fallback',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF22D3A0),
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Auto-speak toggle
          GestureDetector(
            onTap: onToggleAutoSpeak,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: autoSpeak
                    ? const Color(0x15A78BFA)
                    : const Color(0x10FFFFFF),
                border: Border.all(
                  color: autoSpeak
                      ? const Color(0x50A78BFA)
                      : const Color(0x20FFFFFF),
                  width: 0.5,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    autoSpeak ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    size: 12,
                    color: autoSpeak
                        ? const Color(0xFFA78BFA)
                        : Colors.white38,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Auto',
                    style: TextStyle(
                      fontSize: 10,
                      color: autoSpeak
                          ? const Color(0xFFA78BFA)
                          : Colors.white38,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Gesture badge ────────────────────────────────────────────────────────────

class _GestureBadge extends StatelessWidget {
  final String? gesture;
  final double confidence;

  const _GestureBadge({this.gesture, required this.confidence});

  @override
  Widget build(BuildContext context) {
    if (gesture == null) return const SizedBox(height: 32);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0x1522D3A0),
              border: Border.all(color: const Color(0x5022D3A0), width: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              gesture!,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF22D3A0),
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
                letterSpacing: 0.06,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(confidence * 100).round()}%',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white30,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Token strip ──────────────────────────────────────────────────────────────

class _TokenStrip extends StatelessWidget {
  final List<SignToken> tokens;
  final VoidCallback onClear;

  const _TokenStrip({required this.tokens, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: tokens.isEmpty
                ? const Text(
                    'Start signing...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white24,
                      fontFamily: 'monospace',
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: tokens.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) => _TokenChip(token: tokens[i]),
                  ),
          ),
          if (tokens.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.all(6),
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Colors.white30,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TokenChip extends StatelessWidget {
  final SignToken token;

  const _TokenChip({required this.token});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: token.isGemini
            ? const Color(0x15A78BFA)
            : const Color(0x10FFFFFF),
        border: Border.all(
          color: token.isGemini
              ? const Color(0x40A78BFA)
              : const Color(0x18FFFFFF),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        token.sign,
        style: TextStyle(
          fontSize: 11,
          color: token.isGemini
              ? const Color(0xFFC4B5FD)
              : Colors.white70,
          fontFamily: 'monospace',
          fontStyle:
              token.isGemini ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }
}

// ─── Sentence panel ───────────────────────────────────────────────────────────

class _SentencePanel extends StatelessWidget {
  final String sentence;
  final bool isProcessing;
  final VoidCallback onSpeak;

  const _SentencePanel({
    required this.sentence,
    required this.isProcessing,
    required this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        border: Border.all(color: const Color(0x12FFFFFF), width: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                const Text(
                  'OUTPUT',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white24,
                    fontFamily: 'monospace',
                    letterSpacing: 0.1,
                  ),
                ),
                const Spacer(),
                if (isProcessing)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Color(0xFFA78BFA),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: isProcessing && sentence.isEmpty
                  ? const Text(
                      'Completing sentence...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white24,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  : sentence.isEmpty
                      ? const Text(
                          'Your sentence will appear here',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white24,
                          ),
                        )
                      : Text(
                          sentence,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            height: 1.4,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
            ),
          ),
          if (sentence.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: onSpeak,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22D3A0),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded,
                              size: 14, color: Color(0xFF080810)),
                          SizedBox(width: 4),
                          Text(
                            'Speak',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF080810),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
