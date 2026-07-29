import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pn_button.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/groups_controller.dart';

class CreateGroupView extends StatefulWidget {
  const CreateGroupView({super.key});

  @override
  State<CreateGroupView> createState() => _CreateGroupViewState();
}

class _CreateGroupViewState extends State<CreateGroupView> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _joinCode;
  bool _isPrivate = true;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final user = Get.find<AuthController>().currentUser.value;
      if (user == null) return;
      final groupsController = Get.find<GroupsController>();
      final group = await groupsController.createGroup(
        _nameController.text.trim(),
      );
      if (group != null) {
        setState(() => _joinCode = group.joinCode);
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
          icon: const Icon(Icons.close, color: AppColors.textOnDark),
          onPressed: () => context.pop(),
        ),
        title: const Text('Create Group', style: TextStyle(color: AppColors.textOnDark, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _joinCode != null ? _buildSuccess() : _buildForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.casino, size: 40, color: AppColors.accent),
          ).animate().scale(duration: 400.ms),
          const SizedBox(height: 24),
          Text('New Poker Group', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.textOnDark, fontWeight: FontWeight.bold)).animate().fade(delay: 100.ms),
          const SizedBox(height: 8),
          const Text('Set up a new space for your poker nights', style: TextStyle(color: AppColors.textSecondary)).animate().fade(delay: 200.ms),
          const SizedBox(height: 32),
          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            maxLength: AppConstants.maxGroupNameLength,
            style: const TextStyle(color: AppColors.textOnDark),
            decoration: InputDecoration(
              labelText: 'Group Name',
              prefixIcon: const Icon(Icons.emoji_emotions_outlined, color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.darkSurface.withValues(alpha: 0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              counterStyle: const TextStyle(color: AppColors.textSecondary),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Group name is required';
              return null;
            },
          ).animate().fade(delay: 300.ms).slideX(),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descController,
            textInputAction: TextInputAction.done,
            maxLines: 3,
            style: const TextStyle(color: AppColors.textOnDark),
            decoration: InputDecoration(
              labelText: 'Description (Optional)',
              alignLabelWithHint: true,
              filled: true,
              fillColor: AppColors.darkSurface.withValues(alpha: 0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ).animate().fade(delay: 400.ms).slideX(),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.darkSurface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Private Group', style: TextStyle(color: AppColors.textOnDark, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Only people with the code can join', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
                Switch(
                  value: _isPrivate,
                  onChanged: (v) => setState(() => _isPrivate = v),
                  activeThumbColor: AppColors.accent,
                ),
              ],
            ),
          ).animate().fade(delay: 500.ms).slideX(),
          const SizedBox(height: 40),
          PNButton(
            width: double.infinity,
            height: 52,
            loading: _loading,
            onPressed: _create,
            label: 'Create Group',
          ).animate().fade(delay: 600.ms).slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.cardDark,
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.2),
                blurRadius: 32,
                spreadRadius: 8,
              ),
            ],
            border: Border.all(color: Colors.green.withValues(alpha: 0.5), width: 2),
          ),
          child: const Icon(Icons.check_circle, size: 72, color: Colors.green),
        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
        const SizedBox(height: 24),
        Text('Group Created!', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.textOnDark, fontWeight: FontWeight.bold)).animate().fade(delay: 200.ms),
        const SizedBox(height: 32),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
            ),
            child: Column(
              children: [
                const Text('Share this code with friends', style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _joinCode!,
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 12, color: AppColors.accent),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Enter this code in Poker Night to join', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ).animate().fade(delay: 400.ms).slideY(begin: 0.1, end: 0),
        const SizedBox(height: 40),
        PNButton(
          width: double.infinity,
          height: 52,
          onPressed: () {
            final user = Get.find<AuthController>().currentUser.value;
            if (user != null) {
              final groups = Get.find<GroupsController>().groups;
              final group = groups.where((g) => g.joinCode == _joinCode).firstOrNull;
              if (group != null) {
                context.go('/groups/${group.id}');
                return;
              }
            }
            context.go('/groups');
          },
          label: 'Go to Group',
        ).animate().fade(delay: 600.ms).slideY(begin: 0.2, end: 0),
      ],
    );
  }
}
