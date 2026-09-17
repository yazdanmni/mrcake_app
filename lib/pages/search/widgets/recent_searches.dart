import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';

class RecentSearches extends StatelessWidget {
  final List<String> searches;
  final ValueChanged<String> onSearchSelected;
  final VoidCallback onClearAll;

  const RecentSearches({
    super.key,
    required this.searches,
    required this.onSearchSelected,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    if (searches.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'جستجوهای اخیر',
              style: TextStyle(
                fontFamily: 'PinarB',
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),

            const Spacer(),

            GestureDetector(
              onTap: onClearAll,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 5.h,
                  horizontal: 3.w,
                ),
                child: Text(
                  'پاک کردن',
                  style: TextStyle(
                    fontFamily: 'bShabnam',
                    fontSize: 11.sp,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: 14.h),

        Wrap(
          spacing: 8.w,
          runSpacing: 9.h,
          children: searches.map(
            (String search) {
              return _RecentSearchChip(
                title: search,
                onTap: () {
                  onSearchSelected(search);
                },
              );
            },
          ).toList(),
        ),
      ],
    );
  }
}

class _RecentSearchChip extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _RecentSearchChip({
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 12.w,
            vertical: 9.h,
          ),
          decoration: BoxDecoration(
            color: AppColors.field,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: AppColors.border,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history_rounded,
                size: 16.sp,
                color: AppColors.textSecondary,
              ),

              SizedBox(width: 6.w),

              Text(
                title,
                style: TextStyle(
                  fontFamily: 'bShabnam',
                  fontSize: 12.sp,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}