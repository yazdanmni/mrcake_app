import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';

/// Header of the courses screen.
///
/// That screen is reachable **two** ways: as a bottom-navigation tab, and as a
/// push from the home screen («مشاهده همه», the «دوره‌ها» shortcut, a category).
/// A tab must not offer a way "back" — there is nothing behind it — while a
/// pushed screen must. `Navigator.canPop` is exactly that distinction:
/// `MainBottomNavigation` is installed with `pushAndRemoveUntil(_, (_) => false)`,
/// so as a tab the courses screen is the only route and `canPop` is `false`,
/// while every `AppRouter.toCourses` puts it on top of an existing stack and
/// `canPop` is `true`.
class CoursesHeader extends StatelessWidget {
  const CoursesHeader({super.key, this.onCartTap});

  final VoidCallback? onCartTap;

  @override
  Widget build(BuildContext context) {
    // Read, never pushed: this is the same check `AppBar` makes to decide
    // whether to imply a leading back button.
    final bool showBack = Navigator.of(context).canPop();

    return Padding(
      padding: EdgeInsets.only(
        top: 10.h,
        right: 25.w,
        left: 25.w,
        bottom: 25.h,
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'دوره ها',
            style: TextStyle(
              fontSize: 20.sp,
              fontFamily: 'pinarb',
              color: AppColors.textPrimary,
            ),
          ),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Only when the screen was pushed. The title stays pinned to the
              // right either way, so opening courses from a tab looks exactly
              // as it always did.
              if (showBack) ...[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 38.w,
                    height: 38.w,
                    decoration: BoxDecoration(
                      color: AppColors.premium.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.premium,
                        width: 1.5.w,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.arrow_back_ios_rounded,
                      size: 17.sp,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
              ],

              GestureDetector(
                onTap: onCartTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 38.w,
                  height: 38.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.field,
                    border: Border.all(color: AppColors.premium, width: 2),
                  ),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    size: 25.sp,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
