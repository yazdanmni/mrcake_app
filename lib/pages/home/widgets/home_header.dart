import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/core/session/session_manager.dart';
import 'package:mr_cake_project/core/router/app_router.dart';

/// Top bar: notifications, support, greeting, and profile avatar.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderIcon(
                icon: Icons.notifications_none_rounded,
                onTap: () => AppRouter.toNotifications(context),
              ),

              SizedBox(width: 8.w),

              _HeaderIcon(
                icon: Icons.headset_mic_outlined,
                onTap: () {
                  AppRouter.toSupport(context);
                },
              ),
            ],
          ),

          SizedBox(width: 12.w),

          Expanded(
            child: ListenableBuilder(
              listenable: SessionManager.instance,
              builder: (context, child) {
                final session = SessionManager.instance;
                if (session.isLoggedIn && session.user != null) {
                  final firstName = session.user!.firstName?.trim() ?? '';
                  final avatarSize = 66.r;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              textDirection: TextDirection.rtl,
                              children: [
                                Text(
                                  'سلام',
                                  style: TextStyle(
                                    fontFamily: 'pinarb',
                                    fontSize: 20.sp,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (firstName.isNotEmpty) ...[
                                  SizedBox(width: 4.w),
                                  Flexible(
                                    child: Text(
                                      firstName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: 'pinarb',
                                        fontSize: 20.sp,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'خوش اومدی 👋',
                              textDirection: TextDirection.rtl,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'shabnam',
                                fontSize: 20.sp,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Container(
                        width: avatarSize,
                        height: avatarSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.field,
                          border: Border.all(
                            color: AppColors.border,
                            width: 2.w,
                          ),
                        ),
                        child: ClipOval(
                          child:
                              session.user!.avatarUrl != null &&
                                  session.user!.avatarUrl!.isNotEmpty
                              ? Image.network(
                                  session.user!.avatarUrl!, // Display user's profile picture
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.person,
                                      size: 34.sp,
                                      color: AppColors.textPrimary,
                                    );
                                  },
                                )
                              : Image.asset(
                                  'assets/images/profile.png', // Fallback to default if no avatarUrl
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.person,
                                      size: 34.sp,
                                      color: AppColors.textPrimary,
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  );
                } else {
                  return Align(
                    alignment: Alignment.topRight,
                    child: GestureDetector(
                      onTap: () {
                        AppRouter.toLogin(context);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 8.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.field,
                          border: Border.all(
                            color: AppColors.border,
                            width: 2.w,
                          ),
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        child: Text(
                          'ورود / ثبت نام',
                          style: TextStyle(
                            fontFamily: 'shabnam',
                            fontSize: 16.sp,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50.w,
        height: 50.h,
        decoration: BoxDecoration(
          color: AppColors.field,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border, width: 2.w),
        ),
        child: Icon(icon, size: 34.sp, color: AppColors.textPrimary),
      ),
    );
  }
}
