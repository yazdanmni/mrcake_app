import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/network/remote_data.dart';
import 'package:mr_cake_project/core/session/session_manager.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/core/utils/app_feedback.dart';
import 'package:mr_cake_project/models/user_model.dart';
import 'package:mr_cake_project/pages/profile/widgets/profile_edit_info_section.dart';
import 'package:mr_cake_project/pages/profile/widgets/profile_info_section.dart';
import 'package:mr_cake_project/pages/profile/widgets/profile_my_courses_section.dart';
import 'package:mr_cake_project/pages/profile/widgets/profile_quick_actions_grid.dart';
import 'package:mr_cake_project/pages/profile/widgets/profile_top_section.dart';
import 'package:mr_cake_project/pages/support/tickets_screen.dart';
import 'package:mr_cake_project/repositories/profile_repository.dart';
import 'package:mr_cake_project/core/router/app_router.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// ابتدا پروفایل کش‌شده در نشست، سپس پاسخ تازه بک‌اند.
  UserModel? _user;

  @override
  void initState() {
    super.initState();

    _user = SessionManager.instance.user;

    _load();
  }

  /// `GET /api/v1/accounts/profile/`
  Future<void> _load() async {
    if (!SessionManager.instance.isLoggedIn) return;

    final result = await RemoteLoader.value<UserModel>(
      label: 'profile.me',
      seed: _user,
      fetch: ProfileRepository.instance.fetchProfile,
    );

    if (!mounted) return;

    final user = result.data;
    if (user == null) return;

    setState(() => _user = user);

    await SessionManager.instance.updateUser(user);
  }

  /// `PATCH /api/v1/accounts/profile/`
  Future<void> _saveName(String firstName, String lastName) async {
    final saved = await RemoteLoader.action(
      'profile.update',
      () async {
        final user = await ProfileRepository.instance.updateProfile(
          firstName: firstName,
          lastName: lastName,
        );

        await SessionManager.instance.updateUser(user);

        if (!mounted) return;
        setState(() => _user = user);
      },
    );

    if (!mounted) return;

    if (saved) {
      AppFeedback.success(context, 'اطلاعات با موفقیت ذخیره شد.');
    } else {
      AppFeedback.error(context, 'ذخیره اطلاعات ناموفق بود. دوباره تلاش کنید.');
    }
  }

  void _openSupport() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TicketsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListenableBuilder(
        listenable: SessionManager.instance,
        builder: (context, child) {
          if (!SessionManager.instance.isLoggedIn) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'برای مشاهده پروفایل خود، لطفاً وارد شوید یا ثبت نام کنید.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'shabnam',
                      fontSize: 18.sp,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  GestureDetector(
                    onTap: () {
                      AppRouter.toLogin(context);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(25.r),
                      ),
                      child: Text(
                        'ورود / ثبت نام',
                        style: TextStyle(
                          fontFamily: 'shabnam',
                          fontSize: 18.sp,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final user = _user; // User is guaranteed to be logged in here

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // ─────────────────────────────────────
                  // Profile Top Section
                  // Header + Banner + Avatar
                  // ─────────────────────────────────────
                  const ProfileTopSection(),
                  ProfileInfoSection(
                    username: user?.username,
                    email: user?.email,
                  ),
                  SizedBox(height: 20.h),
                  ProfileEditInfoSection(
                    firstName: user?.firstName,
                    lastName: user?.lastName,
                    phoneNumber: user?.phoneNumber,
                    onSave: _saveName,
                  ),
                  ProfileMyCoursesSection(
                    userId: user?.id ?? 0,
                    onCourseTap: null,
                    onGoToCourses: null,
                  ),
                  SizedBox(height: 20.h),
                  ProfileQuickActionsGrid(
                    onSupportTap: _openSupport,
                  ),
                  SizedBox(height: 20.h), // Adjusted spacing
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 25.w),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54.h,
                      child: OutlinedButton(
                        onPressed: () async {
                          await SessionManager.instance.clear();
                          AppRouter.toSplash(context); // Navigate to splash/login after logout
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.error, width: 2.w),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                        child: Text(
                          'خروج از حساب',
                          style: TextStyle(
                            fontFamily: 'bshabnam',
                            fontSize: 18.sp,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 150.h),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
