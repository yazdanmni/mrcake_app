import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
// `FcVideoThumbnailTime` lives in the package's platform-interface library and is
// **not** re-exported by the entry point above, so it has to be imported here.
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:path/path.dart' as p;

/// Grabs a still frame out of a **remote** video so a video work can show a real
/// thumbnail on its card instead of a grey placeholder.
///
/// ## Why this exists
///
/// The backend sends **no poster frame** for a video:
///
/// * on `accounts/teacher-portfolios/` a video row is
///   `image: null, video: "<url>"` — the two fields are mutually exclusive;
/// * the `Media` model has `width`, `bitrate`, `video_codec`… and **no**
///   `thumbnail` field at all.
///
/// So a video card has nothing to paint. This class gets a frame from the file
/// itself.
///
/// ## How
///
/// Two-tier extraction, because the native plugin behaves differently across
/// platforms:
///
/// ### Tier 1 — remote Uri (Android / iOS / macOS)
/// The platform's own thumbnailer does the work — `MediaMetadataRetriever` on
/// Android, `AVAssetImageGenerator` on iOS — reached through
/// `fc_native_video_thumbnail`. Nothing is bundled and no video is downloaded in
/// full: on Android the source is handed over as a **Uri** (`srcFileUri: true`),
/// which is both what makes a remote `https` url work and what enables seeking.
///
/// ### Tier 2 — local temp file (Windows / Linux / mobile fallback)
/// `srcFileUri` is **not** supported on Windows and Linux: the native code
/// treats the path as a local file name and fails for `https://...`. On those
/// platforms the service downloads the video into the system temp directory,
/// asks the thumbnailer to read the *local* copy, then deletes it. The temp
/// file carries a `.mp4` suffix (the thumbnailer sniffs the real container, but
/// MediaFoundation on Windows is happier with a "video-like" extension).
///
/// Tier 2 is also used as a fallback on the mobile tier when tier 1 returns an
/// empty result — some CDNs send an incompatible flavour of MP4 that the
/// platform thumbnailer cannot seek over `http`, but can read once it is on
/// disk.
///
/// ## Failure is normal, and silent
///
/// A frame can be missing for many reasons — no network, a codec the device
/// cannot decode, a platform with no thumbnailer, a widget test with no plugin.
/// Every one of them returns `null` so the caller falls back to its own
/// placeholder. **Nothing here throws**, on purpose: a missing picture must never
/// become an error state on a screen that is otherwise fine.
///
/// Failures are **cached as well as successes**, so a card that cannot produce a
/// frame does not ask again on every rebuild. Use [clear] to force a retry.
class VideoThumbnailService {
  VideoThumbnailService._();

  static final VideoThumbnailService instance = VideoThumbnailService._();

  /// `url|WxH -> bytes`, where a `null` value records a **failed** extraction.
  final Map<String, Uint8List?> _cache = <String, Uint8List?>{};

  /// Requests already on their way, so N cards showing the same video trigger
  /// one extraction rather than N.
  final Map<String, Future<Uint8List?>> _inFlight = <String, Future<Uint8List?>>{};

  /// Set when the platform channel reports `MissingPluginException`, i.e. this
  /// platform has no thumbnailer registered (a desktop embedder without the
  /// plugin, or a `flutter test` process).
  ///
  /// Once known, [_extract] stops before the download tier: fetching megabytes
  /// of video to hand them to a thumbnailer that does not exist would cost the
  /// user data for nothing, and in a widget test it would start a real network
  /// transfer. A successful call clears it again, so a genuine codec failure is
  /// never mistaken for a missing platform.
  bool _nativeUnavailable = false;

  /// Dio instance dedicated to thumbnail downloads — the application's
  /// [ApiClient] has `responseType: ResponseType.json` and a set of envelope
  /// unwrapping interceptors, neither of which is appropriate for fetching raw
  /// video bytes into a temp file. A fresh, plain [Dio] is cheap and keeps the
  /// two concerns fully separated.
  final Dio _downloader = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 45),
  ));

  /// The size the grid asks for. A 3-column card is small, and asking for a
  /// smaller frame is what keeps this cheap on a weak device — the thumbnailer
  /// scales during decode rather than after.
  static const int defaultWidth = 400;
  static const int defaultHeight = 400;

  /// A path that certainly does not exist, used only to reach the platform
  /// channel when probing whether a thumbnailer is installed (see
  /// [_probeNative]). The thumbnailer answers "cannot read that" — which is the
  /// point — rather than `MissingPluginException`.
  static const String _probePath = '__mr_cake_thumbnail_probe__';

  /// How far into the video the frame is taken from.
  ///
  /// Not `0`: the very first frame of a phone recording is often black or a
  /// blurred transition. One second in is "a slice of the video" that actually
  /// looks like the video.
  ///
  /// Not `const` — `FcVideoThumbnailTime` has no const constructor.
  static final FcVideoThumbnailTime _seekTo = FcVideoThumbnailTime(
    1000,
    FcVideoThumbnailTimeUnit.milliseconds,
  );

  /// A frame for [videoUrl], or `null` if one cannot be produced.
  ///
  /// Safe to call from `build`: repeated calls for the same url and size are
  /// served from the cache, and concurrent calls share one extraction.
  Future<Uint8List?> frame(
    String videoUrl, {
    int width = defaultWidth,
    int height = defaultHeight,
  }) {
    final String url = videoUrl.trim();
    if (url.isEmpty) return Future<Uint8List?>.value();

    // Not supported on web, and there is no plugin to call.
    if (kIsWeb) return Future<Uint8List?>.value();

    final String key = '$url|${width}x$height';

    if (_cache.containsKey(key)) {
      return Future<Uint8List?>.value(_cache[key]);
    }

    final Future<Uint8List?>? pending = _inFlight[key];
    if (pending != null) return pending;

    final Future<Uint8List?> request = _extract(url, width, height)
        .then((Uint8List? bytes) {
          _cache[key] = bytes;
          return bytes;
        })
        .whenComplete(() => _inFlight.remove(key));

    _inFlight[key] = request;
    return request;
  }

  Future<Uint8List?> _extract(String url, int width, int height) async {
    final FcNativeVideoThumbnail plugin = FcNativeVideoThumbnail();
    final bool isRemote = url.startsWith('http://') || url.startsWith('https://');

    // -----------------------------------------------------------------------
    // Tier 1: try the remote-Uri path (Android / iOS / macOS). The platform
    // thumbnailers on those systems know how to seek over HTTP, so we do not
    // want to pay the download cost on a mobile data plan unless we have to.
    // -----------------------------------------------------------------------
    final bool canTryUri =
        isRemote && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

    if (canTryUri) {
      final Uint8List? direct =
          await _runNative(plugin, url, width, height, srcFileUri: true);
      if (direct != null) return direct;
    }

    // -----------------------------------------------------------------------
    // Tier 2: download to a local temp file and try again. Reached on any
    // platform when Tier 1 does not apply (Windows / Linux) or when it
    // returned nothing (flaky CDN / codec on mobile).
    //
    // Non-remote urls (file:// or bare paths) skip the download step and go
    // straight through the thumbnailer with `srcFileUri: false`.
    // -----------------------------------------------------------------------
    if (isRemote) {
      if (kIsWeb) return null; // No file system to land on.

      // Probing the thumbnailer *before* paying for the download matters: on a
      // platform with no plugin registered — Windows / Linux desktop builds
      // without the native half, and every `flutter test` process — the local
      // read would fail for exactly the same reason the remote one did. Pulling
      // the whole video first would spend the user's data to hand the bytes to
      // a thumbnailer that does not exist.
      //
      // A cheap, real call is the only reliable probe: `MissingPluginException`
      // is only thrown by the channel, and there is no "is it installed?"
      // accessor on the plugin.
      final bool thumbnailerExists = await _probeNative(plugin);

      if (!thumbnailerExists) return null;

      final String? tempPath = await _downloadToTemp(url);
      if (tempPath == null) return null;

      try {
        return await _runNative(
          plugin,
          tempPath,
          width,
          height,
          srcFileUri: false,
        );
      } finally {
        _deleteTempQuietly(tempPath);
      }
    }

    return await _runNative(plugin, url, width, height, srcFileUri: false);
  }

  /// Whether a native thumbnailer is actually reachable on this platform.
  ///
  /// The result is remembered in [_nativeUnavailable]: the answer cannot change
  /// while the process lives, and a cached negative keeps a grid of video cards
  /// from probing once per cell.
  Future<bool> _probeNative(FcNativeVideoThumbnail plugin) async {
    if (_nativeUnavailable) return false;

    try {
      // Any call reaches the channel; the returned frame is irrelevant, only
      // whether the call got through. Width and height must be > 0 or the
      // plugin throws `ArgumentError` before it ever touches the channel.
      await plugin.saveThumbnailToBytes(
        srcFile: _probePath,
        width: 1,
        height: 1,
        srcFileUri: false,
        at: null,
      );
      return true;
    } on MissingPluginException {
      _nativeUnavailable = true;
      debugPrint('[THUMB] no native thumbnailer on this platform');
      return false;
    } catch (_) {
      // Reached the channel and came back with a real failure (no such file,
      // undecodable codec…): the thumbnailer is there.
      return true;
    }
  }

  /// Runs the native plugin through two seek positions and returns the first
  /// non-empty frame, or `null` if nothing comes out.
  ///
  /// [srcFileUri] selects the plugin's reading mode:
  /// * `true`  — `srcFile` is a content:// or https:// Uri (Android / Apple).
  /// * `false` — `srcFile` is a local file path (every platform).
  Future<Uint8List?> _runNative(
    FcNativeVideoThumbnail plugin,
    String srcFile,
    int width,
    int height, {
    required bool srcFileUri,
  }) async {
    for (final FcVideoThumbnailTime? at in <FcVideoThumbnailTime?>[
      _seekTo,
      null,
    ]) {
      try {
        final Uint8List? bytes = await plugin.saveThumbnailToBytes(
          srcFile: srcFile,
          width: width,
          height: height,
          quality: 80,
          srcFileUri: srcFileUri,
          at: at,
        );

        _nativeUnavailable = false;
        if (bytes != null && bytes.isNotEmpty) return bytes;
      } on MissingPluginException {
        // No implementation behind the channel: there is no thumbnailer on this
        // platform, so every later attempt would fail identically. Recorded so
        // [_extract] can skip the download tier instead of pulling a whole
        // video off the network for nothing.
        _nativeUnavailable = true;
        debugPrint('[THUMB] no native thumbnailer; skipping $srcFile');
        return null;
      } catch (error) {
        // A codec the device cannot decode, a dead network, no plugin in a test
        // process: all of them land here and all of them mean "try the next
        // strategy", not "give up immediately". Only the outermost caller logs.
        debugPrint(
          '[THUMB] native failed (uri=$srcFileUri) for $srcFile: ${error.runtimeType}',
        );
        break;
      }
    }
    return null;
  }

  /// Downloads the video at [url] into the system temp directory and returns
  /// the absolute file path, or `null` if the transfer could not complete.
  ///
  /// The file name embeds a hash of the url so two concurrent requests for the
  /// same video land on the same temp file — the second write simply
  /// overwrites the first, which is safe because both readers see identical
  /// bytes and the thumbnailer reads whatever is on disk.
  Future<String?> _downloadToTemp(String url) async {
    final Directory temp = Directory.systemTemp;
    final String safeName = 'mr_cake_thumb_${url.hashCode.abs()}.mp4';
    final String destination = p.join(temp.path, safeName);
    final File file = File(destination);

    // A fully downloaded temp file from a previous call (that crashed before
    // cleanup, or that a concurrent card still has in flight) can be reused
    // verbatim — no need to hit the network twice for the same resource.
    if (file.existsSync() && file.lengthSync() > 0) {
      return destination;
    }

    try {
      await _downloader.download(url, destination);
      if (!file.existsSync() || file.lengthSync() == 0) return null;
      return destination;
    } on DioException catch (error) {
      debugPrint('[THUMB] download failed for $url: ${error.type}');
      return null;
    } catch (error) {
      debugPrint('[THUMB] download error for $url: ${error.runtimeType}');
      return null;
    }
  }

  /// Removes a temp file that [_downloadToTemp] created, ignoring any I/O
  /// error — the OS will reap it on reboot anyway, so a failure here is not
  /// worth surfacing.
  void _deleteTempQuietly(String path) {
    try {
      final File f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {
      /* ignore */
    }
  }

  /// Forgets every frame, so the next request re-extracts.
  void clear() {
    _cache.clear();
    _inFlight.clear();
    _nativeUnavailable = false;
  }

  /// How many urls have been resolved, for tests.
  @visibleForTesting
  int get cachedCount => _cache.length;
}
