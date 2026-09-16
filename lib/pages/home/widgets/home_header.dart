import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';

/// Top bar: notifications, support, greeting, and profile avatar.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 25.w,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderIcon(
                icon: Icons.notifications_none_rounded,
                onTap: () {},
              ),

              SizedBox(width: 8.w),

              _HeaderIcon(
                icon: Icons.headset_mic_outlined,
                onTap: () {},
              ),
            ],
          ),

          const Spacer(),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    textDirection: TextDirection.rtl,
                    children: [
                      Text(
                        'سلام',
                        style: TextStyle(
                          fontFamily: 'pinarb',
                          fontSize: 20.sp,
                          color: AppColors.textPrimary,
                        ),
                      ),

                      SizedBox(width: 4.w),

                      Text(
                        'جواد',
                        style: TextStyle(
                          fontFamily: 'pinarb',
                          fontSize: 20.sp,
                          color: AppColors.textPrimary
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 4.h),

                  Text(
                    'خوش اومدی 👋',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'shabnam',
                      fontSize: 20.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              SizedBox(width: 10.w),

              Container(
                width: 66.w,
                height: 66.h,
                decoration:  BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.field,
                  border: Border.all(
                    color: AppColors.border,
                    width: 2.w
                  )
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/profile.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.person,
                        size: 34.sp,
                        color: AppColors.textPrimary,
                      );
                    },
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

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIcon({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50.w,
        height: 50.h,
        decoration: BoxDecoration(
          color: AppColors.field,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.border,
            width: 2.w,
          ),
        ),
        child: Icon(
          icon,
          size: 34.sp,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}