// Custom bootstrap so CanvasKit is loaded from THIS origin instead of
// www.gstatic.com.
//
// Flutter's stock bootstrap points `canvasKitBaseUrl` at a Google CDN even
// though `flutter build web` already writes the very same files into
// build/web/canvaskit/. That makes first paint depend on a third-party
// request: the engine cannot start until ~1.5MB of WASM arrives, and if the
// request is slow or blocked — mobile content blockers, carrier proxies,
// regional filtering — it never arrives, the engine never initialises, and
// the page stays blank forever with nothing logged. A white screen on iOS
// Safari is the usual way this shows up.
//
// Serving the bundled copy removes the dependency entirely: same bytes, same
// origin, covered by the hosting cache headers we already set, and it fails
// the same way the rest of the app fails rather than silently.
//
// The URL is relative so it continues to resolve correctly under whatever
// <base href> index.html is built with.

{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
});
