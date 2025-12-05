import 'dart:math';
import 'package:flutter/material.dart';

class AudioWavePainter extends CustomPainter {
  final double amplitude;
  final double animationValue;
  final Color color;
  final int waveCount;

  AudioWavePainter({
    required this.amplitude,
    required this.animationValue,
    required this.color,
    this.waveCount = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final centerY = size.height / 2;
    final waveWidth = size.width;

    for (int i = 0; i < waveCount; i++) {
      final path = Path();
      final opacity = 1.0 - (i * 0.3);
      final frequency = 2.0 + (i * 0.5);
      final phaseShift = animationValue * 2 * pi + (i * pi / 3);

      paint.color = color.withOpacity(opacity);

      for (double x = 0; x <= waveWidth; x += 1) {
        final normalizedX = x / waveWidth;
        final y =
            centerY +
            sin((normalizedX * frequency * 2 * pi) + phaseShift) *
                amplitude *
                (20 + (i * 10));

        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(AudioWavePainter oldDelegate) {
    return oldDelegate.amplitude != amplitude ||
        oldDelegate.animationValue != animationValue;
  }
}
