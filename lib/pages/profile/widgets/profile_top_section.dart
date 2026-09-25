import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/pages/profile/widgets/profile_avatar.dart';
import 'package:mr_cake_project/pages/profile/widgets/profile_banner.dart';
import 'package:mr_cake_project/core/session/session_manager.dart';

class ProfileTopSection extends StatelessWidget {
  final ValueChanged<File?>? onAvatarChanged;
  final ValueChanged<File?>? onBannerChanged;
  final VoidCallback? onCartTap;

  const ProfileTopSection({
    super.key,
    this.onAvatarChanged,
    this.onBannerChanged,
    this.onCartTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SessionManager.instance,
      builder: (context, child) {
        final session = SessionManager.instance;
        final avatarUrl = session.user?.avatarUrl;
        final bannerUrl = session.user?.bannerImageUrl;

        return SizedBox(
          width: double.infinity,
          // Banner: ~245 + Avatar offset: 250 + avatar size: 135 -> ~390, plus padding
          height: 425.h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // =====================================================
              // MINIMAL HEADER — Shopping Cart Icon Only
              // =====================================================
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 25.w,
                      vertical: 10.h,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left side: cart icon (per user's request)
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onCartTap ??
                                () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      behavior: SnackBarBehavior.floating,
                                      margin: EdgeInsets.all(16.w),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14.r),
                                      ),
                                      content: Text(
                                        'سبد خرید به زودی فعال می‌شود.',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontFamily: 'BShabnam',
                                          fontSize: 13.sp,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                            borderRadius: BorderRadius.circular(14.r),
                            child: Container(
                              width: 40.w,
                              height: 40.w,
                              decoration: BoxDecoration(
                                color: AppColors.sectionBackground
                                    .withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(14.r),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  width: 1.0.w,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.10),
                                    blurRadius: 10.r,
                                    offset: Offset(0, 4.h),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 26.sp,
                                  color: const Color(0xFF5B3930),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Right side: empty (all other header icons removed per request)
                        SizedBox(width: 40.w),
                      ],
                    ),
                  ),
                ),
              ),

              // =====================================================
              // BANNER
              // =====================================================
              Positioned(
                top: 60.h,
                left: 0,
                right: 0,
                child: ProfileBanner(
                  bannerImageUrl: bannerUrl,
                  onImageChanged: onBannerChanged,
                ),
              ),

              // =====================================================
              // AVATAR
              // =====================================================
              Positioned(
                top: 250.h,
                child: ProfileAvatar(
                  imageUrl: avatarUrl,
                  onImageChanged: onAvatarChanged,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
