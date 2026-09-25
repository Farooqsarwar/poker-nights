import 'package:flutter/material.dart';
import '../app/typography.dart';
import '../app/colors.dart';

import '../constants/app_constants.dart';
import '../models/game.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'app_tag.dart';

/// A poll with its options, vote counts and progress bars. Multi-choice polls
/// accumulate selections locally and commit via the "Submit vote" button.
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

  final ValueChanged<List<String>> onVote;
  final VoidCallback onClose;

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
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

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (!poll.closed)
                  const AppTag('Open', tone: AppTagTone.success, dot: true)
                else
                  const AppTag('Closed'),
                if (isMulti) ...[
                  const SizedBox(width: AppSpacing.sm),
                  const AppTag('Multi-choice'),
                ],
                const Spacer(),
                if (widget.isAdmin && !poll.closed)
                  InkWell(
                    onTap: widget.onClose,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 4,
                      ),
                      child: Text(
                        'Close poll',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.primaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    '$totalVotes vote${totalVotes != 1 ? 's' : ''}',
                    style: AppTypography.mono(
                      size: AppFontSizes.xs,
                      color: AppColors.mutedForeground,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              poll.question,
              style: AppTypography.display(
                size: AppFontSizes.md,
                weight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
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
              const SizedBox(height: AppSpacing.xs),
              AppButton(
                fullWidth: true,
                onPressed: () => widget.onVote(_multiSelection.toList()),
                child: const Text('Submit vote'),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (poll.closed && totalVotes > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Winner: ${winnerOpt!.key} · '
                '${(winnerOpt.value / totalVotes * 100).round()}%',
                style: AppTypography.bodyXs.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.successText,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (widget.isAdmin && !poll.closed) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$totalVotes vote${totalVotes != 1 ? 's' : ''}',
                style: AppTypography.mono(
                  size: AppFontSizes.xs,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One answer row. The row itself fills from the left in proportion to its
/// share of the vote (crimson-tinted for the viewer's own pick), with the
/// percentage on the right — the redesign's poll bar.
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
    final fraction = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;
    final pct = (fraction * 100).round();
    final radius = BorderRadius.circular(AppRadius.md);

    return Semantics(
      button: !closed,
      selected: isMyVote,
      label: '$label, ${total > 0 ? '$pct percent' : '$count votes'}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: closed ? null : onTap,
          borderRadius: radius,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: radius,
              border: Border.all(
                color: isMyVote ? AppColors.primary : AppColors.borderSubtle,
              ),
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: fraction,
                      child: ColoredBox(
                        color: isMyVote
                            ? AppColors.primarySoftBorder
                            : AppColors.surfaceHover,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 3,
                    ),
                    child: Row(
                      children: [
                        if (!closed) ...[
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
                                ? AppColors.primaryText
                                : AppColors.mutedForeground,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Expanded(
                          child: Text(
                            label,
                            style: AppTypography.bodySm.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isMyVote
                                  ? AppColors.foreground
                                  : AppColors.secondaryForeground,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          total > 0
                              ? '$pct%'
                              : '$count vote${count != 1 ? 's' : ''}',
                          style: AppTypography.mono(
                            size: AppFontSizes.xs,
                            weight: FontWeight.w600,
                            color: isMyVote
                                ? AppColors.foreground
                                : AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
