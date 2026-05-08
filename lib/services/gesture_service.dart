import 'package:camera/camera.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'tflite_gesture_classifier.dart';

class GestureService {
  HandLandmarkerPlugin? _plugin;
  final TfliteGestureClassifier _classifier = TfliteGestureClassifier();
  bool _isInitialized = false;
  bool _isProcessing = false;
  int _sensorOrientation = 0;
  bool _isFrontCamera = true;
  int _inferenceRotationOffsetDegrees = 0;

  final List<String> _recentGestures = [];
  static const int _windowSize = 5;
  String? _lastEmitted;
  DateTime? _lastEmitTime;
  static const int _debounceMs = 900;

  Function(String gesture, double confidence)? onGestureDetected;
  Function(List<List<Landmark>> landmarksByHand)? onLandmarksDetected;

  bool get usingTflite => _classifier.isLoaded;

  Future<void> initialize() async {
    _plugin = HandLandmarkerPlugin.create(
      numHands: 2,
      minHandDetectionConfidence: 0.5,
      delegate: HandLandmarkerDelegate.gpu,
    );
    await _classifier.initialize();
    _isInitialized = true;
  }

  void setSensorOrientation(int orientation) {
    _sensorOrientation = orientation;
  }

  void setIsFrontCamera(bool isFrontCamera) {
    _isFrontCamera = isFrontCamera;
  }

  void setInferenceRotationOffset(int degrees) {
    final normalized = ((degrees % 360) + 360) % 360;
    _inferenceRotationOffsetDegrees = normalized;
  }

  int computeFrameRotationDegrees(int deviceOrientationDegrees) {
    final base = _isFrontCamera
        ? (_sensorOrientation + deviceOrientationDegrees) % 360
        : (_sensorOrientation - deviceOrientationDegrees + 360) % 360;
    return base;
  }

  int get inferenceRotationOffsetDegrees => _inferenceRotationOffsetDegrees;

  void processFrame(CameraImage image, int timestamp, int frameRotationDegrees) {
    if (!_isInitialized || _plugin == null || _isProcessing) return;
    _isProcessing = true;

    try {
      final List<Hand> hands = _plugin!.detect(image, frameRotationDegrees);

      if (hands.isEmpty) {
        _recentGestures.clear();
        return;
      }

      // Send all detected hands for overlay drawing.
      onLandmarksDetected?.call(hands.map((h) => h.landmarks).toList());

      String? gesture;
      double confidence = 0.0;

      if (_classifier.isLoaded) {
        // Pass all detected hands to TFLite classifier
        final allHandLandmarks = hands.map((h) => h.landmarks).toList();
        final result = _classifier.classify(
          allHandLandmarks,
          rotationDegrees: _inferenceRotationOffsetDegrees,
        );
        if (result != null) {
          gesture = result.$1;
          confidence = result.$2;
        }
      } else {
        // Rule-based fallback (1-hand only)
        gesture = _classifyRules(hands.first.landmarks);
        confidence = 0.9;
      }

      if (gesture == null) return;

      _recentGestures.add(gesture);
      if (_recentGestures.length > _windowSize) {
        _recentGestures.removeAt(0);
      }

      final counts = <String, int>{};
      for (final g in _recentGestures) {
        counts[g] = (counts[g] ?? 0) + 1;
      }
      final dominant = counts.entries.reduce((a, b) => a.value > b.value ? a : b);

      if (dominant.value >= (_windowSize * 0.6).ceil()) {
        final now = DateTime.now();
        final isDupe = _lastEmitted == dominant.key &&
            _lastEmitTime != null &&
            now.difference(_lastEmitTime!).inMilliseconds < _debounceMs;
        if (!isDupe) {
          _lastEmitted = dominant.key;
          _lastEmitTime = now;
          onGestureDetected?.call(dominant.key, confidence);
        }
      }
    } catch (_) {
    } finally {
      _isProcessing = false;
    }
  }

  String? _classifyRules(List<Landmark> lm) {
    if (lm.length < 21) return null;
    bool up(int tip, int mcp) => lm[tip].y < lm[mcp].y;
    final thumbOut = lm[4].x < lm[3].x;
    final indexUp  = up(8,  5);
    final middleUp = up(12, 9);
    final ringUp   = up(16, 13);
    final pinkyUp  = up(20, 17);
    final allCurled = !indexUp && !middleUp && !ringUp && !pinkyUp;
    final allOpen   =  indexUp &&  middleUp &&  ringUp &&  pinkyUp;
    if (allOpen && thumbOut)                                    return 'HELLO';
    if (allCurled && thumbOut)                                  return 'PLEASE';
    if (allCurled && !thumbOut)                                 return 'YES';
    if (indexUp && middleUp && !ringUp && !pinkyUp)             return 'NO';
    if (allOpen && lm[0].y > lm[9].y)                          return 'THANK_YOU';
    if (indexUp && !middleUp && !ringUp && pinkyUp)             return 'I_LOVE_YOU';
    if (indexUp && middleUp && ringUp && !pinkyUp && !thumbOut) return 'WATER';
    if (indexUp && !middleUp && !ringUp && !pinkyUp)            return 'WHAT';
    if (!indexUp && !middleUp && !ringUp && pinkyUp)            return 'WHERE';
    if (allOpen && (lm[0].x - lm[9].x).abs() < 0.1)           return 'STOP';
    if (allCurled && lm[0].y > 0.6)                            return 'HELP';
    return null;
  }

  void dispose() {
    _plugin?.dispose();
    _classifier.dispose();
    _plugin = null;
    _isInitialized = false;
  }
}