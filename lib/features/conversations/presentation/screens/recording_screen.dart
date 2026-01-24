import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import '../../data/models/conversation_model.dart';
import '../providers/recording_provider.dart';
import '../../../../core/theme/whisper_colors.dart';
import '../../../../core/widgets/audio_visualizer.dart';
import '../../../../core/widgets/glassmorphic_card.dart';

class RecordingScreen extends ConsumerStatefulWidget {
  final ConversationType mode;

  const RecordingScreen({super.key, required this.mode});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen>
    with SingleTickerProviderStateMixin {
  bool _isStarting = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() {
      _isStarting = true;
    });

    try {
      await ref.read(recordingControllerProvider.notifier).startRecording();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start recording: $e'),
            backgroundColor: WhisperColors.rose,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isStarting = false;
        });
      }
    }
  }

  String _formatTimestamp(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final recordState = ref.watch(recordingControllerProvider);
    final duration = ref.watch(recordingDurationProvider);
    final amplitude = ref.watch(recordingAmplitudeProvider);

    final isRecording = recordState == RecordState.record;
    final isPaused = recordState == RecordState.pause;
    final isIdle = recordState == RecordState.stop && !_isStarting;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: WhisperColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: WhisperColors.textPrimary,
                        size: 28,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: WhisperColors.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: WhisperColors.cardBorder,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        widget.mode == ConversationType.meeting
                            ? 'Meeting'
                            : 'Voice Note',
                        style: const TextStyle(
                          color: WhisperColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // Balance the close button
                  ],
                ),
              ),

              // Main Content Area
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Circular Audio Visualizer
                    amplitude.when(
                      data: (amp) => CircularAudioVisualizer(
                        amplitude: amp.current / 100,
                        isRecording: isRecording,
                        isPaused: isPaused,
                        size: 250,
                      ),
                      loading: () => const CircularAudioVisualizer(
                        amplitude: 0,
                        isRecording: false,
                        size: 250,
                      ),
                      error: (_, __) => const CircularAudioVisualizer(
                        amplitude: 0,
                        isRecording: false,
                        size: 250,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Timer Display
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: WhisperColors.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: WhisperColors.cardBorder,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        isIdle ? '00:00' : _formatTimestamp(duration),
                        style: TextStyle(
                          color: WhisperColors.textPrimary,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -1,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Status Text
                    Text(
                      isIdle
                          ? 'Ready to record'
                          : isRecording
                              ? 'Recording...'
                              : 'Paused',
                      style: TextStyle(
                        color: WhisperColors.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Live Transcript Area (Slide-up panel)
              if (!isIdle)
                GlassmorphicCard(
                  borderRadius: 24,
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.mic_none_rounded,
                            color: WhisperColors.textMuted,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Listening',
                            style: TextStyle(
                              color: WhisperColors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _AnimatedDots(isActive: isRecording),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Transcription will be generated after recording ends',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: WhisperColors.textMuted,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

              // Bottom Controls
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: _isStarting
                    ? SizedBox(
                        height: 80,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: WhisperColors.amber,
                            strokeWidth: 4,
                          ),
                        ),
                      )
                    : isIdle
                        ? _buildStartButton()
                        : _buildRecordingControls(isRecording),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: WhisperColors.amberGradient,
              boxShadow: [
                BoxShadow(
                  color: WhisperColors.amber.withOpacity(0.5),
                  blurRadius: 24,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(40),
                onTap: _startRecording,
                child: const Icon(
                  Icons.mic_rounded,
                  size: 40,
                  color: WhisperColors.slate900,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecordingControls(bool isRecording) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Highlight/Bookmark button
        _buildControlButton(
          icon: Icons.star_border_rounded,
          label: 'Mark',
          color: WhisperColors.purple,
          onPressed: () {
            // TODO: Add highlight moment
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Moment marked'),
                backgroundColor: WhisperColors.purple,
                duration: const Duration(seconds: 1),
              ),
            );
          },
          size: 64,
        ),

        // Pause/Resume button (center, larger)
        _buildControlButton(
          icon: isRecording ? Icons.pause_rounded : Icons.play_arrow_rounded,
          label: isRecording ? 'Pause' : 'Resume',
          color: isRecording ? WhisperColors.purple : WhisperColors.emerald,
          onPressed: () {
            if (isRecording) {
              ref.read(recordingControllerProvider.notifier).pauseRecording();
            } else {
              ref.read(recordingControllerProvider.notifier).resumeRecording();
            }
          },
          size: 80,
          isPrimary: true,
        ),

        // Stop button
        _buildControlButton(
          icon: Icons.stop_rounded,
          label: 'Stop',
          color: WhisperColors.rose,
          onPressed: () async {
            final durationSeconds = ref.read(recordingDurationProvider);
            final path = await ref
                .read(recordingControllerProvider.notifier)
                .stopRecording();
            if (context.mounted && path != null) {
              Navigator.pop(context, (
                path: path,
                type: widget.mode,
                durationMs: durationSeconds * 1000,
              ));
            }
          },
          size: 64,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    required double size,
    bool isPrimary = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color,
                color.withOpacity(0.8),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: isPrimary ? 24 : 16,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(size / 2),
              onTap: onPressed,
              child: Icon(
                icon,
                size: isPrimary ? 40 : 32,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: WhisperColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// Animated dots for "listening" indicator
class _AnimatedDots extends StatefulWidget {
  final bool isActive;

  const _AnimatedDots({required this.isActive});

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots> {
  int _currentDots = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  @override
  void didUpdateWidget(_AnimatedDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _startAnimation();
      } else {
        _stopAnimation();
      }
    }
  }

  void _startAnimation() {
    _timer?.cancel();
    if (widget.isActive) {
      _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (mounted) {
          setState(() {
            _currentDots = (_currentDots + 1) % 4;
          });
        }
      });
    }
  }

  void _stopAnimation() {
    _timer?.cancel();
    setState(() {
      _currentDots = 0;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      child: Text(
        '.' * _currentDots,
        style: TextStyle(
          color: WhisperColors.textSecondary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          height: 1.0,
        ),
      ),
    );
  }
}
