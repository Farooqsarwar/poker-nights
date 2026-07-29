import 'package:flutter/material.dart';

class PNSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final double fontSize;
  final String? actionLabel;
  final VoidCallback? onAction;

  const PNSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.fontSize = 18,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ?trailing,
        ],
      ),
    );
  }
}
