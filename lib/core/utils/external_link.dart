import 'package:url_launcher/url_launcher.dart';

/// Opens the `link_value` that the banners API sends for a tappable banner.
///
/// The backend delivers the target as free text, so it is normalised here
/// before it ever reaches the OS:
///
/// * `https://yazdanmni.ir`   -> opened as is
/// * `yazdanmni.ir`           -> `https://` is added
/// * `tel:+98912...`, `mailto:` -> handed over to the dialer / mail app
/// * `12`, `my-course`, `''`  -> **not** a link, so nothing happens
///
/// The last case matters: `link_type` is sometimes `course` / `screen` with a
/// bare id in `link_value`. Those are in-app targets and must not be pushed to
/// the browser by mistake.
class ExternalLink {
  ExternalLink._();

  /// Turns a raw API value into a launchable [Uri], or `null` when the value is
  /// empty or is not a real external target.
  static Uri? parse(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) {
      final scheme = uri.scheme.toLowerCase();

      // A web link is only usable when it actually carries a host:
      // `Uri.parse('https:')` parses fine but opens nothing.
      if (scheme == 'http' || scheme == 'https') {
        return uri.host.isEmpty ? null : uri;
      }
      if (scheme == 'tel' || scheme == 'mailto') return uri;

      // Any other scheme (file:, intent:, javascript:, …) is refused.
      return null;
    }

    // Bare host such as `yazdanmni.ir` or `www.example.com/promo`.
    if (value.contains(' ') || value.startsWith('.') || !value.contains('.')) {
      return null;
    }

    final prefixed = Uri.tryParse('https://$value');
    if (prefixed == null || prefixed.host.isEmpty) return null;
    if (!prefixed.host.contains('.')) return null;

    return prefixed;
  }

  /// `true` when [raw] is something the device can open.
  static bool isOpenable(String? raw) => parse(raw) != null;

  /// Opens [raw] in the device browser — i.e. **outside** the app — and returns
  /// whether the OS accepted it.
  ///
  /// It never throws and never shows UI: a link the platform refuses to handle
  /// simply does nothing, so a bad value from the backend can not break the
  /// screen it was tapped on.
  static Future<bool> open(String? raw) async {
    final uri = parse(raw);
    if (uri == null) return false;

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
