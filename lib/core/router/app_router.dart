import 'package:flutter/material.dart';

import '../../navigation/main_bottom_navigation.dart';
import '../../pages/authpage/change_password_screen.dart';
import '../../pages/authpage/complete_profile_screen.dart';
import '../../pages/authpage/login_otp_screen.dart';
import '../../pages/authpage/login_password_screen.dart';
import '../../pages/authpage/login_screen.dart';
import '../../pages/splash/splash_screen.dart';
import '../../pages/support/tickets_screen.dart';
import '../../pages/teacher/teachers_list_screen.dart';
import '../../repositories/auth_repository.dart';
import '../../pages/courses/courses_screen.dart';
import '../../pages/courses/course_categories_screen.dart';

/// Route names, used for `RouteSettings` so the whole navigation stack is
/// readable in the devtools / logs.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String otp = '/login/otp';
  static const String password = '/login/password';
  static const String completeProfile = '/register/complete-profile';
  static const String changePassword = '/account/change-password';
  static const String main = '/main';
  static const String support = '/support'; // New route for support page
  static const String teachers = '/teachers';
  static const String courses = '/courses';
  static const String courseCategories = '/course-categories';
}

/// The single place where the auth flow decides which screen comes next.
///
///   splash ──▶ login ──┬─(phone exists)──▶ password ──┬─(ok)──────────▶ main
///                      │                              ├─(otp login)───▶ otp
///                      │                              └─(forgot)──────▶ otp ──▶ change password ──▶ main
///                      ├─(new phone)────▶ otp ──▶ complete profile ──▶ main
///                      └─(skip)────────────────────────────────────────▶ main
class AppRouter {
  AppRouter._();

  static Future<T?> _push<T>(
    BuildContext context,
    Widget page,
    String name, {
    bool replace = false,
    bool clearStack = false,
  }) {
    final route = MaterialPageRoute<T>(
      builder: (_) => page,
      settings: RouteSettings(name: name),
    );

    if (clearStack) {
      return Navigator.of(context).pushAndRemoveUntil(route, (_) => false);
    }
    if (replace) {
      return Navigator.of(context).pushReplacement(route);
    }
    return Navigator.of(context).push(route);
  }

  // ---------------------------------------------------------------------------
  // Splash
  // ---------------------------------------------------------------------------

  static Future<void> toSplash(BuildContext context) => _push(
    context,
    const SplashScreen(),
    AppRoutes.splash,
    clearStack: true,
  );

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  static Future<void> toLogin(
    BuildContext context, {
    bool replace = false,
    String? initialPhone,
  }) => _push(
    context,
    LoginScreen(initialPhone: initialPhone),
    AppRoutes.login,
    replace: replace,
  );

  static Future<void> toPasswordScreen(
    BuildContext context, {
    required String phone,
  }) => _push(
    context,
    LoginPasswordScreen(phone: phone),
    AppRoutes.password,
  );

  static Future<void> toOtpScreen(
    BuildContext context, {
    required String phone,
    required OtpPurpose purpose,
    bool otpAlreadySent = false,
  }) => _push(
    context,
    LoginOtpScreen(
      phone: phone,
      purpose: purpose,
      otpAlreadySent: otpAlreadySent,
    ),
    AppRoutes.otp,
  );

  static Future<void> toCompleteProfile(
    BuildContext context, {
    bool replace = false,
  }) => _push(
    context,
    const CompleteProfileScreen(),
    AppRoutes.completeProfile,
    replace: replace,
  );

  /// Used by the "forgot password" branch: the OTP was already validated, the
  /// user only has to choose a new password (or skip).
  static Future<void> toChangePassword(
    BuildContext context, {
    String? phone,
    String? otp,
    bool allowSkip = true,
    bool replace = false,
  }) => _push(
    context,
    ChangePasswordScreen(phone: phone, otp: otp, allowSkip: allowSkip),
    AppRoutes.changePassword,
    replace: replace,
  );

  // ---------------------------------------------------------------------------
  // Main
  // ---------------------------------------------------------------------------

  static Future<void> toMain(BuildContext context, {bool clearStack = true}) =>
      _push(
        context,
        const MainBottomNavigation(),
        AppRoutes.main,
        clearStack: clearStack,
      );

  // ---------------------------------------------------------------------------
  // Teachers
  // ---------------------------------------------------------------------------

  static Future<void> toTeachers(BuildContext context) => _push(
        context,
        const TeachersListScreen(),
        AppRoutes.teachers,
      );

  // ---------------------------------------------------------------------------
  // Courses
  // ---------------------------------------------------------------------------

  static Future<void> toCourses(
    BuildContext context, {
    int? categoryId,
  }) => _push(
        context,
        CoursesScreen(categoryId: categoryId),
        AppRoutes.courses,
      );

  // ---------------------------------------------------------------------------
  // Support
  // ---------------------------------------------------------------------------

  static Future<void> toSupport(BuildContext context) => _push(
        context,
        const TicketsScreen(),
        AppRoutes.support,
      );

  // ---------------------------------------------------------------------------
  // Course Categories
  // ---------------------------------------------------------------------------

  static Future<void> toCourseCategories(
    BuildContext context, {
    int? categoryId,
    String? categoryTitle,
  }) => _push(
        context,
        CourseCategoriesScreen(categoryId: categoryId, categoryTitle: categoryTitle),
        AppRoutes.courseCategories,
      );
}
