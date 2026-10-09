import re

with open('lib/screens/shell/settings_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add AppSlider import if missing
if 'app_slider.dart' not in content:
    content = content.replace("import '../../widgets/app_toggle.dart';", "import '../../widgets/app_toggle.dart';\nimport '../../widgets/app_slider.dart';")

slider_ui = """                  if (app.voiceEnabled)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.volume_down, size: 20, color: AppColors.mutedForeground),
                          const SizedBox(width: 16),
                          Expanded(
                            child: AppSlider(
                              value: app.voiceVolume,
                              onChanged: (v) => app.setVoiceVolume(v),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.volume_up, size: 20, color: AppColors.mutedForeground),
                        ],
                      ),
                    ),
                  if (app.voiceEnabled)
                    const Divider(height: 1),"""

content = re.sub(
    r'(\s*trailing: AppToggle\(\n\s*value: app\.voiceEnabled,\n\s*onChanged: \(v\) => app\.setVoiceEnabled\(v\),\n\s*\),\n\s*showDivider: )true(,\n\s*\),)',
    r'\g<1>!app.voiceEnabled\g<2>\n' + slider_ui,
    content
)

with open('lib/screens/shell/settings_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
