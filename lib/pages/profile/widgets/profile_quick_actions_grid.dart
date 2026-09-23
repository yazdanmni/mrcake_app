import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';

class ProfileQuickActionsGrid extends StatelessWidget {
  final VoidCallback? onPaymentsTap;
  final VoidCallback? onCreditTap;
  final VoidCallback? onSupportTap;
  final VoidCallback? onGiftsTap;

  const ProfileQuickActionsGrid({
    super.key,
    this.onPaymentsTap,
    this.onCreditTap,
    this.onSupportTap,
    this.onGiftsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 25.w,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // ==========================================================
          // RESPONSIVE WIDTH
          // ==========================================================

          const int itemCount = 4;

          final double availableWidth = constraints.maxWidth;

          // فاصله بین کارت‌ها
          final double spacing = 8.w;

          // مجموع فاصله‌های بین 4 کارت
          final double totalSpacing =
              spacing * (itemCount - 1);

          // عرض واقعی هر کارت
          final double itemWidth =
              (availableWidth - totalSpacing) / itemCount;

          // ==========================================================
          // ACTIONS
          // ==========================================================

          final List<_ProfileQuickAction> actions = [
            _ProfileQuickAction(
              title: 'پرداختی‌ها',
              icon: Icons.receipt_long_outlined,
              onTap: onPaymentsTap,
            ),
            _ProfileQuickAction(
              title: 'اعتبار شما',
              icon: Icons.account_balance_wallet_outlined,
              onTap: onCreditTap,
            ),
            _ProfileQuickAction(
              title: 'پشتیبانی',
              icon: Icons.support_agent_outlined,
              onTap: onSupportTap,
            ),
            _ProfileQuickAction(
              title: 'هدیه‌ها',
              icon: Icons.card_giftcard_outlined,
              onTap: onGiftsTap,
            ),
          ];

          // ==========================================================
          // ROW
          // ==========================================================

          return Directionality(
            textDirection: TextDirection.rtl,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: actions.map(
                (action) {
                  return SizedBox(
                    width: itemWidth,
                    height: 85.h,
                    child: _ProfileQuickActionCard(
                      action: action,
                    ),
                  );
                },
              ).toList(),
            ),
          );
        },
      ),
    );
  }
}

// ===================================================================
// MODEL
// ===================================================================

class _ProfileQuickAction {
  final String title;
  final IconData icon;
  final VoidCallback? onTap;

  const _ProfileQuickAction({
    required this.title,
    required this.icon,
    this.onTap,
  });
}

// ===================================================================
// CARD
// ===================================================================

class _ProfileQuickActionCard extends StatelessWidget {
  final _ProfileQuickAction action;

  const _ProfileQuickActionCard({
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Container(
          width: double.infinity,
          height: 85.h,
          decoration: BoxDecoration(
            color: AppColors.premium.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: AppColors.premium,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                action.icon,
                size: 27.sp,
                color: AppColors.textPrimary,
              ),

              SizedBox(height: 7.h),

              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 3.w,
                ),
                child: Text(
                  action.title,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'bshabnam',
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
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
