import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/pages/profile/widgets/profile_edit_info_section.dart';
import 'package:mr_cake_project/pages/profile/widgets/profile_info_section.dart';
import 'package:mr_cake_project/pages/profile/widgets/profile_my_courses_section.dart';
import 'package:mr_cake_project/pages/profile/widgets/profile_quick_actions_grid.dart';
import 'package:mr_cake_project/pages/profile/widgets/profile_top_section.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // ─────────────────────────────────────
            // Profile Top Section
            // Header + Banner + Avatar
            // ─────────────────────────────────────
            const ProfileTopSection(),
            ProfileInfoSection(),
            SizedBox(height: 20.h),
            const ProfileEditInfoSection(),
            const ProfileMyCoursesSection(
              userId: 1,
              onCourseTap: null,
              onGoToCourses: null,
            ),
            SizedBox(height: 20.h),
            ProfileQuickActionsGrid(),
            SizedBox(height: 50.h),
          ],
        ),
      ),
    );
  }
}
