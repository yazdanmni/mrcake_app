import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';

/// Themed snack bars + a full screen loader, used by every screen so error
/// handling looks identical everywhere.
class AppFeedback {
  AppFeedback._();

  static void error(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.error_outline_rounded,
      accent: const Color(0xFFD9534F),
    );
  }

  static void success(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.check_circle_outline_rounded,
      accent: const Color(0xFF4C9A6A),
    );
  }

  static void info(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.info_outline_rounded,
      accent: AppColors.premium,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color accent,
  }) {
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.sectionBackground,
          elevation: 6,
          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
            side: BorderSide(color: accent.withValues(alpha: 0.35), width: 1.5),
          ),
          content: Row(
            textDirection: TextDirection.rtl,
            children: [
              Icon(icon, color: accent, size: 22.sp),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  message,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'shabnam',
                    fontSize: 13.sp,
                    height: 1.6,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}

/// Small spinner that matches the brand and keeps the exact same footprint as
/// the text it replaces inside buttons.
class InlineLoader extends StatelessWidget {
  const InlineLoader({super.key, this.color = AppColors.white, this.size = 22});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.sp,
      height: size.sp,
      child: CircularProgressIndicator(
        strokeWidth: 2.4,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}
