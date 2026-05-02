import 'package:camera/camera.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

class GestureService {
  HandLandmarkerPlugin? _plugin;
  bool _isInitialized = false;
  bool _isProcessing = false;
  int _sensorOrientation = 0;

  final List<String> _recentGestures = [];
  static const int _windowSize = 5;
  String? _lastEmitted;
  DateTime? _lastEmitTime;
  static const int _debounceMs = 900;

  Function(String gesture, double confidence)? onGestureDetected;
  Function(List<Landmark> landmarks)? onLandmarksDetected;

  Future<void> initialize() async {
    _plugin = HandLandmarkerPlugin.create(
      numHands: 1,
      minHandDetectionConfidence: 0.5,
      delegate: HandLandmarkerDelegate.gpu,
    );
    _isInitialized = true;
  }

  void setSensorOrientation(int orientation) {
    _sensorOrientation = orientation;
  }

  void processFrame(CameraImage image, int timestamp) {
    if (!_isInitialized || _plugin == null || _isProcessing) return;
    _isProcessing = true;

    try {
      // detect() is synchronous in 2.2.0
      final List<Hand> hands = _plugin!.detect(image, _sensorOrientation);

      if (hands.isEmpty) {
        _recentGestures.clear();
        return;
      }

      final hand = hands.first;
      onLandmarksDetected?.call(hand.landmarks);

      final gesture = _classify(hand.landmarks);
      if (gesture == null) return;

      _recentGestures.add(gesture);
      if (_recentGestures.length > _windowSize) _recentGestures.removeAt(0);

      final counts = <String, int>{};
      for (final g in _recentGestures) counts[g] = (counts[g] ?? 0) + 1;
      final dominant = counts.entries.reduce((a, b) => a.value > b.value ? a : b);

      if (dominant.value >= (_windowSize * 0.6).ceil()) {
        final now = DateTime.now();
        final isDupe = _lastEmitted == dominant.key &&
            _lastEmitTime != null &&
            now.difference(_lastEmitTime!).inMilliseconds < _debounceMs;

        if (!isDupe) {
          _lastEmitted = dominant.key;
          _lastEmitTime = now;
          onGestureDetected?.call(dominant.key, dominant.value / _windowSize);
        }
      }
    } catch (_) {
      // drop frame silently
    } finally {
      _isProcessing = false;
    }
  }

  String? _classify(List<Landmark> lm) {
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
    if (_tipsSpread(lm) < 0.12 && !allCurled)                  return 'FOOD';

    return null;
  }

  double _tipsSpread(List<Landmark> lm) {
    final tips = [4, 8, 12, 16, 20];
    double sum = 0; int n = 0;
    for (int i = 0; i < tips.length; i++) {
      for (int j = i + 1; j < tips.length; j++) {
        final dx = lm[tips[i]].x - lm[tips[j]].x;
        final dy = lm[tips[i]].y - lm[tips[j]].y;
        sum += dx * dx + dy * dy; n++;
      }
    }
    return n > 0 ? sum / n : 1.0;
  }

  void dispose() {
    _plugin?.dispose(); // synchronous in 2.2.0
    _plugin = null;
    _isInitialized = false;
  }
}
