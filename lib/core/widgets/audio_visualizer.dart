import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/whisper_colors.dart';

class CircularAudioVisualizer extends StatefulWidget {
  final double amplitude; // 0.0 to 1.0
  final bool isRecording;
  final bool isPaused;
  final double size;

  const CircularAudioVisualizer({
    super.key,
    required this.amplitude,
    this.isRecording = false,
    this.isPaused = false,
    this.size = 200,
  });

  @override
  State<CircularAudioVisualizer> createState() => _CircularAudioVisualizerState();
}

class _CircularAudioVisualizerState extends State<CircularAudioVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _AudioVisualizerPainter(
              amplitude: widget.amplitude,
              isRecording: widget.isRecording,
              isPaused: widget.isPaused,
              animationValue: _controller.value,
            ),
          ),
        );
      },
    );
  }
}

class _AudioVisualizerPainter extends CustomPainter {
  final double amplitude;
  final bool isRecording;
  final bool isPaused;
  final double animationValue;

  _AudioVisualizerPainter({
    required this.amplitude,
    required this.isRecording,
    required this.isPaused,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.3;

    // Choose color based on state
    final color = isPaused ? WhisperColors.purple : WhisperColors.amber;

    // Draw multiple concentric rings that pulse with amplitude
    for (int i = 0; i < 4; i++) {
      final ringDelay = i * 0.25;
      final phase = (animationValue + ringDelay) % 1.0;

      // Calculate radius with amplitude-based pulsing
      final pulseAmount = amplitude * 20;
      final radius = baseRadius + (i * 15) + (math.sin(phase * math.pi * 2) * pulseAmount);

      // Fade out outer rings
      final opacity = 1.0 - (i * 0.2);

      // Draw ring
      final paint = Paint()
        ..color = color.withOpacity(opacity * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + (amplitude * 3);

      canvas.drawCircle(center, radius, paint);
    }

    // Draw center circle
    final centerPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(0.8),
          color.withOpacity(0.4),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: baseRadius));

    canvas.drawCircle(center, baseRadius, centerPaint);

    // Draw glow effect
    final glowPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    canvas.drawCircle(center, baseRadius + (amplitude * 15), glowPaint);

    // Draw small center dot
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _AudioVisualizerPainter oldDelegate) {
    return oldDelegate.amplitude != amplitude ||
        oldDelegate.isRecording != isRecording ||
        oldDelegate.isPaused != isPaused ||
        oldDelegate.animationValue != animationValue;
  }
}

// Compact waveform visualization for cards
class CompactWaveform extends StatelessWidget {
  final List<double> waveformData;
  final Color color;
  final double height;

  const CompactWaveform({
    super.key,
    required this.waveformData,
    this.color = WhisperColors.amber,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _CompactWaveformPainter(
          waveformData: waveformData.isEmpty ? List.filled(50, 0.3) : waveformData,
          color: color,
        ),
      ),
    );
  }
}

class _CompactWaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final Color color;

  _CompactWaveformPainter({
    required this.waveformData,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width / waveformData.length;
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < waveformData.length; i++) {
      final barHeight = waveformData[i] * size.height;
      final x = i * barWidth;
      final y = (size.height - barHeight) / 2;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth * 0.8, barHeight),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CompactWaveformPainter oldDelegate) {
    return oldDelegate.waveformData != waveformData ||
        oldDelegate.color != color;
  }
}
