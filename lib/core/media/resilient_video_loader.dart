import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// One rung of the ladder: a display mode, the player options to create it with,
/// and what the rung is for.
@immutable
class _Rung {
  const _Rung(this.viewType, this.options, this.why);

  final VideoViewType viewType;

  /// `null` means **pass no options at all**, which is not the same as
  /// `VideoPlayerOptions()`: `initialize()` only calls `setMixWithOthers` when it
  /// was given an options object, so `null` leaves the platform's audio mode
  /// untouched — the behaviour the app already had.
  final VideoPlayerOptions? options;

  /// What this rung recovers from, quoted in the log.
  final String why;
}

/// Builds a video player that has a real chance on a **weak device**.
///
/// `VideoPlayerController.networkUrl(...).initialize()` gives up on the first
/// exception. On low-end Android hardware the first attempt fails for reasons
/// that *different display modes* fix, so this walks a short ladder instead:
///
/// | # | display | options | what it recovers from |
/// |---|---|---|---|
/// | 1 | `textureView` | — | nothing: this is the behaviour the app already had |
/// | 2 | `platformView` | `mixWithOthers` | a GPU texture the size of the video not being allocatable |
///
/// Rung 2 is the one that matters on cheap hardware. `textureView` renders the
/// video into a Flutter-managed GPU texture, which needs graphics memory
/// proportional to the video's size; a `platformView` is an Android
/// `SurfaceView` drawn by the compositor, which needs none. A device that cannot
/// allocate the texture reports it as a player error rather than as an
/// out-of-memory one.
///
/// ## ⚠️ Why there is no rung that differs only by `mixWithOthers`
///
/// It is tempting to add a `textureView` + `mixWithOthers` rung between these
/// two, but on Android that option cannot change whether a player is *created*.
/// `VideoPlayer.java` only feeds it to `setAudioAttributes(exoPlayer, isMixMode)`
/// as `handleAudioFocus = !isMixMode`, and even that happens **after**
/// `prepare()`. So a rung that differs from its predecessor by nothing but this
/// flag is guaranteed to fail in exactly the same way — it would buy nothing and
/// would put another create attempt plus the inter-rung delay in front of the
/// rung that does work. On a device that genuinely cannot decode the file, it
/// would also lengthen the wait before the error is shown.
///
/// The flag is still worth passing on rung 2, where it is free: it relaxes the
/// audio-focus handshake, which on some cheap ROMs is what leaves an
/// *initialized* player sitting paused instead of playing. That failure never
/// reaches this ladder — `initialize()` has already returned by then — so the
/// fallback rung is the only place it can be pre-empted, and the devices that
/// reach rung 2 are exactly the ones at risk of it. Rung 1 deliberately keeps
/// the app's existing audio behaviour so the normal case is untouched.
///
/// ## ⚠️ A controller that failed to initialize may never finish disposing
///
/// `VideoPlayerController.dispose()` awaits an internal completer that is only
/// completed **after** the platform has created a player. When creation itself is
/// what threw, nothing ever completes it and `dispose()` waits forever — so a
/// failed attempt is discarded under a timeout rather than awaited.
class ResilientVideoLoader {
  ResilientVideoLoader._();

  /// Not `const`: `VideoPlayerOptions` has no const constructor.
  static final List<_Rung> _ladder = <_Rung>[
    const _Rung(VideoViewType.textureView, null, 'default'),
    _Rung(
      VideoViewType.platformView,
      VideoPlayerOptions(mixWithOthers: true),
      'surface',
    ),
  ];

  /// Between rungs, so a failed attempt's decoder has a moment to be released
  /// and a momentary network stall has a chance to clear.
  static const Duration _betweenRungs = Duration(milliseconds: 300);

  /// How long a discarded controller is given before it is abandoned.
  static const Duration _disposeTimeout = Duration(seconds: 2);

  /// Initializes a player for [url], walking the ladder until one works.
  ///
  /// Returns an **initialized** controller — the caller only has to set looping
  /// and play. Throws the last error if every rung fails, so the caller can show
  /// its own error state.
  ///
  /// [onFailure] is called for each failed rung. This is the only place the real
  /// reason a video would not play is visible: the screens used to swallow it
  /// with `catch (_)`, which is why a failure could not be diagnosed.
  static Future<VideoPlayerController> initialize(
    String url, {
    void Function(Object error, StackTrace stackTrace)? onFailure,
  }) async {
    Object? lastError;
    StackTrace? lastStackTrace;

    for (int index = 0; index < _ladder.length; index++) {
      final _Rung rung = _ladder[index];

      final VideoPlayerController controller =
          VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: rung.options,
        viewType: rung.viewType,
      );

      try {
        await controller.initialize();
        debugPrint('[VIDEO] initialized on rung $index (${rung.why})');
        return controller;
      } catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        debugPrint('[VIDEO] rung $index (${rung.why}) failed: $error');
        onFailure?.call(error, stackTrace);

        // **Not awaited.** Letting go of a failed controller can take the whole
        // dispose timeout, and the next rung must not queue behind it — that
        // would put seconds of black screen in front of the attempt that
        // actually works on this device.
        unawaited(_discard(controller));

        if (index < _ladder.length - 1) {
          await Future<void>.delayed(_betweenRungs);
        }
      }
    }

    if (lastError != null) {
      Error.throwWithStackTrace(
        lastError,
        lastStackTrace ?? StackTrace.current,
      );
    }

    throw StateError('video could not be initialized: $url');
  }

  /// Lets go of a controller that never became usable.
  static Future<void> _discard(VideoPlayerController controller) async {
    try {
      await controller.dispose().timeout(_disposeTimeout);
    } catch (_) {
      // See the class doc — abandoning it is better than hanging the screen.
    }
  }

  /// How many rungs the ladder has, for tests.
  @visibleForTesting
  static int get rungCount => _ladder.length;
}
