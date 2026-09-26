import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';

import '../../../core/media/resilient_video_loader.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/explore_video.dart';

class ReelsViewer extends StatefulWidget {
  final List<ExploreVideo> videos;
  final int initialIndex;

  const ReelsViewer({
    super.key,
    required this.videos,
    this.initialIndex = 0,
  });

  @override
  State<ReelsViewer> createState() => _ReelsViewerState();
}

class _ReelsViewerState extends State<ReelsViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();

    _currentIndex = widget.initialIndex.clamp(
      0,
      widget.videos.isEmpty ? 0 : widget.videos.length - 1,
    );

    _pageController = PageController(
      initialPage: _currentIndex,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (!mounted) return;

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videos.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'ویدیویی وجود ندارد',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Shabnam',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics: const BouncingScrollPhysics(),
        itemCount: widget.videos.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (
          BuildContext context,
          int index,
        ) {
          final ExploreVideo video = widget.videos[index];

          return _ReelItem(
            key: ValueKey(video.id),
            video: video,
            isActive: index == _currentIndex,
          );
        },
      ),
    );
  }
}

class _ReelItem extends StatefulWidget {
  final ExploreVideo video;
  final bool isActive;

  const _ReelItem({
    super.key,
    required this.video,
    required this.isActive,
  });

  @override
  State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem> {
  VideoPlayerController? _controller;

  bool _isInitialized = false;
  bool _hasError = false;
  bool _showPlayIcon = false;
  bool _isRetrying = false;

  /// A portfolio item can be a picture rather than a video: the «هنرجوها»
  /// gallery shares this viewer, and a work with no `videoUrl` is something to
  /// look at, not a playback failure to report. Set in [_initializePlayer] when
  /// there is a thumbnail but no video, and rendered as a still image with no
  /// player chrome at all.
  bool _isImageOnly = false;

  String _errorMessage = '';

  /// `true` when the failure was **permission**, not a missing file — see
  /// [ExploreVideo.videoNeedsAuth]. The error panel swaps «تلاش مجدد» for a
  /// sign-in action, because retrying a request that was refused on principle
  /// cannot succeed.
  bool _needsAuth = false;

  Timer? _hidePlayIconTimer;

  bool _disposed = false;

  @override
  void initState() {
    super.initState();

    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    if (_disposed) return;

    final String url = widget.video.videoUrl.trim();

    if (url.isEmpty) {
      // An image work: show it, do not call it a broken video.
      if (widget.video.thumbnail.trim().isNotEmpty) {
        if (!mounted) return;

        setState(() {
          _isImageOnly = true;
        });

        return;
      }

      // An empty url has **two** causes and they must not share a message.
      //
      // `v1/content/explore-videos/` is public but lists media *ids*, and
      // `v1/media/{id}/` is auth-only — so a guest is refused the lookup and
      // ends up here with a video that is sitting on the public CDN. Telling
      // that user «آدرس ویدیو خالی است» is simply false and leaves them with
      // nothing to do; the honest answer is that they have to sign in.
      if (widget.video.videoNeedsAuth) {
        _setError(
          'برای پخش این ویدیو باید وارد حساب خود شوید.',
          needsAuth: true,
        );
        return;
      }

      _setError('آدرس ویدیو خالی است.');
      return;
    }

    debugPrint('VIDEO INIT → $url');

    try {
      // A ladder of display modes rather than a single attempt, so a weak device
      // gets several chances before this screen declares a playback failure. See
      // [ResilientVideoLoader].
      final VideoPlayerController controller =
          await ResilientVideoLoader.initialize(
        url,
        onFailure: (Object error, StackTrace stackTrace) {
          debugPrint('VIDEO ATTEMPT FAILED: $error');
        },
      );

      if (!mounted || _disposed) {
        await controller.dispose();
        return;
      }

      _controller = controller;

      controller.addListener(_onPlayerChanged);

      await controller.setLooping(true);

      setState(() {
        _isInitialized = true;
        _hasError = false;
        _errorMessage = '';
        _isRetrying = false;
      });

      debugPrint('VIDEO INITIALIZED ✅');

      if (widget.isActive) {
        await controller.play();
      }
    } catch (e, stackTrace) {
      debugPrint('🔥 VIDEO INIT ERROR: $e\n$stackTrace');

      _setError('${e.runtimeType}\n$e');
    }
  }

  void _onPlayerChanged() {
    if (_disposed || !mounted) return;

    final VideoPlayerController? controller = _controller;

    if (controller == null) return;

    final VideoPlayerValue value = controller.value;

    if (value.hasError) {
      final String message = (value.errorDescription ?? '').trim();

      _setError(
        message.isEmpty
            ? 'پخش‌کننده خطای نامشخصی گزارش کرد.'
            : message,
      );

      return;
    }

    setState(() {});
  }

  void _setError(String message, {bool needsAuth = false}) {
    if (!mounted || _disposed) return;

    debugPrint('🔥 VIDEO ERROR: $message');

    setState(() {
      _isInitialized = false;
      _hasError = true;
      _errorMessage = message;
      _needsAuth = needsAuth;
      _isRetrying = false;
    });
  }

  @override
  void didUpdateWidget(
    covariant _ReelItem oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.isActive && widget.isActive) {
      _playVideo();
    }

    if (oldWidget.isActive && !widget.isActive) {
      _pauseVideo();
    }
  }

  Future<void> _playVideo() async {
    if (_disposed) return;

    final VideoPlayerController? controller = _controller;

    if (controller == null || !_isInitialized || _hasError) {
      return;
    }

    try {
      await controller.play();
    } catch (e) {
      debugPrint('VIDEO PLAY ERROR: $e');
    }
  }

  Future<void> _pauseVideo() async {
    if (_disposed) return;

    final VideoPlayerController? controller = _controller;

    if (controller == null || !_isInitialized) {
      return;
    }

    try {
      await controller.pause();
    } catch (e) {
      debugPrint('VIDEO PAUSE ERROR: $e');
    }
  }

  Future<void> _togglePlayPause() async {
    if (_disposed) return;

    final VideoPlayerController? controller = _controller;

    if (controller == null || !_isInitialized || _hasError) {
      return;
    }

    try {
      if (controller.value.isPlaying) {
        await controller.pause();

        if (!mounted || _disposed) return;

        setState(() {
          _showPlayIcon = true;
        });

        _hidePlayIconTimer?.cancel();

        _hidePlayIconTimer = Timer(
          const Duration(milliseconds: 900),
          () {
            if (!mounted || _disposed) return;

            setState(() {
              _showPlayIcon = false;
            });
          },
        );
      } else {
        await controller.play();

        if (!mounted || _disposed) return;

        setState(() {
          _showPlayIcon = false;
        });
      }
    } catch (e) {
      debugPrint('VIDEO TOGGLE ERROR: $e');
    }
  }

  Future<void> _retryVideo() async {
    if (_isRetrying || _disposed) {
      return;
    }

    setState(() {
      _isRetrying = true;
      _hasError = false;
      _errorMessage = '';
      _needsAuth = false;
    });

    final VideoPlayerController? oldController = _controller;

    _controller = null;

    if (oldController != null) {
      oldController.removeListener(_onPlayerChanged);

      try {
        await oldController.dispose();
      } catch (_) {}
    }

    if (!mounted || _disposed) return;

    setState(() {
      _isInitialized = false;
    });

    await _initializePlayer();
  }

  @override
  void dispose() {
    _disposed = true;

    _hidePlayIconTimer?.cancel();

    final VideoPlayerController? controller = _controller;

    _controller = null;

    if (controller != null) {
      controller.removeListener(_onPlayerChanged);
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlayPause,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildVideo(),
          _buildTopGradient(),
          _buildBottomGradient(),
          _buildCloseButton(),
          _buildPlayPauseIcon(),
          _buildBottomInfo(),
          _buildProgressBar(),
        ],
      ),
    );
  }

  Widget _buildVideo() {
    if (_isImageOnly) {
      return Positioned.fill(
        child: Image.network(
          widget.video.thumbnail,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) {
            return Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: const Icon(
                Icons.image_outlined,
                color: Colors.white,
                size: 50,
              ),
            );
          },
        ),
      );
    }

    if (_hasError) {
      return _buildErrorState();
    }

    final VideoPlayerController? controller = _controller;

    if (controller == null || !_isInitialized) {
      return _buildLoading();
    }

    // تمام‌صفحه مثل ریلز، بدون نوار سیاه کناری.
    return Positioned.fill(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: SizedBox(
        width: 30.w,
        height: 30.w,
        child: CircularProgressIndicator(
          strokeWidth: 2.w,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(
        horizontal: 25.w,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _needsAuth
                  ? Icons.lock_outline_rounded
                  : Icons.error_outline_rounded,
              color: Colors.white,
              size: 48.sp,
            ),
            SizedBox(height: 15.h),
            Text(
              _needsAuth
                  ? 'برای پخش این ویدیو وارد شوید'
                  : 'پخش ویدیو با مشکل مواجه شد',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PinarB',
                fontSize: 17.sp,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 12.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(13.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 0.7.w,
                ),
              ),
              child: SelectableText(
                _errorMessage.isEmpty ? 'خطای نامشخص' : _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Shabnam',
                  fontSize: 10.sp,
                  color: Colors.white70,
                  height: 1.7,
                ),
              ),
            ),
            SizedBox(height: 18.h),
            // A refused lookup and a missing file need different actions:
            // one is fixed by signing in, the other by trying the request
            // again. Offering «تلاش مجدد» for a 401 would loop forever, and
            // offering «ورود» for a 404 would send the user to a login screen
            // that cannot help them.
            if (_needsAuth)
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  AppRouter.toLogin(context);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.w,
                    vertical: 11.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(11.r),
                  ),
                  child: Text(
                    'ورود به حساب',
                    style: TextStyle(
                      fontFamily: 'bShabnam',
                      fontSize: 13.sp,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: _retryVideo,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.w,
                    vertical: 11.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(11.r),
                  ),
                  child: Text(
                    _isRetrying ? 'در حال تلاش...' : 'تلاش مجدد',
                    style: TextStyle(
                      fontFamily: 'bShabnam',
                      fontSize: 13.sp,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopGradient() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 130.h,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.55),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomGradient() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: 260.h,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.82),
                Colors.black.withValues(alpha: 0.25),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 12.h,
      left: 18.w,
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).pop();
        },
        child: Container(
          width: 40.w,
          height: 40.w,
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
    );
  }

  Widget _buildPlayPauseIcon() {
    if (!_showPlayIcon) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Container(
        width: 64.w,
        height: 64.w,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: 40.sp,
        ),
      ),
    );
  }

  /// The chip needs at least one name to say anything at all.
  bool get _hasInstructor =>
      widget.video.instructorFirstName.trim().isNotEmpty ||
      widget.video.instructorLastName.trim().isNotEmpty;

  Widget _buildBottomInfo() {
    return Positioned(
      left: 20.w,
      right: 20.w,
      bottom: 25.h,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dropped rather than rendered empty: the chip prints
            // «استاد {lastName}», which would read «استاد » with no name.
            if (_hasInstructor) ...[
              _InstructorChip(
                video: widget.video,
              ),
              SizedBox(height: 12.h),
            ],
            Text(
              widget.video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'PinarB',
                fontSize: 17.sp,
                color: Colors.white,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final VideoPlayerController? controller = _controller;

    if (controller == null || !_isInitialized || _hasError) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (
          BuildContext context,
          VideoPlayerValue value,
          Widget? child,
        ) {
          final int duration = value.duration.inMilliseconds;

          final int position = value.position.inMilliseconds;

          double progress = 0;

          if (duration > 0) {
            progress = position / duration;
          }

          progress = progress.clamp(0.0, 1.0);

          return SizedBox(
            height: 4.h,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  color: AppColors.primary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InstructorChip extends StatelessWidget {
  final ExploreVideo video;

  const _InstructorChip({
    required this.video,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 190.w,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: 6.w,
          vertical: 5.h,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 0.7.w,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.rtl,
          children: [
            ClipOval(
              child: Image.network(
                video.instructorImage,
                width: 34.w,
                height: 34.w,
                fit: BoxFit.cover,
                errorBuilder: (
                  BuildContext context,
                  Object error,
                  StackTrace? stackTrace,
                ) {
                  return Container(
                    width: 34.w,
                    height: 34.w,
                    color: AppColors.field,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.textSecondary,
                      size: 20.sp,
                    ),
                  );
                },
              ),
            ),
            SizedBox(width: 7.w),
            Flexible(
              child: Text(
                'استاد ${video.instructorLastName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'bShabnam',
                  fontSize: 14.sp,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
            ),
            SizedBox(width: 6.w),
          ],
        ),
      ),
    );
  }
}