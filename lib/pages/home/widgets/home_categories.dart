import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';

import '../../../models/category_model.dart';

/// 4-column category grid plus a "more" tile.
class HomeCategories extends StatelessWidget {
  final List<CategoryModel> categories;

  const HomeCategories({
    super.key,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: categories.length + 1,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 8.w,
          mainAxisSpacing: 8.h,
          childAspectRatio: 1,
        ),
        itemBuilder: (context, index) {
          if (index == categories.length) {
            return _GlassCategoryCard(
              title: 'بیشتر',
              isMore: true,
              onTap: () {
              },
            );
          }

          final category = categories[index];

          return _GlassCategoryCard(
            title: category.title,
            image: category.image,
            onTap: () {
            },
          );
        },
      ),
    );
  }
}

/// Frosted category card with a gold border.
class _GlassCategoryCard extends StatelessWidget {
  final String title;
  final String? image;
  final bool isMore;
  final VoidCallback onTap;

  const _GlassCategoryCard({
    required this.title,
    this.image,
    this.isMore = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 6,
            sigmaY: 6,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.premium.withOpacity(0.20),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: AppColors.premium,
                width: 2.w,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isMore)
                  Icon(
                    Icons.grid_view_rounded,
                    size: 25.sp,
                    color: const Color(0xFF5B3930),
                  )
                else if (image != null && image!.isNotEmpty)
                  Image.network(
                    image!,
                    width: 38.w,
                    height: 38.w,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.category_outlined,
                        size: 25.sp,
                        color: AppColors.textPrimary,
                      );
                    },
                  )
                else
                  Icon(
                    Icons.category_outlined,
                    size: 25.sp,
                    color: AppColors.textPrimary,
                  ),

                SizedBox(height: 4.h),

                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'shabnam',
                    fontSize: 16.sp,
                    color: AppColors.textPrimary,
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