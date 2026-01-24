import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/conversation_model.dart';
import '../../data/models/folder_model.dart';
import '../../data/repositories/conversation_repository.dart';
import '../providers/audio_player_provider.dart';
import '../providers/conversation_list_provider.dart';
import '../providers/folder_provider.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/services/gemini_service.dart';
import '../../../../core/services/tts_manager.dart';
import '../../../reminders/presentation/widgets/add_reminder_dialog.dart';
import 'recording_screen.dart';
import '../../../../core/theme/whisper_colors.dart';
import '../../../../core/widgets/glassmorphic_card.dart';

class DetailScreen extends ConsumerStatefulWidget {
  final Conversation conversation;

  const DetailScreen({super.key, required this.conversation});

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen> {
  bool _showEnglish = true;
  bool _isEditingSummary = false;
  bool _isEditingPoints = false;
  bool _isEditingTodos = false;
  bool _isAddingRecording = false;
  bool _isTtsPlaying = false;
  String? _currentTtsSection;
  String? _translatedText;
  String? _translatedSection;
  String? _selectedLanguage;
  late Conversation _conversation;

  // Edit controllers
  late TextEditingController _titleController;
  late TextEditingController _summaryController;
  late List<TextEditingController> _pointsControllers;
  late List<TextEditingController> _todosControllers;

  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    _initEditControllers();
  }

  void _initEditControllers() {
    final aiResult = _conversation.aiResult;
    _titleController = TextEditingController(
      text: _showEnglish ? aiResult?.titleEn ?? '' : aiResult?.titleAr ?? '',
    );
    _summaryController = TextEditingController(
      text: _showEnglish
          ? aiResult?.summaryEn ?? ''
          : aiResult?.summaryAr ?? '',
    );
    _pointsControllers =
        (_showEnglish
                ? aiResult?.bulletPointsEn ?? []
                : aiResult?.bulletPointsAr ?? [])
            .map((p) => TextEditingController(text: p))
            .toList();
    _todosControllers =
        (_showEnglish ? aiResult?.todosEn ?? [] : aiResult?.todosAr ?? [])
            .map((t) => TextEditingController(text: t))
            .toList();
  }

  void _disposeEditControllers() {
    _titleController.dispose();
    _summaryController.dispose();
    for (final c in _pointsControllers) {
      c.dispose();
    }
    for (final c in _todosControllers) {
      c.dispose();
    }
  }

  @override
  void dispose() {
    // Note: Can't use ref.read after widget is disposed, so we don't stop audio here
    // The audio player will stop naturally when navigating away
    _disposeEditControllers();
    super.dispose();
  }

  Future<void> _speakText(String text, String section) async {
    final ttsManager = ref.read(ttsManagerProvider);

    debugPrint('UI: _speakText called for section: $section');

    // If already playing this section, stop it
    if (_isTtsPlaying && _currentTtsSection == section) {
      debugPrint('UI: Stopping current TTS');
      await ttsManager.stop();
      if (mounted) {
        setState(() {
          _isTtsPlaying = false;
          _currentTtsSection = null;
        });
      }
      return;
    }

    // Stop any current speech first
    await ttsManager.stop();

    if (mounted) {
      setState(() {
        _isTtsPlaying = true;
        _currentTtsSection = section;
      });
    }

    // Determine language from current view setting
    final language = _showEnglish ? 'en' : 'ar';
    debugPrint('UI: Speaking with language: $language');

    // Speak in a separate async call
    _performSpeak(ttsManager, text, language, section);
  }

  Future<void> _performSpeak(
    TtsManager ttsManager,
    String text,
    String language,
    String section,
  ) async {
    try {
      debugPrint('UI: Calling ttsManager.speak()');
      await ttsManager.speak(text, language: language);
      debugPrint('UI: TTS speak completed successfully');

      if (mounted) {
        setState(() {
          _isTtsPlaying = false;
          _currentTtsSection = null;
        });
      }
    } catch (e) {
      debugPrint('UI: TTS Error: $e');
      if (mounted) {
        setState(() {
          _isTtsPlaying = false;
          _currentTtsSection = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Speech Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopTts() async {
    final ttsManager = ref.read(ttsManagerProvider);
    await ttsManager.stop();
    if (mounted) {
      setState(() {
        _isTtsPlaying = false;
        _currentTtsSection = null;
      });
    }
  }

  void _showTranslateDialog(String text, String section) {
    showModalBottomSheet(
      context: context,
      backgroundColor: WhisperColors.slate800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => _TranslateSheet(
          text: text,
          section: section,
          scrollController: scrollController,
          onTranslate: (translatedText, language) {
            setState(() {
              _translatedText = translatedText;
              _translatedSection = section;
              _selectedLanguage = language;
            });
          },
        ),
      ),
    );
  }

  void _clearTranslation() {
    setState(() {
      _translatedText = null;
      _translatedSection = null;
      _selectedLanguage = null;
    });
  }

  void _showConversationSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: WhisperColors.slate800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) => _ConversationSettingsSheet(
        conversation: _conversation,
        onUpdate: (updatedConversation) {
          setState(() {
            _conversation = updatedConversation;
          });
          ref
              .read(conversationRepositoryProvider)
              .saveConversation(updatedConversation);
          ref.invalidate(conversationListProvider);
        },
      ),
    );
  }

  String? get _audioPath {
    final segments = _conversation.audioSegments;
    if (segments.isNotEmpty) {
      return segments.first.filePath;
    }
    return null;
  }

  String _formatCopyText() {
    final aiResult = _conversation.aiResult;

    final buffer = StringBuffer();

    // Title
    buffer.writeln(_conversation.title);
    buffer.writeln('');

    // Summary
    if (aiResult != null) {
      buffer.writeln('Summary:');
      buffer.writeln(_showEnglish ? aiResult.summaryEn : aiResult.summaryAr);
      buffer.writeln('');

      // Bullet Points
      final bullets = _showEnglish
          ? aiResult.bulletPointsEn
          : aiResult.bulletPointsAr;
      if (bullets.isNotEmpty) {
        buffer.writeln('Key Points:');
        for (final point in bullets) {
          buffer.writeln('• $point');
        }
        buffer.writeln('');
      }

      // TODOs
      final todos = _showEnglish ? aiResult.todosEn : aiResult.todosAr;
      if (todos.isNotEmpty) {
        buffer.writeln('Action Items:');
        for (final todo in todos) {
          buffer.writeln('☐ $todo');
        }
      }
    }

    return buffer.toString();
  }

  void _toggleStar() {
    final updatedConversation = _conversation.copyWith(
      isStarred: !_conversation.isStarred,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _conversation = updatedConversation;
    });

    ref
        .read(conversationRepositoryProvider)
        .saveConversation(updatedConversation);
  }

  void _toggleTodo(int index, bool? value) {
    if (_conversation.aiResult == null) return;

    final aiResult = _conversation.aiResult!;
    List<bool> updatedCompletedAr = List.from(aiResult.todosCompletedAr);
    List<bool> updatedCompletedEn = List.from(aiResult.todosCompletedEn);

    if (_showEnglish) {
      updatedCompletedEn[index] = value ?? false;
    } else {
      updatedCompletedAr[index] = value ?? false;
    }

    final updatedAiResult = aiResult.copyWith(
      todosCompletedAr: updatedCompletedAr,
      todosCompletedEn: updatedCompletedEn,
    );

    final updatedConversation = _conversation.copyWith(
      aiResult: updatedAiResult,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _conversation = updatedConversation;
    });

    // Save to database
    ref
        .read(conversationRepositoryProvider)
        .saveConversation(updatedConversation);
  }

  void _saveSummary() {
    if (_conversation.aiResult == null) return;

    final aiResult = _conversation.aiResult!;
    final updatedAiResult = _showEnglish
        ? aiResult.copyWith(summaryEn: _summaryController.text)
        : aiResult.copyWith(summaryAr: _summaryController.text);

    final updatedConversation = _conversation.copyWith(
      aiResult: updatedAiResult,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _conversation = updatedConversation;
      _isEditingSummary = false;
    });

    ref
        .read(conversationRepositoryProvider)
        .saveConversation(updatedConversation);
  }

  void _savePoints() {
    if (_conversation.aiResult == null) return;

    final aiResult = _conversation.aiResult!;
    final newPoints = _pointsControllers.map((c) => c.text).toList();
    final updatedAiResult = _showEnglish
        ? aiResult.copyWith(bulletPointsEn: newPoints)
        : aiResult.copyWith(bulletPointsAr: newPoints);

    final updatedConversation = _conversation.copyWith(
      aiResult: updatedAiResult,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _conversation = updatedConversation;
      _isEditingPoints = false;
    });

    ref
        .read(conversationRepositoryProvider)
        .saveConversation(updatedConversation);
  }

  void _saveTodos() {
    if (_conversation.aiResult == null) return;

    final aiResult = _conversation.aiResult!;
    final newTodos = _todosControllers.map((c) => c.text).toList();
    final updatedAiResult = _showEnglish
        ? aiResult.copyWith(
            todosEn: newTodos,
            todosCompletedEn: List.filled(newTodos.length, false),
          )
        : aiResult.copyWith(
            todosAr: newTodos,
            todosCompletedAr: List.filled(newTodos.length, false),
          );

    final updatedConversation = _conversation.copyWith(
      aiResult: updatedAiResult,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _conversation = updatedConversation;
      _isEditingTodos = false;
    });

    ref
        .read(conversationRepositoryProvider)
        .saveConversation(updatedConversation);
  }

  void _addPoint() {
    setState(() {
      _pointsControllers.add(TextEditingController());
    });
  }

  void _removePoint(int index) {
    setState(() {
      _pointsControllers[index].dispose();
      _pointsControllers.removeAt(index);
    });
  }

  void _addTodo() {
    setState(() {
      _todosControllers.add(TextEditingController());
    });
  }

  void _removeTodo(int index) {
    setState(() {
      _todosControllers[index].dispose();
      _todosControllers.removeAt(index);
    });
  }

  void _cancelEdit(String section) {
    // Reinitialize controllers with original data
    _disposeEditControllers();
    _initEditControllers();
    setState(() {
      switch (section) {
        case 'summary':
          _isEditingSummary = false;
          break;
        case 'points':
          _isEditingPoints = false;
          break;
        case 'todos':
          _isEditingTodos = false;
          break;
      }
    });
  }

  Future<void> _addRecording() async {
    final result =
        await Navigator.push<
          ({String path, ConversationType type, int durationMs})
        >(
          context,
          MaterialPageRoute(
            builder: (context) => RecordingScreen(mode: _conversation.type),
          ),
        );

    if (result == null || !mounted) return;

    setState(() => _isAddingRecording = true);

    try {
      final geminiService = ref.read(geminiServiceProvider);

      // Transcribe the new recording
      final newTranscriptText = await geminiService.transcribeAudio(
        result.path,
      );

      // Combine transcripts
      final existingTranscript = _conversation.transcript?.fullText ?? '';
      final combinedTranscript = existingTranscript.isEmpty
          ? newTranscriptText
          : '$existingTranscript\n\n--- New Recording ---\n\n$newTranscriptText';

      // Option: Re-process with AI to get updated summary
      final updatedAiResult = await geminiService.generateSummary(
        combinedTranscript,
      );

      // Create new audio segment
      final newSegment = AudioSegment(
        filePath: result.path,
        durationMs: result.durationMs,
      );

      // Update conversation
      final updatedConversation = _conversation.copyWith(
        audioSegments: [..._conversation.audioSegments, newSegment],
        transcript: Transcript(
          fullText: combinedTranscript,
          languageCode: _conversation.transcript?.languageCode ?? 'en',
        ),
        aiResult: updatedAiResult,
        title: updatedAiResult.titleEn.isNotEmpty
            ? updatedAiResult.titleEn
            : _conversation.title,
        updatedAt: DateTime.now(),
      );

      // Save to database
      await ref
          .read(conversationRepositoryProvider)
          .saveConversation(updatedConversation);
      ref.invalidate(conversationListProvider);

      setState(() {
        _conversation = updatedConversation;
        _disposeEditControllers();
        _initEditControllers();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding recording: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingRecording = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiResult = _conversation.aiResult;
    final transcript = _conversation.transcript;
    final playerState = ref.watch(audioPlayerControllerProvider);
    final positionAsync = ref.watch(audioPositionProvider);
    final durationAsync = ref.watch(audioDurationProvider);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: WhisperColors.slate900,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: WhisperColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            _showEnglish ? aiResult?.titleEn ?? '' : aiResult?.titleAr ?? '',
            style: const TextStyle(
              color: WhisperColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _conversation.isStarred
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: _conversation.isStarred ? WhisperColors.amber : WhisperColors.textPrimary,
              ),
              onPressed: _toggleStar,
            ),
            // Language toggle chip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showEnglish = !_showEnglish;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: WhisperColors.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: WhisperColors.cardBorder),
                  ),
                  child: Text(
                    _showEnglish ? 'EN' : 'AR',
                    style: const TextStyle(
                      color: WhisperColors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_horiz_rounded, color: WhisperColors.textPrimary),
              onPressed: _showConversationSettings,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: WhisperColors.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: WhisperColors.cardBorder),
              ),
              child: TabBar(
                isScrollable: false,
                labelColor: WhisperColors.amber,
                unselectedLabelColor: WhisperColors.textSecondary,
                indicator: BoxDecoration(
                  color: WhisperColors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerHeight: 0,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(text: 'Summary'),
                  Tab(text: 'Analysis'),
                  Tab(text: 'Tasks'),
                  Tab(text: 'Transcript'),
                ],
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            // Audio Player Controls - Glassmorphic
            if (_audioPath != null)
              Container(
                margin: const EdgeInsets.all(16),
                child: GlassmorphicCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: WhisperColors.amber,
                          inactiveTrackColor: WhisperColors.cardBorder,
                          thumbColor: WhisperColors.amber,
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 16,
                          ),
                        ),
                        child: Slider(
                          value: positionAsync.when(
                            data: (pos) => pos.inMilliseconds.toDouble(),
                            loading: () => 0,
                            error: (_, __) => 0,
                          ),
                          max: durationAsync.when(
                            data: (dur) => dur.inMilliseconds.toDouble().clamp(
                              1,
                              double.infinity,
                            ),
                            loading: () => 1,
                            error: (_, __) => 1,
                          ),
                          onChanged: (value) {
                            ref
                                .read(audioPlayerControllerProvider.notifier)
                                .seek(Duration(milliseconds: value.toInt()));
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            positionAsync.when(
                              data: (pos) => formatDuration(pos.inSeconds),
                              loading: () => '0:00',
                              error: (_, __) => '0:00',
                            ),
                            style: TextStyle(
                              color: WhisperColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Row(
                            children: [
                              _buildPlayerButton(
                                icon: Icons.replay_10_rounded,
                                onPressed: () {
                                  positionAsync.whenData((pos) {
                                    final newPos =
                                        pos - const Duration(seconds: 15);
                                    ref
                                        .read(
                                          audioPlayerControllerProvider.notifier,
                                        )
                                        .seek(
                                          newPos < Duration.zero
                                              ? Duration.zero
                                              : newPos,
                                        );
                                  });
                                },
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () {
                                  final controller = ref.read(
                                    audioPlayerControllerProvider.notifier,
                                  );
                                  if (playerState == PlayerState.playing) {
                                    controller.pause();
                                  } else if (playerState == PlayerState.paused) {
                                    controller.resume();
                                  } else {
                                    controller.play(_audioPath!);
                                  }
                                },
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: WhisperColors.emeraldGradient,
                                    boxShadow: [
                                      BoxShadow(
                                        color: WhisperColors.emerald.withOpacity(0.3),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    playerState == PlayerState.playing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              _buildPlayerButton(
                                icon: Icons.forward_10_rounded,
                                onPressed: () {
                                  positionAsync.whenData((pos) {
                                    durationAsync.whenData((dur) {
                                      final newPos =
                                          pos + const Duration(seconds: 15);
                                      ref
                                          .read(
                                            audioPlayerControllerProvider
                                                .notifier,
                                          )
                                          .seek(newPos > dur ? dur : newPos);
                                    });
                                  });
                                },
                              ),
                            ],
                          ),
                          Text(
                            durationAsync.when(
                              data: (dur) => formatDuration(dur.inSeconds),
                              loading: () => '0:00',
                              error: (_, __) => '0:00',
                            ),
                            style: TextStyle(
                              color: WhisperColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            // Tab Content
            Expanded(
              child: TabBarView(
                children: [
                  // Summary Tab
                  _buildSummaryTab(aiResult),
                  // Bullet Points Tab
                  _buildPointsTab(aiResult),
                  // Todos Tab
                  _buildTodosTab(aiResult),
                  // Transcript Tab
                  _buildTranscriptTab(transcript),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: _isAddingRecording
            ? Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: WhisperColors.slate800,
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: WhisperColors.amber),
                ),
              )
            : Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: WhisperColors.amberGradient,
                  boxShadow: [
                    BoxShadow(
                      color: WhisperColors.amber.withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(35),
                    onTap: _addRecording,
                    child: const Center(
                      child: Icon(Icons.add_rounded, size: 36, color: WhisperColors.slate900),
                    ),
                  ),
                ),
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildPlayerButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: WhisperColors.cardBg,
        border: Border.all(color: WhisperColors.cardBorder),
      ),
      child: IconButton(
        icon: Icon(icon, size: 22, color: WhisperColors.textPrimary),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildSummaryTab(AiResult? aiResult) {
    if (_isEditingSummary) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: GlassmorphicCard(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _summaryController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(color: WhisperColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Enter summary...',
                    hintStyle: TextStyle(color: WhisperColors.textMuted),
                    border: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _cancelEdit('summary'),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: WhisperColors.textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saveSummary,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WhisperColors.emerald,
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final summaryText = _showEnglish
        ? aiResult?.summaryEn ?? ''
        : aiResult?.summaryAr ?? '';

    // Show translated text if available for this section
    final displayText =
        (_translatedSection == 'summary' && _translatedText != null)
        ? _translatedText!
        : summaryText;
    final isShowingTranslation =
        _translatedSection == 'summary' && _translatedText != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Translation badge
          if (isShowingTranslation)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: WhisperColors.purple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: WhisperColors.purple.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.translate, size: 16, color: WhisperColors.purple),
                  const SizedBox(width: 6),
                  Text(
                    'Translated to $_selectedLanguage',
                    style: const TextStyle(
                      color: WhisperColors.purple,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _clearTranslation,
                    child: const Icon(Icons.close, size: 16, color: WhisperColors.purple),
                  ),
                ],
              ),
            ),
          // Content card
          GlassmorphicCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayText,
                  style: const TextStyle(
                    color: WhisperColors.textPrimary,
                    fontSize: 16,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 20),
                // Action buttons
                Row(
                  children: [
                    if (summaryText.isNotEmpty) ...[
                      _buildActionButton(
                        icon: Icons.translate,
                        color: WhisperColors.purple,
                        onTap: () => _showTranslateDialog(summaryText, 'summary'),
                        tooltip: 'Translate',
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (displayText.isNotEmpty) ...[
                      _buildActionButton(
                        icon: _currentTtsSection == 'summary'
                            ? Icons.stop_rounded
                            : Icons.volume_up_rounded,
                        color: _currentTtsSection == 'summary'
                            ? WhisperColors.rose
                            : WhisperColors.emerald,
                        onTap: () => _speakText(displayText, 'summary'),
                        tooltip: 'Read aloud',
                      ),
                      const SizedBox(width: 8),
                    ],
                    _buildActionButton(
                      icon: Icons.edit_rounded,
                      color: WhisperColors.amber,
                      onTap: () {
                        _summaryController.text = summaryText;
                        setState(() => _isEditingSummary = true);
                      },
                      tooltip: 'Edit',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, size: 20, color: color),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPointsTab(AiResult? aiResult) {
    if (_isEditingPoints) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _pointsControllers.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassmorphicCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.circle,
                            size: 8,
                            color: WhisperColors.purple,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _pointsControllers[index],
                              style: const TextStyle(
                                color: WhisperColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                filled: false,
                                hintText: 'Enter point...',
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline_rounded,
                              color: WhisperColors.rose,
                            ),
                            onPressed: () => _removePoint(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _addPoint,
                  icon: const Icon(Icons.add_rounded, color: WhisperColors.purple),
                  label: const Text(
                    'Add Point',
                    style: TextStyle(
                      color: WhisperColors.purple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _cancelEdit('points'),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: WhisperColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _savePoints,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WhisperColors.emerald,
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    }

    final points = _showEnglish
        ? aiResult?.bulletPointsEn ?? []
        : aiResult?.bulletPointsAr ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Edit button
          Align(
            alignment: Alignment.centerRight,
            child: _buildActionButton(
              icon: Icons.edit_rounded,
              color: WhisperColors.amber,
              onTap: () {
                _pointsControllers = points
                    .map((p) => TextEditingController(text: p))
                    .toList();
                setState(() => _isEditingPoints = true);
              },
              tooltip: 'Edit',
            ),
          ),
          const SizedBox(height: 12),
          // Points card
          GlassmorphicCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: points.asMap().entries.map((entry) {
                final index = entry.key;
                final point = entry.value;
                return Padding(
                  padding: EdgeInsets.only(bottom: index < points.length - 1 ? 16 : 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 7),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: WhisperColors.purple,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          point,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            color: WhisperColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodosTab(AiResult? aiResult) {
    if (_isEditingTodos) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _todosControllers.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassmorphicCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_box_outline_blank_rounded,
                            size: 20,
                            color: WhisperColors.amber,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _todosControllers[index],
                              style: const TextStyle(
                                color: WhisperColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                filled: false,
                                hintText: 'Enter task...',
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline_rounded,
                              color: WhisperColors.rose,
                            ),
                            onPressed: () => _removeTodo(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _addTodo,
                  icon: const Icon(Icons.add_rounded, color: WhisperColors.amber),
                  label: const Text(
                    'Add Task',
                    style: TextStyle(
                      color: WhisperColors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _cancelEdit('todos'),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: WhisperColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saveTodos,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: WhisperColors.emerald,
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    }

    final todos = _showEnglish
        ? aiResult?.todosEn ?? []
        : aiResult?.todosAr ?? [];
    final completed = _showEnglish
        ? aiResult?.todosCompletedEn ?? []
        : aiResult?.todosCompletedAr ?? [];

    // Calculate progress
    final completedCount = completed.where((c) => c).length;
    final totalCount = todos.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with progress and edit button
          Row(
            children: [
              Expanded(
                child: GlassmorphicCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: Stack(
                          children: [
                            CircularProgressIndicator(
                              value: progress,
                              backgroundColor: WhisperColors.cardBorder,
                              color: WhisperColors.emerald,
                              strokeWidth: 3,
                            ),
                            Center(
                              child: Text(
                                '$completedCount',
                                style: const TextStyle(
                                  color: WhisperColors.emerald,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$completedCount of $totalCount completed',
                            style: const TextStyle(
                              color: WhisperColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${(progress * 100).toInt()}% done',
                            style: TextStyle(
                              color: WhisperColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildActionButton(
                icon: Icons.edit_rounded,
                color: WhisperColors.amber,
                onTap: () {
                  _todosControllers = todos
                      .map((t) => TextEditingController(text: t))
                      .toList();
                  setState(() => _isEditingTodos = true);
                },
                tooltip: 'Edit',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Tasks list
          ...List.generate(todos.length, (index) {
            final isCompleted = index < completed.length
                ? completed[index]
                : false;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassmorphicCard(
                backgroundColor: isCompleted
                    ? WhisperColors.emerald.withOpacity(0.05)
                    : null,
                borderColor: isCompleted
                    ? WhisperColors.emerald.withOpacity(0.2)
                    : null,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Checkbox(
                    value: isCompleted,
                    onChanged: (val) => _toggleTodo(index, val),
                    activeColor: WhisperColors.emerald,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    side: BorderSide(
                      color: isCompleted
                          ? WhisperColors.emerald
                          : WhisperColors.cardBorder,
                      width: 2,
                    ),
                  ),
                  title: Text(
                    todos[index],
                    style: TextStyle(
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: isCompleted
                          ? WhisperColors.textMuted
                          : WhisperColors.textPrimary,
                      fontWeight: isCompleted
                          ? FontWeight.normal
                          : FontWeight.w500,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      size: 22,
                      color: WhisperColors.purple,
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AddReminderDialog(
                          conversationId: _conversation.id,
                          todoText: todos[index],
                          initialTitle: todos[index],
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTranscriptTab(Transcript? transcript) {
    var transcriptText = transcript?.fullText ?? '';

    final displayText =
        (_translatedSection == 'transcript' && _translatedText != null)
        ? _translatedText!
        : transcriptText;
    final isShowingTranslation =
        _translatedSection == 'transcript' && _translatedText != null;

    if (displayText.isEmpty) {
      return Center(
        child: Text(
          'No transcript available.',
          style: TextStyle(color: WhisperColors.textMuted),
        ),
      );
    }

    // Split text by common speaker label patterns (e.g. "Speaker 0:", "Speaker 1:")
    final speakerRegex = RegExp(r'(Speaker \d+):');
    final parts = displayText.split(speakerRegex);
    final speakers = speakerRegex
        .allMatches(displayText)
        .map((m) => m.group(1))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with translation badge and actions
          if (isShowingTranslation)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: WhisperColors.purple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: WhisperColors.purple.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.translate, size: 16, color: WhisperColors.purple),
                  const SizedBox(width: 6),
                  Text(
                    'Translated to $_selectedLanguage',
                    style: const TextStyle(
                      color: WhisperColors.purple,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _clearTranslation,
                    child: const Icon(Icons.close, size: 16, color: WhisperColors.purple),
                  ),
                ],
              ),
            ),
          // Action buttons
          Row(
            children: [
              const Spacer(),
              _buildActionButton(
                icon: Icons.translate_rounded,
                color: WhisperColors.purple,
                onTap: () => _showTranslateDialog(transcriptText, 'transcript'),
                tooltip: 'Translate',
              ),
              const SizedBox(width: 8),
              _buildActionButton(
                icon: _currentTtsSection == 'transcript'
                    ? Icons.stop_rounded
                    : Icons.volume_up_rounded,
                color: _currentTtsSection == 'transcript'
                    ? WhisperColors.rose
                    : WhisperColors.emerald,
                onTap: () => _speakText(displayText, 'transcript'),
                tooltip: 'Read aloud',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Transcript content
          GlassmorphicCard(
            padding: const EdgeInsets.all(20),
            child: speakers.isEmpty
                ? SelectableText(
                    displayText,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.7,
                      color: WhisperColors.textPrimary,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(speakers.length, (index) {
                      final speakerName = speakers[index];
                      final speakerIndex =
                          int.tryParse(
                            speakerName?.replaceAll(RegExp(r'\D'), '') ?? '0',
                          ) ??
                          0;
                      final speakerColors = [
                        WhisperColors.amber,
                        WhisperColors.purple,
                        WhisperColors.emerald,
                        WhisperColors.folderColors[3],
                      ];
                      final speakerColor = speakerColors[speakerIndex % speakerColors.length];
                      final content = index + 1 < parts.length
                          ? parts[index + 1].trim()
                          : '';

                      return Padding(
                        padding: EdgeInsets.only(bottom: index < speakers.length - 1 ? 24 : 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: speakerColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: speakerColor.withOpacity(0.4),
                                ),
                              ),
                              child: Text(
                                speakerName ?? 'Unknown',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: speakerColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SelectableText(
                              content,
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.7,
                                color: WhisperColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TranslateSheet extends ConsumerStatefulWidget {
  final String text;
  final String section;
  final ScrollController scrollController;
  final Function(String translatedText, String language) onTranslate;

  const _TranslateSheet({
    required this.text,
    required this.section,
    required this.scrollController,
    required this.onTranslate,
  });

  @override
  ConsumerState<_TranslateSheet> createState() => _TranslateSheetState();
}

class _TranslateSheetState extends ConsumerState<_TranslateSheet> {
  String? _selectedLanguage;
  String? _translatedText;
  bool _isTranslating = false;
  String? _error;

  Future<void> _translate() async {
    if (_selectedLanguage == null) return;

    setState(() {
      _isTranslating = true;
      _error = null;
    });

    try {
      final geminiService = ref.read(geminiServiceProvider);
      final translated = await geminiService.translateWithContext(
        widget.text,
        _selectedLanguage!,
        context: widget.section,
      );

      setState(() {
        _translatedText = translated;
        _isTranslating = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Translation failed: $e';
        _isTranslating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: WhisperColors.slate800,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: WhisperColors.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Translate',
            style: TextStyle(
              color: WhisperColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: GeminiService.supportedLanguages.map((lang) {
                final isSelected = _selectedLanguage == lang['name'];
                return ChoiceChip(
                  label: Text(lang['name']!),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedLanguage = selected ? lang['name'] : null;
                      _translatedText = null;
                    });
                  },
                  selectedColor: WhisperColors.purple.withOpacity(0.2),
                  backgroundColor: WhisperColors.cardBg,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? WhisperColors.purple
                        : WhisperColors.textSecondary,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  side: BorderSide(
                    color: isSelected ? WhisperColors.purple : WhisperColors.cardBorder,
                  ),
                  showCheckmark: false,
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _selectedLanguage != null && !_isTranslating
                    ? _translate
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: WhisperColors.purple,
                  disabledBackgroundColor: WhisperColors.cardBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  elevation: 0,
                ),
                child: _isTranslating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Translate',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style: const TextStyle(color: WhisperColors.rose),
              ),
            ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: GlassmorphicCard(
                padding: const EdgeInsets.all(20),
                child: _translatedText != null
                    ? Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              controller: widget.scrollController,
                              child: SelectableText(
                                _translatedText!,
                                style: const TextStyle(
                                  color: WhisperColors.textPrimary,
                                  height: 1.6,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: _translatedText!),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Copied to clipboard'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                label: const Text('Copy'),
                                style: TextButton.styleFrom(
                                  foregroundColor: WhisperColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () {
                                  widget.onTranslate(
                                    _translatedText!,
                                    _selectedLanguage!,
                                  );
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: WhisperColors.emerald,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text('Use Translation'),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Center(
                        child: Text(
                          _selectedLanguage != null
                              ? 'Tap "Translate" to translate to $_selectedLanguage'
                              : 'Select a language to translate',
                          style: TextStyle(color: WhisperColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ConversationSettingsSheet extends ConsumerStatefulWidget {
  final Conversation conversation;
  final Function(Conversation) onUpdate;

  const _ConversationSettingsSheet({
    required this.conversation,
    required this.onUpdate,
  });

  @override
  ConsumerState<_ConversationSettingsSheet> createState() =>
      _ConversationSettingsSheetState();
}

class _ConversationSettingsSheetState
    extends ConsumerState<_ConversationSettingsSheet> {
  late TextEditingController _titleController;
  late TextEditingController _tagController;
  late List<String> _tags;
  String? _selectedFolderId;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.conversation.title);
    _tagController = TextEditingController();
    _tags = List.from(widget.conversation.tags);
    _selectedFolderId = widget.conversation.folderId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  void _save() {
    final updatedConversation = widget.conversation.copyWith(
      title: _titleController.text.trim(),
      tags: _tags,
      folderId: _selectedFolderId,
      updatedAt: DateTime.now(),
    );
    widget.onUpdate(updatedConversation);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final folders = ref.watch(folderListProvider);

    return Container(
      decoration: const BoxDecoration(
        color: WhisperColors.slate800,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: WhisperColors.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Settings',
            style: TextStyle(
              color: WhisperColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                const Text(
                  'NAME',
                  style: TextStyle(
                    color: WhisperColors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                GlassmorphicCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextField(
                    controller: _titleController,
                    style: const TextStyle(color: WhisperColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Recording name',
                      border: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'TAGS',
                  style: TextStyle(
                    color: WhisperColors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GlassmorphicCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: TextField(
                          controller: _tagController,
                          style: const TextStyle(color: WhisperColors.textPrimary),
                          decoration: const InputDecoration(
                            hintText: 'Add a tag',
                            border: InputBorder.none,
                            filled: false,
                          ),
                          onSubmitted: (_) => _addTag(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        gradient: WhisperColors.amberGradient,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: _addTag,
                        icon: const Icon(
                          Icons.add_rounded,
                          color: WhisperColors.slate900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tags
                      .map(
                        (tag) => Chip(
                          label: Text(tag),
                          deleteIcon: const Icon(Icons.close_rounded, size: 16),
                          onDeleted: () => _removeTag(tag),
                          backgroundColor: WhisperColors.amber.withOpacity(0.2),
                          labelStyle: const TextStyle(
                            color: WhisperColors.amber,
                            fontWeight: FontWeight.bold,
                          ),
                          side: BorderSide(
                            color: WhisperColors.amber.withOpacity(0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 32),
                const Text(
                  'MOVE TO FOLDER',
                  style: TextStyle(
                    color: WhisperColors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                GlassmorphicCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      RadioListTile<String?>(
                        value: null,
                        groupValue: _selectedFolderId,
                        onChanged: (value) =>
                            setState(() => _selectedFolderId = value),
                        title: const Text(
                          'No folder',
                          style: TextStyle(color: WhisperColors.textPrimary),
                        ),
                        secondary: Icon(
                          Icons.folder_off_rounded,
                          color: WhisperColors.textMuted,
                        ),
                        activeColor: WhisperColors.amber,
                      ),
                      ...folders.map(
                        (folder) => RadioListTile<String?>(
                          value: folder.id,
                          groupValue: _selectedFolderId,
                          onChanged: (value) =>
                              setState(() => _selectedFolderId = value),
                          title: Text(
                            folder.name,
                            style: const TextStyle(
                              color: WhisperColors.textPrimary,
                            ),
                          ),
                          secondary: Icon(
                            Icons.folder_rounded,
                            color: folder.color != null
                                ? Color(
                                    int.parse(
                                      folder.color!.replaceFirst('#', '0xFF'),
                                    ),
                                  )
                                : WhisperColors.amber,
                          ),
                          activeColor: WhisperColors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: WhisperColors.emerald,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(27),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
