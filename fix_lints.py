import re

# auth_screen.dart
with open('lib/screens/public/auth_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

code = code.replace("import '../../widgets/backgrounds.dart';", "")
code = code.replace(r"\", "")
code = code.replace(r"\", "")
code = code.replace(r"\", "")

with open('lib/screens/public/auth_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)

# join_screen.dart
with open('lib/screens/public/join_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

code = code.replace("import '../../widgets/backgrounds.dart';", "")
code = code.replace("final statusBarHeight = MediaQuery.paddingOf(context).top;", "")

with open('lib/screens/public/join_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)

# app_text_field.dart
with open('lib/widgets/app_text_field.dart', 'r', encoding='utf-8') as f:
    code = f.read()

code = code.replace("import 'glass_styles.dart';", "")

with open('lib/widgets/app_text_field.dart', 'w', encoding='utf-8') as f:
    f.write(code)
