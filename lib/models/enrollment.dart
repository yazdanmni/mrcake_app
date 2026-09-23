import '../core/network/api_client.dart';
import 'course.dart';

/// `Enrollment` -> `GET /api/v1/courses/enrollments/`,
/// `GET /api/v1/courses/my_courses/`
///
/// The constructor keeps the original mock-data signature so
/// `lib/data/enrollments_data.dart` and the existing widgets keep compiling;
/// [fromJson] understands **both** the mock keys and the real backend keys.
class Enrollment {
  final int id;
  final int userId;
  final int courseId;

  /// نسبت پیشرفت بین ۰ و ۱ — همان چیزی که ویجت‌ها انتظار دارند.
  final double progress;

  // ---------------------------------------------------------------------------
  // Extra fields provided by the backend (optional).
  // ---------------------------------------------------------------------------

  /// دوره کامل، همان‌طور که بک‌اند در `course` می‌فرستد.
  final Course? course;

  final int pricePaid;
  final int discountApplied;
  final bool isPaid;
  final bool completed;
  final int lessonProgressCount;
  final String? enrolledAt;

  const Enrollment({
    required this.id,
    required this.userId,
    required this.courseId,
    this.progress = 0,
    this.course,
    this.pricePaid = 0,
    this.discountApplied = 0,
    this.isPaid = false,
    this.completed = false,
    this.lessonProgressCount = 0,
    this.enrolledAt,
  });

  /// درصد پیشرفت به صورت عدد صحیح (۰ تا ۱۰۰).
  int get progressPercent => (progress * 100).round();

  factory Enrollment.fromJson(Map<String, dynamic> json) {
    final nestedCourse = Json.asMap(json['course']);

    // `progress_percent` (0..100) از بک‌اند، `progress` (0..1) از موک.
    final percent = Json.asInt(json['progress_percent']);

    final progress = percent != null
        ? (percent / 100).clamp(0.0, 1.0)
        : (Json.asDouble(json['progress']) ?? 0).clamp(0.0, 1.0);

    return Enrollment(
      id: Json.asInt(json['id']) ?? 0,

      // The API has no `user` field on an enrollment; the owner is implied by
      // the token. The mock used `userId`, so it is still read when present.
      userId: Json.asInt(json['user_id']) ?? Json.asInt(json['user']) ?? 0,

      courseId:
          Json.asInt(json['course_id']) ??
              Json.asInt(nestedCourse?['id']) ??
              0,

      progress: progress.toDouble(),

      course: nestedCourse == null ? null : Course.fromJson(nestedCourse),

      pricePaid: Json.asInt(json['price_paid']) ?? 0,
      discountApplied: Json.asInt(json['discount_applied']) ?? 0,
      isPaid: Json.asBool(json['is_paid']),
      completed: Json.asBool(json['completed']),
      lessonProgressCount: Json.asInt(json['lesson_progress_count']) ?? 0,
      enrolledAt: Json.asString(json['enrolled_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'course_id': courseId,
      'progress': progress,
      if (course != null) 'course': course!.toJson(),
      'price_paid': pricePaid,
      'discount_applied': discountApplied,
      'is_paid': isPaid,
      'completed': completed,
      'lesson_progress_count': lessonProgressCount,
      if (enrolledAt != null) 'enrolled_at': enrolledAt,
    };
  }
}
