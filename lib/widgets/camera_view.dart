import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import '../models/app_state.dart';
import 'hand_overlay_painter.dart';

final landmarksProvider = StateProvider<List<List<Landmark>>>((ref) => const []);

class CameraView extends ConsumerStatefulWidget {
  const CameraView({super.key});

  @override
  ConsumerState<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends ConsumerState<CameraView>
    with WidgetsBindingObserver {
  // Rotate input before landmark detection/inference when needed.
  // Allowed values: 0, 90, 180, 270.
  static const int _inferenceRotationOffset = 90;

  CameraController? _controller;
  int _sensorOrientation = 0;
  bool _isFrontCamera = true;
  bool _isStreaming = false;
  int _frameCount = 0;
  static const int _frameSkip = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final camera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    _sensorOrientation = camera.sensorOrientation;
    _isFrontCamera = camera.lensDirection == CameraLensDirection.front;

    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
    await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);

    // Pass sensor orientation to gesture service
    final gestureService = ref.read(gestureServiceProvider);
    gestureService.setSensorOrientation(_sensorOrientation);
    gestureService.setIsFrontCamera(_isFrontCamera);
    gestureService.setInferenceRotationOffset(_inferenceRotationOffset);
    gestureService.onLandmarksDetected = (landmarksByHand) {
      if (mounted) {
        ref.read(landmarksProvider.notifier).state = landmarksByHand;
      }
    };

    if (!mounted) return;
    setState(() {});
    await _startStream();
  }

  Future<void> _startStream() async {
    if (_controller == null || _isStreaming) return;
    _isStreaming = true;
    final gestureService = ref.read(gestureServiceProvider);

    await _controller!.startImageStream((CameraImage image) {
      _frameCount++;
      if (_frameCount % _frameSkip != 0) return;
      final ts = DateTime.now().millisecondsSinceEpoch;
      final frameRotationDegrees = gestureService.computeFrameRotationDegrees(
        0, // Portrait-up only pipeline for stable inference.
      );
      gestureService.processFrame(image, ts, frameRotationDegrees);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.stopImageStream();
      _isStreaming = false;
    } else if (state == AppLifecycleState.resumed) {
      _startStream();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF22D3A0)),
      );
    }

    final landmarksByHand = ref.watch(landmarksProvider);
    final gestureService = ref.read(gestureServiceProvider);
    final frameRotationDegrees = gestureService.computeFrameRotationDegrees(0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          if (landmarksByHand.isNotEmpty)
            CustomPaint(
              painter: HandOverlayPainter(
                landmarksByHand: landmarksByHand,
                imageSize: _controller!.value.previewSize!,
                isFrontCamera: _isFrontCamera,
                frameRotationDegrees: frameRotationDegrees,
                mirrorFrontCamera: true,
              ),
            ),
          CustomPaint(painter: _FrameCornerPainter()),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.stopImageStream();
    _controller?.dispose();
    super.dispose();
  }
}

class _FrameCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF22D3A0)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 24.0, m = 12.0;
    canvas.drawLine(Offset(m, m + len), Offset(m, m), p);
    canvas.drawLine(Offset(m, m), Offset(m + len, m), p);
    canvas.drawLine(Offset(size.width - m - len, m), Offset(size.width - m, m), p);
    canvas.drawLine(Offset(size.width - m, m), Offset(size.width - m, m + len), p);
    canvas.drawLine(Offset(m, size.height - m - len), Offset(m, size.height - m), p);
    canvas.drawLine(Offset(m, size.height - m), Offset(m + len, size.height - m), p);
    canvas.drawLine(Offset(size.width - m - len, size.height - m), Offset(size.width - m, size.height - m), p);
    canvas.drawLine(Offset(size.width - m, size.height - m - len), Offset(size.width - m, size.height - m), p);
  }
  @override
  bool shouldRepaint(_FrameCornerPainter _) => false;
}
