import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/gemini_service.dart';
import '../../../../core/theme/whisper_colors.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import '../../../../core/widgets/stat_card.dart';
import '../../../../core/widgets/folder_chip.dart';
import '../../../../core/widgets/conversation_tile.dart';
import '../../data/models/conversation_model.dart';
import '../../data/models/folder_model.dart';
import '../../data/repositories/conversation_repository.dart';
import '../providers/conversation_list_provider.dart';
import '../providers/folder_provider.dart';
import '../widgets/mode_selection_sheet.dart';
import 'recording_screen.dart';
import 'detail_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  String _searchQuery = '';
  String? _selectedFolderId;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _fabScaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _fabAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(conversationListProvider);
    ref.invalidate(folderListProvider);
  }

  List<Conversation> _filterConversations(
    List<Conversation> conversations,
  ) {
    var filtered = conversations;

    // Filter by folder
    if (_selectedFolderId != null) {
      filtered = filtered.where((c) => c.folderId == _selectedFolderId).toList();
    } else {
      // Show only recordings not in any folder
      filtered = filtered.where((c) => c.folderId == null).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((c) {
        if (c.title.toLowerCase().contains(query)) return true;
        if (c.subtitle?.toLowerCase().contains(query) ?? false) return true;
        if (c.transcript?.fullText.toLowerCase().contains(query) ?? false)
          return true;
        if (c.aiResult?.titleEn.toLowerCase().contains(query) ?? false)
          return true;
        if (c.aiResult?.titleAr.toLowerCase().contains(query) ?? false)
          return true;
        return false;
      }).toList();
    }

    return filtered;
  }

  String _detectLanguage(String text) {
    if (text.isEmpty) return 'en';

    final arabicRegex = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]');
    final arabicChars = arabicRegex.allMatches(text).length;
    final totalChars = text.replaceAll(RegExp(r'\s'), '').length;

    if (totalChars == 0) return 'en';

    final arabicRatio = arabicChars / totalChars;

    if (arabicRatio > 0.5) return 'ar';
    if (arabicRatio > 0.2) return 'mixed';
    return 'en';
  }

  Future<void> _processRecording(
    String path,
    ConversationType type,
    int durationMs,
  ) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final geminiService = ref.read(geminiServiceProvider);
      final settings = ref.read(settingsProvider);

      final transcriptText = await geminiService.transcribeAudio(path);
      final aiResult = await geminiService.generateSummary(transcriptText);
      final detectedLanguage = _detectLanguage(transcriptText);
      final shouldDeleteAudio = settings.deleteAudioAfterTranscription;

      final conversation = Conversation(
        id: const Uuid().v4(),
        type: type,
        title: aiResult.titleEn.isNotEmpty
            ? aiResult.titleEn
            : 'New Conversation',
        subtitle: aiResult.summaryEn,
        primaryLanguage: detectedLanguage,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        audioSegments: shouldDeleteAudio
            ? []
            : [AudioSegment(filePath: path, durationMs: durationMs)],
        transcript: Transcript(
          fullText: transcriptText,
          languageCode: detectedLanguage,
        ),
        aiResult: aiResult,
      );

      await ref
          .read(conversationListProvider.notifier)
          .addConversation(conversation);

      if (shouldDeleteAudio) {
        try {
          final audioFile = File(path);
          if (await audioFile.exists()) {
            await audioFile.delete();
          }
        } catch (e) {
          debugPrint('Failed to delete audio file: $e');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing recording: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showModeSelection() async {
    final selectedMode = await showModalBottomSheet<ConversationType>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const ModeSelectionSheet(),
    );

    if (selectedMode != null && mounted) {
      final result =
          await Navigator.push<
            ({String path, ConversationType type, int durationMs})?
          >(
            context,
            MaterialPageRoute(
              builder: (context) => RecordingScreen(mode: selectedMode),
            ),
          );

      if (result != null) {
        _processRecording(result.path, result.type, result.durationMs);
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 18) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    return DateFormat('EEEE, MMMM d').format(now);
  }

  @override
  Widget build(BuildContext context) {
    final allConversations = ref.watch(conversationListProvider);
    final folders = ref.watch(folderListProvider);
    final conversations = _filterConversations(allConversations);

    // Calculate stats
    final thisWeekStart = DateTime.now().subtract(const Duration(days: 7));
    final thisWeekCount = allConversations
        .where((c) => c.createdAt.isAfter(thisWeekStart))
        .length;
    final totalDuration = allConversations.fold<int>(
      0,
      (sum, c) => sum + c.audioSegments.fold<int>(
        0,
        (s, seg) => s + seg.durationMs,
      ),
    );
    final totalHours = (totalDuration / (1000 * 60 * 60)).toStringAsFixed(1);

    // Map folders to FolderChipData
    final folderChips = folders
        .map(
          (f) => FolderChipData(
            id: f.id,
            name: f.name,
            count: allConversations.where((c) => c.folderId == f.id).length,
            color: f.color != null
                ? Color(int.parse(f.color!.replaceFirst('#', '0xFF')))
                : WhisperColors.amber,
          ),
        )
        .toList();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: WhisperColors.backgroundGradient,
        ),
        child: SafeArea(
          child: _isProcessing
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          color: WhisperColors.amber,
                          strokeWidth: 4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Processing recording with AI...',
                        style: TextStyle(
                          color: WhisperColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This may take a moment',
                        style: TextStyle(
                          color: WhisperColors.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  color: WhisperColors.amber,
                  backgroundColor: WhisperColors.slate800,
                  child: CustomScrollView(
                    slivers: [
                      // Top Section - Greeting & Date
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _getGreeting(),
                                          style: const TextStyle(
                                            color: WhisperColors.textPrimary,
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: -0.8,
                                            height: 1.1,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _getFormattedDate(),
                                          style: TextStyle(
                                            color: WhisperColors.textSecondary,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: () {
                                          // TODO: Implement search
                                        },
                                        icon: const Icon(
                                          Icons.search_rounded,
                                          color: WhisperColors.textPrimary,
                                          size: 24,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const SettingsScreen(),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.settings_outlined,
                                          color: WhisperColors.textPrimary,
                                          size: 24,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Quick Stats Row
                      if (allConversations.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: StatRow(
                              stats: [
                                StatCard(
                                  label: 'This week',
                                  value: thisWeekCount.toString(),
                                  icon: Icons.calendar_today_rounded,
                                  color: WhisperColors.amber,
                                ),
                                StatCard(
                                  label: 'Total hours',
                                  value: totalHours,
                                  icon: Icons.access_time_rounded,
                                  color: WhisperColors.purple,
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Folders Section
                      if (folders.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 24,
                                    bottom: 12,
                                  ),
                                  child: Text(
                                    'FOLDERS',
                                    style: TextStyle(
                                      color: WhisperColors.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                FolderChipList(
                                  folders: folderChips,
                                  selectedFolderId: _selectedFolderId,
                                  onFolderSelected: (folderId) {
                                    setState(() {
                                      _selectedFolderId = folderId;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Recordings Section Header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 24,
                            right: 24,
                            bottom: 16,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedFolderId != null
                                    ? folders
                                        .firstWhere(
                                          (f) => f.id == _selectedFolderId,
                                          orElse: () => Folder(
                                            id: '',
                                            name: 'RECORDINGS',
                                            createdAt: DateTime.now(),
                                            updatedAt: DateTime.now(),
                                          ),
                                        )
                                        .name
                                        .toUpperCase()
                                    : 'RECORDINGS',
                                style: TextStyle(
                                  color: WhisperColors.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                              if (conversations.isNotEmpty)
                                Text(
                                  '${conversations.length}',
                                  style: TextStyle(
                                    color: WhisperColors.textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // Empty State
                      if (conversations.isEmpty)
                        SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        WhisperColors.amber.withOpacity(0.2),
                                        WhisperColors.amber.withOpacity(0.05),
                                      ],
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.mic_none_rounded,
                                    size: 64,
                                    color: WhisperColors.amber,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'No recordings yet',
                                  style: TextStyle(
                                    color: WhisperColors.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap the button below to start',
                                  style: TextStyle(
                                    color: WhisperColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.only(bottom: 120),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final conversation = conversations[index];
                                return ConversationTile(
                                  id: conversation.id,
                                  title: conversation.title,
                                  subtitle: conversation.subtitle,
                                  createdAt: conversation.createdAt,
                                  duration: Duration(
                                    milliseconds: conversation.audioSegments.fold<int>(
                                      0,
                                      (sum, seg) => sum + seg.durationMs,
                                    ),
                                  ),
                                  isStarred: conversation.isStarred,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          DetailScreen(conversation: conversation),
                                    ),
                                  ),
                                  onMore: () => _showConversationMenu(conversation),
                                );
                              },
                              childCount: conversations.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _fabScaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _fabScaleAnimation.value,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: WhisperColors.amberGradient,
                boxShadow: [
                  BoxShadow(
                    color: WhisperColors.amber.withOpacity(0.4),
                    blurRadius: 24,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(36),
                  onTap: _showModeSelection,
                  child: const Icon(
                    Icons.mic_rounded,
                    size: 32,
                    color: WhisperColors.slate900,
                  ),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _showConversationMenu(Conversation conversation) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassmorphicCard(
        borderRadius: 24,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: WhisperColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              ListTile(
                leading: Icon(
                  conversation.isStarred ? Icons.star : Icons.star_border_rounded,
                  color: WhisperColors.amber,
                ),
                title: Text(
                  conversation.isStarred ? 'Unstar' : 'Star',
                  style: const TextStyle(color: WhisperColors.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _toggleStar(conversation);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.folder_outlined,
                  color: WhisperColors.purple,
                ),
                title: const Text(
                  'Move to folder',
                  style: TextStyle(color: WhisperColors.textPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showMoveToFolderDialog(conversation);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: WhisperColors.rose,
                ),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: WhisperColors.rose),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteDialog(conversation);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleStar(Conversation conversation) {
    final updated = conversation.copyWith(
      isStarred: !conversation.isStarred,
      updatedAt: DateTime.now(),
    );
    ref.read(conversationRepositoryProvider).saveConversation(updated);
    ref.invalidate(conversationListProvider);
  }

  void _showMoveToFolderDialog(Conversation conversation) {
    final folders = ref.read(folderListProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassmorphicCard(
        borderRadius: 24,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: WhisperColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Move to Folder',
                  style: TextStyle(
                    color: WhisperColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(
                  Icons.folder_off_outlined,
                  color: Colors.white.withOpacity(0.7),
                ),
                title: const Text(
                  'No Folder',
                  style: TextStyle(color: Colors.white),
                ),
                selected: conversation.folderId == null,
                onTap: () {
                  _moveToFolder(conversation, null);
                  Navigator.pop(context);
                },
              ),
              ...folders.map(
                (folder) => ListTile(
                  leading: Icon(
                    Icons.folder,
                    color: folder.color != null
                        ? Color(int.parse(folder.color!.replaceFirst('#', '0xFF')))
                        : WhisperColors.amber,
                  ),
                  title: Text(
                    folder.name,
                    style: const TextStyle(color: WhisperColors.textPrimary),
                  ),
                  selected: conversation.folderId == folder.id,
                  onTap: () {
                    _moveToFolder(conversation, folder.id);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _moveToFolder(Conversation conversation, String? folderId) {
    final updatedConversation = conversation.copyWith(
      folderId: folderId,
      updatedAt: DateTime.now(),
    );
    ref
        .read(conversationRepositoryProvider)
        .saveConversation(updatedConversation);
    ref.invalidate(conversationListProvider);
  }

  void _showDeleteDialog(Conversation conversation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: WhisperColors.slate800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Delete Recording',
          style: TextStyle(color: WhisperColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete "${conversation.title}"?',
          style: TextStyle(color: WhisperColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: WhisperColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(conversationListProvider.notifier)
                  .deleteConversation(conversation.id);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: WhisperColors.rose),
            ),
          ),
        ],
      ),
    );
  }
}
