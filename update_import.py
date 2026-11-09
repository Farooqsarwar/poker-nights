import re
with open('lib/screens/tournament/final_table_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()
if 'svg_countdown_ring.dart' not in content:
    content = content.replace("import '../../widgets/app_page.dart';", "import '../../widgets/app_page.dart';\nimport '../../widgets/svg_countdown_ring.dart';")
with open('lib/screens/tournament/final_table_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
