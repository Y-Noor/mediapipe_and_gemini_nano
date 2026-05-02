import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_state.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(appStateProvider.select((s) => s.history));
    final notifier = ref.read(appStateProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF080810),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080810),
        title: const Text(
          'History',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (history.isNotEmpty)
            TextButton(
              onPressed: notifier.clearHistory,
              child: const Text(
                'Clear',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
        ],
      ),
      body: history.isEmpty
          ? const Center(
              child: Text(
                'No sentences yet.\nStart signing!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white30, fontSize: 15, height: 1.6),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _HistoryCard(
                entry: history[i],
                onSpeak: () => notifier.speakEntry(history[i]),
              ),
            ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final SentenceEntry entry;
  final VoidCallback onSpeak;

  const _HistoryCard({required this.entry, required this.onSpeak});

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(entry.timestamp);
    final signsStr = entry.tokens.map((t) => t.sign).join(' · ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
        border: Border.all(color: const Color(0x12FFFFFF), width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Signs used
          Text(
            signsStr,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF22D3A0),
              fontFamily: 'monospace',
              letterSpacing: 0.04,
            ),
          ),
          const SizedBox(height: 6),
          // Sentence
          Text(
            entry.sentence,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.white,
              fontWeight: FontWeight.w300,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                timeStr,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white24,
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onSpeak,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: const Color(0x3022D3A0), width: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded,
                          size: 12, color: Color(0xFF22D3A0)),
                      SizedBox(width: 4),
                      Text(
                        'Replay',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF22D3A0),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
