import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';

class ProfileTextField extends StatelessWidget {
  final String label;
  final String hint;
  final bool required;
  final TextEditingController? controller;
  final TextInputType? keyboardType;

  const ProfileTextField({
    super.key,
    required this.label,
    required this.hint,
    this.required = false,
    this.controller,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          RichText(
            textDirection: TextDirection.rtl,
            text: TextSpan(
              text: label,
              style: TextStyle(
                fontFamily: 'lshabnam',
                fontSize: 16.sp,
                color: AppColors.textPrimary,
              ),
              children: required
                  ? [
                      TextSpan(
                        text: ' *',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16.sp,
                        ),
                      ),
                    ]
                  : null,
            ),
          ),

          SizedBox(height: 6.h),

          SizedBox(
            width: double.infinity,
            height: 64.h,
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'bshabnam',
                color: AppColors.textPrimary,
                fontSize: 16.sp,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  fontFamily: 'shabnam',
                  fontSize: 16.sp,
                  color: AppColors.placeholder,
                ),
                filled: true,
                fillColor: AppColors.field,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 18.w,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  borderSide: const BorderSide(
                    color: AppColors.border,
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  borderSide: const BorderSide(
                    color: AppColors.border,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  borderSide: const BorderSide(
                    color: AppColors.premium,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}