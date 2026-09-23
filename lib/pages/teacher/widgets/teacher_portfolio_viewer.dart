import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/models/teacher_model.dart';
import 'package:video_player/video_player.dart';

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
          );
        },
      ),
    );
  }
}

class _PortfolioItem extends StatefulWidget {
  final Teacher teacher;
  final TeacherPortfolioItem item;

  const _PortfolioItem({
    super.key,
    required this.teacher,
    required this.item,
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

  @override
  void initState() {
    super.initState();

    if (widget.item.isVideo) {
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    final String url =
        (widget.item.videoUrl ?? '').trim();

    if (url.isEmpty) {
      setState(() {
        _hasError = true;
      });
      return;
    }

    final controller =
        VideoPlayerController.networkUrl(
      Uri.parse(url),
    );

    _controller = controller;

    try {
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      await controller.setLooping(true);
      await controller.play();

      setState(() {
        _isInitialized = true;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _hasError = true;
      });
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

  Widget _buildMedia() {
    if (!widget.item.isVideo) {
      return Image.network(
        widget.item.image,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
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
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.start,
              children: [
                ClipOval(
                  child: Image.network(
                    widget.teacher.profileImage,
                    width: 46.w,
                    height: 46.w,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
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
                          'استاد ${widget.teacher.fullName}',
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'bShabnam',
                            fontSize: 16.sp,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      if (widget.teacher.isVerified)
                        Padding(
                          padding:
                              EdgeInsets.only(
                            right: 6.w,
                          ),
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
            ),

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
}