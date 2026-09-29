import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../providers/app_provider.dart';
import 'app_badge.dart';
import 'app_button.dart';
import 'app_card.dart';
import 'icon_tile.dart';

/// C-ops "Take-over" (T84, §E9) — what a second host/co-host phone sees when
/// it opens a game another phone is already running.
///
/// Exactly one device operates the clock, and that is not a convention this
/// widget has to police: the provider resolves it from `editorDeviceId` and
/// every clock action is already gated on it. What the second phone had was no
/// way to *find out* — it sat on a live game with dead controls and no
/// explanation. This is that explanation, plus the two answers §E9 allows.
///
/// Renders nothing at all on a member, guest or TV device, and nothing on the
/// phone that already holds the clock.
class ClockAuthorityNotice extends StatefulWidget {
  const ClockAuthorityNotice({super.key});

  @override
  State<ClockAuthorityNotice> createState() => _ClockAuthorityNoticeState();
}

class _ClockAuthorityNoticeState extends State<ClockAuthorityNotice> {
  bool _takingOver = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    // The silent-clock rescue outranks the everyday prompt: after 30 minutes
    // the night is at risk of stopping, and that is a different message with a
    // different answer.
    final orphaned = app.shouldOfferOrphanedClockTakeover;
    if (!orphaned && !app.shouldOfferClockTakeover) {
      return const SizedBox.shrink();
    }
    final operator = app.clockOperatorName;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        borderColor: orphaned ? AppColors.warning : AppColors.borderSubtle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTile(
                  icon: orphaned
                      ? Icons.portable_wifi_off_rounded
                      : Icons.smartphone_rounded,
                  size: 44,
                  tone: orphaned ? IconTileTone.warning : IconTileTone.neutral,
                  glow: false,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppBadge(
                        label: orphaned
                            ? 'Clock silent for 30 min'
                            : 'Another phone has the clock',
                        variant: orphaned
                            ? AppBadgeVariant.red
                            : AppBadgeVariant.muted,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        orphaned
                            ? "The host's phone isn't responding — "
                                'take over the clock?'
                            : operator == null
                                ? 'Another phone is running this clock'
                                : '$operator is running this clock on '
                                    'another phone',
                        style: AppTypography.bodyLg.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        orphaned
                            ? 'Nothing has been written to this game for 30 '
                                'minutes. Take over and this phone runs the '
                                'clock — everyone else sees who took over.'
                            : operator == null
                                ? 'One phone runs the clock. Take over and the '
                                    'other phone becomes a live view, or keep '
                                    'watching from here.'
                                : "One phone runs the clock. Take over and "
                                    "$operator's phone becomes a live view, or "
                                    'keep watching from here.',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    fullWidth: true,
                    variant: AppButtonVariant.primary,
                    loading: _takingOver,
                    onPressed: _takingOver ? null : () => _takeOver(app),
                    child: Text(orphaned ? 'Take over the clock' : 'Take over'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    fullWidth: true,
                    variant: AppButtonVariant.secondary,
                    onPressed: _takingOver
                        ? null
                        : () => app.watchTheClockOnly(),
                    child: Text(orphaned ? 'Not now' : 'Watch only'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _takeOver(AppProvider app) async {
    setState(() => _takingOver = true);
    // The provider's claim is a transaction; the local state flips first so
    // this device is the clock immediately rather than after a round trip.
    await app.takeOverTheClock();
    if (!mounted) return;
    setState(() => _takingOver = false);
  }
}
