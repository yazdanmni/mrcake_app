import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:video_player/video_player.dart';

import 'package:mr_cake_project/core/network/remote_data.dart';
import 'package:mr_cake_project/core/session/session_manager.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/models/course.dart';
import 'package:mr_cake_project/models/course_details.dart';
import 'package:mr_cake_project/repositories/catalog_repository.dart';

class LessonScreen extends StatefulWidget {
  final Course course;
  final CourseLesson lesson;

  const LessonScreen({
    super.key,
    required this.course,
    required this.lesson,
  });

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  int _selectedTab = 0;

  /// جزئیات کامل قسمت؛ ابتدا همان موردی که از لیست آمده و سپس پاسخ بک‌اند.
  late CourseLesson _lesson;

  bool _reportedCompletion = false;

  @override
  void initState() {
    super.initState();

    _lesson = widget.lesson;

    _loadLesson();
  }

  Future<void> _loadLesson() async {
    final result = await RemoteLoader.value<CourseLesson>(
      label: 'lesson.detail',
      seed: _lesson,
      fetch: () => CatalogRepository.instance.fetchLesson(widget.lesson.id),
    );

    if (!mounted) return;

    final loaded = result.data;
    if (loaded == null) return;

    setState(() => _lesson = loaded);
  }

  /// وقتی ویدیو به پایان می‌رسد، قسمت به عنوان دیده‌شده ثبت می‌شود.
  Future<void> _markCompleted() async {
    if (_reportedCompletion) return;
    if (!SessionManager.instance.isLoggedIn) return;

    _reportedCompletion = true;

    await RemoteLoader.action(
      'lesson.mark',
      () => CatalogRepository.instance.markLesson(
        courseId: widget.course.id,
        lessonId: _lesson.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _Header(
                courseTitle: widget.course.title,
                lessonTitle: _lesson.title,
              ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      SizedBox(height: 12.h),

                      _IntroVideo(
                        imageUrl: widget.course.image,
                        videoUrl: _lesson.video,
                        onCompleted: _markCompleted,
                      ),

                      SizedBox(height: 33.h),

                      _TabsBar(
                        selectedIndex: _selectedTab,
                        onChanged: (index) {
                          setState(() {
                            _selectedTab = index;
                          });
                        },
                      ),

                      SizedBox(height: 12.h),

                      if (_selectedTab == 0)
                        _DescriptionSection(
                          description:
                              _lesson.description,
                        )
                      else
                        _IngredientsSection(
                          ingredients:
                              _lesson.ingredients,
                        ),

                      SizedBox(height: 30.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// HEADER
// ============================================================================

class _Header extends StatelessWidget {
  final String courseTitle;
  final String lessonTitle;

  const _Header({
    required this.courseTitle,
    required this.lessonTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20.w,
        12.h,
        20.w,
        0,
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
  child: RichText(
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    textAlign: TextAlign.right,
    text: TextSpan(
      children: [
        TextSpan(
          text: '$courseTitle - ',
          style: TextStyle(
            fontFamily: 'pinarb',
            fontSize: 18.sp,
            color: AppColors.textPrimary,
          ),
        ),
        TextSpan(
          text: lessonTitle,
          style: TextStyle(
            fontFamily: 'pinarr',
            fontSize: 16.sp,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  ),
),

          SizedBox(width: 10.w),

          const _BackButton(),
        ],
      ),
    );
  }
}

// ============================================================================
// BACK BUTTON
// ============================================================================

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).pop();
      },
      child: Container(
        width: 44.w,
        height: 44.w,
        decoration: BoxDecoration(
          color: AppColors.premium.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: AppColors.premium,
            width: 1.5.w,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 19.sp,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

// ============================================================================
// TABS BAR
// ============================================================================

class _TabsBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _TabsBar({
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54.h,
      margin: EdgeInsets.symmetric(horizontal: 25.w),
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(100.r),
        border: Border.all(
          color: AppColors.premium,
          width: 1.w,
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: _TabItem(
              title: 'توضیحات',
              active: selectedIndex == 0,
              onTap: () => onChanged(0),
            ),
          ),

          SizedBox(width: 6.w),

          Expanded(
            child: _TabItem(
              title: 'مواد اولیه',
              active: selectedIndex == 1,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB ITEM
// ============================================================================

class _TabItem extends StatelessWidget {
  final String title;
  final bool active;
  final VoidCallback onTap;

  const _TabItem({
    required this.title,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          color: active
              ? AppColors.premium
              : Colors.transparent,
          borderRadius: BorderRadius.circular(100.r),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontFamily: active
                ? 'bshabnam'
                : 'shabnam',
            fontSize: 18.sp,
            fontWeight: active
                ? FontWeight.w600
                : FontWeight.w400,
            color: active
                ? AppColors.white
                : AppColors.premium,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// DESCRIPTION
// ============================================================================

class _DescriptionSection extends StatelessWidget {
  final String description;

  const _DescriptionSection({
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    if (description.trim().isEmpty) {
      return _EmptyContent(
        text: 'توضیحاتی برای این قسمت ثبت نشده است.',
      );
    }

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 25.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: AppColors.premium,
          width: 1.w,
        ),
      ),
      child: Text(
        description,
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: 'shabnam',
          fontSize: 14.sp,
          color: AppColors.textSecondary,
          height: 1.8,
        ),
      ),
    );
  }
}

// ============================================================================
// INGREDIENTS SECTION
// ============================================================================

class _IngredientsSection extends StatelessWidget {
  final List<CourseIngredient> ingredients;

  const _IngredientsSection({
    required this.ingredients,
  });

  @override
  Widget build(BuildContext context) {
    if (ingredients.isEmpty) {
      return _EmptyContent(
        text: 'مواد اولیه‌ای برای این قسمت ثبت نشده است.',
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w),
      child: Column(
        children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _IngredientHeader(
                    title: 'مقدار',
                    color: AppColors.primary,
                  ),
                ),

                SizedBox(width: 10.w),

                Expanded(
                  child: _IngredientHeader(
                    title: 'مواد لازم',
                    color: AppColors.premium,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 11.h),

          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _IngredientColumn(
                    ingredients: ingredients,
                    showAmount: true,
                  ),
                ),

                SizedBox(width: 10.w),

                Expanded(
                  child: _IngredientColumn(
                    ingredients: ingredients,
                    showAmount: false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// INGREDIENT HEADER
// ============================================================================

class _IngredientHeader extends StatelessWidget {
  final String title;
  final Color color;

  const _IngredientHeader({
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 33.h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8.r),
      ),
      alignment: Alignment.center,
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'bShabnam',
          fontSize: 15.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.white,
          height: 1,
        ),
      ),
    );
  }
}

// ============================================================================
// INGREDIENT COLUMN
// ============================================================================

class _IngredientColumn extends StatelessWidget {
  final List<CourseIngredient> ingredients;
  final bool showAmount;

  const _IngredientColumn({
    required this.ingredients,
    required this.showAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      textDirection: TextDirection.rtl,
      children: List.generate(
        ingredients.length,
        (index) {
          final ingredient = ingredients[index];

          return Padding(
            padding: EdgeInsets.only(
              bottom: index ==
                      ingredients.length - 1
                  ? 0
                  : 6.h,
            ),
            child: _IngredientItem(
              text: showAmount
                  ? ingredient.amount
                  : ingredient.name,
              borderColor: showAmount
                  ? AppColors.primary
                  : AppColors.premium,
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// INGREDIENT ITEM
// ============================================================================

class _IngredientItem extends StatelessWidget {
  final String text;
  final Color borderColor;

  const _IngredientItem({
    required this.text,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: 36.h,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 10.w,
        vertical: 7.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: borderColor,
          width: 2.w,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'bShabnam',
          fontSize: 15.sp,
          color: AppColors.textPrimary,
          height: 1.25,
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY CONTENT
// ============================================================================

class _EmptyContent extends StatelessWidget {
  final String text;

  const _EmptyContent({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 25.w),
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: AppColors.premium,
          width: 1.w,
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'shabnam',
          fontSize: 14.sp,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ============================================================================
// INTRO VIDEO
// ============================================================================

class _IntroVideo extends StatefulWidget {
  final String imageUrl;
  final String videoUrl;

  /// وقتی ویدیو تا انتها دیده شد فراخوانی می‌شود.
  final VoidCallback? onCompleted;

  const _IntroVideo({
    required this.imageUrl,
    required this.videoUrl,
    this.onCompleted,
  });

  @override
  State<_IntroVideo> createState() =>
      _IntroVideoState();
}

class _IntroVideoState extends State<_IntroVideo> {
  VideoPlayerController? _controller;

  bool _initialized = false;
  bool _hasError = false;
  bool _isLoading = true;

  /// فقط یک بار گزارش «دیده شد» فرستاده می‌شود.
  bool _reportedCompletion = false;

  bool _showControls = true;

  Timer? _controlsTimer;

  bool _wasPlayingBeforeBuffering = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    final url = widget.videoUrl.trim();

    if (url.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      return;
    }

    try {
      final uri = Uri.tryParse(url);

      if (uri == null || !uri.hasScheme) {
        throw Exception(
          'Invalid video URL: $url',
        );
      }

      final controller =
          VideoPlayerController.networkUrl(uri);

      _controller = controller;

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      controller.addListener(_videoListener);

      setState(() {
        _initialized = true;
        _isLoading = false;
        _hasError = false;
      });

      _startControlsTimer();
    } catch (e, stackTrace) {
      debugPrint(
        '================================================',
      );
      debugPrint('LESSON VIDEO ERROR');
      debugPrint('URL: $url');
      debugPrint('ERROR: $e');
      debugPrint('STACK: $stackTrace');
      debugPrint(
        '================================================',
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _videoListener() {
    final controller = _controller;

    if (!mounted || controller == null) {
      return;
    }

    final value = controller.value;

    if (value.hasError) {
      if (!_hasError) {
        setState(() {
          _hasError = true;
        });
      }

      return;
    }

    // پایان ویدیو = مشاهده قسمت؛ یک بار به بک‌اند گزارش می‌شود.
    if (!_reportedCompletion &&
        value.isInitialized &&
        value.duration > Duration.zero &&
        value.position >= value.duration) {
      _reportedCompletion = true;
      widget.onCompleted?.call();
    }

    if (value.isBuffering) {
      if (value.isPlaying) {
        _wasPlayingBeforeBuffering = true;
      }
    } else {
      if (_wasPlayingBeforeBuffering &&
          !value.isPlaying) {
        controller.play();
      }

      _wasPlayingBeforeBuffering = false;
    }

    setState(() {});
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();

    final controller = _controller;

    if (controller == null ||
        !controller.value.isPlaying) {
      return;
    }

    _controlsTimer = Timer(
      const Duration(seconds: 3),
      () {
        if (!mounted) return;

        setState(() {
          _showControls = false;
        });
      },
    );
  }

  void _showControlsTemporarily() {
    _controlsTimer?.cancel();

    if (!_showControls) {
      setState(() {
        _showControls = true;
      });
    }

    _startControlsTimer();
  }

  void _handleVideoTap() {
    final controller = _controller;

    if (controller == null || !_initialized) {
      return;
    }

    if (!_showControls) {
      _showControlsTemporarily();
      return;
    }

    setState(() {
      _showControls = false;
    });

    _controlsTimer?.cancel();
  }

  Future<void> _togglePlay() async {
    final controller = _controller;

    if (controller == null || !_initialized) {
      return;
    }

    if (controller.value.isPlaying) {
      await controller.pause();

      _controlsTimer?.cancel();

      if (mounted) {
        setState(() {
          _showControls = true;
        });
      }
    } else {
      await controller.play();

      if (mounted) {
        setState(() {
          _showControls = true;
        });
      }

      _startControlsTimer();
    }
  }

  Future<void> _toggleVolume() async {
    final controller = _controller;

    if (controller == null || !_initialized) {
      return;
    }

    final newVolume =
        controller.value.volume > 0 ? 0.0 : 1.0;

    await controller.setVolume(newVolume);

    if (mounted) {
      setState(() {
        _showControls = true;
      });

      _startControlsTimer();
    }
  }

  Future<void> _openFullscreen() async {
    final controller = _controller;

    if (controller == null || !_initialized) {
      return;
    }

    _controlsTimer?.cancel();

    final wasPlaying =
        controller.value.isPlaying;

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );

    if (!mounted) return;

    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder: (
          context,
          animation,
          secondaryAnimation,
        ) {
          return _FullscreenVideoPage(
            controller: controller,
            wasPlaying: wasPlaying,
          );
        },
        transitionsBuilder: (
          context,
          animation,
          secondaryAnimation,
          child,
        ) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );

    if (!mounted) return;

    setState(() {
      _showControls = true;
    });

    _startControlsTimer();
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();

    _controller?.removeListener(_videoListener);
    _controller?.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Container(
      height: 201.h,
      margin: EdgeInsets.symmetric(
        horizontal: 25.w,
      ),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_initialized &&
              controller != null)
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width:
                    controller.value.size.width,
                height:
                    controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            )
          else
            Image.network(
              widget.imageUrl,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (
                context,
                error,
                stackTrace,
              ) {
                return Container(
                  color: AppColors.field,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons
                        .video_library_outlined,
                    size: 40.sp,
                    color:
                        AppColors.textSecondary,
                  ),
                );
              },
            ),

          if (_initialized && !_hasError)
            Positioned.fill(
              child: GestureDetector(
                behavior:
                    HitTestBehavior.opaque,
                onTap: _handleVideoTap,
              ),
            ),

          IgnorePointer(
            child: AnimatedOpacity(
              duration:
                  const Duration(milliseconds: 250),
              opacity:
                  _showControls ? 1 : 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient:
                      LinearGradient(
                    begin:
                        Alignment.topCenter,
                    end:
                        Alignment.bottomCenter,
                    colors: [
                      Colors.black
                          .withValues(alpha: 0.06),
                      Colors.black
                          .withValues(alpha: 0.38),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (_isLoading)
            Center(
              child: SizedBox(
                width: 28.w,
                height: 28.w,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2.2.w,
                  color: AppColors.white,
                ),
              ),
            ),

          if (_initialized &&
              controller != null &&
              controller.value.isBuffering)
            Center(
              child: Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: Colors.black
                      .withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: SizedBox(
                  width: 22.w,
                  height: 22.w,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2.2.w,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),

          if (_initialized &&
              !_hasError &&
              !(_controller?.value.isPlaying ??
                  false))
            Center(
              child: AnimatedOpacity(
                duration:
                    const Duration(milliseconds: 200),
                opacity:
                    _showControls ? 1 : 0,
                child: GestureDetector(
                  behavior:
                      HitTestBehavior.opaque,
                  onTap: _togglePlay,
                  child: ClipOval(
                    child: BackdropFilter(
                      filter:
                          ImageFilter.blur(
                        sigmaX: 10,
                        sigmaY: 10,
                      ),
                      child: Container(
                        width: 58.w,
                        height: 58.w,
                        decoration:
                            BoxDecoration(
                          color: Colors.white
                              .withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white
                                .withValues(alpha: 0.55),
                            width: 1.w,
                          ),
                        ),
                        alignment:
                            Alignment.center,
                        child: Icon(
                          Icons
                              .play_arrow_rounded,
                          color:
                              AppColors.white,
                          size: 32.sp,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          if (_initialized &&
              controller != null &&
              !_hasError)
            Positioned(
              left: 14.w,
              right: 14.w,
              bottom: 10.h,
              child: AnimatedOpacity(
                duration:
                    const Duration(milliseconds: 250),
                opacity:
                    _showControls ? 1 : 0,
                child: IgnorePointer(
                  ignoring:
                      !_showControls,
                  child: Column(
                    children: [
                      VideoProgressIndicator(
                        controller,
                        allowScrubbing: true,
                        padding: EdgeInsets.zero,
                        colors:
                            VideoProgressColors(
                          playedColor:
                              AppColors.premium,
                          bufferedColor:
                              Colors.white
                                  .withValues(alpha: 
                            0.35,
                          ),
                          backgroundColor:
                              Colors.white
                                  .withValues(alpha: 
                            0.22,
                          ),
                        ),
                      ),

                      SizedBox(height: 7.h),

                      Row(
                        textDirection:
                            TextDirection.ltr,
                        children: [
                          GestureDetector(
                            onTap:
                                _togglePlay,
                            child: Icon(
                              controller
                                      .value
                                      .isPlaying
                                  ? Icons
                                      .pause_rounded
                                  : Icons
                                      .play_arrow_rounded,
                              color:
                                  AppColors.white,
                              size: 21.sp,
                            ),
                          ),

                          SizedBox(width: 10.w),

                          Text(
                            _formatDuration(
                              controller
                                  .value
                                  .position,
                            ),
                            style: TextStyle(
                              fontFamily:
                                  'shabnam',
                              fontSize: 11.sp,
                              color:
                                  AppColors.white,
                            ),
                          ),

                          const Spacer(),

                          Text(
                            _formatDuration(
                              controller
                                  .value
                                  .duration,
                            ),
                            style: TextStyle(
                              fontFamily:
                                  'shabnam',
                              fontSize: 11.sp,
                              color:
                                  AppColors.white,
                            ),
                          ),

                          SizedBox(width: 12.w),

                          GestureDetector(
                            onTap:
                                _toggleVolume,
                            child: Icon(
                              controller
                                          .value
                                          .volume >
                                      0
                                  ? Icons
                                      .volume_up_rounded
                                  : Icons
                                      .volume_off_rounded,
                              color:
                                  AppColors.white,
                              size: 20.sp,
                            ),
                          ),

                          SizedBox(width: 12.w),

                          GestureDetector(
                            onTap:
                                _openFullscreen,
                            child: Icon(
                              Icons
                                  .fullscreen_rounded,
                              color:
                                  AppColors.white,
                              size: 22.sp,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_hasError)
            Center(
              child: Padding(
                padding:
                    EdgeInsets.symmetric(
                  horizontal: 20.w,
                ),
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Icon(
                      Icons
                          .error_outline_rounded,
                      color:
                          AppColors.white,
                      size: 32.sp,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'پخش ویدیو امکان‌پذیر نیست',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        fontFamily:
                            'shabnam',
                        fontSize: 12.sp,
                        color:
                            AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(
    Duration duration,
  ) {
    final hours = duration.inHours;
    final minutes =
        duration.inMinutes.remainder(60);
    final seconds =
        duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}

// ============================================================================
// FULLSCREEN VIDEO
// ============================================================================

class _FullscreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;
  final bool wasPlaying;

  const _FullscreenVideoPage({
    required this.controller,
    required this.wasPlaying,
  });

  @override
  State<_FullscreenVideoPage> createState() =>
      _FullscreenVideoPageState();
}

class _FullscreenVideoPageState
    extends State<_FullscreenVideoPage> {
  bool _showControls = true;
  Timer? _controlsTimer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _controlsTimer?.cancel();

    if (!widget.controller.value.isPlaying) {
      return;
    }

    _controlsTimer = Timer(
      const Duration(seconds: 3),
      () {
        if (!mounted) return;

        setState(() {
          _showControls = false;
        });
      },
    );
  }

  void _toggleControls() {
    if (!_showControls) {
      setState(() {
        _showControls = true;
      });

      _startTimer();
      return;
    }

    setState(() {
      _showControls = false;
    });

    _controlsTimer?.cancel();
  }

  Future<void> _togglePlay() async {
    if (widget.controller.value.isPlaying) {
      await widget.controller.pause();

      _controlsTimer?.cancel();

      if (mounted) {
        setState(() {
          _showControls = true;
        });
      }
    } else {
      await widget.controller.play();

      if (mounted) {
        setState(() {
          _showControls = true;
        });
      }

      _startTimer();
    }
  }

  void _exitFullscreen() {
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
    final controller = widget.controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio:
                  controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),

          Positioned.fill(
            child: GestureDetector(
              behavior:
                  HitTestBehavior.opaque,
              onTap: _toggleControls,
            ),
          ),

          IgnorePointer(
            child: AnimatedOpacity(
              duration:
                  const Duration(milliseconds: 250),
              opacity:
                  _showControls ? 1 : 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient:
                      LinearGradient(
                    begin:
                        Alignment.topCenter,
                    end:
                        Alignment.bottomCenter,
                    colors: [
                      Colors.black
                          .withValues(alpha: 0.45),
                      Colors.transparent,
                      Colors.black
                          .withValues(alpha: 0.5),
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
                child:
                    CircularProgressIndicator(
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
              duration:
                  const Duration(milliseconds: 250),
              opacity:
                  _showControls ? 1 : 0,
              child: GestureDetector(
                onTap: _exitFullscreen,
                child: Container(
                  width: 42.w,
                  height: 42.w,
                  decoration: BoxDecoration(
                    color: Colors.black
                        .withValues(alpha: 0.35),
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
                duration:
                    const Duration(milliseconds: 200),
                opacity:
                    _showControls ? 1 : 0,
                child: GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 62.w,
                    height: 62.w,
                    decoration: BoxDecoration(
                      color: Colors.white
                          .withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white
                            .withValues(alpha: 0.55),
                      ),
                    ),
                    alignment:
                        Alignment.center,
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
              duration:
                  const Duration(milliseconds: 250),
              opacity:
                  _showControls ? 1 : 0,
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Column(
                  children: [
                    VideoProgressIndicator(
                      controller,
                      allowScrubbing: true,
                      padding: EdgeInsets.zero,
                      colors:
                          VideoProgressColors(
                        playedColor:
                            AppColors.premium,
                        bufferedColor:
                            Colors.white
                                .withValues(alpha: 
                          0.35,
                        ),
                        backgroundColor:
                            Colors.white
                                .withValues(alpha: 
                          0.22,
                        ),
                      ),
                    ),

                    SizedBox(height: 10.h),

                    Row(
                      children: [
                        GestureDetector(
                          onTap:
                              _togglePlay,
                          child: Icon(
                            controller
                                    .value
                                    .isPlaying
                                ? Icons
                                    .pause_rounded
                                : Icons
                                    .play_arrow_rounded,
                            color: Colors.white,
                            size: 25.sp,
                          ),
                        ),

                        SizedBox(width: 12.w),

                        Text(
                          _formatDuration(
                            controller
                                .value
                                .position,
                          ),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                          ),
                        ),

                        const Spacer(),

                        Text(
                          _formatDuration(
                            controller
                                .value
                                .duration,
                          ),
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

  String _formatDuration(
    Duration duration,
  ) {
    final hours = duration.inHours;
    final minutes =
        duration.inMinutes.remainder(60);
    final seconds =
        duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}
