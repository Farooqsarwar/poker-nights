import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/colors.dart';
import '../app/route_paths.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../models/game.dart';
import '../models/live_game.dart';
import '../providers/app_provider.dart';
import '../utils/formatters.dart';
import 'app_avatar.dart';
import 'app_badge.dart';
import 'app_button.dart';
import 'app_modal.dart';
import 'rsvp_badge.dart';

/// A single chat message: pinned system announcements render as an event card,
/// everything else as a traditional chat bubble (mine right/filled, theirs
/// left/white with avatar).
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.canDelete,
    required this.onDelete,
    required this.app,
    required this.userId,
  });

  final ChatMessage message;
  final bool isMine;
  final bool canDelete;
  final VoidCallback onDelete;
  final AppProvider app;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    // Pinned system messages (published games / edits) render as an event card
    // rather than a chat bubble (§4.3) and are never deletable by members.
    if (message.pinned) {
      return _EventCard(message: message, app: app, userId: userId);
    }

    final mine = isMine;
    final maxWidth = MediaQuery.sizeOf(context).width <= 720
        ? MediaQuery.sizeOf(context).width * 0.82
        : 480.0;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: mine ? AppColors.primary : AppColors.secondary,
        borderRadius: BorderRadius.circular(18).copyWith(
          bottomRight: mine ? const Radius.circular(5) : null,
          bottomLeft: mine ? null : const Radius.circular(5),
        ),
        border: mine ? null : Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!mine)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                message.authorName,
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Text(
            message.body,
            style: AppTypography.bodySm.copyWith(
              color: mine ? AppColors.primaryForeground : AppColors.foreground,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            Formatters.relativeTime(message.timestamp),
            style: AppTypography.bodyXs.copyWith(
              color: mine
                  ? AppColors.primaryForeground.withValues(alpha: 0.75)
                  : AppColors.mutedForeground,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mine) ...[
            AppAvatar(name: message.authorName, size: AppAvatarSize.sm),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: mine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                bubble,
                if (canDelete)
                  InkWell(
                    onTap: onDelete,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2, right: 4, left: 4),
                      child: Text(
                        'delete',
                        style: AppTypography.bodyXs.copyWith(
                          color: AppColors.mutedForeground,
                          fontSize: 10,
                        ),
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

/// Pinned game announcement card (RSVP-able).
class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.message,
    required this.app,
    required this.userId,
  });

  final ChatMessage message;
  final AppProvider app;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    // The card carries the game id it announces (client rule: RSVPs count
    // automatically as people answer from the invite in chat), so it opens
    // and updates the *specific* game rather than whatever happens to be
    // "current" in the app.
    final game = message.gameId != null ? app.gameById(message.gameId!) : null;
    final myRsvp = game?.players.where((p) => p.id == userId).firstOrNull?.rsvp;
    final goingCount = game?.goingWithGuestsCount;
    final rsvpOpen =
        game != null &&
        !game.settings.rsvpCutoffPassed &&
        game.status == LiveGameStatus.published;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () {
          if (game != null) {
            if (game.status == LiveGameStatus.cancelled) {
              showAppModal(
                context: context,
                title: 'Tournament Cancelled',
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'This event has been cancelled and is no longer active.',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              );
              return;
            }
            app.setCurrentGame(game);
            context.go(RoutePaths.invitation);
          } else {
            // Game not resolvable on this device yet (bundle not synced) —
            // land on the games hub instead of a dead "No game selected.".
            context.go(RoutePaths.group);
          }
        },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.12),
                AppColors.secondary.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.push_pin, size: 14, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Pinned event',
                    style: AppTypography.monoXs.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (goingCount != null) ...[
                    const Spacer(),
                    Text(
                      '$goingCount going',
                      style: AppTypography.monoXs.copyWith(
                        color: AppColors.mutedForeground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message.body,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.foreground,
                ),
              ),
              if (game != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    AppBadge(
                      label: game.settings.rebuys
                          ? (game.settings.rebuyLimit == null
                                ? 'Unlimited rebuys to L${game.settings.rebuysCloseLevel}'
                                : '${game.settings.rebuyLimit} rebuys to L${game.settings.rebuysCloseLevel}${game.settings.rebuyCost != null ? ' @ ${game.settings.rebuyCost}' : ''}')
                          : 'No rebuys',
                      variant: game.settings.rebuys
                          ? AppBadgeVariant.gold
                          : AppBadgeVariant.muted,
                    ),
                    AppBadge(
                      label: game.settings.addOn
                          ? 'Add-on to L${game.settings.addOnCloseLevel}'
                          : 'No add-on',
                      variant: game.settings.addOn
                          ? AppBadgeVariant.gold
                          : AppBadgeVariant.muted,
                    ),
                    AppBadge(
                      label: game.settings.anteEnabled
                          ? 'Ante L${game.settings.anteAfterLevel}'
                          : 'No ante',
                      variant: game.settings.anteEnabled
                          ? AppBadgeVariant.gold
                          : AppBadgeVariant.muted,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Posted by ${message.authorName} · ${Formatters.relativeTime(message.timestamp)}',
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                  fontSize: 10,
                ),
              ),
              // RSVP is set on the game screen (tap this card) — shown here
              // read-only so chat and the hub never carry a second control.
              if (game != null && userId != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    RSVPBadge(rsvp: myRsvp),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      rsvpOpen
                          ? (myRsvp == null
                                ? 'Tap to respond'
                                : 'Tap to change')
                          : 'RSVPs closed',
                      style: AppTypography.bodyXs.copyWith(
                        color: rsvpOpen
                            ? AppColors.primary
                            : AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
