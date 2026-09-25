import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_alert_banner.dart';
import '../../widgets/app_eyebrow.dart';
import '../../widgets/app_icon_label.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_timer.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/code_input.dart';
import '../../widgets/form_screen_header.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/min_tap_target.dart';
import '../../widgets/onboarding_scaffold.dart';
import '../../widgets/prompt_link.dart';
import '../../widgets/stat_rows_card.dart';

enum _GuestStep {
  enterCode,
  eventIntro,
  chooseInviter,
  chooseSlot,
  enterName,
  waiting,
  confirmed,
  rejected,
  notLive,
  wrongOwner,
  /// Arrived after late registration closed permanently, or the event was
  /// called off. A real dead end for tonight — say so kindly and offer the
  /// only things that still help.
  tooLate,
  completed,
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

  /// Why tonight is over for this guest — closed registration, or the event
  /// being called off. Drives [_buildTooLate].
  String? _tooLateReason;
  String? _selectedInviter;
  int? _selectedSlot;
  bool _submittingCheckIn = false;

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
      _step = _routeAfterBooking(game, guest, sessionPending: true);
    } else {
      // No saved session: show the event details first, then claim.
      _step = game == null ? _GuestStep.enterCode : _GuestStep.eventIntro;
    }
  }

  /// Decides where a guest who now owns a booking should land — straight into
  /// the confirmed seat view (from where they enter the live match) when the
  /// game is already live, or the "come back later" screen when it hasn't
  /// started yet.
  static _GuestStep _routeAfterBooking(
    LiveGame game,
    Player? guest, {
    bool sessionPending = false,
  }) {
    if (game.status == LiveGameStatus.completed) {
      return _GuestStep.completed;
    }
    // sessionPending: this device holds a persisted booking for this game, but
    // the row is not in the projection yet (the request is still travelling to
    // the host, or the game doc predates the host consuming it). The guest
    // cannot be claimed either way — keep them waiting rather than bounce them
    // to "confirmed" or the entry screen. A session with no row on a proposal
    // that is genuinely over still falls through to confirmed/notLive below.
    final preStart =
        game.status.index >= LiveGameStatus.checkin.index &&
        game.status.index <= LiveGameStatus.finaltable.index;
    if (guest != null && !guest.confirmed) {
      // Check-in opens at LiveGameStatus.checkin. Once open, unconfirmed guests
      // wait for admin approval instead of being told to come back later.
      if (preStart) {
        return _GuestStep.waiting;
      }
    } else if (guest == null && sessionPending && preStart) {
      return _GuestStep.waiting;
    }
    return game.status.isActiveLive ? _GuestStep.confirmed : _GuestStep.notLive;
  }

  /// Renders the schedule date/time, uppercasing the time suffix so e.g.
  /// "8:00 PM" reads consistently.
  static String _formatSchedule(String date, String time) {
    final t = time.trim();
    if (t.toLowerCase().endsWith('am') || t.toLowerCase().endsWith('pm')) {
      return '$date · ${t.toUpperCase()}';
    }
    return '$date · $t';
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
    // A pending booking may live in pendingGuests before the host has consumed
    // it (and the guest projection now carries it), so re-identify there too.
    for (final p in game.pendingGuests) {
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
        () => _codeError = 'Too many attempts. Wait a minute and try again.',
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
          _step = _routeAfterBooking(game, guest, sessionPending: true);
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
            'That code opens the TV display — ask the admin for the player code.',
      );
    }
  }

  Future<void> _requestCheckIn() async {
    if (_submittingCheckIn) return; // #5: block double-tap / double-claim race
    final app = context.read<AppProvider>();
    if (_selectedInviter == null ||
        _selectedSlot == null ||
        _nameController.text.trim().isEmpty) {
      return;
    }
    setState(() => _submittingCheckIn = true);
    final result = await app.requestGuestCheckIn(
      _nameController.text.trim(),
      _selectedInviter!,
      _selectedSlot!,
    );
    if (mounted) setState(() => _submittingCheckIn = false);
    if (!mounted) return;

    if (result.status == GuestCheckInStatus.taken) {
      // The slot is booked under a different name — don't overwrite it. Show
      // the conflict and send the guest back to pick another slot.
      setState(() {
        _nameError = null;
        _step = _GuestStep.wrongOwner;
      });
      return;
    }
    if (!result.ok) {
      // Registration closing is not a validation error the guest can correct
      // by retyping their name — it is the end of the road for tonight. It
      // used to leave them staring at a red line under the name field with no
      // way forward. Route it to a proper explanation instead.
      final closed = _closedMessage(result.message);
      if (closed != null) {
        setState(() {
          _nameError = null;
          _tooLateReason = closed;
          _step = _GuestStep.tooLate;
        });
        return;
      }
      // Anything else really is transient — keep them at the name step.
      setState(
        () => _nameError = result.message ?? 'Could not reserve that slot.',
      );
      return;
    }

    // Booked (new) or confirmed (re-identified): route by whether the game is
    // live. Live -> seat view (from there they enter the match); not live ->
    // "come back later" with the start schedule.
    final game = app.currentGame;
    final guest = _currentGuest();
    setState(() {
      _nameError = null;
      _step = _routeAfterBooking(game!, guest);
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
      _tooLateReason = null;
    });
  }

  /// Recognises the "the door is shut" failures, which a guest cannot fix by
  /// editing anything, and returns the sentence to show them.
  String? _closedMessage(String? raw) {
    final m = (raw ?? '').toLowerCase();
    if (m.contains('late registration') || m.contains('registration has closed')) {
      return 'Registration for tonight closed when the rebuy period ended, '
          'so no new players can be added to this tournament.';
    }
    if (m.contains('cancelled')) {
      return 'This tournament has been cancelled by the host.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final game = app.currentGame;

    return OnboardingScaffold(child: _buildBody(app, game));
  }

  Widget _buildBody(AppProvider app, LiveGame? game) {
    if (game != null && game.status == LiveGameStatus.cancelled) {
      // Silently bouncing back to the code screen looked like the code had
      // stopped working. Say what happened.
      if (_step != _GuestStep.tooLate) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _tooLateReason = 'This tournament has been cancelled by the host.';
            _step = _GuestStep.tooLate;
          });
        });
      }
      return _buildTooLate();
    }

    if (game == null) {
      if (_step == _GuestStep.enterCode) return _buildCodeEntry();
      return const SizedBox.shrink();
    }

    // Race-safe: if we arrived via JoinScreen and the game just loaded,
    // auto-advance from enterCode to eventIntro (tech spec §4.2).
    if (_step == _GuestStep.enterCode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _step == _GuestStep.enterCode) {
          setState(() => _step = _GuestStep.eventIntro);
        }
      });
      return _buildCodeEntry();
    }

    final registeredPlayers = game.players.where((p) => !p.isGuest).toList();
    final inviter = _selectedInviter == null
        ? null
        : registeredPlayers.where((p) => p.id == _selectedInviter).firstOrNull;
    final availableSlots = inviter?.rsvp?.guestCount ?? 0;
    final level = game.currentLevelData;
    // Private addresses are hidden from unconfirmed guests (User Flow §11.1):
    // revealed only after the admin confirms this guest's seat, or when the
    // event is public.
    final session = app.guestSession;
    final guestConfirmed =
        session != null &&
        game.players.any(
          (p) =>
              p.isGuest &&
              p.confirmed &&
              p.inviterId == session.inviterId &&
              p.guestSlot == session.slot,
        );
    final showAddress = !game.settings.locationPrivate || guestConfirmed;

    // While waiting, react to the admin's decision in real time: the guest is
    // confirmed once their player record is confirmed (07-027/07-028). A
    // pending guest is deliberately NOT downgraded to "rejected" here — their
    // own booking is authoritative until the host explicitly frees the slot,
    // so a projection refresh while the request is still pending must not show
    // a false decline.
    var view = _step;
    if (view == _GuestStep.waiting) {
      final guest = _currentGuest();
      if (guest != null && guest.confirmed) {
        view = _GuestStep.confirmed;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Connection status banner (tech spec §4.2 — stale-state for guests).
        Consumer<AppProvider>(
          builder: (_, app, x) {
            if (app.isOffline) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppAlertBanner(
                  type: AppAlertType.warning,
                  message: 'Connection interrupted — showing last known state.',
                ),
              );
            }
            if (app.hasReconnected) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppAlertBanner(
                  type: AppAlertType.success,
                  message: 'Back online — data is live.',
                  actionLabel: 'Dismiss',
                  onAction: () => app.clearReconnectedBanner(),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        // Header
        FormScreenHeader(
          centered: true,
          titleSize: AppFontSizes.xxl,
          leading: const IconTile(label: '♠', size: 40),
          title: game.settings.name,
          subtitle: showAddress
              ? '${game.settings.date} · ${game.settings.location}'
              : game.settings.date,
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
          _GuestStep.eventIntro => _buildEventIntro(
            game,
            showAddress: showAddress,
          ),
          _GuestStep.chooseInviter => _buildChooseInviter(
            game,
            registeredPlayers,
          ),
          _GuestStep.chooseSlot => _buildChooseSlot(
            game,
            inviter,
            availableSlots,
            game.players,
          ),
          _GuestStep.enterName => _buildEnterName(inviter),
          _GuestStep.waiting => _buildWaiting(game, inviter),
          _GuestStep.confirmed => _buildConfirmed(level),
          _GuestStep.rejected => _buildRejected(),
          _GuestStep.tooLate => _buildTooLate(),
          _GuestStep.notLive => _buildNotLive(game),
          _GuestStep.completed => _buildCompleted(),
          _GuestStep.wrongOwner => _buildWrongOwner(),
          _GuestStep.enterCode => const SizedBox.shrink(),
        },
      ],
    );
  }

  Widget _buildCodeEntry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        const FormScreenHeader(
          centered: true,
          titleSize: 24,
          leading: IconTile(label: '♠', size: 52),
          title: 'Join as guest',
          subtitle: 'Enter the code from the admin or invitation link',
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppEyebrow('Game code', muted: true),
              const SizedBox(height: AppSpacing.sm),
              CodeInput(
                controller: _codeController,
                hint: 'ENTER CODE',
                semanticLabel: 'Game code',
                autofocus: true,
                maxLength: 8,
                hasError: _codeError != null,
                onChanged: (_) {
                  if (_codeError != null) setState(() => _codeError = null);
                },
              ),
              if (_codeError != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _codeError!,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyXs.copyWith(
                      color: AppColors.destructiveText,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: AppButton(
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.md,
                  width: 128,
                  onPressed: _submitCode,
                  child: const Text('Join'),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 4,
                          ),
                          child: Text(
                            'FP2608',
                            style: AppTypography.monoXs.copyWith(
                              color: AppColors.primaryText,
                              fontWeight: FontWeight.w700,
                            ),
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
        const SizedBox(height: AppSpacing.md),
        PromptLink(
          prompt: 'Have an account? ',
          action: 'Sign in',
          onTap: () => context.go(RoutePaths.login),
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
  Widget _buildEventIntro(LiveGame game, {required bool showAddress}) {
    final s = game.settings;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppEyebrow('You’re invited to', textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
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
              if (s.location.isNotEmpty && showAddress)
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
            child: AppIconLabel(
              label: 'Claim My Guest Place',
              trailing: Icons.arrow_forward,
              color: AppColors.primaryForeground,
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepTitle(
            title: 'Who invited you?',
            subtitle:
                'Select the Registered Group Member who brought you along.',
          ),
          const SizedBox(height: AppSpacing.md),
          if (invited.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                // Two situations were reported with one sentence and the
                // guest could not tell which applied: nobody brought guests
                // at all, versus every slot already claimed. The second is
                // far more likely for a guest arriving last.
                game.guestSlots.isEmpty &&
                        !game.players.any((p) => p.isGuest)
                    ? 'Nobody has brought a guest to this game yet. Ask '
                          'whoever invited you to add you as their +1, then '
                          'come back.'
                    : 'Every guest place has already been claimed. Ask the '
                          'person who invited you, or the host, to free one '
                          'up for you.',
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
                child: _ChoiceRow(
                  selected: _selectedInviter == p.id,
                  onTap: () => setState(() => _selectedInviter = p.id),
                  leading: AppAvatar(name: p.name),
                  label: p.name,
                  trailing: AppTag(
                    '${_freeSlotsFor(game, p)} free',
                    tone: AppTagTone.success,
                  ),
                ),
              ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            variant: AppButtonVariant.primary,
            fullWidth: true,
            size: AppButtonSize.lg,
            onPressed: _selectedInviter == null
                ? null
                : () => setState(() => _step = _GuestStep.chooseSlot),
            child: AppIconLabel(
              label: 'Continue',
              trailing: Icons.arrow_forward,
              color: AppColors.primaryForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChooseSlot(
    LiveGame game,
    Player? inviter,
    int availableSlots,
    List<Player> players,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _BackLink(
              onTap: () => setState(() => _step = _GuestStep.chooseInviter),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          _StepTitle(
            title: 'Choose your guest slot',
            subtitle:
                '${inviter?.name ?? 'The admin'} is bringing $availableSlots guest${availableSlots > 1 ? 's' : ''}. Which slot are you?',
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

                final slotRecord = game.guestSlots
                    .where((s) => s.inviterId == inviter?.id && s.slot == slot)
                    .firstOrNull;
                final reservedName = slotRecord?.guestName;
                final isReserved =
                    slotRecord?.status == GuestSlotStatus.reserved &&
                    reservedName != null &&
                    reservedName.isNotEmpty;

                return _ChoiceRow(
                  selected: _selectedSlot == slot,
                  disabled: taken,
                  onTap: taken
                      ? null
                      : () => setState(() => _selectedSlot = slot),
                  label: isReserved
                      ? "Reserved for $reservedName"
                      : "${inviter?.name ?? ''}'s Guest $slot",
                  trailing: taken
                      ? const AppTag('Taken', tone: AppTagTone.danger)
                      : isReserved
                      ? const AppTag('Reserved', tone: AppTagTone.primary)
                      : null,
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            variant: AppButtonVariant.primary,
            fullWidth: true,
            size: AppButtonSize.lg,
            onPressed: _selectedSlot == null
                ? null
                : () => setState(() => _step = _GuestStep.enterName),
            child: AppIconLabel(
              label: 'Continue',
              trailing: Icons.arrow_forward,
              color: AppColors.primaryForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnterName(Player? inviter) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _BackLink(
              onTap: () => setState(() => _step = _GuestStep.chooseSlot),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const _StepTitle(
            title: 'Enter your name',
            subtitle:
                'This is shown to the admin and displayed on the seating plan.',
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _nameController,
            autofocus: true,
            placeholder: 'Your first name',
            textCapitalization: TextCapitalization.words,
            // Same 32-character cap as before, without the visible counter.
            inputFormatters: [LengthLimitingTextInputFormatter(32)],
            error: _nameError,
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
              setState(() {});
            },
            textStyle: AppTypography.body(
              size: AppFontSizes.lg,
              weight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            variant: AppButtonVariant.primary,
            fullWidth: true,
            size: AppButtonSize.lg,
            loading: _submittingCheckIn,
            onPressed:
                (_nameController.text.trim().isEmpty || _submittingCheckIn)
                ? null
                : _requestCheckIn,
            child: const Text('Confirm'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'If this slot is free, it will be booked for you. If it is already booked, it must match the name you used.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaiting(LiveGame game, Player? inviter) {
    final slotRecord = game.guestSlots
        .where(
          (s) => s.inviterId == inviter?.id && s.slot == (_selectedSlot ?? 1),
        )
        .firstOrNull;
    final reservedName = slotRecord?.guestName;
    final isReserved =
        slotRecord?.status == GuestSlotStatus.reserved &&
        reservedName != null &&
        reservedName.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StateCard(
          tile: IconTile(
            tone: IconTileTone.soft,
            size: 52,
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primaryText,
              ),
            ),
          ),
          title: 'Waiting for admin',
          message:
              'Your check-in request has been sent. The admin will confirm you shortly.',
        ),
        const SizedBox(height: AppSpacing.md),
        StatRowsCard(
          rows: [
            StatRow(
              'Guest slot',
              value: isReserved
                  ? "Reserved for $reservedName"
                  : "${inviter?.name ?? ''}'s Guest ${_selectedSlot ?? 1}",
            ),
          ],
        ),
      ],
    );
  }

  /// Dead end for tonight — registration closed, or the event was called off.
  ///
  /// A guest who turns up late is still a person standing in the room, so this
  /// says plainly what happened, what the host can and cannot do about it, and
  /// leaves the one door that is still open: make an account so the next
  /// invitation comes straight to them.
  Widget _buildTooLate() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StateCard(
          tile: const IconTile(
            icon: Icons.schedule,
            tone: IconTileTone.neutral,
            size: 52,
          ),
          title: 'You have missed this one',
          message:
              _tooLateReason ??
              'This tournament is no longer accepting new players.',
          footnote:
              'Have a word with the host — they can see exactly where the '
              'tournament is up to. Nothing here can reopen it for you.',
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          size: AppButtonSize.lg,
          fullWidth: true,
          onPressed: () => context.go(RoutePaths.register),
          child: const Text('Create an account for next time'),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.lg,
          fullWidth: true,
          onPressed: _startOver,
          child: const Text('Enter a different code'),
        ),
      ],
    );
  }

  Widget _buildRejected() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StateCard(
          tile: const IconTile(
            icon: Icons.close,
            tone: IconTileTone.danger,
            size: 52,
          ),
          title: 'Request declined',
          titleColor: AppColors.destructiveText,
          borderColor: AppColors.destructive.withValues(alpha: 0.4),
          message:
              'The host could not confirm your guest slot. This can happen when the slot was already taken or registration has closed.',
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

  Widget _buildCompleted() {
    return const _StateCard(
      tile: IconTile(
        icon: Icons.emoji_events,
        tone: IconTileTone.neutral,
        size: 52,
      ),
      title: 'Game Completed',
      message: 'This tournament has already finished.',
    );
  }

  Widget _buildNotLive(LiveGame game) {
    final session = context.read<AppProvider>().guestSession;
    final reservedName = session?.name;
    final guest = _currentGuest();
    final confirmed = guest != null && guest.confirmed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StateCard(
          glow: true,
          borderColor: AppColors.successSoftBorder,
          tile: IconTile(
            icon: confirmed ? Icons.check_circle : Icons.event_available,
            tone: IconTileTone.success,
            size: 52,
          ),
          title: confirmed ? 'You’re confirmed!' : 'Your slot is booked',
          titleColor: AppColors.successText,
          message: confirmed
              ? 'The admin has accepted your seat.'
              : (reservedName == null || reservedName.isEmpty
                    ? 'You have a reserved seat.'
                    : 'Reserved for $reservedName.'),
        ),
        if (confirmed) ...[
          const SizedBox(height: AppSpacing.md),
          _SeatCard(
            seat: guest.table > 0 && guest.seat > 0
                ? 'Table ${guest.table} · Seat ${guest.seat}'
                : 'Table 1 · Seat ${_selectedSlot ?? 1}',
            pending: !(guest.table > 0 && guest.seat > 0),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The game isn’t live yet',
                style: AppTypography.display(size: AppFontSizes.lg),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'The tournament goes live once the admin starts it. Come back then to watch your match live.',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        StatRowsCard(
          rows: [
            StatRow(
              'Scheduled for',
              value: _formatSchedule(game.settings.date, game.settings.time),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.lg,
          fullWidth: true,
          onPressed: _startOver,
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _buildWrongOwner() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StateCard(
          borderColor: AppColors.warning.withValues(alpha: 0.6),
          tile: const IconTile(
            icon: Icons.event_busy,
            tone: IconTileTone.warning,
            size: 52,
          ),
          title: 'Not booked on your name',
          message:
              'This slot is not booked on the name you entered — it is reserved for someone else. It was not changed.',
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          variant: AppButtonVariant.primary,
          size: AppButtonSize.lg,
          fullWidth: true,
          onPressed: () {
            _nameController.clear();
            setState(() => _step = _GuestStep.chooseSlot);
          },
          child: const Text('Pick a different slot'),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.lg,
          fullWidth: true,
          onPressed: () {
            setState(() => _step = _GuestStep.enterName);
          },
          child: const Text('Try another name'),
        ),
      ],
    );
  }

  Widget _buildConfirmed(BlindLevel? level) {
    final guest = _currentGuest();
    final seated = guest != null && guest.table > 0 && guest.seat > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StateCard(
          glow: true,
          borderColor: AppColors.successSoftBorder,
          tile: const IconTile(
            icon: Icons.check_circle,
            tone: IconTileTone.success,
            size: 52,
          ),
          title: "You're in!",
          titleColor: AppColors.successText,
          message: 'Your seat has been confirmed.',
        ),
        const SizedBox(height: AppSpacing.md),
        _SeatCard(
          seat: seated
              ? 'Table ${guest.table} · Seat ${guest.seat}'
              : 'Pending seating',
          pending: !seated,
        ),
        if (level != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppEyebrow('Live game', muted: true),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final game = context.read<AppProvider>().currentGame;
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
          child: AppIconLabel(
            label: 'Watch live game',
            trailing: Icons.arrow_forward,
            color: AppColors.primaryForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        PromptLink(
          prompt: 'Create an account to use chat and get notifications. ',
          action: 'Sign up',
          onTap: () => context.go(RoutePaths.register),
        ),
      ],
    );
  }
}

/// Title + helper line at the top of a guest-flow step card.
class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.display(
            size: AppFontSizes.lg,
            weight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: AppTypography.bodySm.copyWith(
            color: AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }
}

/// A selectable row — inviter or guest slot. Crimson outline and soft fill
/// when selected; dimmed and inert when [disabled].
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.selected,
    required this.onTap,
    required this.label,
    this.leading,
    this.trailing,
    this.disabled = false,
  });

  final bool selected;
  final VoidCallback? onTap;
  final String label;
  final Widget? leading;
  final Widget? trailing;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: !disabled,
      selected: selected,
      enabled: !disabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AnimatedContainer(
            duration: AppDurations.fast,
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              color: disabled
                  ? AppColors.muted
                  : (selected ? AppColors.primarySoft : AppColors.card),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : AppColors.border.withValues(alpha: 0.75),
              ),
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                      color: disabled ? AppColors.mutedForeground : null,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Centred outcome card for a guest-flow state: a tinted [IconTile], a title,
/// the explanation, and an optional quieter footnote panel.
class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.tile,
    required this.title,
    required this.message,
    this.titleColor,
    this.borderColor,
    this.glow = false,
    this.footnote,
  });

  final Widget tile;
  final String title;
  final String message;
  final Color? titleColor;
  final Color? borderColor;
  final bool glow;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      glow: glow,
      borderColor: borderColor,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          tile,
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.display(
              size: AppFontSizes.xl,
              weight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            liveRegion: true,
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          if (footnote != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.75),
                ),
              ),
              child: Text(
                footnote!,
                textAlign: TextAlign.center,
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Your seat" — the guest's table and seat, or a pending note.
class _SeatCard extends StatelessWidget {
  const _SeatCard({required this.seat, required this.pending});

  final String seat;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppEyebrow('Your seat', muted: true),
          const SizedBox(height: AppSpacing.sm),
          Text(
            seat,
            style: AppTypography.mono(
              size: AppFontSizes.xxl,
              weight: FontWeight.w700,
            ),
          ),
          if (pending) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Seats are assigned once the admin generates the seating plan.',
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ],
      ),
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
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: MinTapTarget(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chevron_left,
              size: 18,
              color: AppColors.mutedForeground,
            ),
            Text(
              'Back',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ),
      ),
    );
  }
}
