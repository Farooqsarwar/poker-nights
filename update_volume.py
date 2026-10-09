import re

# 1. app_provider.dart
with open('lib/providers/app_provider.dart', 'r', encoding='utf-8') as f:
    content = f.read()
if '_voiceVolume' not in content:
    content = content.replace('bool _voiceEnabled = true;', 'bool _voiceEnabled = true;\n  double _voiceVolume = 1.0;')
with open('lib/providers/app_provider.dart', 'w', encoding='utf-8') as f:
    f.write(content)

# 2. app_provider_auth.dart
with open('lib/providers/app_provider_auth.dart', 'r', encoding='utf-8') as f:
    content = f.read()
if '_voiceVolume' not in content:
    content = content.replace(
        'if (voice is bool) _voiceEnabled = voice;',
        'if (voice is bool) _voiceEnabled = voice;\n      final vol = prefs[\'voiceVolume\'];\n      if (vol is num) {\n        _voiceVolume = vol.toDouble();\n        VoiceService.instance.setVolume(_voiceVolume);\n      }'
    )
with open('lib/providers/app_provider_auth.dart', 'w', encoding='utf-8') as f:
    f.write(content)

# 3. app_provider_notifications_settings.dart
with open('lib/providers/app_provider_notifications_settings.dart', 'r', encoding='utf-8') as f:
    content = f.read()
if 'voiceVolume' not in content:
    content = content.replace(
        'bool get voiceEnabled => _voiceEnabled;',
        'bool get voiceEnabled => _voiceEnabled;\n  double get voiceVolume => _voiceVolume;'
    )
    content = content.replace(
        'void setVoiceEnabled(bool value) {',
        'void setVoiceVolume(double value) {\n    if (_voiceVolume == value) return;\n    _voiceVolume = value;\n    VoiceService.instance.setVolume(value);\n    _persistPref(\'voiceVolume\', _voiceVolume);\n    if (!_disposed) notifyListeners();\n  }\n\n  void setVoiceEnabled(bool value) {'
    )
with open('lib/providers/app_provider_notifications_settings.dart', 'w', encoding='utf-8') as f:
    f.write(content)

# 4. app_provider_user_data.dart
with open('lib/providers/app_provider_user_data.dart', 'r', encoding='utf-8') as f:
    content = f.read()
if 'voiceVolume' not in content:
    content = content.replace(
        "'voiceEnabled': _voiceEnabled,",
        "'voiceEnabled': _voiceEnabled,\n        'voiceVolume': _voiceVolume,"
    )
with open('lib/providers/app_provider_user_data.dart', 'w', encoding='utf-8') as f:
    f.write(content)

# 5. voice_service.dart
with open('lib/utils/voice_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()
if 'setVolume(' not in content or 'Future<void> setVolume' not in content:
    content = content.replace(
        'Future<void> stop() async {',
        'Future<void> setVolume(double volume) async {\n    await _tts?.setVolume(volume);\n  }\n\n  Future<void> stop() async {'
    )
with open('lib/utils/voice_service.dart', 'w', encoding='utf-8') as f:
    f.write(content)

# 6. settings_screen.dart
with open('lib/screens/shell/settings_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()
if 'voiceVolume' not in content:
    # Add AppSlider import if missing
    if 'app_slider.dart' not in content:
        content = content.replace("import '../../widgets/app_toggle.dart';", "import '../../widgets/app_toggle.dart';\nimport '../../widgets/app_slider.dart';")
    
    # Add the slider
    slider_ui = """                  if (app.voiceEnabled)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.volume_down, size: 20, color: AppColors.mutedForeground),
                          Expanded(
                            child: AppSlider(
                              value: app.voiceVolume,
                              onChanged: (v) => app.setVoiceVolume(v),
                            ),
                          ),
                          Icon(Icons.volume_up, size: 20, color: AppColors.mutedForeground),
                        ],
                      ),
                    ),"""
    
    content = content.replace(
        '''                    trailing: AppToggle(
                      value: app.voiceEnabled,
                      onChanged: (v) => app.setVoiceEnabled(v),
                    ),
                    showDivider: true,
                  ),''',
        f'''                    trailing: AppToggle(
                      value: app.voiceEnabled,
                      onChanged: (v) => app.setVoiceEnabled(v),
                    ),
                    showDivider: !app.voiceEnabled,
                  ),
{slider_ui}
                  if (app.voiceEnabled)
                    const Divider(height: 1),'''
    )
with open('lib/screens/shell/settings_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)

