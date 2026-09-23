import 'dart:io';

import 'api_config.dart';

/// Relaxes TLS validation **for the media host and nothing else**.
///
/// ## Why this exists
///
/// `media.dl.mceiran.website` serves a certificate that does not cover its own
/// hostname:
///
/// ```
/// $ openssl s_client -connect media.dl.mceiran.website:443 \
///       -servername media.dl.mceiran.website | openssl x509 -noout -subject -ext subjectAltName
///   subject=CN=alvand.irandns.com
///   X509v3 Subject Alternative Name:
///       DNS:alvand.irandns.com
/// ```
///
/// `media.dl.mceiran.website` is not in the SAN list, so every HTTPS client —
/// `Image.network`, a browser, `curl` — rejects it with a hostname mismatch.
/// The files themselves are served correctly (a valid 24 KB PNG arrives over the
/// wire once verification is skipped).
///
/// Compare the API host, which is configured correctly:
///
/// ```
///   subject=CN=*.mceiran.website
///   SAN: DNS:*.mceiran.website, DNS:mceiran.website, DNS:www.api.mceiran.website
/// ```
///
/// ## The correct fix
///
/// Server-side, not here: issue a certificate whose SAN list includes
/// `media.dl.mceiran.website` (or serve media from a host the existing wildcard
/// covers). Nothing in the Flutter app can substitute for that.
///
/// ## Why this class is narrow
///
/// [badCertificateCallback] returns true **only** when the host matches
/// [ApiConfig.mediaBaseUrl]'s host. Every other request — the API, the payment
/// gateway, the VPN probe — keeps full certificate validation. A blanket
/// `(_) => true` would expose the JWT and the user's traffic to interception.
///
/// Enabled by `AppConfig.allowInsecureMediaHost`, which defaults to `false`.
class MediaHostHttpOverrides extends HttpOverrides {
  /// The one host allowed to present a mismatched certificate.
  static final String allowedHost = Uri.parse(ApiConfig.mediaBaseUrl).host;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);

    client.badCertificateCallback = (X509Certificate cert, String host, int port) {
      final allowed = host == allowedHost;
      if (allowed) {
        debugLogRejectedCertificate(cert, host);
      }
      return allowed;
    };

    return client;
  }

  /// Prints what was accepted, so the workaround cannot be forgotten silently.
  static void debugLogRejectedCertificate(X509Certificate cert, String host) {
    assert(() {
      // ignore: avoid_print
      print(
        '[MEDIA-TLS] accepting a mismatched certificate for $host '
        '(cert CN="${cert.subject}", issuer="${cert.issuer}"). '
        'This is the temporary workaround in MediaHostHttpOverrides — '
        'fix the server certificate and set '
        'AppConfig.allowInsecureMediaHost = false.',
      );
      return true;
    }());
  }
}
