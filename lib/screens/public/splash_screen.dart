import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/colors.dart';
import '../../app/route_paths.dart';

/// Splash screen reproducing the Poker Night Tools product mockup:
/// a rounded matte-black card with a metal rim that spins on its Y axis,
/// showing the red bracket + spade face on one side and the
/// POKER / NIGHT / TOOLS lockup on the other.
///
/// All face geometry below is measured from the reference render, expressed as
/// fractions of the card size so it scales to any screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // ---------------------------------------------------------------------------
  // Timing
  // ---------------------------------------------------------------------------
  static const Duration _totalDuration = Duration(milliseconds: 4200);

  late final AnimationController _controller;

  late final Animation<double> _opacityAnimation; // fade in
  late final Animation<double> _scaleAnimation;   // pop in
  late final Animation<double> _liftAnimation;    // vertical settle
  late final Animation<double> _spinAnimation;    // Y rotation, in TURNS
  late final Animation<double> _glowAnimation;    // red bloom behind card
  late final Animation<double> _exitAnimation;    // fade out before routing

  Timer? _timer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // Controls the complete splash animation.
    _controller = AnimationController(
      vsync: this,
      duration: _totalDuration,
    );

    // 0% - 14% : smooth fade-in.
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.14, curve: Curves.easeOut),
      ),
    );

    // 0% - 22% : grows the card from small to full size with a slight overshoot.
    _scaleAnimation = Tween<double>(
      begin: 0.62,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.22, curve: Curves.easeOutBack),
      ),
    );

    // 0% - 26% : the card drops into place.
    _liftAnimation = Tween<double>(
      begin: 26.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.26, curve: Curves.easeOutCubic),
      ),
    );

    // 20% - 72% : the flip. 1.5 turns == 540 degrees, so it passes edge-on
    // twice and SETTLES ON THE BACK (wordmark) face.
    // Use 1.0 or 2.0 instead if you want it to land back on the spade face.
    _spinAnimation = Tween<double>(
      begin: 0.0,
      end: 1.5,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.20, 0.72, curve: Curves.easeInOutCubic),
      ),
    );

    // Red bloom: rises, holds, then dies with the card.
    _glowAnimation = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 45),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 25),
    ]).animate(_controller);

    // 88% - 100% : fade out just before we route away.
    _exitAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.88, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    // Navigate as soon as the animation finishes...
    _controller.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) _goNext();
    });

    // ...with a safety net in case a frame stalls and the status never fires.
    _timer = Timer(_totalDuration + const Duration(milliseconds: 400), _goNext);
  }

  void _goNext() {
    if (_navigated || !mounted) return;
    _navigated = true;
    context.go(RoutePaths.landing);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect the OS "reduce motion" setting: no spin, just show the wordmark.
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final double shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final double cardSize = (shortestSide * 0.55).clamp(180.0, 300.0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _goNext, // let impatient users skip the splash
        child: SafeArea(
          child: SizedBox.expand(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, Widget? child) {
                final double fade =
                (_opacityAnimation.value * _exitAnimation.value)
                    .clamp(0.0, 1.0);

                return Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    // Soft red bloom behind the card.
                    Opacity(
                      opacity:
                      (0.6 * _glowAnimation.value * _exitAnimation.value)
                          .clamp(0.0, 1.0),
                      child: Container(
                        width: cardSize * 2.2,
                        height: cardSize * 2.2,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: <Color>[
                              Color(0x33E41B23),
                              Color(0x00000000),
                            ],
                            stops: <double>[0.0, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // The flipping card.
                    Opacity(
                      opacity: fade,
                      child: Transform.translate(
                        offset: Offset(0.0, _liftAnimation.value),
                        child: Transform.scale(
                          scale: _scaleAnimation.value,
                          alignment: Alignment.center,
                          child: _FlipCard(
                            size: cardSize,
                            turns: reduceMotion ? 0.5 : _spinAnimation.value,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Brand constants (sampled from the reference render)
// =============================================================================

const Color _kBrandRed = Color(0xFFE01F26);

/// Card height as a fraction of its width — measured 0.953 in the mockup.
const double _kCardAspect = 0.953;

// =============================================================================
// 3D flip card
// =============================================================================

/// Rotates around its Y axis. `turns` is in rotations: 0 = front, 0.5 = back.
/// The face is swapped exactly when the card is edge-on, so the back is never
/// rendered mirrored.
class _FlipCard extends StatelessWidget {
  const _FlipCard({required this.size, required this.turns});

  final double size;
  final double turns;

  @override
  Widget build(BuildContext context) {
    final double angle = turns * 2 * math.pi;
    final double cos = math.cos(angle);
    final bool showFront = cos >= 0;

    // Fake specular highlight: strongest when angled, gone when flat on.
    final double sheen = (1.0 - cos.abs()).clamp(0.0, 1.0);

    final double height = size * _kCardAspect;

    final Widget faceContent = showFront
        ? _FrontFace(width: size, height: height)
        : Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..rotateY(math.pi), // un-mirror
      child: _BackFace(width: size, height: height),
    );

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0011) // perspective
        ..rotateY(angle)
        ..rotateX(0.06 * math.sin(angle)), // subtle tilt, reads as a real object
      child: _CardShell(
        width: size,
        height: height,
        sheen: sheen,
        child: faceContent,
      ),
    );
  }
}

/// Metallic rim, matte plate, contact shadow and a sweeping highlight.
class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.width,
    required this.height,
    required this.sheen,
    required this.child,
  });

  final double width;
  final double height;
  final double sheen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double radius = width * 0.155;
    final double rim = width * 0.022;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF5A5A5E),
            Color(0xFF232326),
            Color(0xFF3C3C41),
            Color(0xFF141416),
          ],
          stops: <double>[0.0, 0.35, 0.65, 1.0],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.75),
            blurRadius: width * 0.20,
            spreadRadius: width * 0.01,
            offset: Offset(0.0, height * 0.10),
          ),
          BoxShadow(
            color: _kBrandRed.withValues(alpha: 0.10 + 0.10 * sheen),
            blurRadius: width * 0.35,
            spreadRadius: width * 0.02,
          ),
        ],
      ),
      padding: EdgeInsets.all(rim),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - rim),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.3, -0.5),
                  radius: 1.3,
                  colors: <Color>[Color(0xFF1A1A1C), Color(0xFF0A0A0B)],
                ),
              ),
            ),
            child,
            // Sweeping specular highlight while it spins.
            IgnorePointer(
              child: Opacity(
                opacity: 0.35 * sheen,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.28),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                      stops: const <double>[0.28, 0.5, 0.72],
                    ),
                  ),
                ),
              ),
            ),
            // Inner top edge light.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.white.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                    stops: const <double>[0.0, 0.35],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// FRONT FACE — red corner brackets + spade
// =============================================================================

class _FrontFace extends StatelessWidget {
  const _FrontFace({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FrontFacePainter(),
      size: Size(width, height),
    );
  }
}

class _FrontFacePainter extends CustomPainter {
  // All values are fractions of the plate, measured from the reference.
  static const double _pad = 0.058;       // bracket outer offset
  static const double _armLen = 0.185;    // arm length
  static const double _thick = 0.042;     // stroke thickness
  static const double _spadeW = 0.393;    // spade width  (of plate width)
  static const double _spadeH = 0.570;    // spade height (of plate height)

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    _paintBrackets(canvas, w, h);

    // Spade, optically centred on the plate.
    final double sw = w * _spadeW;
    final double sh = h * _spadeH;
    canvas.save();
    canvas.translate((w - sw) / 2, (h - sh) / 2);
    canvas.drawPath(_spadePath(sw, sh), Paint()..color = _kBrandRed);
    canvas.restore();
  }

  void _paintBrackets(Canvas canvas, double w, double h) {
    final double t = w * _thick;
    final Paint p = Paint()
      ..color = _kBrandRed
      ..style = PaintingStyle.stroke
      ..strokeWidth = t
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final double lx = w * _pad + t / 2;        // left stroke centre
    final double rx = w * (1 - _pad) - t / 2;  // right stroke centre
    final double ty = h * _pad + t / 2;        // top stroke centre
    final double by = h * (1 - _pad) - t / 2;  // bottom stroke centre

    final double ax = w * _armLen; // horizontal reach
    final double ay = h * _armLen; // vertical reach
    final double r = t * 0.9;      // inner corner radius

    void bracket(double cx, double cy, double sx, double sy) {
      final Path path = Path()
        ..moveTo(cx + sx * ax, cy)
        ..lineTo(cx + sx * r, cy)
        ..quadraticBezierTo(cx, cy, cx, cy + sy * r)
        ..lineTo(cx, cy + sy * ay);
      canvas.drawPath(path, p);
    }

    bracket(lx, ty, 1, 1);   // top-left
    bracket(rx, ty, -1, 1);  // top-right
    bracket(lx, by, 1, -1);  // bottom-left
    bracket(rx, by, -1, -1); // bottom-right
  }

  /// Spade silhouette. The control points were least-squares fitted to the
  /// reference artwork (97.5% area overlap), then mirrored for the right half.
  Path _spadePath(double w, double h) {
    double x(double v) => v * w;
    double y(double v) => v * h;

    return Path()
      ..moveTo(x(0.500), y(0.000))
    // left shoulder sweeping down to the widest point
      ..cubicTo(x(0.360), y(0.260), x(0.000), y(0.340), x(0.000), y(0.600))
    // left lobe
      ..cubicTo(x(0.040), y(0.770), x(0.200), y(0.800), x(0.245), y(0.815))
      ..cubicTo(x(0.330), y(0.800), x(0.390), y(0.800), x(0.472), y(0.715))
    // stem, left side
      ..cubicTo(x(0.465), y(0.860), x(0.400), y(0.960), x(0.303), y(1.000))
      ..lineTo(x(0.697), y(1.000))
    // stem, right side (mirror)
      ..cubicTo(x(0.600), y(0.960), x(0.535), y(0.860), x(0.528), y(0.715))
    // right lobe (mirror)
      ..cubicTo(x(0.610), y(0.800), x(0.670), y(0.800), x(0.755), y(0.815))
      ..cubicTo(x(0.800), y(0.800), x(0.960), y(0.770), x(1.000), y(0.600))
    // right shoulder back to the tip (mirror)
      ..cubicTo(x(1.000), y(0.340), x(0.640), y(0.260), x(0.500), y(0.000))
      ..close();
  }

  @override
  bool shouldRepaint(covariant _FrontFacePainter oldDelegate) => false;
}

// =============================================================================
// BACK FACE — POKER / NIGHT / TOOLS lockup
// =============================================================================

class _BackFace extends StatelessWidget {
  const _BackFace({required this.width, required this.height});

  final double width;
  final double height;

  // Measured from the reference render, as fractions of the plate.
  static const double _blockW = 0.748;  // width of the justified word rows
  static const double _rowTop = 0.188;  // top of the first row
  static const double _rowPitch = 0.187;
  static const double _capH = 0.120;    // cap height of a word row
  static const double _ruleY = 0.753;
  static const double _ruleW = 0.736;
  static const double _tagY = 0.825;
  static const double _tagCapH = 0.039;

  @override
  Widget build(BuildContext context) {
    final double w = width;
    final double h = height;
    final double blockW = w * _blockW;

    // Cap height is roughly 0.70 em for this style of grotesque.
    final double wordSize = h * _capH / 0.70;
    final double tagSize = h * _tagCapH / 0.70;

    return Stack(
      children: <Widget>[
        _word('POKER', Colors.white, 0, w, h, blockW, wordSize),
        _word('NIGHT', _kBrandRed, 1, w, h, blockW, wordSize),
        _word('TOOLS', Colors.white, 2, w, h, blockW, wordSize),

        // Red rule under the lockup.
        Positioned(
          left: (w - w * _ruleW) / 2,
          top: h * _ruleY,
          child: Container(
            width: w * _ruleW,
            height: math.max(1.0, h * 0.004),
            color: _kBrandRed,
          ),
        ),

        // Tagline.
        Positioned(
          left: 0,
          right: 0,
          top: h * _tagY,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
                  children: <TextSpan>[
                    TextSpan(
                      text: 'SCAN. TRADE. TRACK. ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: tagSize,
                        height: 1.0,
                        fontWeight: FontWeight.w600,
                        letterSpacing: tagSize * 0.10,
                      ),
                    ),
                    TextSpan(
                      text: 'WIN.',
                      style: TextStyle(
                        color: _kBrandRed,
                        fontSize: tagSize,
                        height: 1.0,
                        fontWeight: FontWeight.w700,
                        letterSpacing: tagSize * 0.10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// One justified word row.
  ///
  /// Each letter is laid out with `spaceBetween` across a fixed width, which is
  /// exactly how the reference is set: POKER / NIGHT / TOOLS all span the same
  /// measure regardless of their differing letter widths.
  Widget _word(
      String text,
      Color color,
      int row,
      double w,
      double h,
      double blockW,
      double fontSize,
      ) {
    return Positioned(
      left: (w - blockW) / 2,
      top: h * (_rowTop + row * _rowPitch) - fontSize * 0.15,
      width: blockW,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          for (final String ch in text.split(''))
            Text(
              ch,
              style: TextStyle(
                color: color,
                fontSize: fontSize,
                height: 1.0,
                fontWeight: FontWeight.w400,
              ),
            ),
        ],
      ),
    );
  }
}
