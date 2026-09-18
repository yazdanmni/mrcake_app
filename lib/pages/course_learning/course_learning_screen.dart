import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/models/course.dart';
import 'package:mr_cake_project/models/course_details.dart';
import 'package:mr_cake_project/pages/course_learning/lesson_screen.dart';

class CourseLearningScreen extends StatefulWidget {
  final Course course;
  final CourseDetails details;

  const CourseLearningScreen({
    super.key,
    required this.course,
    required this.details,
  });

  @override
  State<CourseLearningScreen> createState() =>
      _CourseLearningScreenState();
}

class _CourseLearningScreenState
    extends State<CourseLearningScreen> {
  final Set<int> _openedChapters = {};

  void _toggleChapter(int chapterId) {
    setState(() {
      if (_openedChapters.contains(chapterId)) {
        _openedChapters.remove(chapterId);
      } else {
        _openedChapters.add(chapterId);
      }
    });
  }

  void _openLesson(CourseLesson lesson) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LessonScreen(
          course: widget.course,
          lesson: lesson,
        ),
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
                title: widget.course.title,
              ),

              Expanded(
                child: widget.details.chapters.isEmpty
                    ? const _EmptyChapters()
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          20.w,
                          18.h,
                          20.w,
                          30.h,
                        ),
                        physics:
                            const BouncingScrollPhysics(),
                        itemCount:
                            widget.details.chapters.length,
                        itemBuilder: (context, index) {
                          final chapter =
                              widget.details.chapters[index];

                          final isOpen =
                              _openedChapters.contains(
                            chapter.id,
                          );

                          return _Chapter(
                            chapter: chapter,
                            isOpen: isOpen,
                            onTap: () =>
                                _toggleChapter(chapter.id),
                            onLessonTap: _openLesson,
                          );
                        },
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
  final String title;

  const _Header({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20.w,
        12.h,
        20.w,
        8.h,
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'pinarb',
                fontSize: 22.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          SizedBox(width: 12.w),

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
          color: AppColors.premium.withOpacity(0.12),
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
// CHAPTER
// ============================================================================

class _Chapter extends StatelessWidget {
  final CourseChapter chapter;
  final bool isOpen;
  final VoidCallback onTap;
  final ValueChanged<CourseLesson> onLessonTap;

  const _Chapter({
    required this.chapter,
    required this.isOpen,
    required this.onTap,
    required this.onLessonTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Row(
              textDirection: TextDirection.rtl,
              crossAxisAlignment:
                  CrossAxisAlignment.center,
              children: [
                // =========================================================
                // NUMBER
                // =========================================================

                Container(
                  width: 38.w,
                  height: 38.w,
                  decoration: BoxDecoration(
                    color: AppColors.field,
                    borderRadius:
                        BorderRadius.circular(9.r),
                    border: Border.all(
                      color: AppColors.premium,
                      width: 1.2.w,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    chapter.number
                        .toString()
                        .padLeft(2, '0'),
                    style: TextStyle(
                      fontFamily: 'bshabnam',
                      fontSize: 17.sp,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                SizedBox(width: 8.w),

                // =========================================================
                // TITLE
                // =========================================================

                Expanded(
                  child: Container(
                    height: 38.h,
                    decoration: BoxDecoration(
                      color: AppColors.field,
                      borderRadius:
                          BorderRadius.circular(9.r),
                      border: Border.all(
                        color: AppColors.primary,
                        width: 1.2.w,
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: 11.w,
                    ),
                    child: Row(
                      textDirection:
                          TextDirection.rtl,
                      children: [
                        Expanded(
                          child: Text(
                            chapter.title,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontFamily: 'bshabnam',
                              fontSize: 18.sp,
                              color:
                                  AppColors.textPrimary,
                            ),
                          ),
                        ),

                        SizedBox(width: 7.w),

                        AnimatedRotation(
                          turns: isOpen ? 0.5 : 0,
                          duration:
                              const Duration(
                            milliseconds: 220,
                          ),
                          child: Icon(
                            Icons
                                .keyboard_arrow_down_rounded,
                            size: 22.sp,
                            color:
                                AppColors.premium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ==============================================================
          // LESSONS
          // ==============================================================

          AnimatedSize(
            duration:
                const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: isOpen
                ? Padding(
                    padding: EdgeInsets.only(
                      top: 8.h,
                      right: 46.w,
                    ),
                    child: Column(
                      children: List.generate(
                        chapter.lessons.length,
                        (index) {
                          final lesson =
                              chapter.lessons[index];

                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index ==
                                      chapter.lessons
                                              .length -
                                          1
                                  ? 0
                                  : 5.h,
                            ),
                            child: _LessonItem(
                              lesson: lesson,
                              onTap: () =>
                                  onLessonTap(lesson),
                            ),
                          );
                        },
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// LESSON
// ============================================================================

class _LessonItem extends StatelessWidget {
  final CourseLesson lesson;
  final VoidCallback onTap;

  const _LessonItem({
    required this.lesson,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 42.h,
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius:
              BorderRadius.circular(9.r),
          border: Border.all(
            color: AppColors.premium,
            width: 1.w,
          ),
        ),
        padding: EdgeInsets.only(
          right: 10.w,
          left: 7.w,
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Expanded(
              child: Text(
                lesson.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'bshabnam',
                  fontSize: 16.sp,
                  color: AppColors.textSecondary,
                ),
              ),
            ),

            SizedBox(width: 6.w),

            if (lesson.duration.isNotEmpty &&
                lesson.duration != '0')
              Text(
                lesson.duration,
                style: TextStyle(
                  fontFamily: 'bshabnam',
                  fontSize: 12.sp,
                  color: AppColors.textSecondary
                      .withOpacity(0.75),
                ),
              ),

            SizedBox(width: 7.w),

            Container(
              width: 30.w,
              height: 30.w,
              decoration: BoxDecoration(
                color: AppColors.premium
                    .withOpacity(0.14),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.premium,
                  width: 1.w,
                ),
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                size: 18.sp,
                color: AppColors.premium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY
// ============================================================================

class _EmptyChapters extends StatelessWidget {
  const _EmptyChapters();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'هنوز سرفصلی برای این دوره ثبت نشده است.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'bshabnam',
          fontSize: 16.sp,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}