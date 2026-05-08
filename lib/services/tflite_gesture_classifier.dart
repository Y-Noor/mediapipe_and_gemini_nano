import 'dart:typed_data';
import 'dart:math' as math;
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
  (String, double)? classify(
    List<List<Landmark>> allHands, {
    int rotationDegrees = 0,
  }) {
    if (!_isLoaded || _interpreter == null) return null;

    try {
      final input = _extractFeatures(
        allHands,
        rotationDegrees: rotationDegrees,
      );
      if (input == null) return null;

      final output = List.filled(_labels.length, 0.0).reshape([1, _labels.length]);
      _interpreter!.run(input.reshape([1, 126]), output);

      final probs = (output[0] as List).cast<double>();
      final maxIdx = _argMax(probs);
      final confidence = probs[maxIdx];

      if (confidence < _confidenceThreshold) return null;
      final label = _labels[maxIdx];
      if (label == 'none') return null;

      return (label.toUpperCase(), confidence);
    } catch (e) {
      return null;
    }
  }

  Float32List? _extractFeatures(
    List<List<Landmark>> allHands, {
    required int rotationDegrees,
  }) {
    if (allHands.isEmpty) return null;

    final features = Float32List(126);

    // Fill hand 0 (first 63 values)
    if (allHands.isNotEmpty) {
      _fillHand(
        allHands[0],
        features,
        offset: 0,
        rotationDegrees: rotationDegrees,
      );
    }
    // Fill hand 1 (next 63 values) — zeros if only 1 hand
    if (allHands.length > 1) {
      _fillHand(
        allHands[1],
        features,
        offset: 63,
        rotationDegrees: rotationDegrees,
      );
    }

    return features;
  }

  int _argMax(List<double> values) {
    int best = 0;
    for (int i = 1; i < values.length; i++) {
      if (values[i] > values[best]) best = i;
    }
    return best;
  }

  void _fillHand(
    List<Landmark> lm,
    Float32List out, {
    required int offset,
    required int rotationDegrees,
  }) {
    if (lm.length < 21) return;
    final wristX = lm[0].x, wristY = lm[0].y, wristZ = lm[0].z;
    final dx = lm[9].x - wristX;
    final dy = lm[9].y - wristY;
    final dz = lm[9].z - wristZ;
    final span = math.sqrt(dx * dx + dy * dy + dz * dz) + 1e-6;
    final rot = ((rotationDegrees % 360) + 360) % 360;
    for (int i = 0; i < 21; i++) {
      final relX = lm[i].x - wristX;
      final relY = lm[i].y - wristY;
      double rx = relX;
      double ry = relY;

      switch (rot) {
        case 90:
          rx = relY;
          ry = -relX;
          break;
        case 180:
          rx = -relX;
          ry = -relY;
          break;
        case 270:
          rx = -relY;
          ry = relX;
          break;
      }

      out[offset + i * 3 + 0] = rx / span;
      out[offset + i * 3 + 1] = ry / span;
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
