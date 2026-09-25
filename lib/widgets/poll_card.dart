import 'package:flutter/material.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../models/game.dart';
import 'app_badge.dart';
import 'app_button.dart';
import 'app_card.dart';

/// A poll with its options, vote counts and progress bars. Multi-choice polls
/// accumulate selections locally and commit via the "Submit vote" button
/// (Tech §14.2, audit fix B11).
class PollCard extends StatefulWidget {
  const PollCard({
    super.key,
    required this.poll,
    required this.userId,
    required this.isAdmin,
    required this.onVote,
    required this.onClose,
  });

  final Poll poll;
  final String? userId;
  final bool isAdmin;

  /// Commits the member's selection. For single-choice polls this is a one-
  /// element list; for multi-choice polls it carries every ticked option
  /// (Tech §14.2, audit fix B11).
  final ValueChanged<List<String>> onVote;
  final VoidCallback onClose;

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
  // Local multi-choice selection (committed via the "Vote" button).
  final Set<String> _multiSelection = {};

  @override
  void didUpdateWidget(PollCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldMine = oldWidget.userId != null
        ? oldWidget.poll.votes[oldWidget.userId!]
        : null;
    final newMine = widget.userId != null
        ? widget.poll.votes[widget.userId!]
        : null;
    bool changed = false;
    if (oldMine == null && newMine != null) {
      changed = true;
    } else if (oldMine != null && newMine == null) {
      changed = true;
    } else if (oldMine != null &&
        newMine != null &&
        oldMine.length != newMine.length) {
      changed = true;
    } else if (oldMine != null && newMine != null) {
      for (var i = 0; i < oldMine.length; i++) {
        if (oldMine[i] != newMine[i]) changed = true;
      }
    }
    if (widget.poll.multi && changed) {
      _multiSelection.clear();
      if (newMine != null) _multiSelection.addAll(newMine);
    }
  }

  @override
  void initState() {
    super.initState();
    final mine = widget.userId != null
        ? widget.poll.votes[widget.userId!]
        : null;
    if (widget.poll.multi && mine != null) {
      _multiSelection.addAll(mine);
    }
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.poll;
    final isMulti = poll.multi;
    final totalVotes = poll.totalVotes;
    final counts = poll.optionCounts();
    final mySingle = !isMulti && widget.userId != null
        ? poll.votes[widget.userId!]
        : null;
    final winnerOpt = poll.closed && totalVotes > 0
        ? counts.entries.fold<MapEntry<String, int>?>(
            null,
            (acc, e) => acc == null || e.value > acc.value ? e : acc,
          )
        : null;

    void toggleMulti(String opt) {
      setState(() {
        if (!_multiSelection.remove(opt)) _multiSelection.add(opt);
      });
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  poll.question,
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isMulti)
                const AppBadge(
                  label: 'Multi-choice',
                  variant: AppBadgeVariant.accent,
                  border: true,
                ),
              const SizedBox(width: AppSpacing.sm),
              if (poll.closed)
                const AppBadge(label: 'Closed', variant: AppBadgeVariant.muted),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final opt in poll.options)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _PollOption(
                label: opt,
                count: counts[opt] ?? 0,
                total: totalVotes,
                isMyVote: isMulti
                    ? _multiSelection.contains(opt)
                    : mySingle != null && mySingle.contains(opt),
                closed: poll.closed,
                checkbox: isMulti,
                onTap: isMulti
                    ? () => toggleMulti(opt)
                    : () => widget.onVote([opt]),
              ),
            ),
          if (isMulti && !poll.closed) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                size: AppButtonSize.sm,
                onPressed: () => widget.onVote(_multiSelection.toList()),
                child: const Text('Submit vote'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (poll.closed && totalVotes > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Winner: ${winnerOpt!.key} · '
                    '${(winnerOpt.value / totalVotes * 100).round()}%',
                    style: AppTypography.bodyXs.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.successText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          Row(
            children: [
              Text(
                '$totalVotes vote${totalVotes != 1 ? 's' : ''}',
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const Spacer(),
              if (widget.isAdmin && !poll.closed)
                AppButton(
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.ghost,
                  onPressed: widget.onClose,
                  child: const Text('Close poll'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PollOption extends StatelessWidget {
  const _PollOption({
    required this.label,
    required this.count,
    required this.total,
    required this.isMyVote,
    required this.closed,
    required this.onTap,
    this.checkbox = false,
  });

  final String label;
  final int count;
  final int total;
  final bool isMyVote;
  final bool closed;
  final bool checkbox;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (count / total) * 100 : 0.0;
    return InkWell(
      onTap: closed ? null : onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isMyVote ? AppColors.primarySoft : AppColors.secondary,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isMyVote ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  checkbox
                      ? (isMyVote
                            ? Icons.check_box
                            : Icons.check_box_outline_blank)
                      : (isMyVote
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked),
                  size: 16,
                  color: isMyVote
                      ? AppColors.primary
                      : AppColors.mutedForeground,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.bodySm.copyWith(
                      color: isMyVote
                          ? AppColors.primary
                          : AppColors.foreground,
                    ),
                  ),
                ),
                Text(
                  total > 0
                      ? '${pct.round()}%'
                      : '$count vote${count != 1 ? 's' : ''}',
                  style: AppTypography.mono(
                    size: AppFontSizes.xs,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
            if (total > 0)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: pct.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: AppColors.muted,
                    valueColor: AlwaysStoppedAnimation(
                      isMyVote
                          ? AppColors.primary
                          : AppColors.mutedForeground.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}