import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';

/// Kitchen illustration and the "start learning" CTA.
class HomeHero extends StatelessWidget {
  const HomeHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w),
      child: AspectRatio(
        aspectRatio: 376 / 344,
        child: Column(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/home_hero.png',
                fit: BoxFit.contain,
              ),
            ),

            Padding(
              padding: EdgeInsets.only(top: 16.h),
              child: SizedBox(
                width: 160.w,
                height: 43.h,
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Center(
                      child: Text(
                        'شروع یادگیری',
                        style: TextStyle(
                          color: AppColors.white,
                          fontFamily: 'pinarb',
                          fontSize: 16.sp,
                        ),
                      ),
                    ),
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
