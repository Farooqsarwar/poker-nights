import os
import re

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    original = content

    # Add imports if missing
    if 'package:flutter/material.dart' in content:
        if 'pn_button.dart' not in content:
            content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:poker_night/core/widgets/pn_button.dart';\nimport 'package:poker_night/core/widgets/pn_card.dart';")

    # Replace ElevatedButton
    content = re.sub(
        r'ElevatedButton\.icon\(\s*onPressed:\s*(.+?),\s*icon:\s*(.+?),\s*label:\s*const Text\((.+?)\),\s*style:\s*ElevatedButton\.styleFrom\([^\)]+\),\s*\)',
        r'PNButton(\n  onPressed: \1,\n  icon: (\2).icon,\n  label: \3,\n)',
        content, flags=re.DOTALL
    )
    content = re.sub(
        r'ElevatedButton\.icon\(\s*onPressed:\s*(.+?),\s*icon:\s*(.+?),\s*label:\s*const Text\((.+?)\),\s*\)',
        r'PNButton(\n  onPressed: \1,\n  icon: (\2).icon,\n  label: \3,\n)',
        content, flags=re.DOTALL
    )

    # Replace OutlinedButton
    content = re.sub(
        r'OutlinedButton\.icon\(\s*onPressed:\s*(.+?),\s*icon:\s*(.+?),\s*label:\s*const Text\((.+?)\),\s*style:\s*OutlinedButton\.styleFrom\([^\)]+\),\s*\)',
        r'PNSecondaryButton(\n  onPressed: \1,\n  icon: (\2).icon,\n  label: \3,\n)',
        content, flags=re.DOTALL
    )
    content = re.sub(
        r'OutlinedButton\.icon\(\s*onPressed:\s*(.+?),\s*icon:\s*(.+?),\s*label:\s*const Text\((.+?)\),\s*\)',
        r'PNSecondaryButton(\n  onPressed: \1,\n  icon: (\2).icon,\n  label: \3,\n)',
        content, flags=re.DOTALL
    )
    
    # Replace Card + InkWell + Padding
    content = re.sub(
        r'Card\(\s*child:\s*InkWell\(\s*borderRadius:[^,]+,\s*onTap:\s*(.+?),\s*child:\s*Padding\(\s*padding:\s*(.+?),\s*child:\s*(Row|Column|Container)\(',
        r'PNCard(\n  onTap: \1,\n  padding: \2,\n  child: \3(',
        content, flags=re.DOTALL
    )

    content = re.sub(
        r'Card\(\s*margin:\s*(.+?),\s*child:\s*InkWell\(\s*borderRadius:[^,]+,\s*onTap:\s*(.+?),\s*child:\s*Padding\(\s*padding:\s*(.+?),\s*child:\s*(Row|Column|Container)\(',
        r'PNCard(\n  margin: \1,\n  onTap: \2,\n  padding: \3,\n  child: \4(',
        content, flags=re.DOTALL
    )

    content = re.sub(
        r'Card\(\s*child:\s*Padding\(\s*padding:\s*(.+?),\s*child:\s*(Row|Column|Container|Icon)\(',
        r'PNCard(\n  padding: \1,\n  child: \2(',
        content, flags=re.DOTALL
    )

    content = re.sub(
        r'Card\(\s*margin:\s*(.+?),\s*child:\s*ListTile\(',
        r'PNCard(\n  margin: \1,\n  padding: EdgeInsets.zero,\n  child: ListTile(',
        content, flags=re.DOTALL
    )

    content = re.sub(
        r'Card\(\s*child:\s*ListTile\(',
        r'PNCard(\n  padding: EdgeInsets.zero,\n  child: ListTile(',
        content, flags=re.DOTALL
    )

    # Remove Gradients
    content = re.sub(
        r'gradient:\s*LinearGradient\([^)]+\),',
        r'color: AppColors.primary,',
        content, flags=re.DOTALL
    )
    
    # In _buildHeader inside home_view.dart
    content = re.sub(
        r'gradient:\s*LinearGradient\(\s*begin:[^,]+,\s*end:[^,]+,\s*colors:\s*\[[^\]]+\],\s*\),',
        r'color: AppColors.primary,',
        content, flags=re.DOTALL
    )

    if original != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Updated {filepath}")

dirs = ['lib/features/groups/views', 'lib/features/home/views', 'lib/features/history/views', 'lib/features/settings/views']
for d in dirs:
    d = os.path.join('D:/StudioProjects/poker_night', d)
    for f in os.listdir(d):
        if f.endswith('.dart'):
            process_file(os.path.join(d, f))

