import re

with open('lib/screens/public/auth_screen.dart', 'r', encoding='utf-8') as f:
    code = f.read()

build_method = '''  @override
  Widget build(BuildContext context) {
    final device = AppBreakpoints.deviceOf(context);
    final twoColumn = device.isDesktop || device.isLargeDesktop;

    final logo = const PokerNightLogo(size: 160);
    final card = _buildCard(context);

    final statusBarHeight = MediaQuery.paddingOf(context).top;
    
    final backBtn = Semantics(
      button: true,
      label: 'Back',
      child: InkWell(
        onTap: () => context.go(RoutePaths.landing),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF242428)),
          ),
          child: const Icon(
            Icons.chevron_left,
            size: 22,
            color: Color(0xFFE5797A),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        bottom: false,
        child: twoColumn
            ? Row(
                children: [
                  Expanded(child: Center(child: logo)),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            backBtn,
                            const SizedBox(height: 24),
                            card,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 16),
                            Align(alignment: Alignment.centerLeft, child: backBtn),
                            const SizedBox(height: 24),
                            card,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }'''

code = re.sub(r'  @override\s+Widget build\(BuildContext context\) \{.*?(?=  Widget _buildCard)', build_method + '\n\n', code, flags=re.DOTALL)

with open('lib/screens/public/auth_screen.dart', 'w', encoding='utf-8') as f:
    f.write(code)
