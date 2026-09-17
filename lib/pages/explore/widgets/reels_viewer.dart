import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

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

  String _errorMessage = '';

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
      _setError('آدرس ویدیو خالی است.');
      return;
    }

    debugPrint('VIDEO INIT → $url');

    final VideoPlayerController controller =
        VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: false,
      ),
    );

    _controller = controller;

    controller.addListener(_onPlayerChanged);

    try {
      await controller.initialize();

      if (!mounted || _disposed) {
        await controller.dispose();
        return;
      }

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

  void _setError(String message) {
    if (!mounted || _disposed) return;

    debugPrint('🔥 VIDEO ERROR: $message');

    setState(() {
      _isInitialized = false;
      _hasError = true;
      _errorMessage = message;
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
      child: const SizedBox(
        width: 30,
        height: 30,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(
        horizontal: 25,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 15),
            const Text(
              'پخش ویدیو با مشکل مواجه شد',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PinarB',
                fontSize: 17,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.12),
                ),
              ),
              child: SelectableText(
                _errorMessage.isEmpty ? 'خطای نامشخص' : _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Shabnam',
                  fontSize: 10,
                  color: Colors.white70,
                  height: 1.7,
                ),
              ),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: _retryVideo,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  _isRetrying ? 'در حال تلاش...' : 'تلاش مجدد',
                  style: const TextStyle(
                    fontFamily: 'bShabnam',
                    fontSize: 13,
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
      height: 130,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.55),
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
      height: 260,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withOpacity(0.82),
                Colors.black.withOpacity(0.25),
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
      top: MediaQuery.paddingOf(context).top + 12,
      left: 18,
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).pop();
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.close_rounded,
            color: Colors.white,
            size: 24,
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
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }

  Widget _buildBottomInfo() {
    return Positioned(
      left: 20,
      right: 20,
      bottom: 25,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InstructorChip(
              video: widget.video,
            ),
            const SizedBox(height: 12),
            Text(
              widget.video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'PinarB',
                fontSize: 17,
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
            height: 4,
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
        constraints: const BoxConstraints(
          maxWidth: 190,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.32),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withOpacity(0.35),
            width: 0.7,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.rtl,
          children: [
            ClipOval(
              child: Image.network(
                video.instructorImage,
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                errorBuilder: (
                  BuildContext context,
                  Object error,
                  StackTrace? stackTrace,
                ) {
                  return Container(
                    width: 34,
                    height: 34,
                    color: AppColors.field,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                'استاد ${video.instructorLastName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: 'bShabnam',
                  fontSize: 14,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}