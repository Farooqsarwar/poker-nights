import re

with open('lib/screens/public/tv_mode_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add import
if 'svg_countdown_ring.dart' not in content:
    content = content.replace("import '../../utils/voice_service.dart';", "import '../../utils/voice_service.dart';\nimport '../../widgets/svg_countdown_ring.dart';")

# Update class signature
content = content.replace('class _RotatingPanelState extends State<_RotatingPanel> {', 'class _RotatingPanelState extends State<_RotatingPanel> with SingleTickerProviderStateMixin {')

# Add animation controller
if '_progressController' not in content:
    content = re.sub(
        r'Timer\?\s*_timer;',
        r'Timer? _timer;\n  late AnimationController _progressController;\n  late Animation<double> _progressAnimation;',
        content
    )

    content = re.sub(
        r'void initState\(\) {\n\s*super\.initState\(\);\n\s*_restartTimer\(\);\n\s*}',
        r'void initState() {\n    super.initState();\n    _progressController = AnimationController(\n      duration: Duration(seconds: widget.display.rotateSeconds),\n      vsync: this,\n    );\n    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(\n      CurvedAnimation(parent: _progressController, curve: Curves.linear),\n    );\n    _restartTimer();\n  }',
        content
    )

    content = re.sub(
        r'void didUpdateWidget\(_RotatingPanel old\) {\n\s*super\.didUpdateWidget\(old\);\n\s*if \(old\.display\.rotateSeconds != widget\.display\.rotateSeconds\) {\n\s*_restartTimer\(\);\n\s*}\n\s*}',
        r'void didUpdateWidget(_RotatingPanel old) {\n    super.didUpdateWidget(old);\n    if (old.display.rotateSeconds != widget.display.rotateSeconds) {\n      _progressController.duration = Duration(seconds: widget.display.rotateSeconds);\n      _restartTimer();\n    }\n  }',
        content
    )

    content = re.sub(
        r'void _restartTimer\(\) {\n\s*_timer\?\.cancel\(\);\n\s*_timer = Timer\.periodic\(\n\s*Duration\(seconds: widget\.display\.rotateSeconds\),\n\s*\(_\) {\n\s*final n = _active\.length;\n\s*if \(n <= 1\) return;\n\s*setState\(\(\) => _panel = \(_panel \+ 1\) % n\);\n\s*},\n\s*\);\n\s*}',
        r'void _restartTimer() {\n    _timer?.cancel();\n    if (_active.length > 1) {\n      _progressController.forward(from: 0.0);\n    }\n    _timer = Timer.periodic(\n      Duration(seconds: widget.display.rotateSeconds),\n      (_) {\n        final n = _active.length;\n        if (n <= 1) return;\n        setState(() => _panel = (_panel + 1) % n);\n        _progressController.forward(from: 0.0);\n      },\n    );\n  }',
        content
    )

    content = re.sub(
        r'void dispose\(\) {\n\s*_timer\?\.cancel\(\);\n\s*super\.dispose\(\);\n\s*}',
        r'void dispose() {\n    _timer?.cancel();\n    _progressController.dispose();\n    super.dispose();\n  }',
        content
    )

    # Replace the Text widget with a Row containing the text and the ring
    content = re.sub(
        r'Text\(\n\s*_titles\[effectivePanel\],\n\s*style: AppTypography\.mono\(\n\s*size: 15 \* widget\.scale,\n\s*weight: FontWeight\.w700,\n\s*letterSpacing: 2\.5,\n\s*color: AppColors\.primary,\n\s*\),\n\s*\),',
        r'''Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _titles[effectivePanel],
                style: AppTypography.mono(
                  size: 15 * widget.scale,
                  weight: FontWeight.w700,
                  letterSpacing: 2.5,
                  color: AppColors.primary,
                ),
              ),
              if (_active.length > 1)
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return SvgCountdownRing(
                      progress: _progressAnimation.value,
                      scale: widget.scale * 0.4,
                    );
                  },
                ),
            ],
          ),''',
        content
    )

with open('lib/screens/public/tv_mode_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
