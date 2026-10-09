import re

with open('lib/screens/tournament/deal_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add import
if 'count_stepper.dart' not in content:
    content = content.replace("import '../../widgets/app_button.dart';", "import '../../widgets/app_button.dart';\nimport '../../widgets/count_stepper.dart';")

# Replace IconButton steppers with CountStepper
content = re.sub(
    r'''IconButton\(\n\s*icon: const Icon\(Icons\.remove_circle_outline, size: 20\),\n\s*onPressed: \(counts\[chip\.value\] \?\? 0\) > 0\n\s*\? \(\) => setModalState\(\(\) {\n\s*counts\[chip\.value\] = \(counts\[chip\.value\] \?\? 0\) - 1;\n\s*}\)\n\s*: null,\n\s*\),\n\s*Text\('\$\{counts\[chip\.value\] \?\? 0\}', style: AppTypography\.monoSm\),\n\s*IconButton\(\n\s*icon: const Icon\(Icons\.add_circle_outline, size: 20\),\n\s*onPressed: \(\) => setModalState\(\(\) {\n\s*counts\[chip\.value\] = \(counts\[chip\.value\] \?\? 0\) \+ 1;\n\s*}\),\n\s*\),''',
    '''SizedBox(
                            width: 150,
                            child: CountStepper(
                              value: counts[chip.value] ?? 0,
                              min: 0,
                              step: 1,
                              quickSteps: const [10],
                              onChanged: (v) => setModalState(() {
                                counts[chip.value] = v;
                              }),
                            ),
                          ),''',
    content
)

with open('lib/screens/tournament/deal_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
