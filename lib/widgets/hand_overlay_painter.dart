import 'package:flutter/material.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

class HandOverlayPainter extends CustomPainter {
  final List<Landmark>? landmarks;
  final Size imageSize;
  final bool isFrontCamera;

  static const List<(int, int)> _connections = [
    (0,1),(1,2),(2,3),(3,4),
    (0,5),(5,6),(6,7),(7,8),
    (0,9),(9,10),(10,11),(11,12),
    (0,13),(13,14),(14,15),(15,16),
    (0,17),(17,18),(18,19),(19,20),
    (5,9),(9,13),(13,17),
  ];

  HandOverlayPainter({
    required this.landmarks,
    required this.imageSize,
    this.isFrontCamera = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks == null || landmarks!.isEmpty) return;

    final sx = size.width / imageSize.width;
    final sy = size.height / imageSize.height;

    Offset toOffset(Landmark lm) {
      final x = isFrontCamera
          ? (1.0 - lm.x) * imageSize.width * sx
          : lm.x * imageSize.width * sx;
      return Offset(x, lm.y * imageSize.height * sy);
    }

    final bone = Paint()
      ..color = const Color(0x9922D3A0)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dot = Paint()
      ..color = const Color(0xFF22D3A0)
      ..style = PaintingStyle.fill;

    final dotBorder = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final (a, b) in _connections) {
      canvas.drawLine(toOffset(landmarks![a]), toOffset(landmarks![b]), bone);
    }
    for (final lm in landmarks!) {
      final pt = toOffset(lm);
      canvas.drawCircle(pt, 4, dot);
      canvas.drawCircle(pt, 4, dotBorder);
    }
  }

  @override
  bool shouldRepaint(HandOverlayPainter old) => old.landmarks != landmarks;
}
