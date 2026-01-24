import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/settings_model.dart';
import '../../../../core/services/tts_manager.dart';
import '../../../../core/services/tts_providers/tts_provider_interface.dart';
import '../../../../core/theme/whisper_colors.dart';
import '../../../../core/widgets/glassmorphic_card.dart';

final settingsBoxProvider = Provider<Box<AppSettings>>((ref) {
  return Hive.box<AppSettings>('settings');
});

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final box = ref.watch(settingsBoxProvider);
  return SettingsNotifier(box, ref);
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  final Box<AppSettings> _box;
  final Ref _ref;

  SettingsNotifier(this._box, this._ref) : super(_loadSettings(_box)) {
    // Initialize TTS manager with saved provider on startup
    _updateTtsManager();
  }

  static AppSettings _loadSettings(Box<AppSettings> box) {
    return box.get('settings') ?? AppSettings();
  }

  Future<void> setDeleteAudioAfterTranscription(bool value) async {
    state = state.copyWith(deleteAudioAfterTranscription: value);
    await _box.put('settings', state);
  }

  Future<void> setEnableNotifications(bool value) async {
    state = state.copyWith(enableNotifications: value);
    await _box.put('settings', state);
  }

  Future<void> setDefaultLanguage(String value) async {
    state = state.copyWith(defaultLanguage: value);
    await _box.put('settings', state);
  }

  Future<void> setTtsProvider(String value) async {
    state = state.copyWith(ttsProvider: value);
    await _box.put('settings', state);
    await _updateTtsManager();
  }

  Future<void> _updateTtsManager() async {
    final ttsManager = _ref.read(ttsManagerProvider);
    TtsProviderType providerType;
    switch (state.ttsProvider) {
      case 'googleAi':
        providerType = TtsProviderType.googleAi;
        break;
      default:
        providerType = TtsProviderType.device;
    }
    await ttsManager.setProvider(providerType);
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: WhisperColors.slate900,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: WhisperColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: WhisperColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Privacy Section
          _buildSectionHeader('Privacy', Icons.shield_outlined),
          const SizedBox(height: 12),
          GlassmorphicCard(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              title: const Text(
                'Delete recordings after transcription',
                style: TextStyle(
                  color: WhisperColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Audio files will be deleted after AI processing. You won\'t be able to replay them.',
                style: TextStyle(
                  color: WhisperColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              value: settings.deleteAudioAfterTranscription,
              activeColor: WhisperColors.purple,
              onChanged: (value) async {
                if (value) {
                  // Show warning dialog
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => _buildWarningDialog(context),
                  );
                  if (confirmed == true) {
                    settingsNotifier.setDeleteAudioAfterTranscription(true);
                  }
                } else {
                  settingsNotifier.setDeleteAudioAfterTranscription(false);
                }
              },
            ),
          ),

          const SizedBox(height: 32),

          // Language Section
          _buildSectionHeader('Language', Icons.language_outlined),
          const SizedBox(height: 12),
          GlassmorphicCard(
            onTap: () => _showLanguagePicker(context, ref, settings, settingsNotifier),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: WhisperColors.emerald.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.translate_rounded, color: WhisperColors.emerald, size: 24),
              ),
              title: const Text(
                'Default display language',
                style: TextStyle(
                  color: WhisperColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                settings.defaultLanguage == 'en' ? 'English' : 'Arabic',
                style: TextStyle(color: WhisperColors.textSecondary),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: WhisperColors.textPrimary),
            ),
          ),

          const SizedBox(height: 32),

          // Text-to-Speech Section
          _buildSectionHeader('Text-to-Speech', Icons.volume_up_outlined),
          const SizedBox(height: 12),
          GlassmorphicCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  onTap: () => _showTtsProviderPicker(context, ref, settings),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: WhisperColors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.settings_voice_rounded, color: WhisperColors.amber, size: 24),
                  ),
                  title: const Text(
                    'TTS Provider',
                    style: TextStyle(
                      color: WhisperColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _getTtsProviderLabel(settings.ttsProvider),
                    style: TextStyle(color: WhisperColors.textSecondary),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: WhisperColors.textPrimary),
                ),
                Divider(height: 1, color: WhisperColors.cardBorder),
                ListTile(
                  onTap: () => _testTts(context, ref),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: WhisperColors.emerald.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: WhisperColors.emerald, size: 24),
                  ),
                  title: const Text(
                    'Test TTS',
                    style: TextStyle(
                      color: WhisperColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Play a sample to verify TTS is working',
                    style: TextStyle(color: WhisperColors.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // About Section
          _buildSectionHeader('About', Icons.info_outline_rounded),
          const SizedBox(height: 12),
          GlassmorphicCard(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: WhisperColors.purpleGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.mic_rounded, color: Colors.white, size: 24),
              ),
              title: const Text(
                'Whisper',
                style: TextStyle(
                  color: WhisperColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                'Version 1.0.0',
                style: TextStyle(color: WhisperColors.textSecondary),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: WhisperColors.amber),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: WhisperColors.amber,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  String _getTtsProviderLabel(String provider) {
    switch (provider) {
      case 'googleAi':
        return 'Google AI';
      default:
        return 'Device (Free)';
    }
  }

  Widget _buildWarningDialog(BuildContext context) {
    return Dialog(
      backgroundColor: WhisperColors.slate800,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: WhisperColors.purple.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: WhisperColors.purple,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Enable Privacy Mode?',
              style: TextStyle(
                color: WhisperColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'When enabled, audio recordings will be permanently deleted after transcription. You will not be able to replay the audio.\n\nThis applies to new recordings only.',
              style: TextStyle(
                color: WhisperColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: WhisperColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WhisperColors.purple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Enable',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    SettingsNotifier notifier,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: WhisperColors.slate800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
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
            const SizedBox(height: 20),
            const Text(
              'Select Language',
              style: TextStyle(
                color: WhisperColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildLanguageOption(
              context: context,
              code: 'en',
              label: 'English',
              flag: 'EN',
              isSelected: settings.defaultLanguage == 'en',
              onTap: () {
                notifier.setDefaultLanguage('en');
                Navigator.pop(context);
              },
            ),
            _buildLanguageOption(
              context: context,
              code: 'ar',
              label: 'Arabic',
              flag: 'AR',
              isSelected: settings.defaultLanguage == 'ar',
              onTap: () {
                notifier.setDefaultLanguage('ar');
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required String code,
    required String label,
    required String flag,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GlassmorphicCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: onTap,
      backgroundColor: isSelected ? WhisperColors.emerald.withOpacity(0.1) : null,
      borderColor: isSelected ? WhisperColors.emerald.withOpacity(0.3) : null,
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isSelected
                ? WhisperColors.emerald.withOpacity(0.2)
                : WhisperColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? WhisperColors.emerald
                  : WhisperColors.cardBorder,
            ),
          ),
          child: Center(
            child: Text(
              flag,
              style: TextStyle(
                color: isSelected ? WhisperColors.emerald : WhisperColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text(
          label,
          style: const TextStyle(
            color: WhisperColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: isSelected
            ? const Icon(Icons.check_circle_rounded, color: WhisperColors.emerald)
            : null,
      ),
    );
  }

  void _showTtsProviderPicker(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: WhisperColors.slate800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
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
            const SizedBox(height: 20),
            const Text(
              'Select TTS Provider',
              style: TextStyle(
                color: WhisperColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildTtsProviderOption(
              context: context,
              ref: ref,
              provider: 'device',
              icon: Icons.phone_android_rounded,
              label: 'Device (Free)',
              description: 'Uses your device\'s built-in TTS',
              color: WhisperColors.emerald,
              isSelected: settings.ttsProvider == 'device',
            ),
            _buildTtsProviderOption(
              context: context,
              ref: ref,
              provider: 'googleAi',
              icon: Icons.auto_awesome_rounded,
              label: 'Google AI',
              description: 'Neural voices powered by Google AI',
              color: WhisperColors.purple,
              isSelected: settings.ttsProvider == 'googleAi',
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTtsProviderOption({
    required BuildContext context,
    required WidgetRef ref,
    required String provider,
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required bool isSelected,
  }) {
    return GlassmorphicCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: () {
        ref.read(settingsProvider.notifier).setTtsProvider(provider);
        Navigator.pop(context);
      },
      backgroundColor: isSelected ? color.withOpacity(0.1) : null,
      borderColor: isSelected ? color.withOpacity(0.3) : null,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : WhisperColors.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : WhisperColors.cardBorder,
            ),
          ),
          child: Icon(icon, color: isSelected ? color : WhisperColors.textPrimary, size: 24),
        ),
        title: Text(
          label,
          style: const TextStyle(
            color: WhisperColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          description,
          style: TextStyle(
            color: WhisperColors.textSecondary,
            fontSize: 12,
          ),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle_rounded, color: color)
            : null,
      ),
    );
  }

  Future<void> _testTts(BuildContext context, WidgetRef ref) async {
    try {
      final ttsManager = ref.read(ttsManagerProvider);
      await ttsManager.testProvider();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('TTS test completed'),
            backgroundColor: WhisperColors.emerald,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('TTS Error: ${e.toString()}'),
            backgroundColor: WhisperColors.rose,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }
}
