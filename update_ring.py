import re

with open('lib/screens/tournament/final_table_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the red ring with SvgCountdownRing
content = re.sub(
    r'''// Crimson red ring boundary\n\s*Container\(\n\s*width: ringRadius \* 2,\n\s*height: ringRadius \* 2,\n\s*decoration: BoxDecoration\(\n\s*shape: BoxShape\.circle,\n\s*border: Border\.all\(\n\s*color: AppColors\.primary,\n\s*width: 2\.5,\n\s*\),\n\s*boxShadow: \[\n\s*BoxShadow\(\n\s*color: AppColors\.primary\.withValues\(alpha: 0\.4\),\n\s*blurRadius: 18,\n\s*spreadRadius: 1,\n\s*\),\n\s*\],\n\s*\),\n\s*\),''',
    '''// Crimson red ring boundary using SvgCountdownRing
          Container(
            width: ringRadius * 2,
            height: ringRadius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: SvgCountdownRing(progress: 1.0, scale: (ringRadius * 2) / 48),
          ),''',
    content
)

with open('lib/screens/tournament/final_table_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
