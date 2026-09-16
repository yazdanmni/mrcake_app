import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';


class HomeQuickActions extends StatelessWidget {
  final VoidCallback? onCoursesTap;
  final VoidCallback? onTeachersTap;
  final VoidCallback? onStudentsTap;
  final VoidCallback? onRecipesTap;

  const HomeQuickActions({
    super.key,
    this.onCoursesTap,
    this.onTeachersTap,
    this.onStudentsTap,
    this.onRecipesTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        final double width = constraints.maxWidth;

        final double horizontalGap =
            width < 360 ? 8 : 10;

        return Row(
          textDirection: TextDirection.rtl,
          children: [
            Expanded(
              child: _QuickActionItem(
                icon: Icons.auto_stories_rounded,
                title: 'دوره‌ها',
                onTap: onCoursesTap,
              ),
            ),

            SizedBox(width: horizontalGap),

            Expanded(
              child: _QuickActionItem(
                icon: Icons.school_rounded,
                title: 'استاد',
                onTap: onTeachersTap,
              ),
            ),

            SizedBox(width: horizontalGap),

            Expanded(
              child: _QuickActionItem(
                icon: Icons.groups_rounded,
                title: 'هنرجوها',
                onTap: onStudentsTap,
              ),
            ),

            SizedBox(width: horizontalGap),

            Expanded(
              child: _QuickActionItem(
                icon: Icons.menu_book_rounded,
                title: 'رسپی‌ها',
                onTap: onRecipesTap,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ================================================================
// QUICK ACTION ITEM
// ================================================================

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const _QuickActionItem({
    required this.icon,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor:
            AppColors.primary.withOpacity(0.10),
        highlightColor:
            AppColors.primary.withOpacity(0.05),
        child: Ink(
          height: 85.h,
          width: 85.w,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.border,
              width: 2.w,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 9,
            ),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                // ==================================================
                // ICON
                // ==================================================

                Container(
                  width: 37.w,
                  height: 37.h,
                  decoration: BoxDecoration(
                    color: AppColors.primary
                        .withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: 22.sp,
                    color: AppColors.primary,
                  ),
                ),

                const SizedBox(height: 6),

                // ==================================================
                // TITLE
                // ==================================================

                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style:  TextStyle(
                    fontFamily: 'Shabnam',
                    fontSize: 16.sp,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}