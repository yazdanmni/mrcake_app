import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/course_order.dart';

/// The coloured pill that renders an order's `status`.
///
/// The colour is what carries the meaning at a glance — «در انتظار پرداخت» is
/// gold, «پرداخت شده» is green, a failure is red — and the Persian label always
/// comes from [OrderStatus.label], never from the raw enum.
class OrderStatusChip extends StatelessWidget {
  final String status;

  const OrderStatusChip({super.key, required this.status});

  static Color colorFor(String status) {
    switch (status) {
      case OrderStatus.paid:
        return AppColors.success;
      case OrderStatus.pending:
        return AppColors.premium;
      case OrderStatus.failed:
        return AppColors.error;
      case OrderStatus.canceled:
        return AppColors.textSecondary;
      case OrderStatus.refunded:
        return AppColors.accent;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color color = colorFor(status);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        OrderStatus.label(status),
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: 'bshabnam',
          fontSize: 10.5.sp,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
