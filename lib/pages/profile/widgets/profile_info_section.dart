import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';

class ProfileInfoSection extends StatelessWidget {
  const ProfileInfoSection({
    super.key,
    this.username = 'username',
    this.email = 'example@email.com',
    this.onEditEmail,
  });

  /// بعداً از API دریافت می‌شود.
  final String username;

  /// بعداً از API دریافت می‌شود.
  final String email;

  /// بعداً به API درخواست ویرایش ایمیل متصل می‌شود.
  final VoidCallback? onEditEmail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // =====================================================
          // Username
          // =====================================================

          _InfoRow(
            title: 'نام کاربری',
            value: username,
            trailing: _StatusBox(
              text: 'قابل ویرایش نیست',
              icon: Icons.lock_outline_rounded,
            ),
          ),

          SizedBox(height: 18.h),

          // =====================================================
          // Email
          // =====================================================

          _InfoRow(
            title: 'ایمیل',
            value: email,
            trailing: _ActionButton(
              text: 'درخواست ویرایش',
              icon: Icons.edit_outlined,
              onTap: onEditEmail,
            ),
          ),
        ],
      ),
    );
  }
}

// ===============================================================
// Info Row
// ===============================================================

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.title,
    required this.value,
    required this.trailing,
  });

  final String title;
  final String value;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // عنوان + مقدار
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'BShabnam',
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),

              SizedBox(height: 6.h),

              Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'BShabnam',
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),

        SizedBox(width: 16.w),

        trailing,
      ],
    );
  }
}

// ===============================================================
// Cannot Edit Box
// ===============================================================

class _StatusBox extends StatelessWidget {
  const _StatusBox({
    required this.text,
    required this.icon,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 12.w,
        vertical: 9.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppColors.border,
          width: 1.w,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15.sp,
            color: AppColors.textSecondary,
          ),

          SizedBox(width: 6.w),

          Text(
            text,
            style: TextStyle(
              fontFamily: 'BShabnam',
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ===============================================================
// Edit Button
// ===============================================================

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.text,
    required this.icon,
    this.onTap,
  });

  final String text;
  final IconData icon;
  final VoidCallback? onTap;

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
            color: AppColors.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.30),
              width: 1.w,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15.sp,
                color: AppColors.primary,
              ),

              SizedBox(width: 6.w),

              Text(
                text,
                style: TextStyle(
                  fontFamily: 'BShabnam',
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
