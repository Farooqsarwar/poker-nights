import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/route_paths.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/app_page.dart';

/// Landing page for a group invite link/QR code (`/join-group?code=...`).
/// Matches A8_JoinGroup.png layout with squircle badge, group summary, and actions.
class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key, required this.code});

  final String code;

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

enum _JoinState { working, success, failure }

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  _JoinState _state = _JoinState.working;

  String get _groupName => context.read<AppProvider>().currentGroup.name;

  int get _memberCount =>
      context.read<AppProvider>().currentGroup.members.length;

  int get _gamesCount => context.read<AppProvider>().currentGroup.games.length;

  String get _invitedBy {
    final group = context.read<AppProvider>().currentGroup;
    final owner = group.members.where((m) => m.id == group.ownerId).firstOrNull;
    if (owner != null && owner.name.isNotEmpty) {
      return 'Invited by ${owner.name}';
    }
    return 'You\'ve been invited to join';
  }

  String get _groupInitials {
    final name = _groupName;
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return 'FP';
    return parts
        .map((p) => p[0].toUpperCase())
        .join()
        .substring(0, parts.length >= 2 ? 2 : 1);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attemptJoin());
  }

  Future<void> _attemptJoin() async {
    final ok = await context.read<AppProvider>().joinGroup(widget.code);
    if (!mounted) return;
    setState(() => _state = ok ? _JoinState.success : _JoinState.failure);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final group = app.currentGroup;

    return AppPage(
      maxWidth: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top bar: Squircle back button <
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () => context.go(RoutePaths.home),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF141416),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF242428)),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          if (_state == _JoinState.working)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 64),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(color: Color(0xFFD53032)),
                    SizedBox(height: 20),
                    Text(
                      'Checking invitation…',
                      style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else if (_state == _JoinState.failure)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141416),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF242428)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFE53935),
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Invalid Invitation',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'That invite link or QR code is invalid or has expired.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),
                      InkWell(
                        onTap: () => context.go(RoutePaths.home),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2024),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF242428)),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Go home',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            // GROUP INVITE eyebrow badge
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2024),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'GROUP INVITE',
                  style: TextStyle(
                    color: Color(0xFFE5797A),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Red 64x64 squircle initials badge
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFD53032),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33D53032),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  _groupInitials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            // Group name
            Text(
              _groupName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            // Invited by
            Text(
              _invitedBy,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
            ),
            const SizedBox(height: 28),
            // Summary Card: Members + Games played
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF141416),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF242428)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 28,
                          child: Row(
                            children: [
                              for (
                                var i = 0;
                                i < group.members.length && i < 3;
                                i++
                              )
                                Align(
                                  widthFactor: 0.7,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF141416),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: AppAvatar(
                                      name: group.members[i].name,
                                      size: AppAvatarSize.sm,
                                    ),
                                  ),
                                ),
                              if (group.members.length > 3)
                                Align(
                                  widthFactor: 0.7,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF242428),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF141416),
                                        width: 1.5,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '+${group.members.length - 3}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_memberCount members',
                          style: const TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 48,
                    color: const Color(0xFF242428),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_gamesCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Games played',
                          style: TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // Join group button
            InkWell(
              onTap: () => context.go(RoutePaths.group),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFD53032),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33D53032),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Join group',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Not now link
            Center(
              child: InkWell(
                onTap: () => context.go(RoutePaths.home),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Text(
                    'Not now',
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
