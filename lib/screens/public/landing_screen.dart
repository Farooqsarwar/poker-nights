import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';
import '../../app/typography.dart';
import '../../constants/app_constants.dart';
import '../../responsive/responsive.dart';
import '../../widgets/backgrounds.dart';
import '../../widgets/app_card.dart';

/// Public landing page mirroring the web `LandingPage`.
class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  void _openJoin() {
    context.go(RoutePaths.join);
  }

  @override
  Widget build(BuildContext context) {
    final device = AppBreakpoints.deviceOf(context);
    final isDesktop = device.isDesktop || device.isLargeDesktop;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FeltBackground(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              _buildHero(context, isDesktop),
              if (isDesktop) ...[
                _buildHowItWorks(context, isDesktop),
                _buildFeatures(context, isDesktop),
                _buildLifecycle(context, isDesktop),
                _buildTools(context, isDesktop),
                _buildFaq(context, isDesktop),
                _buildFooter(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isMobile = AppBreakpoints.deviceOf(context).isMobile;
    final statusBarHeight = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.only(
        left: isMobile ? AppSpacing.lg : AppSpacing.xxl,
        right: isMobile ? AppSpacing.lg : AppSpacing.xxl,
        top: statusBarHeight + (isMobile ? AppSpacing.sm : AppSpacing.lg),
        bottom: isMobile ? AppSpacing.sm : AppSpacing.lg,
      ),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFD53032),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55D53032),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  '♠',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Poker Night',
                style: AppTypography.display(
                  size: 17,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const Spacer(),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFF161618),
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF28282C)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => context.go(RoutePaths.login),
            child: const Text(
              'Sign in',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD53032),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => context.go(RoutePaths.register),
            child: const Text(
              'Sign up',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, bool isDesktop) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? AppSpacing.xxxl : AppSpacing.lg,
            vertical: isDesktop ? AppSpacing.huge : AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              Text(
                'PRIVATE HOME POKER',
                textAlign: TextAlign.center,
                style: AppTypography.bodyXs.copyWith(
                  color: const Color(0xFF9A9AA6),
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w600,
                  fontSize: 9.5,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Run your best',
                textAlign: TextAlign.center,
                style: AppTypography.display(
                  size: isDesktop ? 44.0 : 34.0,
                  weight: FontWeight.w800,
                  height: 1.15,
                  color: Colors.white,
                ),
              ),
              Text(
                'poker night',
                textAlign: TextAlign.center,
                style: AppTypography.display(
                  size: isDesktop ? 44.0 : 34.0,
                  weight: FontWeight.w800,
                  height: 1.15,
                  color: const Color(0xFFD53032),
                ),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Text(
                  'One admin, one app. Tournament structure generated from your real chips. Timer, blinds, seating and prizes — handled.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFFB8B8C2),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Feature pills in 3 rows
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      _FeaturePill(label: 'AUTO BLIND STRUCTURE'),
                      SizedBox(width: 8),
                      _FeaturePill(label: 'LIVE TIMER'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      _FeaturePill(label: 'SEATING & REDRAWS'),
                      SizedBox(width: 8),
                      _FeaturePill(label: 'TV MODE'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      _FeaturePill(label: 'CASH GAME TRACKER'),
                      SizedBox(width: 8),
                      _FeaturePill(label: 'GROUP CHAT'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Two buttons side by side in a row!
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66D53032),
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD53032),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => context.go(RoutePaths.register),
                        child: const Text(
                          'Create account',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFF161618),
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF28282C)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _openJoin,
                        child: const Text(
                          'Join with a code',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Free for up to 9 players. No card, nothing to install.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9A9AA6), fontSize: 11),
              ),
              const SizedBox(height: 20),
              Container(height: 1, color: const Color(0xFF1E1E22)),
              const SizedBox(height: 20),
              const Text(
                'Runs in any browser today',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Host, player and TV views all open from a link — nothing to download.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9A9AA6), fontSize: 11),
              ),
              const SizedBox(height: 16),
              Row(
                children: const [
                  Expanded(
                    child: _StoreBadge(icon: Icons.apple, store: 'App Store'),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _StoreBadge(
                      icon: Icons.play_arrow_rounded,
                      store: 'Google Play',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Section shell: a heading, an optional standfirst, and a centred body
  /// capped so nothing stretches on an ultra-wide monitor.
  Widget _section(
    BuildContext context, {
    required bool isDesktop,
    String? eyebrow,
    required String title,
    String? standfirst,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? AppSpacing.xxxl : AppSpacing.lg,
        vertical: isDesktop ? AppSpacing.huge : AppSpacing.xxl,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairlineWhite)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.primaryText,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.display(
                  size: isDesktop ? AppFontSizes.xxl : AppFontSizes.xl,
                  weight: FontWeight.w700,
                ),
              ),
              if (standfirst != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Text(
                      standfirst,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                ),
              ],
              SizedBox(height: isDesktop ? AppSpacing.xxl : AppSpacing.xl),
              child,
            ],
          ),
        ),
      ),
    );
  }

  /// Three steps, because the real objection to software like this is not
  /// "will it work" but "how long before I can actually run a game on it".
  Widget _buildHowItWorks(BuildContext context, bool isDesktop) {
    const steps = [
      (
        '01',
        'Create a group',
        'Sign in and make your group. No setup wizard, nothing to import, '
            'no structure to write before you start.',
      ),
      (
        '02',
        'Send the link',
        'Players RSVP from their phones. Guests join with a code and never '
            'need an account at all.',
      ),
      (
        '03',
        'Start the clock',
        'Tell it your chips and how long you want to play. The structure is '
            'generated, seats are drawn, and the TV page is already live.',
      ),
    ];

    final cards = [
      for (final s in steps) _StepCard(step: s.$1, title: s.$2, body: s.$3),
    ];

    return _section(
      context,
      isDesktop: isDesktop,
      eyebrow: 'How it works',
      title: 'Running a game in minutes',
      standfirst:
          'Nothing to install and nothing to learn first. Set it up and run '
          'it the same night.',
      child: isDesktop
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    Expanded(child: cards[i]),
                    if (i != cards.length - 1)
                      const SizedBox(width: AppSpacing.xl),
                  ],
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  cards[i],
                  if (i != cards.length - 1)
                    const SizedBox(height: AppSpacing.lg),
                ],
              ],
            ),
    );
  }

  /// The product organised as the NIGHT, not as a feature list — which is the
  /// actual claim being made: one system that carries the whole evening
  /// rather than a timer with extras bolted on.
  Widget _buildLifecycle(BuildContext context, bool isDesktop) {
    const phases = [
      (
        'Before',
        'Set it up once.',
        [
          'Structure built from the chips you actually own',
          'Invites, RSVPs and an expected head-count you control',
          'Breaks, rebuy window and antes planned into the schedule',
          'Saved presets for the game you run every month',
        ],
      ),
      (
        'During',
        'One clock, every screen.',
        [
          'Check-in, seat draw and table balancing',
          'Rebuys, add-ons, re-entries and knockouts',
          'Colour-ups called when the chips need them',
          'Player phones and the TV stay in sync with the host',
        ],
      ),
      (
        'After',
        'The night records itself.',
        [
          'Payouts calculated as the field shrinks',
          'Final table, finishing order and results',
          'Organizer costs kept private to the host',
          'Group history and lifetime stats',
        ],
      ),
    ];

    final cards = [
      for (final p in phases)
        _PhaseCard(phase: p.$1, headline: p.$2, items: p.$3),
    ];

    return _section(
      context,
      isDesktop: isDesktop,
      eyebrow: 'The whole night',
      title: 'From the invite to the last hand',
      standfirst:
          'One system carrying the evening end to end, so nothing has to be '
          'rebuilt in a spreadsheet halfway through.',
      child: isDesktop
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    Expanded(child: cards[i]),
                    if (i != cards.length - 1)
                      const SizedBox(width: AppSpacing.xl),
                  ],
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  cards[i],
                  if (i != cards.length - 1)
                    const SizedBox(height: AppSpacing.lg),
                ],
              ],
            ),
    );
  }

  /// The four public calculators, surfaced.
  ///
  /// These already existed on their own routes and were reachable only from a
  /// single footer link. Somebody searching for a payout calculator can get
  /// their answer here and discover the rest afterwards, which is the
  /// cheapest introduction the product has.
  Widget _buildTools(BuildContext context, bool isDesktop) {
    final tools = [
      (
        Icons.timeline,
        'Blind structure generator',
        'A full schedule built around your chips and how long you want to play.',
        RoutePaths.toolBlinds,
      ),
      (
        Icons.timer_outlined,
        'Tournament clock',
        'A readable clock for a structure you already have.',
        RoutePaths.toolClock,
      ),
      (
        Icons.calculate_outlined,
        'ICM calculator',
        'What each stack is actually worth. Settle the chop.',
        RoutePaths.toolIcm,
      ),
      (
        Icons.payments_outlined,
        'Payout calculator',
        'Clean splits that divide properly at a real table.',
        RoutePaths.toolPayouts,
      ),
    ];

    return _section(
      context,
      isDesktop: isDesktop,
      eyebrow: 'Free tools',
      title: 'Use them without an account',
      standfirst:
          'Four calculators, free and open to anyone. No sign-up, no email, '
          'nothing to install.',
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.lg,
        children: [
          for (final t in tools)
            SizedBox(
              width: isDesktop ? 250 : double.infinity,
              child: _ToolCard(
                icon: t.$1,
                title: t.$2,
                body: t.$3,
                onTap: () => context.go(t.$4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFaq(BuildContext context, bool isDesktop) {
    // Written from what the app actually does, in the words a host would use
    // to ask. Every claim here is checked against the code — the earlier pass
    // described a guest flow this app does not have, which is worse than
    // saying nothing.
    const faqs = [
      (
        'Is it free?',
        'Hosting one table of up to nine active players is free, and that is '
            'a whole tournament — the clock, check-in, seating, rebuys, '
            'add-ons, knockouts and payouts. Premium is for scale and depth: '
            'more tables, manual seating and balancing, saved presets, ICM '
            'and KO payouts, advanced stats and TV customisation.',
      ),
      (
        'Fifteen said yes. What if twenty turn up?',
        'Tell it twenty. RSVPs undercount every time, and the chip and blind '
            'plan should be built for the room you expect rather than the '
            'people who replied. You can also lock that number once you have '
            'counted the chips out, so a late RSVP cannot quietly reshuffle '
            'a structure you already physically prepared.',
      ),
      (
        'Someone turned up after we started.',
        'Late registration stays open until the rebuy window closes. They '
            'get a full starting stack, a seat at the emptiest table, and '
            'the prize pool recalculates to include them.',
      ),
      (
        'We are running behind. Can I speed it up?',
        'It watches for that. If the projected finish drifts more than about '
            'twenty minutes from your target, it flags it and suggests '
            'speeding up or slowing down — but it never changes the '
            'structure on its own. You confirm, and only future levels move. '
            'Levels already played are never rewritten.',
      ),
      (
        'Will the structure work with the chips I own?',
        'That is the part most generators skip. You enter your colours, '
            'their values and how many of each you actually have, and every '
            'blind and ante in the schedule is checked to be payable from '
            'that box. Colour-ups get planned in too, so the denominations '
            'you run short of are swapped before they bite.',
      ),
      (
        'Do players need an account?',
        'Group members do — they RSVP, chat and keep their history. Guests '
            'do not. A member says how many guests they are bringing, and '
            'each guest opens the link or types the code, picks who invited '
            'them and takes one of those places. The host confirms them, and '
            'only then does a private address become visible to them.',
      ),
      (
        'How do check-in and seating work on the night?',
        'Players can check themselves in from their phone, but it stays a '
            'request until you confirm it — the head-count you start on is '
            'the one you approved. Seats are then drawn for you. A random '
            'draw is free; Premium adds manual placement and the choice to '
            'seat guests with whoever brought them, or deliberately apart.',
      ),
      (
        'What if I record something wrong mid-game?',
        'Undo it. Eliminations, rebuys and add-ons are each timestamped, so '
            'a mistake at the table is a correction rather than a restart.',
      ),
      (
        'What if the internet drops?',
        'The host device is the authoritative clock and keeps counting down '
            'locally. Player and TV screens reconcile with it when the '
            'connection returns. Progress is also kept on the host device, '
            'so a reload mid-tournament does not lose the night.',
      ),
      (
        'Can players see what I take for costs?',
        'No. You can set a percentage for equipment, drinks and snacks, and '
            'it stays private to the host. Players and guests never receive '
            'it, and that is enforced by the database rules rather than '
            'hidden in the interface.',
      ),
      (
        'How does the TV work?',
        'Open the TV page in any browser — a laptop wired to the television, '
            'or the browser built into the set. Blinds, the clock, standings '
            'and '
            'announcements, in sync with the host, with the private figures '
            'left out. There is a one-minute warning and the level change '
            'announced out loud as well.',
      ),
      (
        'Can I run a cash game too?',
        'Yes, separately from tournaments. Set the blinds and the minimum '
            'and maximum buy-in, then track every buy-in and cash-out. It '
            'works out who is up and who is down, so the table settles from '
            'one screen instead of an argument.',
      ),
    ];

    return _section(
      context,
      isDesktop: isDesktop,
      eyebrow: 'Questions',
      title: 'Common questions',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final f in faqs) _FaqItem(question: f.$1, answer: f.$2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatures(BuildContext context, bool isDesktop) {
    final features = [
      (
        Icons.casino_outlined,
        'Smart tournament engine',
        'Enter your chip set and target duration — Poker Night works out stack sizes, blind levels and payouts that actually fit.',
      ),
      (
        Icons.tv_outlined,
        'TV mode & voice',
        'Open the TV page on any browser. Clean full-screen timer with voice announcements for level changes and eliminations.',
      ),
      (
        Icons.groups_outlined,
        'Group management',
        'Private group with RSVP, chat, polls and game history. Guests join with a code — no account required.',
      ),
    ];

    // Build standard feature cards
    final cards = features
        .map((f) => _FeatureCard(icon: f.$1, title: f.$2, body: f.$3))
        .toList();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? AppSpacing.xxxl : AppSpacing.lg,
        vertical: isDesktop ? AppSpacing.huge : AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairlineWhite)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1100,
          ), // Prevent stretching on ultra-wide screens
          child: isDesktop
              // Desktop: Row with IntrinsicHeight ensures all cards stretch to match the tallest one
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < cards.length; i++) ...[
                        Expanded(child: cards[i]),
                        if (i != cards.length - 1)
                          const SizedBox(width: AppSpacing.xxl),
                      ],
                    ],
                  ),
                )
              // Mobile: Standard stacked column
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < cards.length; i++) ...[
                      cards[i],
                      if (i != cards.length - 1)
                        const SizedBox(height: AppSpacing.xl),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final isMobile = AppBreakpoints.deviceOf(context).isMobile;

    // Every link carried its own left padding AND sat in a Wrap that already
    // spaced them, so the gaps were doubled and the first item hung off its
    // own edge. On a phone the outer spaceBetween then shoved the copyright
    // and the links apart hard enough to strand "Support" alone on a line.
    final links = <String, String>{
      'Free Tools': RoutePaths.tools,
      'Privacy Policy': RoutePaths.privacy,
      'Terms of Service': RoutePaths.terms,
      'Support': RoutePaths.support,
    };

    final linkRow = Wrap(
      alignment: isMobile ? WrapAlignment.center : WrapAlignment.end,
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.xs,
      children: [
        for (final entry in links.entries)
          InkWell(
            onTap: () => context.go(entry.value),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              // A comfortable tap target without inventing horizontal gaps
              // the Wrap is already providing.
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Text(
                entry.key,
                style: AppTypography.bodyXs.copyWith(
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
          ),
      ],
    );

    final copyright = Text(
      '© 2026 Poker Night. All rights reserved.',
      textAlign: isMobile ? TextAlign.center : TextAlign.start,
      style: AppTypography.bodyXs.copyWith(color: AppColors.mutedForeground),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppSpacing.lg : AppSpacing.xxl,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairlineWhite)),
      ),
      // Stacked and centred on a phone, opposed on a wide screen — the same
      // content, laid out the way each width can actually carry it.
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                linkRow,
                const SizedBox(height: AppSpacing.sm),
                copyright,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(child: copyright),
                const SizedBox(width: AppSpacing.lg),
                Flexible(child: linkRow),
              ],
            ),
    );
  }
}

// -----------------------------------------------------------------------------
// Helper Widgets
// -----------------------------------------------------------------------------

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.card.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.bodyXs.copyWith(
          color: AppColors.mutedForeground,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.title,
    required this.body,
  });

  final String step;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            step,
            style: AppTypography.display(
              size: AppFontSizes.xxl,
              weight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: AppTypography.bodyStyle.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({
    required this.phase,
    required this.headline,
    required this.items,
  });

  final String phase;
  final String headline;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.primarySoftBorder),
            ),
            child: Text(
              phase.toUpperCase(),
              style: AppTypography.bodyXs.copyWith(
                color: AppColors.primaryText,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            headline,
            style: AppTypography.bodyStyle.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.check,
                      size: 14,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      item,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.mutedForeground,
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

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: AppColors.primaryText),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            body,
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Open →',
            style: AppTypography.bodyXs.copyWith(
              color: AppColors.primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Collapsed by default: a wall of open answers buries the questions, and the
/// point of an FAQ is that somebody can find THEIR question quickly.
class _FaqItem extends StatefulWidget {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: () => setState(() => _open = !_open),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.question,
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  _open ? Icons.remove : Icons.add,
                  size: 18,
                  color: AppColors.mutedForeground,
                ),
              ],
            ),
            if (_open) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.answer,
                style: AppTypography.bodySm.copyWith(
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

/// A store badge for an app that does not exist yet.
///
/// Shaped like the real thing — platform mark, small line over a larger
/// wordmark — so the section reads as a proper download row rather than an
/// apology. But it is deliberately INERT and says "Coming soon" where the
/// real badge says "Download on the": a badge that goes nowhere, or implies a
/// store listing that is not there, is the one landing-page claim that costs
/// real trust rather than just polish.
///
/// NOTE FOR LAUNCH: Apple's and Google's official badges are trademarked
/// artwork governed by their brand guidelines (fixed proportions, clear
/// space, approved wording). These are Material's platform glyphs standing in
/// for them. Replace with the official assets when the apps actually ship.
class _StoreBadge extends StatelessWidget {
  const _StoreBadge({required this.icon, required this.store});

  final IconData icon;
  final String store;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.75,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.card.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: AppColors.foreground),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Coming soon',
                  style: AppTypography.bodyXs.copyWith(
                    color: AppColors.onSurfaceHint,
                    height: 1.1,
                  ),
                ),
                Text(
                  store,
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppFontSizes.xxxl, color: AppColors.icon),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: AppTypography.display(size: AppFontSizes.lg)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            body,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
