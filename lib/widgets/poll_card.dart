import 'package:flutter/material.dart';

import '../models/game.dart';

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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF242428)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!poll.closed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F3826),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 6, color: Color(0xFF4ADE80)),
                      SizedBox(width: 4),
                      Text(
                        'OPEN',
                        style: TextStyle(
                          color: Color(0xFF4ADE80),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2024),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'CLOSED',
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (isMulti) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2024),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'MULTI-CHOICE',
                    style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (widget.isAdmin && !poll.closed)
                InkWell(
                  onTap: widget.onClose,
                  child: const Text(
                    'Close poll',
                    style: TextStyle(
                      color: Color(0xFFE5797A),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            poll.question,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          for (final opt in poll.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
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
            const SizedBox(height: 6),
            InkWell(
              onTap: () => widget.onVote(_multiSelection.toList()),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFD53032),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Submit vote',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (poll.closed && totalVotes > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Winner: ${winnerOpt!.key} · '
                    '${(winnerOpt.value / totalVotes * 100).round()}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4ADE80),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          const SizedBox(height: 4),
          Text(
            '$totalVotes vote${totalVotes != 1 ? 's' : ''}',
            style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12),
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
    final fraction = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;
    final pct = (fraction * 100).round();

    return InkWell(
      onTap: closed ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMyVote ? const Color(0xFF1E1819) : const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMyVote ? const Color(0xFFD53032) : const Color(0xFF242428),
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
                      ? const Color(0xFFD53032)
                      : const Color(0xFF8E8E93),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isMyVote ? Colors.white : const Color(0xFFE5E5E7),
                      fontSize: 14,
                      fontWeight: isMyVote ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                Text(
                  total > 0 ? '$pct%' : '$count vote${count != 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
            if (total > 0) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 4,
                  backgroundColor: const Color(0xFF242428),
                  valueColor: AlwaysStoppedAnimation(
                    isMyVote
                        ? const Color(0xFFD53032)
                        : const Color(0xFF3F3F46),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
