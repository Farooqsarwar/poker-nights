import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../providers/app_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_modal.dart';
import '../../widgets/app_page.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_toggle.dart';
import '../../widgets/group_switcher.dart';
import '../../widgets/poll_card.dart';

/// Group polls as a full screen (single navigation layer — no hub tab bar, so
/// the Polls item never appears twice).
class PollsScreen extends StatefulWidget {
  const PollsScreen({super.key});

  @override
  State<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends State<PollsScreen> {
  bool _showPollModal = false;
  String? _pollError;
  final _pollQuestion = TextEditingController();
  final List<TextEditingController> _pollOptions = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _pollMulti = false;

  @override
  void dispose() {
    _pollQuestion.dispose();
    for (final c in _pollOptions) {
      c.dispose();
    }
    super.dispose();
  }

  void _createPoll(AppProvider app) {
    final opts = _pollOptions
        .map((c) => c.text.trim())
        .where((o) => o.isNotEmpty)
        .toList();
    if (_pollQuestion.text.trim().isEmpty || opts.length < 2) {
      setState(() => _pollError = 'Enter a question and at least two options.');
      return;
    }
    final error = app.createPoll(
      _pollQuestion.text.trim(),
      opts,
      multi: _pollMulti,
    );
    if (error != null) {
      setState(() => _pollError = error);
      return;
    }
    setState(() {
      _pollError = null;
      _pollQuestion.clear();
      for (var i = 0; i < _pollOptions.length; i++) {
        if (i >= 2) {
          _pollOptions[i].dispose();
        } else {
          _pollOptions[i].clear();
        }
      }
      _pollOptions.removeRange(2, _pollOptions.length);
      _pollMulti = false;
      _showPollModal = false;
    });
  }

  Widget _pollModal(AppProvider app) {
    return AppModal(
      open: _showPollModal,
      onClose: () => setState(() => _showPollModal = false),
      title: 'Create poll',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _pollQuestion,
            label: 'Question',
            placeholder: 'e.g. What buy-in for next game?',
          ),
          if (_pollError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _pollError!,
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.destructiveText,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Options (min. 2)',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < _pollOptions.length; i++) ...[
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _pollOptions[i],
                    placeholder: 'Option ${i + 1}',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (i >= 2)
                  IconButton(
                    tooltip: 'Remove option ${i + 1}',
                    onPressed: () => setState(() {
                      _pollOptions.removeAt(i).dispose();
                    }),
                    icon: Text(
                      '×',
                      semanticsLabel: '',
                      style: TextStyle(
                        color: AppColors.mutedForeground,
                        fontSize: AppFontSizes.lg,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (_pollOptions.length < 10)
            InkWell(
              onTap: () => setState(
                () => _pollOptions.add(TextEditingController()),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12.0,
                ),
                child: Text(
                  '+ Add option',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.primaryText,
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Multi-choice', style: AppTypography.bodySm),
                    Text(
                      'Members may pick more than one option',
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              AppToggle(
                value: _pollMulti,
                onChanged: (v) => setState(() => _pollMulti = v),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            fullWidth: true,
            disabled:
                _pollQuestion.text.trim().isEmpty ||
                _pollOptions
                        .where((c) => c.text.trim().isNotEmpty)
                        .length <
                    2,
            onPressed: () => _createPoll(app),
            child: const Text('Create poll'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final group = app.currentGroup;
    final user = app.user;
    final userId = user?.id;
    final isAdmin = app.isAdmin;

    if (!app.hasCurrentGroup) {
      return AppPage(
        maxWidth: 960,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 96),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.poll_outlined, size: 64, color: AppColors.mutedForeground),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'No group selected',
                  style: AppTypography.display(size: AppFontSizes.lg, weight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Join or create a group to see its polls.',
                  style: AppTypography.bodySm.copyWith(color: AppColors.mutedForeground),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  onPressed: () => context.go(RoutePaths.home),
                  child: const Text('Go to Home'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AppPage(
      maxWidth: 960,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GroupContextHeader(title: 'Polls'),
          const SizedBox(height: AppSpacing.lg),
          if (group.polls.isEmpty) ...[
            if (isAdmin)
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton(
                  size: AppButtonSize.sm,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => setState(() => _showPollModal = true),
                  child: const Text('+ Create poll'),
                ),
              ),
            AppEmptyState(
              icon: Icons.poll_outlined,
              title: 'No polls yet',
              description: 'Create a poll to help plan the next game.',
            ),
          ] else ...[
            if (isAdmin) ...[
              AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.secondary,
                onPressed: () => setState(() => _showPollModal = true),
                child: const Text('+ Create poll'),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            for (final poll in group.polls)
              PollCard(
                poll: poll,
                userId: userId,
                isAdmin: isAdmin,
                onVote: (opts) => app.votePoll(poll.id, opts),
                onClose: () => app.closePoll(poll.id),
              ),
          ],
          _pollModal(app),
        ],
      ),
    );
  }
}