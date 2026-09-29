/// C9 — "Results: podium, story and share" (Build Spec v3.1 §C9, line 1075):
/// the **1080 x 1350** share image behind the results screen's **Share**
/// action, handed to the OS share sheet (T93; checklist row 56, "Share-card
/// image generation").
///
/// Layout, in the spec's own order: red top rule · "FRIDAY REGULARS · 2 OCT" ·
/// "Alexey wins" (or "Deal at 3 players") · "11 players · 189 prize pool" ·
/// the podium with prizes and season points · most knockouts · the PNT logo.
///
/// ## Why this file does NOT use `AppTypography`
///
/// [AppTypography] sizes every style through `AppScale.sp`, which multiplies
/// the *device's* width/height scale. That is right for a responsive screen
/// and wrong here: this card is a fixed 1,080 x 1,350 canvas and must look
/// identical whether it was rasterised on a phone or a tablet. The styles
/// below are therefore absolute, pinned to the app's one type family
/// ([AppTypography.displayFamily]) at fixed sizes.
///
/// ## Why the card avoids anything that decodes late
///
/// The capture reads a [RepaintBoundary] with no frame in between painting it
/// and reading it, so anything still decoding at that moment is missing from
/// the bitmap, and emoji render as tofu in an offscreen raster.
///
/// * **Type** is the app's own family named as a plain string
///   ([AppTypography.displayFamily]), never `GoogleFonts.*`. The Google Fonts
///   package is only a *resolver*; calling it starts a network fetch per text
///   style, and a style that has not come back paints as the fallback face (or
///   not at all) in the exported PNG. Naming the family directly is also what
///   the running app has already done for every other screen.
/// * **Icons** are `Icons.*` only — MaterialIcons ships with the engine.
/// * **The logo** is the app's real asset ([PokerNightLogo], i.e.
///   `assets/logo_<palette>.png`) and is deliberately NOT replaced by a
///   redrawn wordmark: §C9 asks for "the PNT logo", and a second, invented
///   mark is not it. Because it *is* an asset, [shareResults] resolves it with
///   [precacheImage] before the overlay entry is inserted, so it is decoded
///   and in the image cache by the time the card paints.
///
/// §B1 / User Flow §3.4 also applies here: no currency symbols anywhere — all
/// money goes through [Formatters.prize], and no gold, silver or bronze is
/// used for the podium.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../app/colors.dart';
import '../app/typography.dart';
import '../constants/app_constants.dart';
import '../models/game.dart';
import '../models/live_game.dart';
import '../models/tournament.dart';
import '../providers/app_provider.dart';
import '../widgets/brand_lockup.dart';
import 'formatters.dart';
import 'payouts_engine.dart';

/// The pinned geometry of the share image (§C9: "a 1080 x 1350 image").
abstract final class ShareCardSpec {
  /// 1,080 px wide — half the spec's "1080 x 1350".
  static const double imageWidth = 1080;

  /// 1,350 px tall — the other half.
  static const double imageHeight = 1350;

  /// The card is laid out in *logical* pixels at its real size and captured
  /// 1:1, so the PNG is exactly [imageWidth] x [imageHeight] device pixels.
  /// `toImage` computes `(size x pixelRatio).round()`; both factors are whole
  /// numbers, so there is no rounding to drift by a pixel.
  static const double capturePixelRatio = 1;
}

/// One podium pedestal. [place] is 1, 2 or 3.
class SharePodiumEntry {
  const SharePodiumEntry({
    required this.place,
    required this.name,
    this.prizeText,
    this.seasonPointsText,
  });

  final int place;
  final String name;

  /// The prize figure, already formatted without a currency symbol. Null when
  /// the viewer may not see individual amounts (§C9's money rules; see
  /// [buildShareCardData]).
  final String? prizeText;

  /// "+34.6 pts" when seasons are on, else null (§C9).
  final String? seasonPointsText;
}

/// A single award line — currently only "most knockouts" is on the card.
class ShareAward {
  const ShareAward({required this.label, required this.valueText});

  final String label;
  final String valueText;
}

/// Everything the card draws, with no dependency on `AppProvider` so the
/// widget (and therefore the 1,080 x 1,350 contract) can be rendered in
/// isolation.
class ShareCardData {
  const ShareCardData({
    required this.eyebrow,
    required this.headline,
    required this.metaLine,
    this.podium = const <SharePodiumEntry>[],
    this.mostKnockouts,
  });

  /// "FRIDAY REGULARS · 2 OCT".
  final String eyebrow;

  /// "Alexey wins" or "Deal at 3 players".
  final String headline;

  /// "11 players · 189 prize pool" (the pool is dropped when amounts are
  /// private).
  final String metaLine;

  final List<SharePodiumEntry> podium;
  final ShareAward? mostKnockouts;
}

/// Renders [data] on the fixed 1,080 x 1,350 canvas. Pure — no overlay, no
/// capture — so it can be pumped straight into a test.
Widget buildShareCard(ShareCardData data) => _ShareCardView(data);

/// A captured share image. The caller owns [image] and must [dispose] it.
class ShareCardImage {
  ShareCardImage._(this.image, this.pngBytes)
    : width = image.width,
      height = image.height;

  final ui.Image image;
  final Uint8List pngBytes;
  final int width;
  final int height;

  void dispose() => image.dispose();
}

/// The one capture routine, shared by [shareResults] and the widget test, so
/// the size that is asserted is the size that is actually shared.
///
/// ## This must be awaited from a real async zone
///
/// [RenderRepaintBoundary.toImage] resolves on the engine's raster path, so it
/// completes from an `await` in ordinary app code. It does **not** resolve
/// inside the fake-async zone a `testWidgets` body runs in, and the failure is
/// silent and total: the test body finishes, then `flutter test` hangs
/// forever — the end-of-test `runApp`/`pump` never completes, so not even
/// `--timeout` fires and nothing is printed.
///
/// A widget test must therefore wrap the call:
///
/// ```dart
/// final captured = (await tester.runAsync(() => captureShareCard(boundary)))!;
/// ```
Future<ShareCardImage> captureShareCard(RenderRepaintBoundary boundary) async {
  final image = await boundary.toImage(
    pixelRatio: ShareCardSpec.capturePixelRatio,
  );
  try {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Share card capture produced no PNG bytes.');
    }
    return ShareCardImage._(image, byteData.buffer.asUint8List());
  } catch (_) {
    image.dispose();
    rethrow;
  }
}

/// C9's **Share** action: build the card, rasterise it to a 1,080 x 1,350 PNG
/// and hand it to the OS share sheet (T93).
///
/// [showAmounts] mirrors the results screen's own visibility rule — individual
/// payout amounts are private to organisers (checklist 14-042, 19-020), and a
/// non-organiser must not be able to export in an image what the screen hides
/// from them.
///
/// [dealPlayerCount] overrides the chop detection below with an authoritative
/// count once C-deal records one.
Future<void> shareResults(
  BuildContext context, {
  required LiveGame game,
  required GameRecap recap,
  bool showAmounts = false,
  bool seasonsOn = false,
  int? dealPlayerCount,
  String? shareText,
  Rect? sharePositionOrigin,
}) async {
  final data = buildShareCardData(
    game: game,
    recap: recap,
    showAmounts: showAmounts,
    seasonsOn: seasonsOn,
    dealPlayerCount: dealPlayerCount,
  );

  final overlay = Overlay.of(context, rootOverlay: true);
  final mount = await mountShareCard(overlay, data);
  try {
    final captured = await captureShareCard(mount.boundary);
    try {
      await _present(
        captured.pngBytes,
        // The share sheet gets a caption as well as the image, and it is the
        // same headline the card draws — §C9's "Alexey wins" / "Deal at 3
        // players" must not say one thing in the image and another in the text
        // the user edits before sending it.
        shareText: shareText ?? '${data.eyebrow} · ${data.headline}',
        sharePositionOrigin: sharePositionOrigin,
      );
    } finally {
      captured.dispose();
    }
  } finally {
    mount.dispose();
  }
}

/// A card that is in the tree, painted, and ready to be captured. The owner
/// must [dispose] it, which takes the entry back out of the overlay.
class ShareCardMount {
  ShareCardMount._(this._entry, this.boundary);

  final OverlayEntry _entry;
  bool _disposed = false;

  /// Read this with [captureShareCard], then dispose the mount.
  final RenderRepaintBoundary boundary;

  /// Takes the entry back out of the overlay. Safe to call twice: [shareResults]
  /// disposes in a `finally`, and `OverlayEntry.remove` asserts if it is
  /// removed more than once.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _entry.remove();
  }
}

/// Inserts [data] into [overlay] off-screen and waits for it to be painted and
/// ready to capture.
///
/// Split out of [shareResults] because every part of it can fail *quietly*:
/// an entry that never lays out, a frame that has not painted yet, or an
/// asset that has not decoded all still hand back a perfectly
/// 1,080 x 1,350 bitmap — of nothing, or of a card with no logo. The widget
/// test captures through this exact function, so those three failures show up
/// as a failing test rather than as a blank image in someone's chat app.
Future<ShareCardMount> mountShareCard(
  OverlayState overlay,
  ShareCardData data,
) async {
  // The logo is an asset, and the capture reads the layer as it stands, so it
  // has to be decoded BEFORE the entry is inserted. `precacheImage` returns
  // immediately when the image is already cached — which it normally is,
  // because the shell's top bar draws the same lockup — so this is free in
  // the common case and a first decode in the rest. A failure here is not
  // worth failing the share over: the card is still produced, only its logo is
  // missing, and `precacheImage` completes (with an error) rather than hanging.
  try {
    await precacheImage(brandLockupImage(), overlay.context);
  } catch (_) {
    // Fall through: the card is still shareable without its mark.
  }

  final boundaryKey = GlobalKey();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      // Parked off the left edge. The card has to be PAINTED for `toImage` to
      // have a layer to read, but a 1,080 x 1,350 overlay painted on a phone
      // screen would flash over the UI for a frame, so it is laid out clear of
      // the viewport. Nothing clips it — Overlay's theatre does not clip — and
      // `toImage` reads the boundary's own layer regardless of where it sits.
      left: -ShareCardSpec.imageWidth - 32,
      top: 0,
      child: RepaintBoundary(key: boundaryKey, child: buildShareCard(data)),
    ),
  );

  overlay.insert(entry);
  // One frame for layout and paint of the freshly inserted entry; a second so
  // the boundary is guaranteed clean (no pending paint) before toImage.
  await WidgetsBinding.instance.endOfFrame;
  await WidgetsBinding.instance.endOfFrame;

  final boundary =
      boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) {
    entry.remove();
    throw StateError('Share card failed to lay out.');
  }
  return ShareCardMount._(entry, boundary);
}

/// Hands the PNG to the platform share sheet.
///
/// The bytes are shared **directly**, not written to a temp file: `XFile` is
/// built with `XFile.fromData`, which share_plus materialises for the platform
/// itself. That keeps the 1,080 x 1,350 image the only copy and avoids needing
/// `path_provider` at all.
Future<void> _present(
  Uint8List pngBytes, {
  String? shareText,
  Rect? sharePositionOrigin,
}) {
  return SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(
          pngBytes,
          mimeType: 'image/png',
          name: 'poker-night-results.png',
        ),
      ],
      text: shareText,
      title: 'Poker Night results',
      sharePositionOrigin: sharePositionOrigin,
    ),
  );
}

/// Builds the card's content from a completed game.
///
/// Ranking deliberately mirrors the results screen: `finishOrder` is stored
/// first-out first, so place = `finishOrder.length - index`. Two readings of
/// the same list must never disagree, so this copies the screen's convention
/// rather than inventing a second one.
///
/// ## "Deal at 3 players" (spec §C9 + §C-deal)
///
/// The models carry **no explicit chop flag**. A natural finish is recorded
/// only when a bust leaves one active player (spec §C8), so a completed game
/// with more than one non-eliminated player can only have ended on an agreed
/// deal — the same reasoning `AppProviderTournament.recapFor` already uses
/// when it excludes a "chopped or hand-recorded finish" from fastest bust.
/// That survivor count is the {n} in "Deal at {n} players". [dealPlayerCount]
/// overrides it for an authoritative figure once C-deal records one.
ShareCardData buildShareCardData({
  required LiveGame game,
  required GameRecap recap,
  bool showAmounts = false,
  bool seasonsOn = false,
  int? dealPlayerCount,
}) {
  final players = game.players;
  final finishOrder = game.finishOrder;
  final prizes = game.structure.prizes;

  final ranked = <({Player player, int place})>[
    for (var i = 0; i < finishOrder.length; i++)
      if (players.where((p) => p.id == finishOrder[i]).firstOrNull
          case final player?)
        (player: player, place: finishOrder.length - i),
  ];

  final podium = <SharePodiumEntry>[
    for (final row in ranked)
      if (row.place <= 3)
        SharePodiumEntry(
          place: row.place,
          name: row.player.name,
          prizeText: showAmounts ? _prizeFor(prizes, row.place) : null,
          seasonPointsText: seasonsOn
              ? _seasonPoints(players.length, row.place)
              : null,
        ),
  ]..sort((a, b) => a.place.compareTo(b.place));

  final winner = ranked.where((r) => r.place == 1).firstOrNull;

  // §C-deal: the deal screen is entered with the stacks of the players still
  // in, and the results screen is titled "{leader} leads on chips — deal at
  // {n}". `activePlayers` is still that set after completion — `completion`
  // never clears `active`.
  final dealCount = dealPlayerCount ?? game.activePlayers.length;
  final headline = dealCount > 1
      ? 'Deal at $dealCount players'
      : winner != null
      ? '${winner.player.name} wins'
      : 'Final results';

  final meta = showAmounts
      ? '${players.length} players · ${Formatters.prize(game.structure.prizePool)} prize pool'
      : '${players.length} players';

  final knockoutRow = recap.mostKnockouts;
  final mostKnockouts = knockoutRow == null
      ? null
      : ShareAward(
          label: 'MOST KNOCKOUTS',
          valueText: '${knockoutRow.playerName} · ${knockoutRow.value} KOs',
        );

  return ShareCardData(
    eyebrow:
        '${game.settings.name.toUpperCase()} · '
        '${_shortDate(game.settings.date)}',
    headline: headline,
    metaLine: meta,
    podium: podium,
    mostKnockouts: mostKnockouts,
  );
}

/// §F2.9 season points, on the default `fieldSize` formula, one decimal.
String? _seasonPoints(int players, int place) {
  if (players <= 0 || place <= 0) return null;
  final points = PayoutsEngine.seasonPoints(players, place);
  return '+${points.toStringAsFixed(1)} pts';
}

String? _prizeFor(List<Prize> prizes, int place) {
  final prize = prizes.where((p) => p.place == place).firstOrNull;
  return prize == null ? null : Formatters.prize(prize.amount);
}

/// "2026-10-02" -> "2 OCT". Anything unparseable is upper-cased verbatim rather
/// than dropped.
String _shortDate(String raw) {
  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  final parsed = DateTime.tryParse(raw.trim());
  if (parsed == null) return raw.trim().toUpperCase();
  return '${parsed.day} ${months[parsed.month - 1]}';
}

// ── The card ────────────────────────────────────────────────────────────────

const double _pad = 72;
const double _blockHeight = 600;
const double _podiumStackHeight = 200;
const double _knockoutBandHeight = 116;

/// The PNT lockup is near-square (2,022 x 1,926), so this is its height and
/// the width follows. Sized against the other blocks so the fixed content
/// still leaves a positive gap for the [Spacer] on the 1,350px canvas:
/// 40 + 26 + 100 + 18 + 50 + 52 + 600 + 48 + 116 + 120 = 1,170 of the 1,208
/// the padded column has, leaving 38 to breathe.
const double _logoHeight = 120;
const double _contentTop = 64;
const double _contentBottom = 64;

/// Absolute text style for the fixed canvas — see the file header for why
/// [AppTypography]'s scaled styles are deliberately not used here.
TextStyle _type({
  required double size,
  FontWeight weight = FontWeight.w400,
  Color? color,
  double height = 1.15,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: AppTypography.displayFamily,
    fontSize: size,
    fontWeight: weight,
    color: color ?? AppColors.foreground,
    height: height,
    letterSpacing: letterSpacing,
    fontFeatures: AppTypography.numericFeatures,
  );
}

class _ShareCardView extends StatelessWidget {
  const _ShareCardView(this.data);

  final ShareCardData data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ShareCardSpec.imageWidth,
      height: ShareCardSpec.imageHeight,
      child: ColoredBox(
        color: AppColors.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _TopRule(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _pad,
                  _contentTop,
                  _pad,
                  _contentBottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 40,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            data.eyebrow,
                            maxLines: 1,
                            style: _type(
                              size: 30,
                              weight: FontWeight.w600,
                              color: AppColors.primaryText,
                              height: 1.3,
                              letterSpacing: 4,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    // Headline. `FittedBox(scaleDown)` rather than an ellipsis:
                    // a long winner's name shrinks to fit instead of being cut
                    // to "Alexey wins…" on the one artefact people forward.
                    SizedBox(
                      height: 100,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            data.headline,
                            maxLines: 1,
                            style: _type(size: 84, weight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 50,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          data.metaLine,
                          maxLines: 1,
                          style: _type(
                            size: 36,
                            weight: FontWeight.w500,
                            color: AppColors.mutedForeground,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 52),
                    SizedBox(
                      height: _blockHeight,
                      child: _Podium(entries: data.podium),
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      height: _knockoutBandHeight,
                      child: _KnockoutBand(award: data.mostKnockouts),
                    ),
                    // The logo sits on the card's bottom edge however the
                    // blocks above measure out, so the canvas is always full.
                    const Spacer(),
                    const SizedBox(height: _logoHeight, child: _LogoLockup()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "red top rule" — the first element the spec lists.
class _TopRule extends StatelessWidget {
  const _TopRule();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 14,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryHover],
        ),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.entries});

  final List<SharePodiumEntry> entries;

  /// 1st stands highest — the spec's "raised, crimson pedestal".
  static const Map<int, double> _pedestalHeights = {1: 380, 2: 290, 3: 220};

  @override
  Widget build(BuildContext context) {
    final byPlace = {for (final e in entries) e.place: e};
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Spec §C9 order: 2nd · 1st (raised) · 3rd.
        for (final place in const [2, 1, 3])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _PedestalColumn(
                entry: byPlace[place],
                place: place,
                pedestalHeight: _pedestalHeights[place]!,
              ),
            ),
          ),
      ],
    );
  }
}

class _PedestalColumn extends StatelessWidget {
  const _PedestalColumn({
    required this.entry,
    required this.place,
    required this.pedestalHeight,
  });

  final SharePodiumEntry? entry;
  final int place;
  final double pedestalHeight;

  @override
  Widget build(BuildContext context) {
    final row = entry;
    if (row == null) return const SizedBox.shrink();

    final isFirst = place == 1;
    return Column(
      children: [
        // Avatar and name sit above the block, exactly as the results screen
        // draws them; the block itself carries the place, prize and points.
        SizedBox(
          height: _podiumStackHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(
                _medal(place),
                size: 46,
                color: isFirst ? AppColors.primary : AppColors.icon,
              ),
              const SizedBox(height: 10),
              _Avatar(name: row.name, size: 92),
              const SizedBox(height: 10),
              Text(
                row.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: _type(
                  size: 32,
                  weight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          height: pedestalHeight,
          padding: const EdgeInsets.fromLTRB(12, 28, 12, 12),
          decoration: BoxDecoration(
            // 1st stands on the crimson brand fill. 2nd/3rd are a raised
            // surface with a hairline — never gold, silver or bronze (§B4.9).
            color: isFirst ? AppColors.primary : AppColors.card,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
            border: isFirst
                ? null
                : Border.all(color: AppColors.border, width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                _placeLabel(place),
                style: _type(
                  size: 26,
                  weight: FontWeight.w600,
                  letterSpacing: 3,
                  color: isFirst
                      ? AppColors.white.withValues(alpha: 0.85)
                      : AppColors.onSurfaceHint,
                ),
              ),
              if (row.prizeText != null) ...[
                const SizedBox(height: 14),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    row.prizeText!,
                    maxLines: 1,
                    style: _type(
                      size: 44,
                      weight: FontWeight.w700,
                      // "prize (white)" — §C9.
                      color: AppColors.white,
                    ),
                  ),
                ),
              ],
              if (row.seasonPointsText != null) ...[
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    row.seasonPointsText!,
                    maxLines: 1,
                    style: _type(
                      size: 24,
                      weight: FontWeight.w600,
                      color: isFirst
                          ? AppColors.white.withValues(alpha: 0.9)
                          : AppColors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _KnockoutBand extends StatelessWidget {
  const _KnockoutBand({required this.award});

  final ShareAward? award;

  @override
  Widget build(BuildContext context) {
    final row = award;
    if (row == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_fire_department,
            size: 48,
            color: AppColors.primaryText,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.label,
                  maxLines: 1,
                  style: _type(
                    size: 22,
                    weight: FontWeight.w600,
                    // §B3: small red text is `redText`, not the darker
                    // `primaryText` the eyebrow uses.
                    color: AppColors.redText,
                    height: 1.3,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    row.valueText,
                    maxLines: 1,
                    style: _type(
                      size: 32,
                      weight: FontWeight.w700,
                      color: AppColors.white,
                      height: 1.2,
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

/// The `AssetImage` behind [PokerNightLogo] — the app's own PNT lockup,
/// `assets/logo_<palette>.png`.
///
/// [PokerNightLogo] derives that path from `AppColors.currentPalette` inline
/// (`widgets/brand_lockup.dart`), so the two have to agree for [shareResults]'s
/// `precacheImage` to be warming the image the card actually draws. It is
/// duplicated rather than extracted because that widget is outside this
/// feature's files; the comment there is the contract.
AssetImage brandLockupImage() => AssetImage(
  'assets/logo_${AppColors.currentPalette.id.replaceAll('-', '_')}.png',
);

/// §C9's last line, "the PNT logo": the app's real lockup, sized to the card.
///
/// Deliberately [PokerNightLogo] and not a hand-drawn spade-and-wordmark — the
/// app has one logo, it is an asset, and a second mark invented for this one
/// screen would not be the PNT logo. [shareResults] precaches
/// [brandLockupImage] so the decode is finished before the capture reads the
/// layer.
class _LogoLockup extends StatelessWidget {
  const _LogoLockup();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.center,
      child: PokerNightLogo(size: _logoHeight),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.avatarColorFor(name),
        shape: BoxShape.circle,
        // The palette includes near-black variants; the ring keeps every
        // avatar legible against the card.
        border: Border.all(color: AppColors.borderStrong, width: 2),
      ),
      child: Text(
        initial,
        style: _type(
          size: size * 0.42,
          weight: FontWeight.w700,
          color: AppColors.white,
        ),
      ),
    );
  }
}

IconData _medal(int place) => switch (place) {
  1 => Icons.emoji_events,
  2 => Icons.military_tech,
  3 => Icons.workspace_premium,
  _ => Icons.emoji_events_outlined,
};

String _placeLabel(int place) => switch (place) {
  1 => '1ST',
  2 => '2ND',
  3 => '3RD',
  _ => '#$place',
};
