import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:poker_night/core/widgets/pn_button.dart';
import 'package:poker_night/core/widgets/pn_card.dart';
import 'package:poker_night/core/widgets/pn_empty_state.dart';
import 'package:poker_night/core/widgets/pn_text_field.dart';
import 'package:poker_night/features/auth/controllers/auth_controller.dart';
import 'package:poker_night/features/polls/controllers/polls_controller.dart';
import 'package:poker_night/features/polls/models/poll_model.dart';

class PollView extends StatefulWidget {
  final String groupId;
  final String groupName;

  const PollView({
    super.key,
    required this.groupId,
    this.groupName = '',
  });

  @override
  State<PollView> createState() => _PollViewState();
}

class _PollViewState extends State<PollView> {
  final _votedPollIds = <String>{};
  late final PollsController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(PollsController(widget.groupId), tag: widget.groupId);
  }

  void _showCreatePollDialog() {
    final questionCtrl = TextEditingController();
    final optionCtrls = <TextEditingController>[
      TextEditingController(),
      TextEditingController(),
    ];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create Poll'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PNTextField(label: 'Question', hint: 'Enter poll question', controller: questionCtrl),
                    const SizedBox(height: 16),
                    Text('Options (${optionCtrls.length}/10)', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    ...optionCtrls.asMap().entries.map((entry) {
                      final index = entry.key;
                      final controller = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: PNTextField(label: 'Option ${index + 1}', hint: 'Enter option', controller: controller),
                            ),
                            if (optionCtrls.length > 2)
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                color: Colors.red,
                                onPressed: () => setDialogState(() => optionCtrls.removeAt(index)),
                              ),
                          ],
                        ),
                      );
                    }),
                    if (optionCtrls.length < 10)
                      TextButton.icon(
                        onPressed: () => setDialogState(() => optionCtrls.add(TextEditingController())),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Option'),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
                PNButton(
                  label: 'Create Poll',
                  onPressed: () {
                    final question = questionCtrl.text.trim();
                    if (question.isEmpty) return;
                    final optionTexts = optionCtrls.map((c) => c.text.trim()).where((o) => o.isNotEmpty).toList();
                    if (optionTexts.length < 2) return;

                    final authController = Get.find<AuthController>();
                    controller.createPoll(
                      question: question,
                      createdBy: authController.currentUser.value?.name ?? 'Unknown',
                      options: optionTexts,
                    );
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _castVote(Poll poll, int optionIndex) {
    if (!poll.isActive) return;
    if (_votedPollIds.contains(poll.id)) return;
    _votedPollIds.add(poll.id);
    controller.vote(poll.id, poll.options[optionIndex].id);
  }

  int _totalVotes(Poll poll) {
    return poll.options.fold(0, (sum, opt) => sum + opt.voteCount);
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')}/${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final polls = controller.polls;
      final isLoading = controller.isLoading.value;

      return Scaffold(
        appBar: AppBar(title: Text(widget.groupName.isNotEmpty ? '${widget.groupName} Polls' : 'Polls')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : polls.isEmpty
                    ? PNEmptyState(
                        icon: Icons.poll_outlined,
                        title: 'No polls yet',
                        subtitle: 'Create a poll to get feedback from the group!',
                        actionLabel: 'Create Poll',
                        onAction: _showCreatePollDialog,
                      )
                    : RefreshIndicator(
                        onRefresh: () => controller.loadPolls(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: polls.length,
                          itemBuilder: (context, index) => _buildPollCard(polls[index]),
                        ),
                      ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showCreatePollDialog,
          child: const Icon(Icons.poll),
        ),
      );
    });
  }

  Widget _buildPollCard(Poll poll) {
    final theme = Theme.of(context);
    final totalVotes = _totalVotes(poll);
    final hasVoted = _votedPollIds.contains(poll.id);
    final isActive = poll.isActive;

    return PNCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(poll.question, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green.shade100 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isActive ? 'Active' : 'Closed',
                  style: TextStyle(fontSize: 12, color: isActive ? Colors.green.shade800 : Colors.black54),
                ),
              ),
              if (!isActive && poll.closedAt != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () => controller.deletePoll(poll.id),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('by ${poll.createdBy}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
              const SizedBox(width: 8),
              Text(_formatDate(poll.createdAt), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
            ],
          ),
          if (isActive)
            TextButton.icon(
              icon: const Icon(Icons.lock_outline, size: 16),
              label: const Text('Close Poll'),
              onPressed: () => controller.closePoll(poll.id),
            ),
          const SizedBox(height: 16),
          ...poll.options.asMap().entries.map((entry) {
            final optionIndex = entry.key;
            final option = entry.value;
            final voteCount = option.voteCount;
            final percentage = totalVotes > 0 ? (voteCount / totalVotes) * 100 : 0.0;
            final disabled = !isActive || hasVoted;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PNCard(
                onTap: disabled ? null : () => _castVote(poll, optionIndex),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(option.text, style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: hasVoted ? FontWeight.w600 : FontWeight.w400,
                          )),
                        ),
                        Text('$voteCount vote${voteCount == 1 ? '' : 's'}', style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        )),
                      ],
                    ),
                    if (totalVotes > 0) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percentage / 100,
                          minHeight: 8,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('${percentage.toStringAsFixed(1)}%', style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      )),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
