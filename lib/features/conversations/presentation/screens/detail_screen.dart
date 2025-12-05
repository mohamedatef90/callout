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
      text: _showEnglish ? aiResult?.summaryEn ?? '' : aiResult?.summaryAr ?? '',
    );
    _pointsControllers = (_showEnglish
            ? aiResult?.bulletPointsEn ?? []
            : aiResult?.bulletPointsAr ?? [])
        .map((p) => TextEditingController(text: p))
        .toList();
    _todosControllers = (_showEnglish
            ? aiResult?.todosEn ?? []
            : aiResult?.todosAr ?? [])
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

  Future<void> _performSpeak(TtsManager ttsManager, String text, String language, String section) async {
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
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => _ConversationSettingsSheet(
        conversation: _conversation,
        onUpdate: (updatedConversation) {
          setState(() {
            _conversation = updatedConversation;
          });
          ref.read(conversationRepositoryProvider).saveConversation(updatedConversation);
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
      final bullets = _showEnglish ? aiResult.bulletPointsEn : aiResult.bulletPointsAr;
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

  String _formatShareText() {
    final aiResult = _conversation.aiResult;
    final transcript = _conversation.transcript;

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
      final bullets = _showEnglish ? aiResult.bulletPointsEn : aiResult.bulletPointsAr;
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
        buffer.writeln('');
      }
    }

    // Transcript
    if (transcript != null && transcript.fullText.isNotEmpty) {
      buffer.writeln('Transcript:');
      buffer.writeln(transcript.fullText);
    }

    buffer.writeln('');
    buffer.writeln('---');
    buffer.writeln('Shared from Callout App');

    return buffer.toString();
  }

  void _showShareOptions() {
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
              'Share Recording',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.white),
              title: const Text('Copy to Clipboard', style: TextStyle(color: Colors.white)),
              subtitle: Text(
                'Summary & key points only',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
              ),
              onTap: () {
                Clipboard.setData(ClipboardData(text: _formatCopyText()));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.white),
              title: const Text('Share as Text', style: TextStyle(color: Colors.white)),
              subtitle: Text(
                'Includes transcript',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
              ),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await Share.share(_formatShareText());
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to share: $e')),
                    );
                  }
                }
              },
            ),
            if (_audioPath != null)
              ListTile(
                leading: const Icon(Icons.audiotrack, color: Colors.white),
                title: const Text('Share Audio File', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final file = XFile(_audioPath!);
                    await Share.shareXFiles([file], text: _conversation.title);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to share audio: $e')),
                      );
                    }
                  }
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _toggleStar() {
    final updatedConversation = _conversation.copyWith(
      isStarred: !_conversation.isStarred,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _conversation = updatedConversation;
    });

    ref.read(conversationRepositoryProvider).saveConversation(updatedConversation);
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
    ref.read(conversationRepositoryProvider).saveConversation(updatedConversation);
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

    ref.read(conversationRepositoryProvider).saveConversation(updatedConversation);
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

    ref.read(conversationRepositoryProvider).saveConversation(updatedConversation);
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

    ref.read(conversationRepositoryProvider).saveConversation(updatedConversation);
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
    final result = await Navigator.push<({String path, ConversationType type, int durationMs})>(
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
      final newTranscriptText = await geminiService.transcribeAudio(result.path);

      // Combine transcripts
      final existingTranscript = _conversation.transcript?.fullText ?? '';
      final combinedTranscript = existingTranscript.isEmpty
          ? newTranscriptText
          : '$existingTranscript\n\n--- New Recording ---\n\n$newTranscriptText';

      // Option: Re-process with AI to get updated summary
      final updatedAiResult = await geminiService.generateSummary(combinedTranscript);

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
      await ref.read(conversationRepositoryProvider).saveConversation(updatedConversation);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding recording: $e')),
        );
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
        appBar: AppBar(
          title: Text(
            _showEnglish ? aiResult?.titleEn ?? '' : aiResult?.titleAr ?? '',
          ),
          actions: [
            IconButton(
              icon: Icon(
                _conversation.isStarred ? Icons.star : Icons.star_border,
                color: _conversation.isStarred ? Colors.amber : null,
              ),
              onPressed: _toggleStar,
              tooltip: _conversation.isStarred ? 'Unstar' : 'Star',
            ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: _showShareOptions,
              tooltip: 'Share',
            ),
            IconButton(
              icon: Icon(_showEnglish ? Icons.language : Icons.translate),
              onPressed: () {
                setState(() {
                  _showEnglish = !_showEnglish;
                });
              },
              tooltip: 'Switch Language',
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: _showConversationSettings,
              tooltip: 'Settings',
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Summary'),
              Tab(text: 'Points'),
              Tab(text: 'Todos'),
              Tab(text: 'Transcript'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Audio Player Controls
            if (_audioPath != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    // Progress Bar
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFF6366F1),
                        inactiveTrackColor: Colors.white.withOpacity(0.2),
                        thumbColor: const Color(0xFF6366F1),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: positionAsync.when(
                          data: (pos) => pos.inMilliseconds.toDouble(),
                          loading: () => 0,
                          error: (_, __) => 0,
                        ),
                        max: durationAsync.when(
                          data: (dur) =>
                              dur.inMilliseconds.toDouble().clamp(1, double.infinity),
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
                    // Time and Controls Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Current Time
                        Text(
                          positionAsync.when(
                            data: (pos) => formatDuration(pos.inSeconds),
                            loading: () => '0:00',
                            error: (_, __) => '0:00',
                          ),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        // Play Controls
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.replay_10),
                              color: Colors.white,
                              onPressed: () {
                                positionAsync.whenData((pos) {
                                  final newPos =
                                      pos - const Duration(seconds: 10);
                                  ref
                                      .read(audioPlayerControllerProvider.notifier)
                                      .seek(newPos < Duration.zero
                                          ? Duration.zero
                                          : newPos);
                                });
                              },
                            ),
                            Container(
                              width: 56,
                              height: 56,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF6366F1),
                                    Color(0xFF8B5CF6)
                                  ],
                                ),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  playerState == PlayerState.playing
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  size: 32,
                                ),
                                color: Colors.white,
                                onPressed: () {
                                  final controller = ref.read(
                                      audioPlayerControllerProvider.notifier);
                                  if (playerState == PlayerState.playing) {
                                    controller.pause();
                                  } else if (playerState == PlayerState.paused) {
                                    controller.resume();
                                  } else {
                                    controller.play(_audioPath!);
                                  }
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.forward_10),
                              color: Colors.white,
                              onPressed: () {
                                positionAsync.whenData((pos) {
                                  durationAsync.whenData((dur) {
                                    final newPos =
                                        pos + const Duration(seconds: 10);
                                    ref
                                        .read(
                                            audioPlayerControllerProvider.notifier)
                                        .seek(newPos > dur ? dur : newPos);
                                  });
                                });
                              },
                            ),
                          ],
                        ),
                        // Duration
                        Text(
                          durationAsync.when(
                            data: (dur) => formatDuration(dur.inSeconds),
                            loading: () => '0:00',
                            error: (_, __) => '0:00',
                          ),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
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
                  color: const Color(0xFF1E293B),
                ),
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                ),
              )
            : Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.4),
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
                      child: Icon(Icons.mic, size: 32, color: Colors.white),
                    ),
                  ),
                ),
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
              child: TextField(
                controller: _summaryController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter summary...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
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
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saveSummary,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
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
    final displayText = (_translatedSection == 'summary' && _translatedText != null)
        ? _translatedText!
        : summaryText;
    final isShowingTranslation = _translatedSection == 'summary' && _translatedText != null;

    return Column(
      children: [
        // Action buttons bar at top
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          child: Row(
            children: [
              if (isShowingTranslation)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.translate, size: 16, color: Color(0xFF6366F1)),
                        const SizedBox(width: 6),
                        Text(
                          'Translated to $_selectedLanguage',
                          style: const TextStyle(
                            color: Color(0xFF6366F1),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _clearTranslation,
                          child: const Icon(Icons.close, size: 16, color: Color(0xFF6366F1)),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const Spacer(),
              if (summaryText.isNotEmpty) ...[
                _buildActionButton(
                  icon: Icons.translate,
                  color: const Color(0xFF8B5CF6),
                  onTap: () => _showTranslateDialog(summaryText, 'summary'),
                  tooltip: 'Translate',
                ),
                const SizedBox(width: 8),
              ],
              if (displayText.isNotEmpty) ...[
                _buildActionButton(
                  icon: _currentTtsSection == 'summary' ? Icons.stop : Icons.volume_up,
                  color: _currentTtsSection == 'summary' ? Colors.red : const Color(0xFF10B981),
                  onTap: () => _speakText(displayText, 'summary'),
                  tooltip: 'Read aloud',
                ),
                const SizedBox(width: 8),
              ],
              _buildActionButton(
                icon: Icons.edit,
                color: const Color(0xFF6366F1),
                onTap: () {
                  _summaryController.text = summaryText;
                  setState(() => _isEditingSummary = true);
                },
                tooltip: 'Edit',
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Text(
              displayText,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      ],
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
      child: Material(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 20, color: color),
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
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, size: 8, color: Colors.white54),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _pointsControllers[index],
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF1E293B),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () => _removePoint(index),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _addPoint,
                  icon: const Icon(Icons.add, color: Color(0xFF6366F1)),
                  label: const Text(
                    'Add Point',
                    style: TextStyle(color: Color(0xFF6366F1)),
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _cancelEdit('points'),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _savePoints,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
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

    return Column(
      children: [
        // Action buttons bar at top
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          child: Row(
            children: [
              const Spacer(),
              _buildActionButton(
                icon: Icons.edit,
                color: const Color(0xFF6366F1),
                onTap: () {
                  _pointsControllers = points
                      .map((p) => TextEditingController(text: p))
                      .toList();
                  setState(() => _isEditingPoints = true);
                },
                tooltip: 'Edit',
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: points.length,
            itemBuilder: (context, index) {
              return ListTile(
                leading: const Icon(Icons.circle, size: 8),
                title: Text(points[index]),
              );
            },
          ),
        ),
      ],
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
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.check_box_outline_blank, size: 20, color: Colors.white54),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _todosControllers[index],
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF1E293B),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () => _removeTodo(index),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _addTodo,
                  icon: const Icon(Icons.add, color: Color(0xFF6366F1)),
                  label: const Text(
                    'Add Todo',
                    style: TextStyle(color: Color(0xFF6366F1)),
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _cancelEdit('todos'),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saveTodos,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
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

    return Column(
      children: [
        // Action buttons bar at top
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          child: Row(
            children: [
              const Spacer(),
              _buildActionButton(
                icon: Icons.edit,
                color: const Color(0xFF6366F1),
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
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: todos.length,
            itemBuilder: (context, index) {
              final isCompleted = index < completed.length ? completed[index] : false;
              return Card(
                color: const Color(0xFF1E293B),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Checkbox(
                    value: isCompleted,
                    onChanged: (val) => _toggleTodo(index, val),
                    activeColor: const Color(0xFF10B981),
                    checkColor: Colors.white,
                  ),
                  title: Text(
                    todos[index],
                    style: TextStyle(
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                      color: isCompleted ? const Color(0xFF10B981) : Colors.white,
                      fontWeight: isCompleted ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.alarm_add, color: Color(0xFF6366F1)),
                    tooltip: 'Set Reminder',
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
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTranscriptTab(Transcript? transcript) {
    final transcriptText = transcript?.fullText ?? '';

    // Show translated text if available for this section
    final displayText = (_translatedSection == 'transcript' && _translatedText != null)
        ? _translatedText!
        : transcriptText;
    final isShowingTranslation = _translatedSection == 'transcript' && _translatedText != null;

    return Column(
      children: [
        // Action buttons bar at top
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          child: Row(
            children: [
              if (isShowingTranslation)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.translate, size: 16, color: Color(0xFF6366F1)),
                        const SizedBox(width: 6),
                        Text(
                          'Translated to $_selectedLanguage',
                          style: const TextStyle(
                            color: Color(0xFF6366F1),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _clearTranslation,
                          child: const Icon(Icons.close, size: 16, color: Color(0xFF6366F1)),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const Spacer(),
              if (transcriptText.isNotEmpty) ...[
                _buildActionButton(
                  icon: Icons.translate,
                  color: const Color(0xFF8B5CF6),
                  onTap: () => _showTranslateDialog(transcriptText, 'transcript'),
                  tooltip: 'Translate',
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: _currentTtsSection == 'transcript' ? Icons.stop : Icons.volume_up,
                  color: _currentTtsSection == 'transcript' ? Colors.red : const Color(0xFF10B981),
                  onTap: () => _speakText(displayText, 'transcript'),
                  tooltip: 'Read aloud',
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Text(
              displayText.isEmpty ? 'No transcript available.' : displayText,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }
}

/// Translation sheet widget
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
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Translate',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        // Language selection
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
                selectedColor: const Color(0xFF6366F1),
                backgroundColor: const Color(0xFF0F172A),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        // Translate button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedLanguage != null && !_isTranslating
                  ? _translate
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                disabledBackgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isTranslating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Translate', style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        const SizedBox(height: 16),
        // Translated text
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _translatedText != null
                ? Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          controller: widget.scrollController,
                          child: Text(
                            _translatedText!,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _translatedText!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Copied to clipboard')),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 18),
                            label: const Text('Copy'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              widget.onTranslate(_translatedText!, _selectedLanguage!);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
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
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Conversation settings sheet widget
class _ConversationSettingsSheet extends ConsumerStatefulWidget {
  final Conversation conversation;
  final Function(Conversation) onUpdate;

  const _ConversationSettingsSheet({
    required this.conversation,
    required this.onUpdate,
  });

  @override
  ConsumerState<_ConversationSettingsSheet> createState() => _ConversationSettingsSheetState();
}

class _ConversationSettingsSheetState extends ConsumerState<_ConversationSettingsSheet> {
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

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
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
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Conversation Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Rename section
                const Text(
                  'Name',
                  style: TextStyle(
                    color: Color(0xFF6366F1),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Conversation name',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
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
                ),
                const SizedBox(height: 24),

                // Tags section
                const Text(
                  'Tags',
                  style: TextStyle(
                    color: Color(0xFF6366F1),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tagController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Add a tag',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
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
                        onSubmitted: (_) => _addTag(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _addTag,
                      icon: const Icon(Icons.add_circle, color: Color(0xFF6366F1)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _tags.map((tag) => Chip(
                    label: Text(tag),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => _removeTag(tag),
                    backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
                    labelStyle: const TextStyle(color: Colors.white),
                    deleteIconColor: Colors.white70,
                  )).toList(),
                ),
                const SizedBox(height: 24),

                // Folder section
                const Text(
                  'Folder',
                  style: TextStyle(
                    color: Color(0xFF6366F1),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      RadioListTile<String?>(
                        value: null,
                        groupValue: _selectedFolderId,
                        onChanged: (value) {
                          setState(() {
                            _selectedFolderId = value;
                          });
                        },
                        title: const Text(
                          'No folder',
                          style: TextStyle(color: Colors.white),
                        ),
                        secondary: const Icon(Icons.folder_off, color: Colors.white54),
                        activeColor: const Color(0xFF6366F1),
                      ),
                      ...folders.map((folder) => RadioListTile<String?>(
                        value: folder.id,
                        groupValue: _selectedFolderId,
                        onChanged: (value) {
                          setState(() {
                            _selectedFolderId = value;
                          });
                        },
                        title: Text(
                          folder.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        secondary: Icon(
                          Icons.folder,
                          color: folder.color != null
                              ? Color(int.parse(folder.color!.replaceFirst('#', '0xFF')))
                              : const Color(0xFF6366F1),
                        ),
                        activeColor: const Color(0xFF6366F1),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
          // Save button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
