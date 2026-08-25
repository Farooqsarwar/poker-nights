import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../models/game.dart';
import '../../models/live_game.dart';
import '../../models/tournament.dart';
import '../../providers/app_provider.dart';
import '../../services/recovery_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon_label.dart';
import '../../widgets/app_timer.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/brand_lockup.dart';

enum _GuestStep {
  enterCode,
  eventIntro,
  chooseInviter,
  chooseSlot,
  enterName,
  waiting,
  confirmed,
  rejected,
}

/// Guest join flow mirroring the web `GuestFlowPage`.
class GuestFlowScreen extends StatefulWidget {
  const GuestFlowScreen({super.key});

  @override
  State<GuestFlowScreen> createState() => _GuestFlowScreenState();
}

class _GuestFlowScreenState extends State<GuestFlowScreen> {
  late _GuestStep _step;
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String? _codeError;
  String? _nameError;
  String? _selectedInviter;
  int? _selectedSlot;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppProvider>();
    final session = app.guestSession;
    final game = app.currentGame;
    if (session != null && game != null && session.gameId == game.id) {
      // Restore the guest's own check-in session (checklist 07-030).
      _selectedInviter = session.inviterId;
      _selectedSlot = session.slot;
      _nameController.text = session.name;
      final guest = _matchGuest(game, session);
      _step = guest != null && guest.confirmed
          ? _GuestStep.confirmed
          : _GuestStep.waiting;
    } else {
      // No saved session: show the event details first, then claim.
      _step = game == null ? _GuestStep.enterCode : _GuestStep.eventIntro;
    }
  }

  /// Finds the guest in [game]'s player list that matches the stored session.
  static Player? _matchGuest(LiveGame game, GuestSession session) {
    for (final p in game.players) {
      if (p.isGuest &&
          p.inviterId == session.inviterId &&
          p.guestSlot == session.slot &&
          p.name.trim() == session.name.trim()) {
        return p;
      }
    }
    return null;
  }

  /// Looks up the guest's current state from the live game so the flow reacts
  /// to admin confirmation or rejection in real time (07-027/07-028).
  Player? _currentGuest() {
    final app = context.read<AppProvider>();
    final session = app.guestSession;
    final game = app.currentGame;
    if (session == null || game == null || session.gameId != game.id) {
      return null;
    }
    return _matchGuest(game, session);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submitCode() async {
    final result = await context.read<AppProvider>().enterGameCode(
      _codeController.text.trim(),
    );
    if (!mounted) return;
    if (result == CodeLookupResult.notFound) {
      setState(
        () => _codeError = 'Game not found — check the code and try again.',
      );
    } else if (result == CodeLookupResult.rateLimited) {
      setState(
        () => _codeError =
            'Too many attempts. Wait a minute and try again.',
      );
    } else if (result == CodeLookupResult.game) {
      final app = context.read<AppProvider>();
      // Guests authenticate anonymously so the request queue accepts their
      // writes and the router guard lets them into the live view.
      await app.ensureGuestAuth();
      if (!mounted) return;
      final session = app.guestSession;
      final game = app.currentGame;
      if (session != null && game != null && session.gameId == game.id) {
        _selectedInviter = session.inviterId;
        _selectedSlot = session.slot;
        _nameController.text = session.name;
        final guest = _matchGuest(game, session);
        setState(() {
          _codeError = null;
          _step = guest != null && guest.confirmed
              ? _GuestStep.confirmed
              : _GuestStep.waiting;
        });
      } else {
        setState(() {
          _codeError = null;
          _step = _GuestStep.eventIntro;
        });
      }
    } else {
      setState(
        () => _codeError =
            'That code opens the TV display — ask the host for the player code.',
      );
    }
  }

  Future<void> _requestCheckIn() async {
    final app = context.read<AppProvider>();
    if (_selectedInviter != null &&
        _selectedSlot != null &&
        _nameController.text.trim().isNotEmpty) {
      final err = await app.requestGuestCheckIn(
        _nameController.text.trim(),
        _selectedInviter!,
        _selectedSlot!,
      );
      if (!mounted) return;
      if (err != null) {
        setState(() => _nameError = err);
        return;
      }
    }
    setState(() {
      _nameError = null;
      _step = _GuestStep.waiting;
    });
  }

  void _startOver() {
    context.read<AppProvider>().clearGuestSession();
    setState(() {
      _step = _GuestStep.enterCode;
      _selectedInviter = null;
      _selectedSlot = null;
      _nameController.clear();
      _codeError = null;
      _nameError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final game = app.currentGame;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.xxxl,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 384),
            child: Center(child: _buildBody(app, game)),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppProvider app, LiveGame? game) {
    if (game == null) {
      if (_step == _GuestStep.enterCode) return _buildCodeEntry();
      return const SizedBox.shrink();
    }

    final registeredPlayers = game.players.where((p) => !p.isGuest).toList();
    final inviter = _selectedInviter == null
        ? null
        : registeredPlayers.where((p) => p.id == _selectedInviter).firstOrNull;
    final availableSlots = inviter?.rsvp?.guestCount ?? 0;
    final level = game.currentLevelData;

    // While waiting, react to the admin's decision in real time: the guest is
    // confirmed once their player record is confirmed, and rejected once it is
    // removed from the game (07-027/07-028).
    var view = _step;
    if (view == _GuestStep.waiting) {
      final guest = _currentGuest();
      if (guest == null) {
        view = _GuestStep.rejected;
      } else if (guest.confirmed) {
        view = _GuestStep.confirmed;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Column(
          children: [
            const PokerNightLogo(size: 40),
            const SizedBox(height: AppSpacing.xs),
            Text(
              game.settings.name,
              style: AppTypography.display(size: AppFontSizes.xl),
            ),
            Text(
              '${game.settings.date} · ${game.settings.location}',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        // Progress
        Row(
          children: [
            for (final s in const [
              _GuestStep.chooseInviter,
              _GuestStep.chooseSlot,
              _GuestStep.enterName,
              _GuestStep.waiting,
              _GuestStep.confirmed,
            ])
              Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: view.index > s.index
                        ? AppColors.primary
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        switch (view) {
          _GuestStep.eventIntro => _buildEventIntro(game),
          _GuestStep.chooseInviter => _buildChooseInviter(
            game,
            registeredPlayers,
          ),
          _GuestStep.chooseSlot => _buildChooseSlot(
            inviter,
            availableSlots,
            game.players,
          ),
          _GuestStep.enterName => _buildEnterName(inviter),
          _GuestStep.waiting => _buildWaiting(inviter),
          _GuestStep.confirmed => _buildConfirmed(level),
          _GuestStep.rejected => _buildRejected(),
          _GuestStep.enterCode => const SizedBox.shrink(),
        },
      ],
    );
  }

  Widget _buildCodeEntry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xl),
        const PokerNightLogo(size: 80),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Join as guest',
          textAlign: TextAlign.center,
          style: AppTypography.display(size: AppFontSizes.xxl),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Enter the code from the host or invitation link',
          textAlign: TextAlign.center,
          style: AppTypography.bodySm.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Game code',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _codeController,
                autofocus: true,
                maxLength: 8,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: AppTypography.monoXl.copyWith(letterSpacing: 3),
                onChanged: (_) {
                  if (_codeError != null) setState(() => _codeError = null);
                },
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'ENTER CODE',
                  hintStyle: AppTypography.monoXl.copyWith(
                    color: AppColors.onSurfaceHint,
                    letterSpacing: 3,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide(color: AppColors.ring),
                  ),
                ),
              ),
              if (_codeError != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _codeError!,
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.destructive,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: AppButton(
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.md,
                  onPressed: _submitCode,
                  child: const Text('Join'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Demo code: ',
                      style: AppTypography.bodyXs.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: InkWell(
                        onTap: () => _codeController.text = 'FP2608',
                        child: Text(
                          'FP2608',
                          style: AppTypography.monoSm.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Have an account? ',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            InkWell(
              onTap: () => context.go(RoutePaths.login),
              child: Text(
                'Sign in',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Number of still-free guest seats under [inviter]. Prefers the persisted
  /// [GuestSlot] records (07-014); falls back to the RSVP guest count minus
  /// guests already claimed so the flow works even without slot records.
  int _freeSlotsFor(LiveGame game, Player inviter) {
    final slots = game.guestSlots
        .where((s) => s.inviterId == inviter.id)
        .toList();
    if (slots.isNotEmpty) return slots.where((s) => s.available).length;
    final taken = game.players
        .where((p) => p.isGuest && p.inviterId == inviter.id)
        .length;
    return (inviter.rsvp?.guestCount ?? 0) - taken;
  }

  /// Friendly event-specific landing card shown right after the guest
  /// resolves the code (audit fix B12 — the spec sample shows date/time,
  /// location, buy-in, rebuys and KO before "Claim My Guest Place").
  Widget _buildEventIntro(LiveGame game) {
    final s = game.settings;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'You’re invited to',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            s.name,
            textAlign: TextAlign.center,
            style: AppTypography.display(
              size: AppFontSizes.xl,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              _IntroLine(
                icon: Icons.calendar_today_outlined,
                text: '${s.date} · ${s.time}',
              ),
              if (s.location.isNotEmpty)
                _IntroLine(icon: Icons.location_on_outlined, text: s.location),
              _IntroLine(
                icon: Icons.attach_money_outlined,
                text:
                    'Buy-in ${s.buyIn}${s.koEnabled ? ' + ${s.koAmount} KO' : ''}',
              ),
              if (s.rebuys)
                _IntroLine(
                  icon: Icons.replay_outlined,
                  text: 'Rebuys until L${s.rebuysCloseLevel}',
                ),
              if (s.addOn)
                _IntroLine(
                  icon: Icons.add_circle_outline,
                  text: 'Add-on available',
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            fullWidth: true,
            size: AppButtonSize.lg,
            onPressed: () => setState(() => _step = _GuestStep.chooseInviter),
            child: const AppIconLabel(
              label: 'Claim My Guest Place',
              trailing: Icons.arrow_forward,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChooseInviter(LiveGame game, List<Player> registeredPlayers) {
    // Only members with at least one free guest seat are shown — players whose
    // "+N" seats are all taken (or who said "Going" with no guests) cannot be
    // chosen (§6.3, checklist 07-014).
    final invited = registeredPlayers
        .where(
          (p) =>
              p.rsvp != null && p.rsvp!.isGoing && _freeSlotsFor(game, p) > 0,
        )
        .toList();
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Who invited you?',
            style: AppTypography.display(size: AppFontSizes.lg),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Select the registered member who brought you along.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (invited.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                'No one has RSVP\'d with guests. Please ask the host.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            )
          else
            for (final p in invited)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: InkWell(
                  onTap: () => setState(() => _selectedInviter = p.id),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: _selectedInviter == p.id
                          ? AppColors.primarySoft
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: _selectedInviter == p.id
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        AppAvatar(name: p.name),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            p.name,
                            style: AppTypography.bodySm.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        AppBadge(
                          label: '${_freeSlotsFor(game, p)} free',
                          variant: AppBadgeVariant.green,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            variant: AppButtonVariant.primary,
            fullWidth: true,
            onPressed: _selectedInviter == null
                ? null
                : () => setState(() => _step = _GuestStep.chooseSlot),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Continue'),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward, size: 14, color: AppColors.icon),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChooseSlot(
    Player? inviter,
    int availableSlots,
    List<Player> players,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BackLink(
            onTap: () => setState(() => _step = _GuestStep.chooseInviter),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Choose your guest slot',
            style: AppTypography.display(size: AppFontSizes.lg),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${inviter?.name ?? 'Your host'} is bringing $availableSlots guest${availableSlots > 1 ? 's' : ''}. Which slot are you?',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (var slot = 1; slot <= availableSlots; slot++) ...[
            Builder(
              builder: (context) {
                final taken = players.any(
                  (p) =>
                      p.isGuest &&
                      p.inviterId == inviter?.id &&
                      p.guestSlot == slot,
                );
                return InkWell(
                  onTap: taken
                      ? null
                      : () => setState(() => _selectedSlot = slot),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: taken
                          ? AppColors.muted
                          : (_selectedSlot == slot
                                ? AppColors.primarySoft
                                : Colors.transparent),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: taken
                            ? AppColors.border
                            : (_selectedSlot == slot
                                  ? AppColors.primary
                                  : AppColors.border),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          "${inviter?.name ?? ''}'s Guest $slot",
                          style: AppTypography.bodySm.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (taken) ...[
                          const Spacer(),
                          const AppBadge(
                            label: 'Taken',
                            variant: AppBadgeVariant.red,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppButton(
            variant: AppButtonVariant.primary,
            fullWidth: true,
            onPressed: _selectedSlot == null
                ? null
                : () => setState(() => _step = _GuestStep.enterName),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Select slot'),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward, size: 14, color: AppColors.icon),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnterName(Player? inviter) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BackLink(onTap: () => setState(() => _step = _GuestStep.chooseSlot)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Enter your name',
            style: AppTypography.display(size: AppFontSizes.lg),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'This is shown to the host and displayed on the seating plan.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _nameController,
            autofocus: true,
            maxLength: 32,
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
              setState(() {});
            },
            style: AppTypography.body(
              size: AppFontSizes.lg,
              weight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'Your first name',
              hintStyle: AppTypography.bodyLg.copyWith(
                color: AppColors.onSurfaceHint,
              ),
              isDense: true,
              filled: true,
              fillColor: AppColors.card,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide(color: AppColors.ring),
              ),
            ),
          ),
          if (_nameError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _nameError!,
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.destructive,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            variant: AppButtonVariant.primary,
            fullWidth: true,
            onPressed: _nameController.text.trim().isEmpty
                ? null
                : _requestCheckIn,
            child: const Text('Request check-in'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'The host will confirm your seat.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaiting(Player? inviter) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Waiting for host',
            style: AppTypography.display(size: AppFontSizes.xl),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your check-in request has been sent. The host will confirm you shortly.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.muted,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Text(
                  'Guest slot',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                Text(
                  "${inviter?.name ?? ''}'s Guest ${_selectedSlot ?? 1}",
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejected() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          borderColor: AppColors.destructive.withValues(alpha: 0.4),
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            children: [
              Icon(
                Icons.close,
                size: AppFontSizes.displayLg,
                color: AppColors.destructive,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                "Request declined",
                style: AppTypography.display(
                  size: AppFontSizes.xl,
                  weight: FontWeight.w600,
                  color: AppColors.destructive,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'The host could not confirm your guest slot. This can happen when the slot was already taken or registration has closed.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.lg,
          fullWidth: true,
          onPressed: _startOver,
          child: const Text('Start over'),
        ),
      ],
    );
  }

  Widget _buildConfirmed(BlindLevel? level) {
    final guest = _currentGuest();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          glow: true,
          borderColor: AppColors.successSoftBorder,
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            children: [
              Icon(
                Icons.check_circle,
                size: AppFontSizes.displayLg,
                color: AppColors.success,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                "You're in!",
                style: AppTypography.display(
                  size: AppFontSizes.xl,
                  weight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Your seat has been confirmed.',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your seat',
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              Text(
                guest != null && guest.table > 0 && guest.seat > 0
                    ? 'Table ${guest.table} · Seat ${guest.seat}'
                    : 'Table 1 · Seat ${_selectedSlot ?? 1}',
                style: AppTypography.mono(
                  size: AppFontSizes.xxl,
                  weight: FontWeight.w700,
                ),
              ),
              if (!(guest != null && guest.table > 0 && guest.seat > 0))
                Text(
                  'Seats are assigned once the host generates the seating plan.',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
            ],
          ),
        ),
        if (level != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live game',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Builder(
                            builder: (context) {
                              final game = context
                                  .read<AppProvider>()
                                  .currentGame;
                              return Column(
                                children: [
                                  if (game != null)
                                    LiveTimerBuilder(
                                      game: game,
                                      builder: (context, remaining) => AppTimer(
                                        secondsRemaining: remaining,
                                        size: AppFontSizes.xxl,
                                      ),
                                    )
                                  else
                                    AppTimer(
                                      secondsRemaining: 0,
                                      size: AppFontSizes.xxl,
                                    ),
                                  Text(
                                    'Level ${game?.currentLevel ?? 1}',
                                    style: AppTypography.bodyXs.copyWith(
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            '${Formatters.chips(level.sb)}/${Formatters.chips(level.bb)}',
                            style: AppTypography.mono(
                              size: AppFontSizes.xxl,
                              weight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Blinds',
                            style: AppTypography.bodyXs.copyWith(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          variant: AppButtonVariant.primary,
          size: AppButtonSize.lg,
          fullWidth: true,
          onPressed: () => context.go(RoutePaths.playerLive),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Watch live game'),
              SizedBox(width: 6),
              Icon(Icons.arrow_forward, size: 14, color: AppColors.icon),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Create an account to use chat and get notifications. ',
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: InkWell(
                  onTap: () => context.go(RoutePaths.register),
                  child: Text(
                    'Sign up',
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// One icon + text line on the guest event-intro card.
class _IntroLine extends StatelessWidget {
  const _IntroLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.mutedForeground),
        const SizedBox(width: 6),
        Text(
          text,
          style: AppTypography.bodySm.copyWith(color: AppColors.foreground),
        ),
      ],
    );
  }
}

class _BackLink extends StatelessWidget {
  const _BackLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_back, size: 14, color: AppColors.icon),
          const SizedBox(width: 4),
          Text(
            'Back',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
