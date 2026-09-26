import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../core/theme/app_colors.dart';

/// The house screen header: a `pinarb` title on the right, and a raised back
/// pill on the left.
///
/// Every pushed screen in this app uses this geometry, so it lives in one place
/// instead of being re-typed per screen:
///
///   * title — `pinarb 20.sp`, inside a `Flexible` with ellipsis, because a long
///     course or ticket title must clip rather than overflow (see MEMORY: `.sp`
///     tracks the screen **width**, `.h` tracks the height);
///   * back pill — `44.w × 44.w`, `premium @ 0.12` fill, `radius 14.r`,
///     `Border.all(premium, 1.5.w)`, `arrow_forward_ios_rounded 19.sp` (the RTL
///     "back" glyph);
///   * an optional [trailing] slot for a screen-level action.
class HouseScreenHeader extends StatelessWidget {
  const HouseScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onBack,
    this.padding,
  });

  final String title;

  /// A smaller second line under [title]. Optional.
  final String? subtitle;

  /// Pinned to the far side of the row, after the title.
  final Widget? trailing;

  /// Defaults to `Navigator.pop`.
  final VoidCallback? onBack;

  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final String? subtitle = this.subtitle;

    return Padding(
      padding: padding ?? EdgeInsets.fromLTRB(25.w, 12.h, 25.w, 10.h),
      child: Row(
        textDirection: TextDirection.rtl,
        children: <Widget>[
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: 'pinarb',
                    fontSize: 20.sp,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...<Widget>[
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'bshabnam',
                      fontSize: 12.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (trailing != null) ...<Widget>[
            SizedBox(width: 10.w),
            trailing!,
          ],

          SizedBox(width: 10.w),

          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
            child: Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: AppColors.premium.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: AppColors.premium, width: 1.5.w),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 19.sp,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The pill used for in-page section titles: `premium`, `radius 8.r`,
/// `bshabnam 16.sp` white.
class HouseSectionPill extends StatelessWidget {
  const HouseSectionPill({super.key, required this.title, this.trailing});

  final String title;

  /// Rendered to the side of the pill, in secondary text.
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final String? trailing = this.trailing;

    return Row(
      textDirection: TextDirection.rtl,
      children: <Widget>[
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: AppColors.premium,
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'bshabnam',
              fontSize: 15.sp,
              color: AppColors.white,
              height: 1.2,
            ),
          ),
        ),
        if (trailing != null && trailing.isNotEmpty) ...<Widget>[
          SizedBox(width: 10.w),
          Flexible(
            child: Text(
              trailing,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'bshabnam',
                fontSize: 12.sp,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The house empty state: a big premium icon, a line of `textPrimary` copy, and
/// an optional action.
class HouseEmptyState extends StatelessWidget {
  const HouseEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w, vertical: 50.h),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 52.sp, color: AppColors.premium),
          SizedBox(height: 15.h),
          Text(
            message,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'bshabnam',
              fontSize: 16.sp,
              color: AppColors.textPrimary,
              height: 1.8,
            ),
          ),
          if (action != null) ...<Widget>[
            SizedBox(height: 20.h),
            action!,
          ],
        ],
      ),
    );
  }
}
