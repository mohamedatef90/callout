import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../data/models/settings_model.dart';
import '../../../../core/services/tts_manager.dart';
import '../../../../core/services/tts_providers/tts_provider_interface.dart';

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

  SettingsNotifier(this._box, this._ref) : super(_loadSettings(_box));

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
      case 'openai':
        providerType = TtsProviderType.openai;
        break;
      case 'googleCloud':
        providerType = TtsProviderType.googleCloud;
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
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _buildSectionHeader('Privacy'),
          SwitchListTile(
            title: const Text(
              'Delete recordings after transcription',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              'Audio files will be deleted after AI processing. You won\'t be able to replay them.',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
            ),
            value: settings.deleteAudioAfterTranscription,
            activeColor: const Color(0xFF6366F1),
            onChanged: (value) async {
              if (value) {
                // Show warning dialog
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Text(
                      'Enable Privacy Mode?',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: Text(
                      'When enabled, audio recordings will be permanently deleted after transcription. You will not be able to replay the audio.\n\nThis applies to new recordings only.',
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white.withOpacity(0.7)),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Enable',
                          style: TextStyle(color: Color(0xFF6366F1)),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  settingsNotifier.setDeleteAudioAfterTranscription(true);
                }
              } else {
                settingsNotifier.setDeleteAudioAfterTranscription(false);
              }
            },
          ),
          const Divider(color: Color(0xFF334155)),
          _buildSectionHeader('Language'),
          ListTile(
            title: const Text(
              'Default display language',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              settings.defaultLanguage == 'en' ? 'English' : 'Arabic',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.white54),
            onTap: () {
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
                      const SizedBox(height: 16),
                      const Text(
                        'Select Language',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Text('EN', style: TextStyle(color: Colors.white, fontSize: 20)),
                        title: const Text('English', style: TextStyle(color: Colors.white)),
                        trailing: settings.defaultLanguage == 'en'
                            ? const Icon(Icons.check, color: Color(0xFF6366F1))
                            : null,
                        onTap: () {
                          settingsNotifier.setDefaultLanguage('en');
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        leading: const Text('AR', style: TextStyle(color: Colors.white, fontSize: 20)),
                        title: const Text('Arabic', style: TextStyle(color: Colors.white)),
                        trailing: settings.defaultLanguage == 'ar'
                            ? const Icon(Icons.check, color: Color(0xFF6366F1))
                            : null,
                        onTap: () {
                          settingsNotifier.setDefaultLanguage('ar');
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              );
            },
          ),
          const Divider(color: Color(0xFF334155)),
          _buildSectionHeader('Text-to-Speech'),
          _buildTtsProviderTile(context, ref, settings),
          _buildTestTtsTile(context, ref),
          const Divider(color: Color(0xFF334155)),
          _buildSectionHeader('About'),
          ListTile(
            title: const Text(
              'Version',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              '1.0.0',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTtsProviderTile(BuildContext context, WidgetRef ref, AppSettings settings) {
    String providerLabel;
    switch (settings.ttsProvider) {
      case 'openai':
        providerLabel = 'OpenAI TTS';
        break;
      case 'googleCloud':
        providerLabel = 'Google Cloud TTS';
        break;
      default:
        providerLabel = 'Device (Free)';
    }

    return ListTile(
      title: const Text(
        'TTS Provider',
        style: TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        providerLabel,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.white54),
      onTap: () {
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
                const SizedBox(height: 16),
                const Text(
                  'Select TTS Provider',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.phone_android, color: Colors.white),
                  title: const Text('Device (Free)', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    'Uses your device\'s built-in TTS',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                  ),
                  trailing: settings.ttsProvider == 'device'
                      ? const Icon(Icons.check, color: Color(0xFF10B981))
                      : null,
                  onTap: () {
                    ref.read(settingsProvider.notifier).setTtsProvider('device');
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.smart_toy, color: Colors.white),
                  title: const Text('OpenAI TTS', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    'High quality voices (requires API key)',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                  ),
                  trailing: settings.ttsProvider == 'openai'
                      ? const Icon(Icons.check, color: Color(0xFF10B981))
                      : null,
                  onTap: () {
                    ref.read(settingsProvider.notifier).setTtsProvider('openai');
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cloud, color: Colors.white),
                  title: const Text('Google Cloud TTS', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    'Neural voices with Arabic support',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                  ),
                  trailing: settings.ttsProvider == 'googleCloud'
                      ? const Icon(Icons.check, color: Color(0xFF10B981))
                      : null,
                  onTap: () {
                    ref.read(settingsProvider.notifier).setTtsProvider('googleCloud');
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTestTtsTile(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: const Text(
        'Test TTS',
        style: TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        'Play a sample to verify TTS is working',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
      ),
      trailing: const Icon(Icons.play_arrow, color: Color(0xFF6366F1)),
      onTap: () async {
        try {
          final ttsManager = ref.read(ttsManagerProvider);
          await ttsManager.testProvider();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('TTS test completed'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('TTS Error: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF6366F1),
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
