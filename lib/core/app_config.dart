/// Application level switches.
///
/// Everything that a product owner may want to flip without touching the
/// business logic lives here.
class AppConfig {
  AppConfig._();

  /// When a valid JWT is stored on the device the splash goes straight to the
  /// main navigation instead of asking for the phone number again.
  /// Set to `false` to always show the login screen after the splash.
  static const bool autoLoginWithSavedToken = true;

  /// Shows the VPN warning card on the splash screen when a tunnel / foreign
  /// IP is detected.
  static const bool showVpnWarning = true;

  /// When true the splash screen does not continue automatically while a VPN is
  /// detected; the user has to press "ادامه". When false the warning is shown
  /// and the app continues after [ApiConfig.vpnWarningAutoContinue].
  static const bool blockOnVpn = false;

  /// Enables the public IP country lookup used as a second VPN signal.
  /// Disable it to rely on the network interfaces only.
  static const bool enableVpnIpLookup = true;

  /// When the backend answers with an error (401 / 404 / 500) or with an empty
  /// page, the catalogue screens keep showing the bundled seed content so the
  /// app never looks broken — the production database is still being filled.
  ///
  /// Set to `false` to render the real backend state instead (empty lists and
  /// error placeholders).
  static const bool useSeedFallback = true;

  /// How long a resolved API response is cached in memory so navigating back
  /// and forth does not re-hit the network. `Duration.zero` disables it.
  static const Duration catalogueCacheTtl = Duration(minutes: 5);

  /// Relaxes TLS certificate validation **for the media host only**, so images
  /// from `media.dl.mceiran.website` can load.
  ///
  /// `media.dl.mceiran.website` serves a certificate whose SAN list contains
  /// only `alvand.irandns.com`, so the host is rejected with a hostname mismatch
  /// and **no server image loads at all**. The files themselves are fine.
  ///
  /// This is currently `true` because that is the only way to display server
  /// media until the certificate is fixed. It changes **no** UI — it only lets
  /// the existing `Image.network` calls succeed.
  ///
  /// Scope: `badCertificateCallback` accepts a mismatch **only** for
  /// `media.dl.mceiran.website`. The API host, the payment gateway and the VPN
  /// probe keep full certificate validation, so the JWT is never exposed.
  ///
  /// **Turn this back to `false` as soon as the server certificate covers
  /// `media.dl.mceiran.website`** (or media is served from a host the
  /// `*.mceiran.website` wildcard already covers). While it is `true`, someone
  /// able to intercept traffic to that one host could serve arbitrary images.
  /// Debug builds log every accepted certificate so it is not forgotten.
  static const bool allowInsecureMediaHost = true;
}
