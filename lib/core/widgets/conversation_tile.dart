import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import '../theme/whisper_colors.dart';
import 'audio_visualizer.dart';

class ConversationTile extends StatelessWidget {
  final String id;
  final String title;
  final String? subtitle;
  final DateTime createdAt;
  final Duration duration;
  final bool isStarred;
  final VoidCallback onTap;
  final VoidCallback? onStar;
  final VoidCallback? onDelete;
  final VoidCallback? onMore;
  final List<double>? waveformData;
  final Color? accentColor;

  const ConversationTile({
    super.key,
    required this.id,
    required this.title,
    this.subtitle,
    required this.createdAt,
    required this.duration,
    this.isStarred = false,
    required this.onTap,
    this.onStar,
    this.onDelete,
    this.onMore,
    this.waveformData,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final displayColor = accentColor ?? WhisperColors.amber;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              splashColor: Colors.white.withOpacity(0.1),
              highlightColor: Colors.white.withOpacity(0.05),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: WhisperColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: WhisperColors.cardBorder,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Left: Circular waveform thumbnail or gradient circle
                    _buildThumbnail(displayColor),
                    const SizedBox(width: 16),

                    // Center: Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Text(
                            title,
                            style: const TextStyle(
                              color: WhisperColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),

                          // Subtitle
                          if (subtitle != null && subtitle!.isNotEmpty)
                            Text(
                              subtitle!,
                              style: TextStyle(
                                color: WhisperColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 6),

                          // Date and duration
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: WhisperColors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(createdAt),
                                style: TextStyle(
                                  color: WhisperColors.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.timer_outlined,
                                size: 12,
                                color: WhisperColors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDuration(duration),
                                style: TextStyle(
                                  color: WhisperColors.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Right: Star and menu icons
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        if (isStarred)
                          Icon(
                            Icons.star_rounded,
                            color: WhisperColors.amber,
                            size: 20,
                          ),
                        if (onMore != null) ...[
                          const SizedBox(height: 8),
                          IconButton(
                            onPressed: onMore,
                            icon: Icon(
                              Icons.more_vert_rounded,
                              color: WhisperColors.textMuted,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(Color color) {
    if (waveformData != null && waveformData!.isNotEmpty) {
      // Show compact waveform
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CompactWaveform(
            waveformData: waveformData!,
            color: color,
            height: 56,
          ),
        ),
      );
    }

    // Show gradient circle
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.8),
            color.withOpacity(0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.mic_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return DateFormat('EEEE').format(date);
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}
