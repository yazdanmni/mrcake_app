import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';

class PopularCategories extends StatelessWidget {
  final List<String> categories;
  final ValueChanged<String> onCategorySelected;

  const PopularCategories({
    super.key,
    required this.categories,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'دسته‌بندی‌های محبوب',
          style: TextStyle(
            fontFamily: 'PinarB',
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),

        SizedBox(height: 14.h),

        Wrap(
          spacing: 9.w,
          runSpacing: 10.h,
          children: categories.map(
            (String category) {
              return _CategoryChip(
                title: category,
                onTap: () {
                  onCategorySelected(category);
                },
              );
            },
          ).toList(),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13.r),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 15.w,
            vertical: 10.h,
          ),
          decoration: BoxDecoration(
            color: AppColors.field,
            borderRadius: BorderRadius.circular(13.r),
            border: Border.all(
              color: AppColors.border,
              width: 1,
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'bShabnam',
              fontSize: 12.sp,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}