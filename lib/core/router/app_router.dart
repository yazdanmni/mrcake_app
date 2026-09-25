import 'package:flutter/material.dart';
import 'package:mr_cake_project/pages/teacher/teacher_screen.dart';

import '../../navigation/main_bottom_navigation.dart';
import '../../pages/authpage/change_password_screen.dart';
import '../../pages/authpage/complete_profile_screen.dart';
import '../../pages/authpage/login_otp_screen.dart';
import '../../pages/authpage/login_password_screen.dart';
import '../../pages/authpage/login_screen.dart';
import '../../pages/cart/cart_screen.dart';
import '../../pages/orders/orders_screen.dart';
import '../../pages/recipes/recipes_screen.dart';
import '../../pages/splash/splash_screen.dart';
import '../../pages/students/students_screen.dart';
import '../../pages/support/tickets_screen.dart';
import '../../pages/teacher/teacher_courses_screen.dart';
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
  static const String support = '/support';
  static const String teachers = '/teachers';
  static const String teacherDetail = '/teacher/detail';
  static const String courses = '/courses';
  static const String courseCategories = '/course-categories';
  static const String teacherCourses = '/teachers/courses';
  static const String students = '/students';
  static const String recipes = '/recipes';
  static const String cart = '/cart';
  static const String orders = '/orders';
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
  static Future<void> toTeacherCourses(BuildContext context, int teacherId, String teacherName) => _push(
        context,
        TeacherCoursesScreen(teacherId: teacherId, teacherName: teacherName),
        AppRoutes.teacherCourses,
      );
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

  static Future<void> toTeacherDetail(
    BuildContext context, {
    int? teacherId,
  }) => _push(
        context,
        TeacherScreen(teacherId: teacherId),
        AppRoutes.teacherDetail,
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
  // Students
  // ---------------------------------------------------------------------------

  /// «هنرجوها» — the home shortcut. Only ever *pushed*, so it always has a back
  /// button, unlike `CoursesScreen` which is also a bottom-navigation tab.
  static Future<void> toStudents(BuildContext context) => _push(
        context,
        const StudentsScreen(),
        AppRoutes.students,
      );

  // ---------------------------------------------------------------------------
  // Recipes
  // ---------------------------------------------------------------------------

  /// «رسپی‌ها» — the home shortcut. Like [toStudents] this screen is never a
  /// navigation tab, so it is always entered from a button and always has a way
  /// back.
  static Future<void> toRecipes(BuildContext context) => _push(
        context,
        const RecipesScreen(),
        AppRoutes.recipes,
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

  // ---------------------------------------------------------------------------
  // Cart
  // ---------------------------------------------------------------------------

  /// «سبد خرید» — the courses whose enrollment request is still pending.
  ///
  /// Opened from the cart icon in the courses header and in the profile header;
  /// both used to be a placeholder ("سبد خرید به زودی فعال می‌شود").
  static Future<void> toCart(BuildContext context) => _push(
        context,
        const CartScreen(),
        AppRoutes.cart,
      );

  // ---------------------------------------------------------------------------
  // Orders
  // ---------------------------------------------------------------------------

  /// «سفارش های من» — every order the backend holds for this user.
  ///
  /// Opened from the «پرداختی‌ها» tile in the profile. A paid registration lives
  /// here as a `pending` order; once an admin marks it paid, the backend creates
  /// the enrollment and the course appears in «دوره‌های من».
  static Future<void> toOrders(BuildContext context) => _push(
        context,
        const OrdersScreen(),
        AppRoutes.orders,
      );
}
