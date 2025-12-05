import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/gemini_service.dart';
import '../../data/models/conversation_model.dart';
import '../../data/models/folder_model.dart';
import '../../data/repositories/conversation_repository.dart';
import '../providers/conversation_list_provider.dart';
import '../providers/folder_provider.dart';
import '../widgets/conversation_card.dart';
import '../widgets/mode_selection_sheet.dart';
import 'recording_screen.dart';
import 'detail_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isProcessing = false;
  String _searchQuery = '';
  bool _showStarredOnly = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(conversationListProvider);
    ref.invalidate(folderListProvider);
  }

  List<Conversation> _filterConversations(
    List<Conversation> conversations,
    String? selectedFolderId,
  ) {
    var filtered = conversations;

    // Filter by folder
    if (selectedFolderId != null) {
      filtered = filtered.where((c) => c.folderId == selectedFolderId).toList();
    }

    // Filter by starred
    if (_showStarredOnly) {
      filtered = filtered.where((c) => c.isStarred).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((c) {
        // Search in title
        if (c.title.toLowerCase().contains(query)) return true;
        // Search in subtitle
        if (c.subtitle?.toLowerCase().contains(query) ?? false) return true;
        // Search in transcript
        if (c.transcript?.fullText.toLowerCase().contains(query) ?? false) return true;
        // Search in AI result titles
        if (c.aiResult?.titleEn.toLowerCase().contains(query) ?? false) return true;
        if (c.aiResult?.titleAr.toLowerCase().contains(query) ?? false) return true;
        return false;
      }).toList();
    }

    return filtered;
  }

  /// Detects the primary language of the transcript based on Arabic character ratio
  String _detectLanguage(String text) {
    if (text.isEmpty) return 'en';

    // Count Arabic characters (Unicode range for Arabic)
    final arabicRegex = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]');
    final arabicChars = arabicRegex.allMatches(text).length;
    final totalChars = text.replaceAll(RegExp(r'\s'), '').length;

    if (totalChars == 0) return 'en';

    final arabicRatio = arabicChars / totalChars;

    if (arabicRatio > 0.5) return 'ar';
    if (arabicRatio > 0.2) return 'mixed';
    return 'en';
  }

  Future<void> _processRecording(String path, ConversationType type, int durationMs) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final geminiService = ref.read(geminiServiceProvider);
      final settings = ref.read(settingsProvider);

      // 1. Transcribe
      final transcriptText = await geminiService.transcribeAudio(path);

      // 2. Generate AI Result
      final aiResult = await geminiService.generateSummary(transcriptText);

      // 3. Detect language
      final detectedLanguage = _detectLanguage(transcriptText);

      // 4. Check if we should delete the audio after transcription
      final shouldDeleteAudio = settings.deleteAudioAfterTranscription;

      // 5. Create Conversation
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
        audioSegments: shouldDeleteAudio ? [] : [
          AudioSegment(filePath: path, durationMs: durationMs),
        ],
        transcript: Transcript(fullText: transcriptText, languageCode: detectedLanguage),
        aiResult: aiResult,
      );

      // 6. Save conversation
      await ref
          .read(conversationListProvider.notifier)
          .addConversation(conversation);

      // 7. Delete audio file if privacy mode is enabled
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
          await Navigator.push<({String path, ConversationType type, int durationMs})?>(
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

  void _showFolderManagement() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => _FolderManagementSheet(
        onFolderSelected: (folderId) {
          ref.read(selectedFolderProvider.notifier).select(folderId);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showMoveToFolderDialog(Conversation conversation) {
    final folders = ref.read(folderListProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Move to Folder',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.folder_off, color: Colors.white),
              title: const Text('No Folder', style: TextStyle(color: Colors.white)),
              selected: conversation.folderId == null,
              onTap: () {
                _moveToFolder(conversation, null);
                Navigator.pop(context);
              },
            ),
            ...folders.map((folder) => ListTile(
                  leading: const Icon(Icons.folder, color: Color(0xFF6366F1)),
                  title: Text(folder.name, style: const TextStyle(color: Colors.white)),
                  selected: conversation.folderId == folder.id,
                  onTap: () {
                    _moveToFolder(conversation, folder.id);
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _moveToFolder(Conversation conversation, String? folderId) {
    final updatedConversation = conversation.copyWith(
      folderId: folderId,
      updatedAt: DateTime.now(),
    );
    ref.read(conversationRepositoryProvider).saveConversation(updatedConversation);
    ref.invalidate(conversationListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final allConversations = ref.watch(conversationListProvider);
    final folders = ref.watch(folderListProvider);
    final selectedFolderId = ref.watch(selectedFolderProvider);
    final conversations = _filterConversations(allConversations, selectedFolderId);
    final selectedFolder = selectedFolderId != null
        ? folders.firstWhere((f) => f.id == selectedFolderId, orElse: () => Folder(id: '', name: '', createdAt: DateTime.now(), updatedAt: DateTime.now()))
        : null;

    return Scaffold(
      appBar: AppBar(
        title: selectedFolder != null && selectedFolder.id.isNotEmpty
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      ref.read(selectedFolderProvider.notifier).select(null);
                    },
                  ),
                  Text(selectedFolder.name),
                ],
              )
            : const Text('Callout'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder),
            onPressed: _showFolderManagement,
            tooltip: 'Folders',
          ),
          if (allConversations.any((c) => c.isStarred))
            IconButton(
              icon: Icon(
                _showStarredOnly ? Icons.star : Icons.star_border,
                color: _showStarredOnly ? Colors.amber : null,
              ),
              onPressed: () {
                setState(() {
                  _showStarredOnly = !_showStarredOnly;
                });
              },
              tooltip: _showStarredOnly ? 'Show all' : 'Show starred only',
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
        ],
        bottom: allConversations.isNotEmpty
            ? PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search recordings...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: Colors.white.withOpacity(0.5),
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside
          _searchFocusNode.unfocus();
        },
        child: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF6366F1)),
                  const SizedBox(height: 16),
                  Text(
                    'Processing recording with AI...',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              color: const Color(0xFF6366F1),
              child: CustomScrollView(
              slivers: [
                // Folders section (only show when not in a folder)
                if (selectedFolderId == null && folders.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'Folders',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: folders.length,
                            itemBuilder: (context, index) {
                              final folder = folders[index];
                              final folderConversations = allConversations
                                  .where((c) => c.folderId == folder.id)
                                  .length;
                              final folderColor = folder.color != null
                                  ? Color(int.parse(folder.color!.replaceFirst('#', '0xFF')))
                                  : const Color(0xFF6366F1);
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: InkWell(
                                  onTap: () {
                                    ref.read(selectedFolderProvider.notifier).select(folder.id);
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    width: 100,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: folderColor.withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.folder,
                                          color: folderColor,
                                          size: 32,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          folder.name,
                                          style: const TextStyle(
                                            color: Color(0xFFF8FAFC),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                        Text(
                                          '$folderConversations items',
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Text(
                            'Recordings',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Empty state
                if (conversations.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                              ),
                            ),
                            child: const Icon(
                              Icons.mic_none_rounded,
                              size: 64,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No recordings yet',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the button below to start recording',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  // Conversations list
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final conversation = conversations[index];
                          return ConversationCard(
                            conversation: conversation,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      DetailScreen(conversation: conversation),
                                ),
                              );
                            },
                            onLongPress: () => _showMoveToFolderDialog(conversation),
                            onDelete: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E293B),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  title: const Text(
                                    'Delete Recording',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  content: Text(
                                    'Are you sure you want to delete "${conversation.title}"? This action cannot be undone.',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text(
                                        'Cancel',
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
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
                                        style: TextStyle(color: Color(0xFFEF4444)),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
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
      floatingActionButton: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: _showModeSelection,
            child: const Icon(Icons.add_rounded, size: 40, color: Colors.white),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _FolderManagementSheet extends ConsumerStatefulWidget {
  final Function(String?) onFolderSelected;

  const _FolderManagementSheet({required this.onFolderSelected});

  @override
  ConsumerState<_FolderManagementSheet> createState() =>
      _FolderManagementSheetState();
}

class _FolderManagementSheetState extends ConsumerState<_FolderManagementSheet> {
  final TextEditingController _folderNameController = TextEditingController();
  bool _isCreating = false;
  String _selectedColor = '#6366F1';

  static const List<String> _folderColors = [
    '#6366F1', // Indigo
    '#8B5CF6', // Purple
    '#EC4899', // Pink
    '#EF4444', // Red
    '#F97316', // Orange
    '#EAB308', // Yellow
    '#22C55E', // Green
    '#14B8A6', // Teal
    '#3B82F6', // Blue
    '#6B7280', // Gray
  ];

  @override
  void dispose() {
    _folderNameController.dispose();
    super.dispose();
  }

  void _createFolder() {
    if (_folderNameController.text.trim().isEmpty) return;

    final folder = Folder(
      id: const Uuid().v4(),
      name: _folderNameController.text.trim(),
      color: _selectedColor,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    ref.read(folderListProvider.notifier).addFolder(folder);
    _folderNameController.clear();
    setState(() {
      _isCreating = false;
      _selectedColor = '#6366F1';
    });
  }

  void _deleteFolder(Folder folder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Folder', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete "${folder.name}"? Recordings in this folder will not be deleted.',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.7))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(folderListProvider.notifier).deleteFolder(folder.id);
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final folders = ref.watch(folderListProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF64748B),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Folders',
                  style: TextStyle(
                    color: Color(0xFFF8FAFC),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isCreating ? Icons.close : Icons.add,
                    color: const Color(0xFFF8FAFC),
                  ),
                  onPressed: () => setState(() => _isCreating = !_isCreating),
                ),
              ],
            ),
          ),
          if (_isCreating) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _folderNameController,
                          autofocus: true,
                          style: const TextStyle(color: Color(0xFFF8FAFC)),
                          decoration: InputDecoration(
                            hintText: 'Folder name',
                            hintStyle: const TextStyle(color: Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _createFolder(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _createFolder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        child: const Text('Create'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Color',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _folderColors.map((colorHex) {
                      final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
                      final isSelected = _selectedColor == colorHex;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = colorHex),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 2)
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              controller: scrollController,
              children: [
                ListTile(
                  leading: const Icon(Icons.folder_off, color: Color(0xFF94A3B8)),
                  title: const Text('All Recordings', style: TextStyle(color: Color(0xFFF8FAFC))),
                  onTap: () => widget.onFolderSelected(null),
                ),
                ...folders.map((folder) {
                  final folderColor = folder.color != null
                      ? Color(int.parse(folder.color!.replaceFirst('#', '0xFF')))
                      : const Color(0xFF6366F1);
                  return ListTile(
                    leading: Icon(Icons.folder, color: folderColor),
                    title: Text(folder.name, style: const TextStyle(color: Color(0xFFF8FAFC))),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Color(0xFF64748B)),
                      onPressed: () => _deleteFolder(folder),
                    ),
                    onTap: () => widget.onFolderSelected(folder.id),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
