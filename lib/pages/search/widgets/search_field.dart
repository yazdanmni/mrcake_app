import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';

class SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final VoidCallback onClear;
  final ValueChanged<String> onSubmitted;

  const SearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hasText,
    required this.onClear,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56.h,
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(17.r),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textDirection: TextDirection.rtl,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        style: TextStyle(
          fontFamily: 'bShabnam',
          fontSize: 14.sp,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,

          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 17.h,
          ),

          hintText: 'چی دوست داری یاد بگیری؟',
          hintTextDirection: TextDirection.rtl,

          hintStyle: TextStyle(
            fontFamily: 'bShabnam',
            fontSize: 13.sp,
            color: AppColors.textSecondary,
          ),

          prefixIcon: Padding(
            padding: EdgeInsets.only(
              right: 14.w,
              left: 4.w,
            ),
            child: Icon(
              Icons.search_rounded,
              size: 23.sp,
              color: AppColors.textSecondary,
            ),
          ),

          suffixIcon: hasText
              ? IconButton(
                  onPressed: onClear,
                  splashRadius: 20.r,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20.sp,
                    color: AppColors.textSecondary,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}