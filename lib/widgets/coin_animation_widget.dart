import 'dart:ui';

import 'package:flutter/material.dart';

class CoinAnimationWidget extends StatefulWidget {
  const CoinAnimationWidget({
    super.key,
    this.chipAsset,
    this.onAnimationComplete,
    this.autoStart = true,
    this.loop = false,
  });

  final Widget? chipAsset;

  final VoidCallback? onAnimationComplete;

  final bool autoStart;

  final bool loop;

  @override
  State<CoinAnimationWidget> createState() => _CoinAnimationWidgetState();
}

class _CoinAnimationWidgetState extends State<CoinAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _translateY;
  late Animation<double> _blurY;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _translateY = Tween<double>(
      begin: 0.0,
      end: -100.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInCubic));

    _blurY = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 18.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 18.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 60,
      ),
    ]).animate(_controller);

    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !widget.loop) {
        widget.onAnimationComplete?.call();
      }
    });

    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) startAnimation();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void startAnimation() {
    if (_controller.isAnimating) return;
    if (widget.loop) {
      _controller.repeat();
    } else if (_controller.isCompleted) {
      _controller.reset();
      _controller.forward();
    } else {
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: startAnimation,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _translateY.value),
            child: Opacity(
              opacity: _opacity.value,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 0, sigmaY: _blurY.value),
                child: child,
              ),
            ),
          );
        },
        child: widget.chipAsset ?? _buildDefaultChipStack(),
      ),
    );
  }

  Widget _buildDefaultChipStack() {
    final colors = [
      Colors.blue[600]!,
      Colors.yellow[700]!,
      Colors.red[600]!,
      Colors.white,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(6, (index) {
        return Container(
          width: 50,
          height: 8,
          margin: const EdgeInsets.only(bottom: 1),
          decoration: BoxDecoration(
            color: colors[index % colors.length],
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black38, width: 0.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                offset: Offset(0, 1),
                blurRadius: 1,
              ),
            ],
          ),
        );
      }),
    );
  }
}
