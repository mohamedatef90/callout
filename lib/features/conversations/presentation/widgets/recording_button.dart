import 'package:flutter/material.dart';

enum RecordingButtonState { idle, recording, paused }

class RecordingButton extends StatefulWidget {
  final RecordingButtonState state;
  final VoidCallback onPressed;
  final Color primaryColor;
  final Color secondaryColor;

  const RecordingButton({
    super.key,
    required this.state,
    required this.onPressed,
    this.primaryColor = const Color(0xFFEF4444),
    this.secondaryColor = const Color(0xFFDC2626),
  });

  @override
  State<RecordingButton> createState() => _RecordingButtonState();
}

class _RecordingButtonState extends State<RecordingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _updatePulseAnimation();
  }

  @override
  void didUpdateWidget(RecordingButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updatePulseAnimation();
    }
  }

  void _updatePulseAnimation() {
    if (widget.state == RecordingButtonState.recording) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  IconData _getIcon() {
    switch (widget.state) {
      case RecordingButtonState.idle:
        return Icons.mic;
      case RecordingButtonState.recording:
        return Icons.pause;
      case RecordingButtonState.paused:
        return Icons.play_arrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulsing ring (only when recording)
              if (widget.state == RecordingButtonState.recording)
                Container(
                  width: 120 * _pulseAnimation.value,
                  height: 120 * _pulseAnimation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.primaryColor.withOpacity(
                        0.3 * (1 - (_pulseAnimation.value - 1) / 0.2),
                      ),
                      width: 3,
                    ),
                  ),
                ),

              // Main button
              AnimatedScale(
                scale: _isPressed ? 0.9 : 1.0,
                duration: const Duration(milliseconds: 100),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [widget.primaryColor, widget.secondaryColor],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.primaryColor.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(_getIcon(), size: 48, color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
