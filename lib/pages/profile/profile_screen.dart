import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/network/api_exception.dart';
import 'package:mr_cake_project/core/network/remote_data.dart';
import 'package:mr_cake_project/core/session/session_manager.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/core/utils/app_feedback.dart';
import 'package:mr_cake_project/models/course.dart';
import 'package:mr_cake_project/models/user_model.dart';
import 'package:mr_cake_project/pages/course_learning/course_learning_screen.dart';
import 'package:mr_cake_project/pages/profile/widgets/profile_edit_info_section.dart';
import 'package:mr_cake_project/pages/profile/widgets/profile_info_section.dart';
import 'package:mr_cake_project/pages/profile/widgets/profile_my_courses_section.dart';
import 'package:mr_cake_project/pages/profile/widgets/profile_quick_actions_grid.dart';
import 'package:mr_cake_project/pages/profile/widgets/profile_top_section.dart';
import 'package:mr_cake_project/pages/support/tickets_screen.dart';
import 'package:mr_cake_project/repositories/profile_repository.dart';
import 'package:mr_cake_project/core/router/app_router.dart';

class ProfileScreen extends StatefulWidget {
  /// Whether this tab is the one currently shown by `MainBottomNavigation`.
  ///
  /// The tabs live in an `IndexedStack`, so this screen is built once and kept
  /// alive for the whole session — its state, including «دوره‌های من», would
  /// never reload on its own. Flipping this to `true` is what tells the screen
  /// "you are visible again, re-read the server".
  final bool visible;

  const ProfileScreen({super.key, this.visible = true});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserModel? _user;

  /// Bumped to make `ProfileMyCoursesSection` re-fetch.
  int _coursesReloadToken = 0;

  @override
  void initState() {
    super.initState();
    _user = SessionManager.instance.user;
    _load();
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Coming back to the tab: the user may have registered for a course, or an
    // admin may have approved an order while they were away.
    if (widget.visible && !oldWidget.visible) {
      _reload();
    }
  }

  /// Reloads the profile **and** «دوره‌های من».
  ///
  /// `_load` only refreshes the account fields; the course list has its own
  /// state, so it is driven by [_coursesReloadToken].
  Future<void> _reload() async {
    await _load();
    if (!mounted) return;
    setState(() => _coursesReloadToken++);
  }

  Future<void> _load() async {
    if (!SessionManager.instance.isLoggedIn) return;

    final result = await RemoteLoader.value<UserModel>(
      label: 'profile.me',
      seed: _user,
      fetch: ProfileRepository.instance.fetchProfile,
    );

    if (!mounted) return;

    final fresh = result.data;
    if (fresh == null) return;

    // Persist the API payload first.  `SessionManager.updateUser` will merge
    // a server-side banner (if any) into the client-side cache.  If the
    // backend did not include a banner field, the on-device cached banner is
    // kept intact by `SessionManager`.
    await SessionManager.instance.updateUser(fresh);

    // Use the **merged** profile (server payload + client-side banner).
    // Widgets should never render `fresh` directly because it would drop the
    // locally-cached banner.
    if (!mounted) return;
    setState(() => _user = SessionManager.instance.user);
  }

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
        setState(() => _user = SessionManager.instance.user);
      },
    );

    if (!mounted) return;

    if (saved) {
      AppFeedback.success(context, 'اطلاعات با موفقیت ذخیره شد.');
    } else {
      AppFeedback.error(context, 'ذخیره اطلاعات ناموفق بود. دوباره تلاش کنید.');
    }
  }

  Future<bool> _saveEmail(String newEmail) async {
    final result = await RemoteLoader.action(
      'profile.updateEmail',
      () async {
        final user = await ProfileRepository.instance.updateProfile(
          email: newEmail,
        );
        await SessionManager.instance.updateUser(user);
        if (!mounted) return;
        setState(() => _user = SessionManager.instance.user);
      },
    );
    return result;
  }

  Future<void> _uploadAvatar(File image) async {
    // The repository's own message is used on failure: a dropped upload and a
    // rejected payload need different answers, and a fixed "try again" sentence
    // would hide which one happened.
    String? failure;

    final ok = await RemoteLoader.action(
      'profile.uploadAvatar',
      () async {
        final url = await MediaRepository.instance.uploadUrl(image);
        final user = await ProfileRepository.instance.updateProfile(
          avatarUrl: url,
        );
        await SessionManager.instance.updateUser(user);
        if (!mounted) return;
        setState(() => _user = SessionManager.instance.user);
      },
      onError: (ApiException error) => failure = error.message,
    );

    if (!mounted) return;
    if (ok) {
      AppFeedback.success(context, 'تصویر پروفایل با موفقیت آپلود شد.');
    } else {
      AppFeedback.error(context, failure ?? 'آپلود تصویر ناموفق بود. دوباره تلاش کنید.');
    }
  }

  void _openSupport() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TicketsScreen()),
    );
  }

  /// Tapping a course in «دوره‌های من» goes **straight** to the course content.
  ///
  /// The course is already an enrollment — the backend created it — so there is
  /// nothing to decide here: no details screen in between, no registration
  /// button. [CourseLearningScreen.open] seeds itself from the [Course] the
  /// enrollments endpoint returned and refreshes from the API on its first
  /// frame.
  ///
  /// Coming back re-reads the list, so progress made in the lesson screen (or a
  /// course added elsewhere) is reflected instead of showing a stale row.
  Future<void> _openCourse(Course course) async {
    await CourseLearningScreen.open(context, course: course);

    if (!mounted) return;
    setState(() => _coursesReloadToken++);
  }

  void _goToCourses() {
    AppRouter.toCourses(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListenableBuilder(
        listenable: SessionManager.instance,
        builder: (context, child) {
          if (!SessionManager.instance.isLoggedIn) {
            return _buildGuestProfile();
          }

          final user = _user;

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _reload,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  ProfileTopSection(
                    onCartTap: () => AppRouter.toCart(context),
                    onAvatarChanged: (File? file) {
                      if (file != null) _uploadAvatar(file);
                    },
                  ),
                  ProfileInfoSection(
                    username: user?.username,
                    email: user?.email,
                    phoneNumber: user?.phoneNumber,
                    onEditEmail: _saveEmail,
                  ),
                  SizedBox(height: 20.h),
                  ProfileEditInfoSection(
                    firstName: user?.firstName,
                    lastName: user?.lastName,
                    onSave: _saveName,
                  ),
                  ProfileMyCoursesSection(
                    userId: user?.id ?? 0,
                    reloadToken: _coursesReloadToken,
                    onCourseTap: _openCourse,
                    onGoToCourses: _goToCourses,
                    onViewAll: _goToCourses,
                  ),
                  SizedBox(height: 20.h),
                  ProfileQuickActionsGrid(
                    onPaymentsTap: () => AppRouter.toOrders(context),
                    onCreditTap: () => AppRouter.toWallet(context),
                    onSupportTap: _openSupport,
                    onGiftsTap: () => AppRouter.toGifts(context),
                  ),
                  SizedBox(height: 20.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 25.w),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54.h,
                      child: OutlinedButton(
                        onPressed: () async {
                          final ctx = context;
                          await SessionManager.instance.clear();
                          if (!mounted) return;
                          AppRouter.toSplash(ctx);
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

  // ==========================================================================
  // GUEST PROFILE — کاربر ثبت‌نام نکرده
  // UI/UX کاملاً هماهنگ با بقیه صفحات برنامه
  // ==========================================================================
  Widget _buildGuestProfile() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          // --------------------------------------------------------------
          // MINIMAL HEADER: فقط آیکون سبد خرید (بدون بنر و بدون آواتار)
          // --------------------------------------------------------------
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 25.w,
                vertical: 16.h,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => AppRouter.toCart(context),
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
                  SizedBox(width: 40.w),
                ],
              ),
            ),
          ),

          SizedBox(height: 16.h),

          // --------------------------------------------------------------
          // WELCOME CARD — کارت دعوت به ورود/ثبت‌نام
          // استایل کاملاً هماهنگ با کارت‌های بقیه برنامه
          // --------------------------------------------------------------
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 25.w),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20.w, 30.h, 20.w, 25.h),
              decoration: BoxDecoration(
                color: AppColors.field,
                borderRadius: BorderRadius.circular(22.r),
                border: Border.all(
                  color: AppColors.border,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20.r,
                    offset: Offset(0, 10.h),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // آیکون بزرگ خوش‌آمدگویی
                  Container(
                    width: 90.w,
                    height: 90.w,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.lock_open_rounded,
                        size: 44.sp,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  SizedBox(height: 22.h),

                  // عنوان خوش‌آمدگویی
                  Text(
                    'به آکادمی مستر کیک خوش آمدید',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'pinarb',
                      fontSize: 19.sp,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 12.h),

                  // توضیحات
                  Text(
                    'برای دسترسی به پروفایل شخصی، دوره‌های خریداری شده، '
                    'پیگیری سفارش‌ها و امکانات اختصاصی دیگر، '
                    'لطفاً وارد حساب کاربری خود شوید یا حساب جدید ایجاد کنید.',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'bshabnam',
                      fontSize: 13.sp,
                      height: 1.9,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 28.h),

                  // دکمه اصلی — ورود / ثبت نام
                  SizedBox(
                    width: double.infinity,
                    height: 58.h,
                    child: ElevatedButton.icon(
                      onPressed: () => AppRouter.toLogin(context),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      icon: Icon(
                        Icons.login_rounded,
                        size: 22.sp,
                      ),
                      label: Text(
                        'ورود به حساب / ثبت نام',
                        style: TextStyle(
                          fontFamily: 'bshabnam',
                          fontSize: 15.sp,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 14.h),

                  // دکمه ثانویه — مشاهده دوره‌ها
                  SizedBox(
                    width: double.infinity,
                    height: 54.h,
                    child: OutlinedButton.icon(
                      onPressed: () => AppRouter.toCourses(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppColors.premium,
                          width: 1.5,
                        ),
                        foregroundColor: AppColors.premium,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      icon: Icon(
                        Icons.menu_book_rounded,
                        size: 21.sp,
                      ),
                      label: Text(
                        'مشاهده دوره‌های آموزشی',
                        style: TextStyle(
                          fontFamily: 'bshabnam',
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 28.h),

          // --------------------------------------------------------------
          // BENEFITS SECTION — مزایای ثبت نام
          // --------------------------------------------------------------
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 25.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.w),
                  child: Text(
                    'مزایای ثبت نام در مستر کیک',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'pinarb',
                      fontSize: 16.sp,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(height: 15.h),
                _buildBenefitRow(
                  icon: Icons.video_library_rounded,
                  title: 'دسترسی به دوره‌های خریداری شده',
                  description: 'همه‌ی دوره‌های خریداری شده‌ی خود را با پیشرفت آموزش در یک مکان ببینید.',
                ),
                SizedBox(height: 10.h),
                _buildBenefitRow(
                  icon: Icons.support_agent_rounded,
                  title: 'پشتیبانی اختصاصی',
                  description: 'ارسال و پیگیری درخواست‌های پشتیبانی در هر زمان.',
                ),
                SizedBox(height: 10.h),
                _buildBenefitRow(
                  icon: Icons.receipt_long_rounded,
                  title: 'پیگیری پرداخت‌ها و سفارشات',
                  description: 'مشاهده تاریخچه‌ی کامل خریدها و وضعیت هر سفارش.',
                ),
                SizedBox(height: 10.h),
                _buildBenefitRow(
                  icon: Icons.card_membership_rounded,
                  title: 'کدهای تخفیف ویژه',
                  description: 'استفاده از تخفیف‌های مخصوص اعضای آکادمی مستر کیک.',
                ),
              ],
            ),
          ),

          SizedBox(height: 150.h),
        ],
      ),
    );
  }

  Widget _buildBenefitRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.sectionBackground.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: AppColors.border,
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: 22.sp,
              color: AppColors.premium,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'pinarb',
                    fontSize: 13.5.sp,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'bshabnam',
                    fontSize: 11.5.sp,
                    height: 1.75,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
