import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/conversation_model.dart';

class ConversationCard extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onLongPress;

  const ConversationCard({
    super.key,
    required this.conversation,
    required this.onTap,
    required this.onDelete,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final isMeeting = conversation.type == ConversationType.meeting;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF1E293B).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMeeting
              ? const Color(0xFF6366F1).withValues(alpha: 0.3)
              : const Color(0xFF10B981).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isMeeting
                          ? [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]
                          : [const Color(0xFF10B981), const Color(0xFF059669)],
                    ),
                  ),
                  child: Icon(
                    isMeeting ? Icons.groups_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title with badge
                      Row(
                        children: [
                          if (conversation.isStarred)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.star,
                                size: 16,
                                color: Colors.amber,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              conversation.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFFF8FAFC), // slate-50
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Mode badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isMeeting
                                  ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                                  : const Color(0xFF10B981).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isMeeting ? 'Meeting' : 'Note',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isMeeting
                                    ? const Color(0xFF6366F1)
                                    : const Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (conversation.subtitle != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          conversation.subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFFCBD5E1), // slate-300
                          ),
                        ),
                      ],

                      const SizedBox(height: 6),
                      Text(
                        dateFormat.format(conversation.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B), // slate-500
                        ),
                      ),
                    ],
                  ),
                ),

                // Delete button
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: const Color(0xFF64748B),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
