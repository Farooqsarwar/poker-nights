import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app/colors.dart';
import '../app/typography.dart';
import 'chip_token.dart';

class ChipLoadingAnimation extends StatelessWidget {
  const ChipLoadingAnimation({
    super.key,
    this.message = 'Generating structure...',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 120,
          height: 60,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Left stack moving right
              Positioned(
                left: 10,
                child:
                    const ChipToken(
                          colorName: 'Red',
                          hex: Color(0xFFE50914),
                          value: 25,
                        )
                        .animate(
                          onPlay: (controller) =>
                              controller.repeat(reverse: true),
                        )
                        .slideX(
                          end: 1.5,
                          duration: 600.ms,
                          curve: Curves.easeInOutSine,
                        ),
              ),
              // Right stack moving left
              Positioned(
                right: 10,
                child:
                    const ChipToken(
                          colorName: 'Black',
                          hex: Color(0xFF2C2C2C),
                          value: 100,
                        )
                        .animate(
                          onPlay: (controller) =>
                              controller.repeat(reverse: true),
                        )
                        .slideX(
                          end: -1.5,
                          duration: 600.ms,
                          curve: Curves.easeInOutSine,
                        ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
              message,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.primaryForeground,
                fontWeight: FontWeight.w600,
              ),
            )
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .fade(begin: 0.5, end: 1.0, duration: 800.ms),
      ],
    );
  }
}
