import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/models/teacher_model.dart';
import 'package:video_player/video_player.dart';

import '../../../core/media/resilient_video_loader.dart';
import '../../../core/theme/app_colors.dart';

class TeacherPortfolioViewer extends StatefulWidget {
  final Teacher teacher;
  final List<TeacherPortfolioItem> items;
  final int initialIndex;

  const TeacherPortfolioViewer({
    super.key,
    required this.teacher,
    required this.items,
    this.initialIndex = 0,
  });

  @override
  State<TeacherPortfolioViewer> createState() =>
      _TeacherPortfolioViewerState();
}

class _TeacherPortfolioViewerState
    extends State<TeacherPortfolioViewer> {
  late final PageController _pageController;

  late int _currentIndex;

  @override
  void initState() {
    super.initState();

    _currentIndex = widget.initialIndex.clamp(
      0,
      widget.items.isEmpty
          ? 0
          : widget.items.length - 1,
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

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.items.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (
          BuildContext context,
          int index,
        ) {
          final TeacherPortfolioItem item =
              widget.items[index];

          return _PortfolioItem(
            key: ValueKey(item.id),
            teacher: widget.teacher,
            item: item,
            // A `PageView` keeps the neighbouring pages built, so without this
            // two adjacent videos would both be playing — and both making
            // noise. Only the page on screen is allowed to play.
            isActive: index == _currentIndex,
          );
        },
      ),
    );
  }
}

class _PortfolioItem extends StatefulWidget {
  final Teacher teacher;
  final TeacherPortfolioItem item;

  /// Whether this page is the one on screen. Only an active page plays.
  final bool isActive;

  const _PortfolioItem({
    super.key,
    required this.teacher,
    required this.item,
    required this.isActive,
  });

  @override
  State<_PortfolioItem> createState() =>
      _PortfolioItemState();
}

class _PortfolioItemState
    extends State<_PortfolioItem> {
  VideoPlayerController? _controller;

  bool _isInitialized = false;
  bool _hasError = false;

  /// Guards against two `initialize()` calls racing on a fast swipe.
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();

    // Built lazily: a video starts buffering only once its page is the visible
    // one, so a gallery of videos does not download all of them at once.
    if (widget.item.isVideo && widget.isActive) {
      _initializeVideo();
    }
  }

  @override
  void didUpdateWidget(covariant _PortfolioItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.item.isVideo) return;

    final bool becameActive = widget.isActive && !oldWidget.isActive;
    final bool becameInactive = !widget.isActive && oldWidget.isActive;

    if (becameActive) {
      // First time on this page: build the player. Swiping back later just
      // resumes it, so there is no second spinner.
      if (_controller == null) {
        _initializeVideo();
      } else if (_isInitialized) {
        _play();
      }
    } else if (becameInactive) {
      _pause();
    }
  }

  Future<void> _initializeVideo() async {
    if (_isInitializing) return;

    final String url =
        (widget.item.videoUrl ?? '').trim();

    if (url.isEmpty) {
      // A row with neither an image nor a video: there is nothing to play, so
      // report a missing work rather than a playback failure.
      setState(() {
        _hasError = true;
      });
      return;
    }

    _isInitializing = true;

    try {
      // Not a bare `VideoPlayerController.networkUrl(...).initialize()`: this
      // walks a ladder of display modes so a weak device gets several chances.
      // See [ResilientVideoLoader].
      final VideoPlayerController controller =
          await ResilientVideoLoader.initialize(
        url,
        onFailure: (Object error, StackTrace stackTrace) {
          // The reason a video will not play is only ever visible here — the
          // screens used to swallow it with `catch (_)`.
          debugPrint('[VIDEO] attempt failed for $url: $error');
        },
      );

      _controller = controller;
      _isInitializing = false;

      if (!mounted) {
        await controller.dispose();
        return;
      }

      await controller.setLooping(true);

      // The user may have swiped away while this was buffering — only the page
      // on screen is allowed to start playing.
      if (widget.isActive) {
        await controller.play();
      }

      setState(() {
        _isInitialized = true;
      });
    } catch (error) {
      _isInitializing = false;

      debugPrint('[VIDEO] every attempt failed for $url: $error');

      if (!mounted) return;

      setState(() {
        _hasError = true;
      });
    }
  }

  Future<void> _play() async {
    final VideoPlayerController? controller = _controller;
    if (controller == null || !_isInitialized) return;

    try {
      await controller.play();
    } catch (_) {
      // The controller was torn down between the check and the call.
    }
  }

  Future<void> _pause() async {
    final VideoPlayerController? controller = _controller;
    if (controller == null || !_isInitialized) return;

    try {
      await controller.pause();
    } catch (_) {
      // The controller was torn down between the check and the call.
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildMedia(),
        _buildTopGradient(),
        _buildBottomGradient(),
        _buildCloseButton(),
        _buildInfo(),
      ],
    );
  }

  /// The neutral "no picture here" panel.
  Widget _buildPlaceholder() {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        color: Colors.white,
        size: 50,
      ),
    );
  }

  Widget _buildMedia() {
    if (!widget.item.isVideo) {
      final String url = widget.item.image.trim();

      // `Image.network('')` resolves against the app's base uri, so it fires a
      // pointless request for the app itself and only then falls back to the
      // error builder. Short-circuit instead.
      if (url.isEmpty) return _buildPlaceholder();

      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildPlaceholder(),
      );
    }

    if (_hasError) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const Icon(
          Icons.error_outline_rounded,
          color: Colors.white,
          size: 50,
        ),
      );
    }

    if (!_isInitialized ||
        _controller == null) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio:
            _controller!.value.aspectRatio,
        child: VideoPlayer(_controller!),
      ),
    );
  }

  Widget _buildTopGradient() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 150.h,
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
      height: 280.h,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withValues(alpha: 0.85),
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

  Widget _buildInfo() {
    return Positioned(
      left: 20.w,
      right: 20.w,
      bottom: 28.h,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            _buildTeacherRow(),

            SizedBox(height: 12.h),

            Text(
              widget.item.description,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'Shabnam',
                fontSize: 15.sp,
                color: Colors.white,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The owner's avatar + name, shown above the description.
  Widget _buildTeacherRow() {
    final Teacher teacher = widget.teacher;

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        ClipOval(
          child: Image.network(
            teacher.profileImage,
            width: 46.w,
            height: 46.w,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) {
              return Container(
                width: 46.w,
                height: 46.w,
                color: AppColors.field,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.textSecondary,
                ),
              );
            },
          ),
        ),

        SizedBox(width: 10.w),

        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  'استاد ${teacher.fullName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'bShabnam',
                    fontSize: 16.sp,
                    color: Colors.white,
                  ),
                ),
              ),

              if (teacher.isVerified)
                Padding(
                  padding: EdgeInsets.only(right: 6.w),
                  child: Icon(
                    Icons.verified_rounded,
                    color: Colors.blue,
                    size: 19.sp,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}