import 'package:flutter/material.dart';
import 'package:poker_night/core/widgets/pn_button.dart';
import 'package:poker_night/core/widgets/pn_card.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:poker_night/core/theme/app_colors.dart';
import 'package:poker_night/features/auth/controllers/auth_controller.dart';
import 'package:poker_night/features/groups/controllers/groups_controller.dart';
import 'package:poker_night/features/groups/models/group_model.dart';
import 'package:poker_night/features/auth/models/user_model.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _currentTab = 0;
  late GroupsController _groupsController;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<GroupsController>()) {
      Get.put(GroupsController());
    }
    _groupsController = Get.find<GroupsController>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadGroups());
  }

  void _loadGroups() {
    final user = Get.find<AuthController>().currentUser.value;
    if (user != null) {
      _groupsController.loadGroups();
    }
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
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: IndexedStack(
              index: _currentTab,
              children: [
                _HomeTab(user: user, onTabChange: (t) => setState(() => _currentTab = t)),
                _GroupsTab(user: user),
                _ProfileTab(user: user),
              ],
            ),
          ),
        ),
        floatingActionButton: _currentTab == 1
            ? FloatingActionButton(
                onPressed: () => _showGroupOptions(context),
                backgroundColor: AppColors.accent,
                child: const Icon(Icons.add, color: Colors.white),
              )
            : null,
        bottomNavigationBar: _buildBottomNav(),
      );
    });
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(icon: Icons.home_rounded, label: 'Home', index: 0, current: _currentTab, onTap: (i) => setState(() => _currentTab = i)),
              _NavItem(icon: Icons.group_rounded, label: 'Groups', index: 1, current: _currentTab, onTap: (i) => setState(() => _currentTab = i)),
              _NavItem(icon: Icons.person_rounded, label: 'Profile', index: 2, current: _currentTab, onTap: (i) => setState(() => _currentTab = i)),
            ],
          ),
        ),
      ),
    );
  }

  void _showGroupOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.add, color: AppColors.accent, size: 22),
                ),
                title: const Text('Create Group', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                subtitle: const Text('Start a new private poker group', style: TextStyle(color: AppColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                onTap: () { Navigator.pop(context); context.push('/groups/create'); },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.qr_code_scanner, color: AppColors.gold, size: 22),
                ),
                title: const Text('Join Group', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                subtitle: const Text('Enter an invite code to join', style: TextStyle(color: AppColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                onTap: () { Navigator.pop(context); context.push('/groups/join'); },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final void Function(int) onTap;

  const _NavItem({required this.icon, required this.label, required this.index, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = index == current;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accent.withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final UserModel user;
  final void Function(int) onTabChange;

  const _HomeTab({required this.user, required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final groupsController = Get.find<GroupsController>();
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          if (groupsController.isLoading.value)
            const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator(color: AppColors.accent))))
          else if (groupsController.error.value.isNotEmpty)
            SliverToBoxAdapter(child: _buildError(groupsController.error.value))
          else if (groupsController.groups.isEmpty)
            _buildEmptySliver(context)
          else
            _buildGroupsSliver(context, groupsController.groups),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      );
    });
  }

  Widget _buildHeader(BuildContext context) {
    final greeting = _getGreeting();
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.cardDark,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(greeting, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      user.name,
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/settings'),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: const Icon(Icons.settings_outlined, color: Colors.white70, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildQuickActions(context),
        ],
      ),
    ).animate().fade(duration: 400.ms);
  }

  Widget _buildQuickActions(BuildContext context) {
    final groups = Get.find<GroupsController>().groups;
    if (groups.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        _QuickStat(label: 'Groups', value: groups.length.toString(), icon: Icons.group_rounded, color: AppColors.accent),
        const SizedBox(width: 12),
        const _QuickStat(label: 'Active', value: '—', icon: Icons.casino_outlined, color: AppColors.gold),
      ],
    );
  }

  SliverToBoxAdapter _buildEmptySliver(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.cardDark,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Icon(Icons.casino_outlined, size: 56, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            const Text('Welcome to Poker Night!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 8),
            Text('Create your first group to start organizing tournaments and cash games.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), height: 1.5, fontSize: 14),
              textAlign: TextAlign.center),
            const SizedBox(height: 28),
            PNButton(
              width: double.infinity,
              onPressed: () => context.push('/groups/create'),
              icon: Icons.add_rounded,
              label: 'Create My First Group',
            ),
            const SizedBox(height: 12),
            PNSecondaryButton(
              onPressed: () => context.push('/groups/join'),
              icon: Icons.qr_code_scanner_rounded,
              label: 'Join with Code',
            ),
          ],
        ),
      ).animate().fade(delay: 200.ms).slideY(begin: 0.1, end: 0),
    );
  }

  SliverList _buildGroupsSliver(BuildContext context, List<GroupModel> groups) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('My Groups', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  TextButton(onPressed: () => onTabChange(1), child: const Text('See All', style: TextStyle(color: AppColors.accent))),
                ],
              ),
            );
          }
          final group = groups[i - 1];
          return _GroupListTile(group: group, index: i - 1);
        },
        childCount: groups.length + 1,
      ),
    );
  }

  Widget _buildError(String e) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.red),
          const SizedBox(height: 12),
          const Text('Error loading groups', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
          Text(e, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
}

class _QuickStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _QuickStat({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
                Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupListTile extends StatelessWidget {
  final GroupModel group;
  final int index;

  const _GroupListTile({required this.group, required this.index});

  @override
  Widget build(BuildContext context) {
    final colors = [AppColors.accent, AppColors.gold, AppColors.green, AppColors.blue, AppColors.purple];
    final color = colors[index % colors.length];

    return PNCard(
      onTap: () => context.push('/groups/${group.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
                    style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(
                      '${group.memberCount} member${group.memberCount == 1 ? '' : 's'}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
            ],
          ),
    ).animate(delay: (index * 60).ms).fade().slideX(begin: 0.05, end: 0);
  }
}

class _GroupsTab extends StatelessWidget {
  final UserModel user;

  const _GroupsTab({required this.user});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final groupsController = Get.find<GroupsController>();
      return CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('Groups', style: TextStyle(color: Colors.white)),
            pinned: true,
            backgroundColor: AppColors.darkSurface,
            actions: [
              IconButton(
                icon: const Icon(Icons.search_rounded, color: Colors.white),
                onPressed: () {},
                tooltip: 'Search groups',
              ),
            ],
          ),
          if (groupsController.isLoading.value)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.accent)))
          else if (groupsController.error.value.isNotEmpty)
            SliverFillRemaining(child: Center(child: Text('Error: ${groupsController.error.value}', style: const TextStyle(color: Colors.red))))
          else if (groupsController.groups.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.group_off_rounded, size: 64, color: AppColors.textSecondary),
                    const SizedBox(height: 16),
                    const Text('No groups yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text('Create or join a group to start playing', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14)),
                    const SizedBox(height: 24),
                    PNButton(
                      onPressed: () => context.push('/groups/create'),
                      icon: Icons.add_rounded,
                      label: 'Create Group',
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _GroupListTile(group: groupsController.groups[i], index: i),
                  childCount: groupsController.groups.length,
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _ProfileTab extends StatelessWidget {
  final UserModel user;
  const _ProfileTab({required this.user});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: const Text('Profile', style: TextStyle(color: Colors.white)),
          pinned: true,
          backgroundColor: AppColors.darkSurface,
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Avatar
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 88, height: 88,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent,
                      ),
                      child: Center(
                        child: Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: AppColors.cardDark, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt_rounded, size: 16, color: AppColors.accent),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(user.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 4),
                Text(user.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                const SizedBox(height: 32),

                // Menu items
                _ProfileMenuItem(icon: Icons.settings_outlined, label: 'App Settings', onTap: () => context.push('/settings')),
                _ProfileMenuItem(icon: Icons.history_rounded, label: 'Game History', onTap: () {}),
                _ProfileMenuItem(icon: Icons.notifications_outlined, label: 'Notifications', onTap: () {}),
                _ProfileMenuItem(icon: Icons.privacy_tip_outlined, label: 'Privacy Policy', onTap: () => context.push('/privacy')),
                _ProfileMenuItem(icon: Icons.article_outlined, label: 'Terms of Service', onTap: () => context.push('/terms')),
                const SizedBox(height: 24),
                PNButton(
                  width: double.infinity,
                  destructive: true,
                  outlined: true,
                  onPressed: () async {
                    await Get.find<AuthController>().logout();
                    if (context.mounted) context.go('/landing');
                  },
                  icon: Icons.logout_rounded,
                  label: 'Sign Out',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ProfileMenuItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PNCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: AppColors.accent, size: 22),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15, color: Colors.white)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
