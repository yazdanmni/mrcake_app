import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/models/teacher_model.dart';

import '../../../core/theme/app_colors.dart';

class TeacherPortfolioItemCard extends StatelessWidget {
  final TeacherPortfolioItem item;
  final VoidCallback? onTap;

  const TeacherPortfolioItemCard({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.r),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                item.image,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) {
                  return Container(
                    color: AppColors.field,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.image_outlined,
                      color:
                          AppColors.textSecondary,
                      size: 30.sp,
                    ),
                  );
                },
              ),

              if (item.isVideo)
                Positioned(
                  left: 8.w,
                  top: 8.h,
                  child: Container(
                    width: 30.w,
                    height: 30.w,
                    decoration: BoxDecoration(
                      color:
                          Colors.black.withOpacity(
                        0.45,
                      ),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 19.sp,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}