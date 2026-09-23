import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import 'app_alert_banner.dart';

/// Global connectivity strip: "you are offline" / "you are back".
///
/// Mounted once in `ScreenShell`, so it covers every signed-in route rather
/// than the two screens that had each hand-rolled their own copy. That matters
/// most on the screens that were missing it: a host editing a structure or
/// settling rebuys while the connection is down otherwise gets no hint that
/// what they are looking at is stale.
///
/// Renders nothing — not even padding — while the connection is healthy and
/// unacknowledged, so it costs mounted screens no layout.
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final offline = context.select<AppProvider, bool>((a) => a.isOffline);
    final reconnected = context.select<AppProvider, bool>(
      (a) => a.hasReconnected,
    );

    if (!offline && !reconnected) return const SizedBox.shrink();

    return Padding(
      padding: padding,
      child: Semantics(
        liveRegion: true,
        child: offline
            ? const AppAlertBanner(
                type: AppAlertType.warning,
                message: 'Connection interrupted — showing last known state.',
                onDismiss: null,
              )
            : AppAlertBanner(
                type: AppAlertType.success,
                message: 'Back online — data is live.',
                actionLabel: 'Dismiss',
                onAction: () =>
                    context.read<AppProvider>().clearReconnectedBanner(),
              ),
      ),
    );
  }
}
