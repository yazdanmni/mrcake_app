import '../models/enrollment.dart';

class EnrollmentsData {
  EnrollmentsData._();

  /// ثبت‌نام‌های موقت برای تست
  ///
  /// بعداً این اطلاعات از API دریافت می‌شوند.
  static const List<Enrollment> enrollments = [
    Enrollment(
      id: 1,
      userId: 1,
      courseId: 1,
      progress: 0.65,
    ),
    Enrollment(
      id: 2,
      userId: 1,
      courseId: 3,
      progress: 0.30,
    ),
  ];

  /// دریافت ثبت‌نام‌های یک کاربر
  static List<Enrollment> getByUserId(int userId) {
    return enrollments
        .where(
          (enrollment) => enrollment.userId == userId,
        )
        .toList();
  }
}
