import 'package:url_launcher/url_launcher.dart';

const String _productionOrigin = 'https://poker-night-tools.web.app';

/// The public, read-only address a host can open on a separate display.
Uri tvDisplayUri(String code, {Uri? base}) {
  final candidate = base ?? Uri.base;
  // DECISION: a web host keeps its current origin (including local preview),
  // while native/file contexts use the published public-view origin.
  final origin = candidate.scheme == 'http' || candidate.scheme == 'https'
      ? candidate.origin
      : _productionOrigin;
  return Uri.parse('$origin/tv/${Uri.encodeComponent(code.trim())}');
}

/// Opens Cast away from the host dashboard. Web uses a new tab; native uses
/// the platform browser, so the control surface remains available.
Future<bool> openTvDisplay(String code) => launchUrl(
      tvDisplayUri(code),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
