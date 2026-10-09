import re

with open('lib/screens/tournament/final_table_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add _FinalistLeaderboard invocation
if '_FinalistLeaderboard(game: game)' not in content:
    content = content.replace(
        '            // Active Seat Card: Player assignment & Dealer toggle',
        '''            _FinalistLeaderboard(game: game),
            const SizedBox(height: AppSpacing.lg),
            // Active Seat Card: Player assignment & Dealer toggle'''
    )

# Add _FinalistLeaderboard class
if 'class _FinalistLeaderboard' not in content:
    content += '''

class _FinalistLeaderboard extends StatelessWidget {
  const _FinalistLeaderboard({required this.game});

  final dynamic game; // LiveGame or Game

  @override
  Widget build(BuildContext context) {
    final active = game.activePlayers.toList()
      ..sort((a, b) => (b.stack ?? 0).compareTo(a.stack ?? 0));
    final bb = game.structure.levels[game.currentLevel - 1].bb;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'CHIP LEADERBOARD',
            style: AppTypography.monoXs.copyWith(
              color: AppColors.mutedForeground,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < active.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${i + 1}',
                      style: AppTypography.monoSm.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      active[i].name,
                      style: AppTypography.bodySm.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${(active[i].stack ?? 0)}',
                    style: AppTypography.monoSm,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${((active[i].stack ?? 0) / bb).toStringAsFixed(1)} BB',
                      textAlign: TextAlign.right,
                      style: AppTypography.monoXs.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
'''

with open('lib/screens/tournament/final_table_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
