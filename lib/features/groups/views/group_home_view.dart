import 'package:flutter/material.dart';
import 'package:poker_night/core/widgets/pn_button.dart';
import 'package:poker_night/core/widgets/pn_card.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:poker_night/core/theme/app_colors.dart';
import 'package:poker_night/features/auth/controllers/auth_controller.dart';
import 'package:poker_night/features/groups/controllers/groups_controller.dart';
import 'package:poker_night/features/groups/models/group_model.dart';
import 'package:poker_night/features/tournament/controllers/tournament_controller.dart';
import 'package:poker_night/features/tournament/models/tournament_model.dart';
import 'package:responsive_framework/responsive_framework.dart';

class GroupHomeView extends StatefulWidget {
  final String groupId;
  const GroupHomeView({super.key, required this.groupId});

  @override
  State<GroupHomeView> createState() => _GroupHomeViewState();
}

class _GroupHomeViewState extends State<GroupHomeView> {
  late GroupsController _groupsController;
  late TournamentController _tournamentController;

  @override
  void initState() {
    super.initState();
    _groupsController = Get.find<GroupsController>();
    final user = Get.find<AuthController>().currentUser.value;
    if (user != null) {
      if (!Get.isRegistered<TournamentController>()) {
        Get.put(TournamentController());
      }
      _tournamentController = Get.find<TournamentController>();
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    final user = Get.find<AuthController>().currentUser.value;
    if (user == null) return;
    _groupsController.loadGroups();
    _tournamentController.loadTournaments(widget.groupId);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final user = Get.find<AuthController>().currentUser.value;
      if (user == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/login'));
        return const SizedBox.shrink();
      }

      final group = _groupsController.groups.firstWhereOrNull((g) => g.id == widget.groupId);
      final isAdmin = group != null && group.ownerUserId == user.id;

      return Scaffold(
        backgroundColor: AppColors.darkSurface,
        appBar: AppBar(
          backgroundColor: AppColors.darkSurface,
          title: Text(group?.name ?? 'Group', style: const TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            if (isAdmin)
              PopupMenuButton<String>(
                color: AppColors.cardDark,
                onSelected: (v) {
                  if (v == 'rotate_code') _rotateCode(group);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'rotate_code', child: Text('Rotate Join Code', style: TextStyle(color: Colors.white))),
                ],
              ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: _groupsController.isLoading.value
                ? const Center(child: CircularProgressIndicator())
                : _groupsController.error.value.isNotEmpty
                    ? Center(child: Text('Error: ${_groupsController.error.value}', style: const TextStyle(color: Colors.red)))
                    : group == null
                        ? const Center(child: Text('Group not found', style: TextStyle(color: Colors.white)))
                        : _buildContent(context, group, isAdmin),
          ),
        ),
      );
    });
  }

  Widget _buildContent(BuildContext context, GroupModel group, bool isAdmin) {
    final isDesktop = ResponsiveBreakpoints.of(context).largerThan(TABLET);

    final content = RefreshIndicator(
      onRefresh: () async => _loadData(),
      color: AppColors.accent,
      backgroundColor: AppColors.cardDark,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _GroupHeader(group: group),
          const SizedBox(height: 24),
          if (!isDesktop) ...[
            _ActionButtons(groupId: widget.groupId, isAdmin: isAdmin),
            const SizedBox(height: 24),
          ],
          Text('Members', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          _MemberListTile(group: group, isAdmin: isAdmin),
          const SizedBox(height: 24),
          Text('Tournaments', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          Obx(() {
            if (_tournamentController.isLoading.value) {
              return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
            }
            if (_tournamentController.error.value.isNotEmpty) {
              return Center(child: Text('Error: ${_tournamentController.error.value}', style: const TextStyle(color: Colors.red)));
            }
            return _buildTournamentsSection(_tournamentController.tournaments, isAdmin, isDesktop);
          }),
        ],
      ),
    );

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: AppColors.darkSurface,
            child: SizedBox(
              width: 250,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Actions', style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.textSecondary, fontWeight: FontWeight.bold,
                    )),
                  ),
                  Expanded(child: _ActionButtonsVertical(groupId: widget.groupId, isAdmin: isAdmin)),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1, color: Colors.white12),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: content,
              ),
            ),
          ),
        ],
      );
    }

    return content;
  }

  Widget _buildTournamentsSection(List<TournamentModel> tournaments, bool isAdmin, bool isDesktop) {
    final upcoming = tournaments.where((t) => t.status == 'draft' || t.status == 'published').toList();
    final past = tournaments.where((t) => t.status == 'completed' || t.status == 'cancelled').toList();
    if (tournaments.isEmpty) {
      return PNCard(
        padding: const EdgeInsets.all(24),
        child: Column(
            children: [
              const Icon(Icons.emoji_events_outlined, size: 40, color: AppColors.textSecondary),
              const SizedBox(height: 8),
              const Text('No tournaments yet', style: TextStyle(color: AppColors.textSecondary)),
              if (isAdmin && !isDesktop) ...[
                const SizedBox(height: 12),
                PNButton(
                  onPressed: () => context.push('/groups/${widget.groupId}/create-tournament'),
                  icon: Icons.add,
                  label: 'Create Tournament',
                ),
              ],
            ],
          ),
      );
    }
    return Column(
      children: [
        if (upcoming.isNotEmpty) ...[
          Text('Upcoming (${upcoming.length})', style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          ...upcoming.map((t) => _TournamentTile(tournament: t, groupId: widget.groupId, groupAdmin: isAdmin)),
          const SizedBox(height: 12),
        ],
        if (past.isNotEmpty) ...[
          Text('Past (${past.length})', style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          ...past.map((t) => _TournamentTile(tournament: t, groupId: widget.groupId, groupAdmin: isAdmin)),
        ],
      ],
    );
  }

  void _rotateCode(GroupModel? group) {
    if (group == null) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: const Text('Rotate Join Code', style: TextStyle(color: Colors.white)),
        content: const Text('This will invalidate the current join code. Are you sure?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          PNButton(
            onPressed: () {
              _groupsController.rotateCode(widget.groupId);
              Navigator.pop(context);
            },
            label: 'Rotate',
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final GroupModel group;
  const _GroupHeader({required this.group});

  @override
  Widget build(BuildContext context) {
    return PNCard(
      padding: const EdgeInsets.all(20),
      child: Row(
            children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.accent.withValues(alpha: 0.15),
              child: Text(group.name[0].toUpperCase(), style: const TextStyle(fontSize: 24, color: AppColors.accent, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Code: ${group.joinCode} · ${group.memberCount} member${group.memberCount == 1 ? '' : 's'}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final String groupId;
  final bool isAdmin;
  const _ActionButtons({required this.groupId, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (isAdmin)
          _ActionChip(icon: Icons.add_circle_outline, label: 'Create Tournament', onTap: () => context.push('/groups/$groupId/create-tournament')),
        _ActionChip(icon: Icons.chat_outlined, label: 'Chat', onTap: () => context.push('/groups/$groupId/chat')),
        _ActionChip(icon: Icons.poll_outlined, label: 'Polls', onTap: () => context.push('/groups/$groupId/polls')),
        _ActionChip(icon: Icons.history, label: 'History', onTap: () => context.push('/groups/$groupId/history')),
        _ActionChip(icon: Icons.attach_money, label: 'Cash Game', onTap: () => context.push('/groups/$groupId/cash-game')),
        if (isAdmin)
          _ActionChip(icon: Icons.admin_panel_settings_outlined, label: 'Admin', onTap: () => _showAdminMenu(context, groupId)),
      ],
    );
  }

  void _showAdminMenu(BuildContext context, String groupId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Admin Actions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: Colors.white)),
            ),
            ListTile(
              leading: const Icon(Icons.people_outline, color: Colors.white),
              title: const Text('Manage Members', style: TextStyle(color: Colors.white)),
              subtitle: const Text('View and manage group members', style: TextStyle(color: Colors.white70)),
              onTap: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member management coming soon'))); },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.white),
              title: const Text('Group Settings', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Edit group name, join code settings', style: TextStyle(color: Colors.white70)),
              onTap: () {
                Navigator.pop(ctx);
                _showGroupSettingsDialog(context, groupId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white),
              title: const Text('App Settings', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Global app preferences', style: TextStyle(color: Colors.white70)),
              onTap: () { Navigator.pop(ctx); context.push('/settings'); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showGroupSettingsDialog(BuildContext context, String groupId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: const Text('Group Settings', style: TextStyle(color: Colors.white)),
        content: const Text('Group settings management will be available in a future update.', style: TextStyle(color: Colors.white70)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: AppColors.textSecondary)))],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: AppColors.cardDark,
      side: const BorderSide(color: Colors.white12),
      onPressed: onTap,
    );
  }
}

class _MemberListTile extends StatelessWidget {
  final GroupModel group;
  final bool isAdmin;
  const _MemberListTile({required this.group, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return PNCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.gold,
          child: Icon(Icons.people, color: Colors.white),
        ),
        title: Text('${group.memberCount} member${group.memberCount == 1 ? '' : 's'}', style: const TextStyle(color: Colors.white)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
        onTap: () => _showMembers(context),
      ),
    );
  }

  void _showMembers(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Members (${group.memberCount})', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: Colors.white)),
            ),
            ListTile(
              leading: CircleAvatar(backgroundColor: AppColors.accent.withValues(alpha: 0.15), child: const Icon(Icons.person, color: AppColors.accent)),
              title: const Text('Owner', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Admin', style: TextStyle(color: Colors.white70)),
            ),
            for (var i = 1; i < group.memberCount; i++)
              ListTile(
                leading: CircleAvatar(backgroundColor: Colors.grey.withValues(alpha: 0.15), child: const Icon(Icons.person_outline, color: Colors.grey)),
                title: Text('Member $i', style: const TextStyle(color: Colors.white)),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _TournamentTile extends StatelessWidget {
  final TournamentModel tournament;
  final String groupId;
  final bool groupAdmin;

  const _TournamentTile({required this.tournament, required this.groupId, this.groupAdmin = false});

  IconData _statusIcon() {
    switch (tournament.status) {
      case 'draft': return Icons.edit_note;
      case 'published': return Icons.publish;
      case 'active': return Icons.play_circle;
      case 'paused': return Icons.pause_circle;
      case 'completed': return Icons.check_circle;
      case 'cancelled': return Icons.cancel;
      default: return Icons.help_outline;
    }
  }

  Color _statusColor() {
    switch (tournament.status) {
      case 'draft': return AppColors.textSecondary;
      case 'published': return AppColors.gold;
      case 'active': return AppColors.green;
      case 'paused': return AppColors.gold;
      case 'completed': return AppColors.green;
      case 'cancelled': return AppColors.red;
      default: return AppColors.textSecondary;
    }
  }

  String _formattedDate() {
    final d = tournament.scheduledAt;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isActive = tournament.status == 'active' || tournament.status == 'paused';
    final isDraft = tournament.status == 'draft';
    final isPublished = tournament.status == 'published';
    final isCompleted = tournament.status == 'completed';

    return PNCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: () {
          if (isDraft) {
            context.push('/groups/$groupId/tournament/${tournament.id}/review');
          } else if (isPublished) {
            context.push('/groups/$groupId/tournament/${tournament.id}/lobby');
          } else if (isCompleted) {
            context.push('/groups/$groupId/tournament/${tournament.id}/results');
          } else {
            context.push('/groups/$groupId/tournament/${tournament.id}/admin');
          }
        },
      padding: const EdgeInsets.all(16),
      child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _statusColor().withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_statusIcon(), color: _statusColor(), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tournament.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (isActive) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                            child: const Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.green)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(_formattedDate(), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              if (isActive)
                PNButton(
                  onPressed: () => context.push('/groups/$groupId/tournament/${tournament.id}/admin'),
                  icon: Icons.play_arrow,
                  label: 'Play',
                  height: 36,
                )
              else
                PopupMenuButton<String>(
                  color: AppColors.cardDark,
                  onSelected: (v) {
                    switch (v) {
                      case 'lobby':
                        context.push('/groups/$groupId/tournament/${tournament.id}/lobby');
                      case 'rsvp':
                        context.push('/groups/$groupId/tournament/${tournament.id}/rsvp');
                      case 'checkin':
                        context.push('/groups/$groupId/tournament/${tournament.id}/check-in');
                      case 'settlement':
                        context.push('/groups/$groupId/tournament/${tournament.id}/settlement');
                      case 'seating':
                        context.push('/groups/$groupId/tournament/${tournament.id}/seating');
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'lobby', child: Text('Lobby', style: TextStyle(color: Colors.white))),
                    const PopupMenuItem(value: 'rsvp', child: Text('RSVP', style: TextStyle(color: Colors.white))),
                    const PopupMenuItem(value: 'checkin', child: Text('Check-In', style: TextStyle(color: Colors.white))),
                    if (groupAdmin) const PopupMenuItem(value: 'settlement', child: Text('Settlement', style: TextStyle(color: Colors.white))),
                    const PopupMenuItem(value: 'seating', child: Text('Seating', style: TextStyle(color: Colors.white))),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(tournament.status.toUpperCase(),
                      style: TextStyle(color: _statusColor(), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
            ],
          ),
    );
  }
}

class _ActionButtonsVertical extends StatelessWidget {
  final String groupId;
  final bool isAdmin;
  const _ActionButtonsVertical({required this.groupId, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (isAdmin)
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: Colors.white),
            title: const Text('Create Tournament', style: TextStyle(color: Colors.white)),
            onTap: () => context.push('/groups/$groupId/create-tournament'),
          ),
        ListTile(
          leading: const Icon(Icons.chat_outlined, color: Colors.white),
          title: const Text('Chat', style: TextStyle(color: Colors.white)),
          onTap: () => context.push('/groups/$groupId/chat'),
        ),
        ListTile(
          leading: const Icon(Icons.poll_outlined, color: Colors.white),
          title: const Text('Polls', style: TextStyle(color: Colors.white)),
          onTap: () => context.push('/groups/$groupId/polls'),
        ),
        ListTile(
          leading: const Icon(Icons.history, color: Colors.white),
          title: const Text('History', style: TextStyle(color: Colors.white)),
          onTap: () => context.push('/groups/$groupId/history'),
        ),
        ListTile(
          leading: const Icon(Icons.attach_money, color: Colors.white),
          title: const Text('Cash Game', style: TextStyle(color: Colors.white)),
          onTap: () => context.push('/groups/$groupId/cash-game'),
        ),
        if (isAdmin)
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined, color: Colors.white),
            title: const Text('Admin', style: TextStyle(color: Colors.white)),
            onTap: () => _showAdminMenu(context, groupId),
          ),
      ],
    );
  }

  void _showAdminMenu(BuildContext context, String groupId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Admin Actions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: Colors.white)),
            ),
            ListTile(
              leading: const Icon(Icons.people_outline, color: Colors.white),
              title: const Text('Manage Members', style: TextStyle(color: Colors.white)),
              subtitle: const Text('View and manage group members', style: TextStyle(color: Colors.white70)),
              onTap: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member management coming soon'))); },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.white),
              title: const Text('Group Settings', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Edit group name, join code settings', style: TextStyle(color: Colors.white70)),
              onTap: () {
                Navigator.pop(ctx);
                _showGroupSettingsDialog(context, groupId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white),
              title: const Text('App Settings', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Global app preferences', style: TextStyle(color: Colors.white70)),
              onTap: () { Navigator.pop(ctx); context.push('/settings'); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showGroupSettingsDialog(BuildContext context, String groupId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: const Text('Group Settings', style: TextStyle(color: Colors.white)),
        content: const Text('Group settings management will be available in a future update.', style: TextStyle(color: Colors.white70)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: AppColors.textSecondary)))],
      ),
    );
  }
}
