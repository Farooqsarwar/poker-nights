import 'package:flutter/material.dart';

import '../models/game.dart';
import 'app_badge.dart';

/// RSVP badge mirroring the web `RSVPBadge` component.
class RSVPBadge extends StatelessWidget {
  const RSVPBadge({super.key, required this.rsvp});

  final Rsvp? rsvp;

  @override
  Widget build(BuildContext context) {
    if (rsvp == null) return const AppBadge(label: 'No response', variant: AppBadgeVariant.muted);
    if (rsvp!.guestCount > 0) {
      return AppBadge(label: 'Going +${rsvp!.guestCount}', variant: AppBadgeVariant.green);
    }
    switch (rsvp!) {
      case Rsvp.going:
        return const AppBadge(label: 'Going', variant: AppBadgeVariant.green);
      case Rsvp.maybe:
        return const AppBadge(label: 'Maybe', variant: AppBadgeVariant.accent);
      case Rsvp.cant:
        return const AppBadge(label: "Can't Come", variant: AppBadgeVariant.red);
      case Rsvp.goingPlus1:
      case Rsvp.goingPlus2:
      case Rsvp.goingPlus3:
        return AppBadge(label: rsvp!.label, variant: AppBadgeVariant.green);
    }
  }
}
