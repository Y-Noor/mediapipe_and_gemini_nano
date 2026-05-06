import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

/// Runs the exported TFLite MLP classifier on up to 2 hands' landmarks.
/// Input: 126 features (2 hands x 21 landmarks x xyz), missing hand = zeros.
class TfliteGestureClassifier {
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isLoaded = false;

  static const double _confidenceThreshold = 0.75;

  Future<void> initialize() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/gesture_classifier.tflite',
        options: InterpreterOptions()..threads = 2,
      );
      final labelData = await rootBundle.loadString(
        'assets/models/gesture_labels.txt',
      );
      _labels = labelData.trim().split('\n').map((l) => l.trim()).toList();
      _isLoaded = true;
      print('TFLite classifier loaded: ${_labels.length} classes');
    } catch (e) {
      _isLoaded = false;
      print('TFLite classifier failed to load: $e');
    }
  }

  /// Pass all detected hands (1 or 2). Returns (label, confidence) or null.
  (String, double)? classify(List<List<Landmark>> allHands) {
    if (!_isLoaded || _interpreter == null) return null;

    try {
      final input = _extractFeatures(allHands);
      if (input == null) return null;

      final output = List.filled(_labels.length, 0.0).reshape([1, _labels.length]);
      _interpreter!.run(input.reshape([1, 126]), output);

      final probs = (output[0] as List).cast<double>();
      final maxIdx = probs.indexWhere((p) => p == probs.reduce((a, b) => a > b ? a : b));
      final confidence = probs[maxIdx];

      if (confidence < _confidenceThreshold) return null;
      final label = _labels[maxIdx];
      if (label == 'none') return null;

      return (label.toUpperCase(), confidence);
    } catch (e) {
      return null;
    }
  }

  Float32List? _extractFeatures(List<List<Landmark>> allHands) {
    if (allHands.isEmpty) return null;

    final features = Float32List(126);

    // Fill hand 0 (first 63 values)
    if (allHands.isNotEmpty) {
      _fillHand(allHands[0], features, offset: 0);
    }
    // Fill hand 1 (next 63 values) — zeros if only 1 hand
    if (allHands.length > 1) {
      _fillHand(allHands[1], features, offset: 63);
    }

    return features;
  }

  void _fillHand(List<Landmark> lm, Float32List out, {required int offset}) {
    if (lm.length < 21) return;
    final wristX = lm[0].x, wristY = lm[0].y, wristZ = lm[0].z;
    final dx = lm[9].x - wristX;
    final dy = lm[9].y - wristY;
    final dz = lm[9].z - wristZ;
    final span = (dx*dx + dy*dy + dz*dz).abs() + 1e-6;
    for (int i = 0; i < 21; i++) {
      out[offset + i * 3 + 0] = (lm[i].x - wristX) / span;
      out[offset + i * 3 + 1] = (lm[i].y - wristY) / span;
      out[offset + i * 3 + 2] = (lm[i].z - wristZ) / span;
    }
  }

  bool get isLoaded => _isLoaded;

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }
}
