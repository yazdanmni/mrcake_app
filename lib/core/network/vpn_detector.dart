import 'dart:io';

import 'package:dio/dio.dart';

import 'api_config.dart';

/// Result of a VPN / proxy inspection.
class VpnStatus {
  const VpnStatus({
    required this.isDetected,
    this.reason,
    this.interfaceName,
    this.countryCode,
  });

  static const VpnStatus none = VpnStatus(isDetected: false);

  final bool isDetected;

  /// Persian explanation shown on the splash screen.
  final String? reason;

  /// The network interface that gave the VPN away (e.g. `tun0`).
  final String? interfaceName;

  /// ISO country code of the public IP when the lookup succeeded.
  final String? countryCode;

  /// Message rendered inside the splash warning card.
  String get message {
    if (!isDetected) return '';
    final country = countryCode;
    if (country != null && country.isNotEmpty && country != 'IR') {
      return 'VPN یا پروکسی شما روشن است (IP شما در کشور $country ثبت شده است). '
          'برای استفاده از مستر کیک لطفاً آن را خاموش کنید.';
    }
    return 'VPN یا پروکسی شما روشن است. '
        'برای دریافت درست اطلاعات، لطفاً آن را خاموش کنید.';
  }
}

/// Detects an active VPN / proxy without adding any native plugin.
///
/// Two independent signals are combined:
///
///  1. **Network interfaces** – every VPN tunnel appears as a virtual
///     interface (`tun0`, `ppp0`, `utun4`, `ipsec0`, `wg0`, ...).
///  2. **Public IP country** – a best effort lookup. When the public IP is not
///     Iranian the traffic is routed through a foreign server, which is exactly
///     what a VPN does. The lookup is optional: if the service is unreachable
///     (which is common on restricted networks) we simply skip this signal.
class VpnDetector {
  VpnDetector._();

  /// Interface prefixes that only exist when a tunnel is up.
  static const List<String> _tunnelPrefixes = <String>[
    'tun',
    'tap',
    'ppp',
    'ipsec',
    'wg',
    'zt',
  ];

  /// iOS always exposes `utun0..utun3` for iCloud / WiFi-Calling, they are not
  /// a VPN. Anything above that range is treated as a tunnel.
  static const int _iosSystemUtunMax = 3;

  /// Best effort public IP lookup. Disable it to rely on interfaces only.
  static bool enableIpLookup = true;

  static const String _ipLookupUrl = 'https://ipwho.is/';
  static const Duration _ipLookupTimeout = Duration(seconds: 4);

  /// A dedicated client for the IP lookup.
  ///
  /// It is intentionally NOT the shared [ApiClient]: that one attaches the
  /// user's `Authorization` header, which must never be sent to a third party.
  static Dio? _lookupClient;

  static Dio get _lookupDio =>
      _lookupClient ??= Dio(
        BaseOptions(
          connectTimeout: _ipLookupTimeout,
          receiveTimeout: _ipLookupTimeout,
          sendTimeout: _ipLookupTimeout,
          headers: const {'Accept': 'application/json'},
          responseType: ResponseType.json,
        ),
      );

  static Future<VpnStatus> detect() async {
    final interfaceName = await _detectByInterface();
    final country = enableIpLookup ? await _detectCountry() : null;

    final foreignIp = country != null && country.isNotEmpty && country != 'IR';
    if (foreignIp || interfaceName != null) {
      return VpnStatus(
        isDetected: true,
        interfaceName: interfaceName,
        countryCode: country,
      );
    }
    return VpnStatus.none;
  }

  /// Returns the name of the first tunnel interface, or null.
  static Future<String?> _detectByInterface() async {
    try {
      final list = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );

      final isIos = Platform.isIOS;

      for (final adapter in list) {
        final name = adapter.name.toLowerCase();

        if (isIos && name.startsWith('utun')) {
          final index = int.tryParse(name.substring(4));
          if (index != null && index <= _iosSystemUtunMax) continue;
          return adapter.name;
        }

        for (final prefix in _tunnelPrefixes) {
          if (name.startsWith(prefix)) return adapter.name;
        }
      }
    } catch (_) {
      // Some platforms restrict interface listing; ignore and fall back.
    }
    return null;
  }

  /// Returns the ISO country code of the public IP, or null when unknown.
  static Future<String?> _detectCountry() async {
    try {
      final response = await _lookupDio
          .get<dynamic>(_ipLookupUrl)
          .timeout(_ipLookupTimeout);

      final data = response.data;
      if (data is Map) {
        final code =
            data['country_code'] ?? data['countryCode'] ?? data['country'];
        if (code is String && code.trim().isNotEmpty) {
          return code.trim().toUpperCase();
        }
      }
    } catch (_) {
      // Offline, blocked or rate limited: not fatal, we just skip the signal.
    }
    return null;
  }

  static bool get isLookupEnabled => enableIpLookup;

  static String get lookupUrl => _ipLookupUrl;

  static String get baseUrl => ApiConfig.baseUrl;
}
