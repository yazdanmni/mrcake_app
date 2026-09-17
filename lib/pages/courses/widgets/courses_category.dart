import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';

import '../../../models/category_model.dart';

class CoursesCategories extends StatefulWidget {
  final List<CategoryModel> categories;
  final ValueChanged<CategoryModel?>? onCategorySelected;

  const CoursesCategories({
    super.key,
    required this.categories,
    this.onCategorySelected,
  });

  @override
  State<CoursesCategories> createState() => _CoursesCategoriesState();
}

class _CoursesCategoriesState extends State<CoursesCategories> {
  int? selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true,
        padding: EdgeInsets.symmetric(horizontal: 25.w),
        physics: const BouncingScrollPhysics(),
        itemCount: widget.categories.length + 1,
        separatorBuilder: (context, index) {
          return SizedBox(width: 8.w);
        },
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = selectedCategoryId == null;

            return _CategoryItem(
              title: 'همه',
              isSelected: isSelected,
              onTap: () {
                setState(() {
                  selectedCategoryId = null;
                });

                widget.onCategorySelected?.call(null);
              },
            );
          }

          final category = widget.categories[index - 1];

          final isSelected = selectedCategoryId == category.id;

          return _CategoryItem(
            title: category.title,
            isSelected: isSelected,
            onTap: () {
              setState(() {
                selectedCategoryId = category.id;
              });

              widget.onCategorySelected?.call(category);
            },
          );
        },
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryItem({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 10.w,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.field,
          borderRadius: BorderRadius.circular(6.r),
          border: Border.all(
            color: AppColors.border,
            width: 2.w,
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'shabnam',
            fontSize: 14.sp,
            color: isSelected
                ? Colors.white
                : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}