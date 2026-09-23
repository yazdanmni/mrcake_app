import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/pages/profile/widgets/profile_avatar.dart';
import 'package:mr_cake_project/pages/profile/widgets/profile_banner.dart';
import 'package:mr_cake_project/pages/profile/widgets/profile_header.dart';
import 'package:mr_cake_project/core/session/session_manager.dart';

class ProfileTopSection extends StatelessWidget {
  const ProfileTopSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SessionManager.instance,
      builder: (context, child) {
        final session = SessionManager.instance;
        final avatarUrl = session.user?.avatarUrl;

        return SizedBox(
          width: double.infinity,

          // ارتفاع واقعی سکشن
          // Header = 60
          // Banner = 245
          // Avatar از 250 شروع می‌شود و حدود 167 ارتفاع دارد
          // بنابراین تا حدود 417 ادامه دارد.
          height: 425.h,

          child: Stack(
            clipBehavior: Clip.none,
            children: [
              
              // =====================================================
              // BANNER
              // =====================================================

              Positioned(
                top: 60.h,
                left: 0,
                right: 0,
                child: ProfileBanner(
                  onImageChanged: (File? image) {
                    // Banner خودش تصویر را مدیریت می‌کند.
                    // بعداً اینجا برای API استفاده می‌کنیم.
                  },
                ),
              ),

              // =====================================================
              // AVATAR
              // =====================================================

              Positioned(
                top: 250.h,
                child: ProfileAvatar(
                  imageUrl: avatarUrl, // Pass dynamic avatar URL
                  onImageChanged: (File? image) {
                    // Avatar خودش تصویر را مدیریت می‌کند.
                    // بعداً اینجا برای API استفاده می‌کنیم.
                  },
                ),
              ),
              // =====================================================
              // HEADER
              // =====================================================

              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ProfileHeader(),
              ),

            ],
          ),
        );
      },
    );
  }
}