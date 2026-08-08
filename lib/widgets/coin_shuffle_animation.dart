import 'dart:math';
import 'package:flutter/material.dart';

class CoinShuffleAnimation extends StatefulWidget {
  const CoinShuffleAnimation({super.key});

  @override
  State<CoinShuffleAnimation> createState() => _CoinShuffleAnimationState();
}

class _CoinShuffleAnimationState extends State<CoinShuffleAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // The colors for our 6 chips
  final List<Color> _chipColors = [
    Colors.blue[600]!,   // Chip 0 (Left)
    Colors.yellow[700]!, // Chip 1 (Right)
    Colors.red[600]!,    // Chip 2 (Left)
    Colors.white,        // Chip 3 (Right)
    Colors.blue[600]!,   // Chip 4 (Left)
    Colors.red[600]!,    // Chip 5 (Right)
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000), 
    );
    
    // Auto-trigger on init
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerAnimation() {
    if (_controller.isCompleted) {
      _controller.reset();
      _controller.forward();
    } else {
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _triggerAnimation,
      child: FittedBox(
        fit: BoxFit.contain,
        child: Container(
          height: 250,
          width: 350,
        color: Colors.transparent, // Tap area
        child: Center(
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: List.generate(_chipColors.length, (index) {
              
              // Evens come from left, Odds come from right
              bool isFromLeft = index % 2 == 0;
              
              // Calculate start and end for stagger effect (0.0 to 1.0 range)
              // We have 6 chips, so they start every 0.08 interval
              double start = index * 0.08;
              double end = start + 0.6; // Each chip takes 60% of the total animation time
              
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  // Get localized animation value between 0.0 and 1.0 for this specific chip
                  double t = ((_controller.value - start) / (end - start)).clamp(0.0, 1.0);
                  
                  // Add a satisfying snap/bounce when they land
                  double curveT = Curves.easeOutBack.transform(t);
                  
                  // Arc curve for Y (goes 0 -> 1 -> 0 to simulate tossing up in the air)
                  double arcT = Curves.easeInOutSine.transform(
                    t < 0.5 ? t * 2 : (2.0 - (t * 2)).clamp(0.0, 1.0)
                  );

                  // X movement: start far off-screen, end at 0
                  double startX = isFromLeft ? -250.0 : 250.0;
                  double currentX = startX * (1 - curveT);

                  // Y movement: Toss arc + final stacked position
                  // Stacked position goes slightly up per chip (overlap)
                  double finalY = -(index * 7.0);
                  // Subtract arcT * 120.0 to make them toss upwards in a nice parabola
                  double currentY = finalY * curveT - (arcT * 120.0);

                  // Rotation: Tumble in the air while flying
                  // Left chips tumble one way, Right chips tumble the other
                  double startRotation = isFromLeft ? -pi * 1.5 : pi * 1.5;
                  double rotation = startRotation * (1 - curveT);

                  // Scale and opacity effects for a premium entrance
                  double scale = t < 0.2 ? Curves.easeOut.transform(t * 5) : 1.0;
                  double opacity = t < 0.1 ? t * 10 : 1.0;

                  return Transform.translate(
                    offset: Offset(currentX, currentY),
                    child: Transform.rotate(
                      angle: rotation,
                      child: Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: opacity,
                          child: child,
                        ),
                      ),
                    ),
                  );
                },
                child: _buildSingleChip(_chipColors[index]),
              );
            }),
          ),
        ),
      ),
      ));
  }

  /// Builds a single 2D chip
  Widget _buildSingleChip(Color color) {
    return Container(
      width: 50,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black54, width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            offset: Offset(0, 4), // slightly deeper shadow for floating feel
            blurRadius: 4,
          ),
        ],
      ),
      // Adding standard white/black casino stripes
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(4, (index) {
          return Container(
            width: 4,
            height: 8,
            color: color == Colors.white ? Colors.black : Colors.white,
          );
        }),
      ),
    );
  }
}
