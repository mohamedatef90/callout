import 'package:flutter/material.dart';
import 'audio_wave_painter.dart';

class WaveVisualization extends StatefulWidget {
  final double amplitude;
  final bool isActive;
  final Color primaryColor;
  final Color secondaryColor;

  const WaveVisualization({
    super.key,
    required this.amplitude,
    required this.isActive,
    this.primaryColor = const Color(0xFF6366F1),
    this.secondaryColor = const Color(0xFF8B5CF6),
  });

  @override
  State<WaveVisualization> createState() => _WaveVisualizationState();
}

class _WaveVisualizationState extends State<WaveVisualization>
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
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            widget.primaryColor.withOpacity(0.1),
            widget.secondaryColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: widget.isActive
          ? AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: AudioWavePainter(
                    amplitude: widget.amplitude,
                    animationValue: _controller.value,
                    color: widget.primaryColor,
                    waveCount: 4,
                  ),
                );
              },
            )
          : Center(
              child: Icon(
                Icons.graphic_eq,
                size: 64,
                color: widget.primaryColor.withOpacity(0.3),
              ),
            ),
    );
  }
}
