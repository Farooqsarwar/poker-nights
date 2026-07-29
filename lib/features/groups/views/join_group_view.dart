import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pn_button.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/groups_controller.dart';

class JoinGroupView extends StatefulWidget {
  const JoinGroupView({super.key});

  @override
  State<JoinGroupView> createState() => _JoinGroupViewState();
}

class _JoinGroupViewState extends State<JoinGroupView> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final user = Get.find<AuthController>().currentUser.value;
      if (user == null) return;
      final group = await Get.find<GroupsController>().joinGroup(
        _codeController.text.trim().toUpperCase(),
      );
      if (!mounted) return;
      if (group != null) {
        context.go('/groups/${group.id}');
      } else {
        setState(() => _error = 'Group not found. Check the code and try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkSurface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textOnDark),
          onPressed: () => context.pop(),
        ),
        title: const Text('Join Group', style: TextStyle(color: AppColors.textOnDark, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.cardDark,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.1),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.group_add, size: 56, color: AppColors.accent),
                    ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                    const SizedBox(height: 32),
                    Text('Enter Join Code', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.textOnDark, fontWeight: FontWeight.bold)).animate().fade(delay: 100.ms),
                    const SizedBox(height: 8),
                    const Text('Ask the group admin for the 6-character code', style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center).animate().fade(delay: 200.ms),
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.darkSurface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                      ),
                      child: TextFormField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _join(),
                        maxLength: AppConstants.joinCodeLength,
                        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 12, color: AppColors.textOnDark, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: '------',
                          hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.3), fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 12, fontFamily: 'monospace'),
                          counterText: '',
                          border: InputBorder.none,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.content_paste, color: AppColors.textSecondary),
                            onPressed: () {
                              // Optional paste implementation here
                            },
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().length != AppConstants.joinCodeLength) {
                            return 'Enter a valid ${AppConstants.joinCodeLength}-character code';
                          }
                          return null;
                        },
                      ),
                    ).animate().fade(delay: 300.ms).slideY(begin: 0.1, end: 0),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.red, size: 20),
                            const SizedBox(width: 8),
                            Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
                          ],
                        ),
                      ).animate().fade().slideY(begin: -0.1, end: 0),
                    ],
                    const SizedBox(height: 32),
                    PNButton(
                      width: double.infinity,
                      height: 52,
                      loading: _loading,
                      onPressed: _join,
                      label: 'Join Group',
                    ).animate().fade(delay: 400.ms).slideY(begin: 0.2, end: 0),
                    const SizedBox(height: 40),
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('OR', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                        ),
                        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                      ],
                    ).animate().fade(delay: 500.ms),
                    const SizedBox(height: 32),
                    PNSecondaryButton(
                      onPressed: () {
                        // QR Scanner placeholder
                      },
                      icon: Icons.qr_code_scanner,
                      label: 'Scan QR Code',
                    ).animate().fade(delay: 600.ms).slideY(begin: 0.2, end: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
