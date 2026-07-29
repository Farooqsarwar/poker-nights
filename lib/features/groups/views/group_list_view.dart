import 'package:flutter/material.dart';
import 'package:poker_night/core/widgets/pn_button.dart';
import 'package:poker_night/core/widgets/pn_card.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:poker_night/core/theme/app_colors.dart';
import 'package:poker_night/features/auth/controllers/auth_controller.dart';
import 'package:poker_night/features/groups/controllers/groups_controller.dart';

class GroupListView extends StatefulWidget {
  const GroupListView({super.key});

  @override
  State<GroupListView> createState() => _GroupListViewState();
}

class _GroupListViewState extends State<GroupListView> {
  late GroupsController _groupsController;

  @override
  void initState() {
    super.initState();
    _groupsController = Get.find<GroupsController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Get.find<AuthController>().currentUser.value;
      if (user != null) _groupsController.loadGroups();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final user = Get.find<AuthController>().currentUser.value;
      if (user == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/login'));
        return const SizedBox.shrink();
      }

      return Scaffold(
        backgroundColor: AppColors.darkSurface,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/groups/create'),
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('New Group', style: TextStyle(fontWeight: FontWeight.bold)),
        ).animate().scale(delay: 400.ms, duration: 400.ms),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 120,
                  pinned: true,
                  backgroundColor: AppColors.darkSurface,
                  flexibleSpace: FlexibleSpaceBar(
                    title: const Text('My Groups', style: TextStyle(color: AppColors.textOnDark, fontWeight: FontWeight.bold)),
                    background: Container(
                      color: AppColors.darkSurface,
                    ),
                  ),
                ),
                SliverFillRemaining(
                  child: _buildBody(),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildBody() {
    if (_groupsController.isLoading.value) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    
    if (_groupsController.error.value.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.red.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.error_outline, color: AppColors.red, size: 48),
            ),
            const SizedBox(height: 16),
            Text('Failed to load groups', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.textOnDark)),
            const SizedBox(height: 8),
            Text(_groupsController.error.value, style: const TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            PNButton(
              onPressed: () {
                _groupsController.loadGroups();
              },
              label: 'Retry',
            ),
          ],
        ),
      );
    }

    final groups = _groupsController.groups;

    if (groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cardDark,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.1),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.3), width: 1),
              ),
              child: const Icon(Icons.casino, size: 64, color: AppColors.gold),
            ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 24),
            Text('No groups yet', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.textOnDark, fontWeight: FontWeight.bold)).animate().fade(delay: 200.ms),
            const SizedBox(height: 8),
            const Text('Create a new group or join an existing one.', style: TextStyle(color: AppColors.textSecondary)).animate().fade(delay: 300.ms),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PNButton(
                  onPressed: () => context.push('/groups/create'),
                  icon: Icons.add,
                  label: 'Create Group',
                ),
                const SizedBox(width: 16),
                PNSecondaryButton(
                  onPressed: () => context.push('/groups/join'),
                  icon: Icons.login,
                  label: 'Join Group',
                ),
              ],
            ).animate().fade(delay: 400.ms).slideY(begin: 0.2, end: 0),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.cardDark,
      onRefresh: () => _groupsController.loadGroups(),
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
        itemCount: groups.length + 1,
        itemBuilder: (_, i) {
          if (i == groups.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: PNSecondaryButton(
                onPressed: () => context.push('/groups/join'),
                icon: Icons.login,
                label: 'Join Another Group',
              ).animate().fade().slideY(begin: 0.2, end: 0),
            );
          }
          final group = groups[i];
          return PNCard(
            margin: const EdgeInsets.only(bottom: 12),
            onTap: () => context.push('/groups/${group.id}'),
            padding: const EdgeInsets.all(16),
            child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        group.name.isNotEmpty ? group.name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: const TextStyle(color: AppColors.textOnDark, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'View Group',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  ],
                ),
          ).animate().fade(delay: (i * 50).ms).slideX(begin: 0.1, end: 0);
        },
      ),
    );
  }
}
