import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';

import '../../core/media/resilient_video_loader.dart';
import '../../core/theme/app_colors.dart';

/// The house video surface: one player, one chrome, one set of failure states.
///
/// This is the **only** place a raw `VideoPlayerController` is built for a
/// full-width player in this app. It exists because the same surface was being
/// hand-rolled in `LessonScreen` and in `IntroductionVideoPlayerScreen`, and the
/// two had drifted — the lesson screen was the one that broke on weak devices.
///
/// ## Why this plays where a bare `.initialize()` did not
///
/// A weak device is not a device that cannot decode the file; it is a device
/// whose first attempt fails for a reason a *different display mode* fixes.
/// [ResilientVideoLoader] walks a short ladder (`textureView` → `platformView`)
/// for exactly that, so routing every player through it is what makes
/// «روی گوشی‌های ضعیف پخش نمی‌شود» stop happening.
///
/// ## The states it renders, in priority order
///
///  1. **error** — [errorMessage] under «پخش ویدیو امکان‌پذیر نیست», with an
///     optional retry action. Never a spinner that cannot resolve.
///  2. **empty url** — the same error panel, so a lesson with no video says so
///     instead of spinning forever.
///  3. **loading** — a spinner over the poster image.
///  4. **ready** — the video, the scrim, the tap-to-toggle chrome, the progress
///     bar, play/pause, the timestamps, mute and fullscreen.
///
/// [onCompleted] fires **once**, when playback reaches the end. That is what
/// marks a lesson watched, and it is deliberately here rather than in the parent
/// so the listener and the controller cannot get out of step.
class HouseVideoPlayer extends StatefulWidget {
  const HouseVideoPlayer({
    super.key,
    required this.videoUrl,
    this.posterUrl,
    this.onCompleted,
    this.autoPlay = false,
    this.aspectRatio = 16 / 9,
    this.margin,
    this.borderRadius,
    this.errorMessage,
    this.onRetry,
    this.overlay,
  });

  /// The video to play. An empty string is a valid, handled state.
  final String videoUrl;

  /// Shown until the first frame is ready. Optional — a lesson without a
  /// thumbnail falls back to [AppColors.field].
  final String? posterUrl;

  /// Fired once when playback reaches the end of the file.
  final VoidCallback? onCompleted;

  /// Whether to start playing as soon as the controller is ready.
  final bool autoPlay;

  /// The shape of the surface. `16/9` unless the parent knows better.
  final double aspectRatio;

  /// Outer margin. `null` means the parent already constrains the box.
  final EdgeInsets? margin;

  /// Corner radius of the surface.
  final BorderRadius? borderRadius;

  /// Overrides the default «آدرس ویدیو خالی است.» for the empty-url state.
  final String? errorMessage;

  /// When given, the error panel offers «تلاش مجدد» wired to this instead of
  /// re-initialising in place.
  final VoidCallback? onRetry;

  /// Painted on top of the video layer, under the chrome. The intro player uses
  /// it for its course pill.
  final Widget? overlay;

  @override
  State<HouseVideoPlayer> createState() => HouseVideoPlayerState();
}

class HouseVideoPlayerState extends State<HouseVideoPlayer> {
  VideoPlayerController? _controller;

  bool _initialized = false;
  bool _hasError = false;
  bool _isLoading = true;
  String _errorText = '';

  /// Only one «دیده شد» report per mounted player.
  bool _reportedCompletion = false;

  bool _showControls = true;
  Timer? _controlsTimer;
  bool _wasPlayingBeforeBuffering = false;

  /// Guards against an in-flight `_load` from a previous url writing state on
  /// top of a newer one.
  int _loadGeneration = 0;

  /// The live controller, so a parent (fullscreen) can reuse the same surface.
  VideoPlayerController? get controller => _controller;

  bool get isReady => _initialized && !_hasError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(HouseVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.videoUrl.trim() != oldWidget.videoUrl.trim()) {
      _load();
    }
  }

  /// (Re)builds the player for [HouseVideoPlayer.videoUrl].
  Future<void> _load() async {
    final int generation = ++_loadGeneration;
    final String url = widget.videoUrl.trim();

    await _resetController();

    if (!mounted || generation != _loadGeneration) return;

    if (url.isEmpty) {
      setState(() {
        _initialized = false;
        _isLoading = false;
        _hasError = true;
        _errorText = widget.errorMessage ?? 'آدرس ویدیو خالی است.';
      });
      return;
    }

    final Uri? uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      setState(() {
        _initialized = false;
        _isLoading = false;
        _hasError = true;
        _errorText = 'آدرس ویدیو معتبر نیست.';
      });
      return;
    }

    try {
      // Not a bare `.initialize()`: see [ResilientVideoLoader]. This is the fix
      // for «ویدیو روی گوشی‌های ضعیف پخش نمی‌شود».
      final VideoPlayerController controller =
          await ResilientVideoLoader.initialize(
        url,
        onFailure: (Object error, StackTrace stackTrace) {
          debugPrint('[LESSON VIDEO] rung failed for $url: $error');
        },
      );

      if (!mounted || generation != _loadGeneration) {
        await _discard(controller);
        return;
      }

      _controller = controller;
      controller.addListener(_videoListener);

      setState(() {
        _initialized = true;
        _isLoading = false;
        _hasError = false;
        _errorText = '';
      });

      if (widget.autoPlay) {
        await controller.play();
      }

      _startControlsTimer();
    } catch (error, stackTrace) {
      debugPrint('================================================');
      debugPrint('[LESSON VIDEO] ERROR for $url: $error');
      debugPrint('$stackTrace');
      debugPrint('================================================');

      if (!mounted || generation != _loadGeneration) return;

      setState(() {
        _initialized = false;
        _isLoading = false;
        _hasError = true;
        _errorText = 'پخش این ویدیو روی این دستگاه ممکن نشد.';
      });
    }
  }

  /// Public so a parent (the intro player's queue) can restart playback after
  /// its data changed.
  Future<void> reload() => _load();

  Future<void> _resetController() async {
    final VideoPlayerController? previous = _controller;
    _controller = null;
    _controlsTimer?.cancel();

    if (previous == null) return;

    previous.removeListener(_videoListener);
    await _discard(previous);
  }

  /// A controller that failed to create may never finish disposing — see
  /// [ResilientVideoLoader]. Abandon it rather than await forever.
  Future<void> _discard(VideoPlayerController controller) async {
    try {
      await controller.dispose().timeout(const Duration(seconds: 2));
    } catch (_) {
      // Nothing to do: the decoder is gone either way.
    }
  }

  void _videoListener() {
    final VideoPlayerController? controller = _controller;

    if (!mounted || controller == null) return;

    final VideoPlayerValue value = controller.value;

    if (value.hasError) {
      if (!_hasError) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorText = 'پخش این ویدیو روی این دستگاه ممکن نشد.';
        });
      }
      return;
    }

    // End of file = watched. Reported once.
    if (!_reportedCompletion &&
        value.isInitialized &&
        value.duration > Duration.zero &&
        value.position >= value.duration) {
      _reportedCompletion = true;
      widget.onCompleted?.call();
    }

    // On a weak device a buffer stall can leave the player paused for good.
    // Remember that it *was* playing and resume once the stall clears.
    if (value.isBuffering) {
      if (value.isPlaying) _wasPlayingBeforeBuffering = true;
    } else {
      if (_wasPlayingBeforeBuffering && !value.isPlaying) {
        controller.play();
      }
      _wasPlayingBeforeBuffering = false;
    }

    setState(() {});
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();

    final VideoPlayerController? controller = _controller;
    if (controller == null || !controller.value.isPlaying) return;

    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showControls = false);
    });
  }

  void _revealControls() {
    _controlsTimer?.cancel();
    if (!_showControls) {
      setState(() => _showControls = true);
    }
    _startControlsTimer();
  }

  /// Tap on the video: reveal the chrome, or hide it. Never toggles playback —
  /// that is what the centre button and the bottom-left icon are for, and it is
  /// the behaviour every player people already use has.
  void _handleSurfaceTap() {
    if (_controller == null || !_initialized) return;

    if (!_showControls) {
      _revealControls();
      return;
    }

    setState(() => _showControls = false);
    _controlsTimer?.cancel();
  }

  Future<void> _togglePlay() async {
    final VideoPlayerController? controller = _controller;
    if (controller == null || !_initialized) return;

    if (controller.value.isPlaying) {
      await controller.pause();
      _controlsTimer?.cancel();
      if (mounted) setState(() => _showControls = true);
      return;
    }

    await controller.play();
    if (!mounted) return;
    setState(() => _showControls = true);
    _startControlsTimer();
  }

  Future<void> _toggleMute() async {
    final VideoPlayerController? controller = _controller;
    if (controller == null || !_initialized) return;

    await controller.setVolume(controller.value.volume > 0 ? 0.0 : 1.0);

    if (!mounted) return;
    setState(() => _showControls = true);
    _startControlsTimer();
  }

  Future<void> _openFullscreen() async {
    final VideoPlayerController? controller = _controller;
    if (controller == null || !_initialized) return;

    _controlsTimer?.cancel();

    final bool wasPlaying = controller.value.isPlaying;

    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    if (!mounted) return;

    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (_, _, _) => HouseVideoFullscreenPage(
          controller: controller,
          wasPlaying: wasPlaying,
        ),
        transitionsBuilder: (_, Animation<double> animation, _, Widget child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );

    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    if (!mounted) return;
    setState(() => _showControls = true);
    _startControlsTimer();
  }

  @override
  void dispose() {
    _loadGeneration++;
    _controlsTimer?.cancel();
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? controller = _controller;

    final Widget surface = AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ClipRRect(
        borderRadius: widget.borderRadius ?? BorderRadius.circular(18.r),
        child: ColoredBox(
          color: AppColors.field,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _buildVideoLayer(controller),
              _buildScrim(),
              if (widget.overlay != null) widget.overlay!,
              if (_initialized && !_hasError) _buildTapCatcher(),
              if (_isLoading) _buildLoading(),
              if (_initialized && controller != null && controller.value.isBuffering)
                _buildBuffering(),
              if (_initialized && !_hasError && controller != null)
                _buildCenterControl(controller),
              if (_initialized && controller != null && !_hasError)
                _buildBottomControls(controller),
              if (_hasError) _buildErrorPanel(),
            ],
          ),
        ),
      ),
    );

    final EdgeInsets? margin = widget.margin;
    if (margin == null) return surface;

    return Padding(padding: margin, child: surface);
  }

  Widget _buildVideoLayer(VideoPlayerController? controller) {
    if (_initialized && controller != null) {
      return FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      );
    }

    final String? poster = widget.posterUrl;
    if (poster == null || poster.isEmpty) {
      return ColoredBox(
        color: AppColors.field,
        child: Center(
          child: Icon(
            Icons.video_library_outlined,
            size: 40.sp,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return Image.network(
      poster,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => ColoredBox(
        color: AppColors.field,
        child: Center(
          child: Icon(
            Icons.video_library_outlined,
            size: 40.sp,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// The gesture surface. `HitTestBehavior.opaque` so the whole video is
  /// tappable and nothing underneath steals the gesture.
  Widget _buildTapCatcher() {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleSurfaceTap,
      ),
    );
  }

  Widget _buildScrim() {
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: _showControls ? 1 : 0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.black.withValues(alpha: 0.06),
                Colors.black.withValues(alpha: 0.38),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: SizedBox(
        width: 28.w,
        height: 28.w,
        child: CircularProgressIndicator(
          strokeWidth: 2.2.w,
          color: AppColors.white,
        ),
      ),
    );
  }

  Widget _buildBuffering() {
    return Center(
      child: Container(
        width: 48.w,
        height: 48.w,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: SizedBox(
          width: 22.w,
          height: 22.w,
          child: CircularProgressIndicator(
            strokeWidth: 2.2.w,
            color: AppColors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildCenterControl(VideoPlayerController controller) {
    if (controller.value.isPlaying) return const SizedBox.shrink();

    return Center(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _showControls ? 1 : 0,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _togglePlay,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 58.w,
                height: 58.w,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                    width: 1.w,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.white,
                  size: 32.sp,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls(VideoPlayerController controller) {
    return Positioned(
      left: 14.w,
      right: 14.w,
      bottom: 10.h,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: _showControls ? 1 : 0,
        child: IgnorePointer(
          ignoring: !_showControls,
          child: Column(
            children: <Widget>[
              VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                padding: EdgeInsets.zero,
                colors: VideoProgressColors(
                  playedColor: AppColors.premium,
                  bufferedColor: Colors.white.withValues(alpha: 0.35),
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                ),
              ),
              SizedBox(height: 7.h),
              Row(
                textDirection: TextDirection.ltr,
                children: <Widget>[
                  GestureDetector(
                    onTap: _togglePlay,
                    child: Icon(
                      controller.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: AppColors.white,
                      size: 21.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    formatPlayerDuration(controller.value.position),
                    style: TextStyle(
                      fontFamily: 'shabnam',
                      fontSize: 11.sp,
                      color: AppColors.white,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatPlayerDuration(controller.value.duration),
                    style: TextStyle(
                      fontFamily: 'shabnam',
                      fontSize: 11.sp,
                      color: AppColors.white,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  GestureDetector(
                    onTap: _toggleMute,
                    child: Icon(
                      controller.value.volume > 0
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      color: AppColors.white,
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  GestureDetector(
                    onTap: _openFullscreen,
                    child: Icon(
                      Icons.fullscreen_rounded,
                      color: AppColors.white,
                      size: 22.sp,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPanel() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              color: AppColors.white,
              size: 32.sp,
            ),
            SizedBox(height: 8.h),
            Text(
              'پخش ویدیو امکان‌پذیر نیست',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'bshabnam',
                fontSize: 12.sp,
                color: AppColors.white,
              ),
            ),
            if (_errorText.isNotEmpty) ...<Widget>[
              SizedBox(height: 4.h),
              Text(
                _errorText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'bshabnam',
                  fontSize: 10.sp,
                  color: AppColors.white.withValues(alpha: 0.65),
                  height: 1.5,
                ),
              ),
            ],
            SizedBox(height: 12.h),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onRetry ?? _load,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(9.r),
                ),
                child: Text(
                  'تلاش مجدد',
                  style: TextStyle(
                    fontFamily: 'bshabnam',
                    fontSize: 13.sp,
                    color: AppColors.white,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `mm:ss`, or `h:mm:ss` past an hour. Shared so every timestamp in the app
/// reads identically.
String formatPlayerDuration(Duration duration) {
  final int hours = duration.inHours;
  final int minutes = duration.inMinutes.remainder(60);
  final int seconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

/// Landscape, immersive, dismissed with ✕. Reuses the parent's controller — the
/// video is never re-created, so fullscreen cannot be the thing that loses the
/// position or breaks on a weak device.
class HouseVideoFullscreenPage extends StatefulWidget {
  const HouseVideoFullscreenPage({
    super.key,
    required this.controller,
    required this.wasPlaying,
  });

  final VideoPlayerController controller;
  final bool wasPlaying;

  @override
  State<HouseVideoFullscreenPage> createState() =>
      _HouseVideoFullscreenPageState();
}

class _HouseVideoFullscreenPageState extends State<HouseVideoFullscreenPage> {
  bool _showControls = true;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _controlsTimer?.cancel();
    if (!widget.controller.value.isPlaying) return;

    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    if (!_showControls) {
      setState(() => _showControls = true);
      _startTimer();
      return;
    }

    setState(() => _showControls = false);
    _controlsTimer?.cancel();
  }

  Future<void> _togglePlay() async {
    if (widget.controller.value.isPlaying) {
      await widget.controller.pause();
      _controlsTimer?.cancel();
      if (mounted) setState(() => _showControls = true);
      return;
    }

    await widget.controller.play();
    if (!mounted) return;
    setState(() => _showControls = true);
    _startTimer();
  }

  void _exit() {
    _controlsTimer?.cancel();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController controller = widget.controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
            ),
          ),
          IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _showControls ? 1 : 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.black.withValues(alpha: 0.45),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.5),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (controller.value.isBuffering)
            Center(
              child: SizedBox(
                width: 38.w,
                height: 38.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5.w,
                  color: AppColors.white,
                ),
              ),
            ),
          Positioned(
            top: 20.h,
            left: 20.w,
            right: 20.w,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _showControls ? 1 : 0,
              child: GestureDetector(
                onTap: _exit,
                child: Container(
                  width: 42.w,
                  height: 42.w,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 24.sp,
                  ),
                ),
              ),
            ),
          ),
          if (!controller.value.isPlaying)
            Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showControls ? 1 : 0,
                child: GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 62.w,
                    height: 62.w,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 34.sp,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 25.w,
            right: 25.w,
            bottom: 20.h,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _showControls ? 1 : 0,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Column(
                  children: <Widget>[
                    VideoProgressIndicator(
                      controller,
                      allowScrubbing: true,
                      padding: EdgeInsets.zero,
                      colors: VideoProgressColors(
                        playedColor: AppColors.premium,
                        bufferedColor: Colors.white.withValues(alpha: 0.35),
                        backgroundColor: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Row(
                      children: <Widget>[
                        GestureDetector(
                          onTap: _togglePlay,
                          child: Icon(
                            controller.value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 25.sp,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          formatPlayerDuration(controller.value.position),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          formatPlayerDuration(controller.value.duration),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
