import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'api_config.dart';
import 'api_exception.dart';

/// Rough classification of the user's connection, derived from the round trip
/// time of a real request to the backend.
enum ConnectionQuality {
  fast,
  normal,
  slow,
  offline;

  static ConnectionQuality fromLatency(Duration latency) {
    final ms = latency.inMilliseconds;
    if (ms <= 700) return ConnectionQuality.fast;
    if (ms <= 2200) return ConnectionQuality.normal;
    return ConnectionQuality.slow;
  }

  String get label {
    switch (this) {
      case ConnectionQuality.fast:
        return 'اتصال سریع';
      case ConnectionQuality.normal:
        return 'در حال دریافت اطلاعات...';
      case ConnectionQuality.slow:
        return 'اینترنت شما کند است، کمی صبر کنید...';
      case ConnectionQuality.offline:
        return 'اتصال به اینترنت برقرار نیست';
    }
  }
}

/// Outcome of the splash warm-up request.
class ProbeResult {
  const ProbeResult({
    required this.reachable,
    required this.latency,
    required this.quality,
    this.error,
  });

  final bool reachable;
  final Duration latency;
  final ConnectionQuality quality;
  final ApiException? error;

  static const ProbeResult offline = ProbeResult(
    reachable: false,
    latency: Duration.zero,
    quality: ConnectionQuality.offline,
  );
}

/// Pings the backend once so the splash screen duration follows the real
/// network speed instead of a hard coded delay.
///
/// The request also warms up DNS + TLS, so the first screen after the splash
/// opens noticeably faster.
class NetworkProbe {
  NetworkProbe._();

  static Future<ProbeResult> warmUp({ApiClient? client}) async {
    final api = client ?? ApiClient.instance;
    final stopwatch = Stopwatch()..start();

    try {
      await api.get<dynamic>(
        ApiEndpoints.bannersHeroActive,
        timeout: ApiConfig.probeTimeout,
      );
      stopwatch.stop();
      final latency = stopwatch.elapsed;
      return ProbeResult(
        reachable: true,
        latency: latency,
        quality: ConnectionQuality.fromLatency(latency),
      );
    } on ApiException catch (error) {
      stopwatch.stop();
      debugPrint('[Probe] failed: $error');
      return ProbeResult(
        reachable: false,
        latency: stopwatch.elapsed,
        quality: ConnectionQuality.offline,
        error: error,
      );
    } catch (error) {
      stopwatch.stop();
      debugPrint('[Probe] unexpected: $error');
      return ProbeResult(
        reachable: false,
        latency: stopwatch.elapsed,
        quality: ConnectionQuality.offline,
        error: ApiException(
          message: 'اتصال به سرور برقرار نشد. لطفاً دوباره تلاش کنید.',
          type: ApiErrorType.network,
        ),
      );
    }
  }
}
