import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';

class CoursesHeader extends StatelessWidget {
  const CoursesHeader({super.key, this.onCartTap});

  final VoidCallback? onCartTap;

  @override
  Widget build(BuildContext context) {
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
    );
  }
}
