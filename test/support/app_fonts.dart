import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads the app's real Persian fonts into the test font collection.
///
/// `flutter test` does **not** load the fonts declared in `pubspec.yaml`, so
/// every Persian glyph is otherwise drawn as a square of `fontSize`. That makes
/// text measurably wider and taller than it is on a device, which turns real
/// production widgets into false `RenderFlex overflowed` reports — precisely the
/// failure a responsive-layout test is trying to detect.
///
/// Swallowing those errors (the usual workaround) is worse than it looks: it also
/// swallows the genuine overflow, and since `tester.takeException()` only sees
/// what `FlutterError.onError` forwarded, the assertion that was supposed to catch
/// the bug silently passes. Loading the real fonts removes the noise at its
/// source, so `expect(tester.takeException(), isNull)` means what it says.
///
/// The family names have to match `TextStyle.fontFamily` **exactly** — the app
/// spells them inconsistently (`Shabnam` / `shabnam`, `BShabnam` / `bShabnam`),
/// and a name with no registered font silently falls back to the squares.
Future<void> loadAppFonts() async {
  if (_loaded) return;
  _loaded = true;

  const Map<String, String> families = <String, String>{
    'shabnam': 'assets/fonts/shabnam.ttf',
    'Shabnam': 'assets/fonts/shabnam.ttf',
    'bshabnam': 'assets/fonts/bshabnam.ttf',
    'bShabnam': 'assets/fonts/bshabnam.ttf',
    'BShabnam': 'assets/fonts/bshabnam.ttf',
    'lshabnam': 'assets/fonts/lshabnam.ttf',
    'pinarb': 'assets/fonts/pbold.ttf',
    'PinarB': 'assets/fonts/pbold.ttf',
    'Pinar': 'assets/fonts/pbold.ttf',
    'pinarr': 'assets/fonts/pregular.ttf',
  };

  for (final MapEntry<String, String> entry in families.entries) {
    final FontLoader loader = FontLoader(entry.key)
      ..addFont(rootBundle.load(entry.value));
    await loader.load();
  }
}

bool _loaded = false;

/// Errors that a widget test cannot avoid and that have nothing to do with the
/// layout under test: network images cannot load without a server.
///
/// Deliberately does **not** filter `overflowed by` — an overflow must still
/// fail the test. Use [loadAppFonts] to remove the font-induced ones.
void ignoreNetworkImageErrors() {
  final void Function(FlutterErrorDetails)? original = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exception is NetworkImageLoadException) return;
    final String text = '${details.exception}';
    if (text.contains('HTTP request failed')) return;
    if (text.contains('No host specified')) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}
