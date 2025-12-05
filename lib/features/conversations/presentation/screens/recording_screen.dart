import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/conversation_model.dart';
import '../providers/recording_provider.dart';
import '../widgets/wave_visualization.dart';
import '../widgets/recording_button.dart';
import '../widgets/control_button.dart';

class RecordingScreen extends ConsumerStatefulWidget {
  final ConversationType mode;

  const RecordingScreen({super.key, required this.mode});

  @override
  ConsumerState<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends ConsumerState<RecordingScreen> {
  bool _isStarting = false;
  String? _error;

  RecordingButtonState _getButtonState(RecordState state) {
    if (_isStarting) return RecordingButtonState.idle;
    switch (state) {
      case RecordState.record:
        return RecordingButtonState.recording;
      case RecordState.pause:
        return RecordingButtonState.paused;
      default:
        return RecordingButtonState.idle;
    }
  }

  Future<void> _startRecording() async {
    setState(() {
      _isStarting = true;
      _error = null;
    });

    try {
      await ref.read(recordingControllerProvider.notifier).startRecording();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start recording: $e'),
            backgroundColor: const Color(0xFFEF4444),
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

  @override
  Widget build(BuildContext context) {
    final recordState = ref.watch(recordingControllerProvider);
    final duration = ref.watch(recordingDurationProvider);
    final amplitude = ref.watch(recordingAmplitudeProvider);

    final isRecording = recordState == RecordState.record;
    final isPaused = recordState == RecordState.pause;
    final isIdle = recordState == RecordState.stop && !_isStarting;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.mode == ConversationType.meeting ? 'Meeting Recording' : 'Voice Note',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Duration Display
              Text(
                formatDuration(duration),
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 12),

              // Status Text
              Text(
                _isStarting
                    ? 'Starting...'
                    : isRecording
                        ? 'Recording...'
                        : isPaused
                            ? 'Paused'
                            : 'Ready to record',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 12),

              // Mode Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.mode == ConversationType.meeting
                        ? [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]
                        : [
                            const Color(0xFF10B981),
                            const Color(0xFF059669),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.mode == ConversationType.meeting
                          ? Icons.groups_rounded
                          : Icons.mic_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.mode == ConversationType.meeting
                          ? 'Meeting'
                          : 'Voice Note',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Wave Visualization
              amplitude.when(
                data: (amp) => WaveVisualization(
                  amplitude: amp.current / 100,
                  isActive: isRecording,
                  primaryColor: const Color(0xFF6366F1),
                  secondaryColor: const Color(0xFF8B5CF6),
                ),
                loading: () =>
                    const WaveVisualization(amplitude: 0, isActive: false),
                error: (_, __) =>
                    const WaveVisualization(amplitude: 0, isActive: false),
              ),

              const Spacer(),

              // Controls
              if (_isStarting)
                // Loading indicator while starting
                const SizedBox(
                  width: 100,
                  height: 100,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF6366F1),
                    ),
                  ),
                )
              else if (isIdle)
                // Initial Record Button
                RecordingButton(
                  state: RecordingButtonState.idle,
                  onPressed: _startRecording,
                )
              else
                // Recording Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Stop Button
                    ControlButton(
                      icon: Icons.stop_rounded,
                      label: 'Stop',
                      color: const Color(0xFFEF4444),
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
                    ),

                    // Pause/Resume Button
                    RecordingButton(
                      state: _getButtonState(recordState),
                      onPressed: () {
                        if (isRecording) {
                          ref
                              .read(recordingControllerProvider.notifier)
                              .pauseRecording();
                        } else {
                          ref
                              .read(recordingControllerProvider.notifier)
                              .resumeRecording();
                        }
                      },
                    ),

                    // Placeholder for symmetry
                    const SizedBox(width: 70),
                  ],
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
