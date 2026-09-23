import '../core/network/api_client.dart';
import '../core/network/api_config.dart';
import 'course.dart';

/// Promo card content for the "معرفی دوره ها" carousel on the home screen.
///
/// There is no dedicated endpoint for these cards, so they are derived from
/// the course list through [CourseIntroVideo.fromCourse].
class CourseIntroVideo {
  final String thumbnail;
  final String title;

  final String teacherFirstName;
  final String teacherLastName;
  final String teacherAvatar;

  /// برچسب مدت روی کاور (MM:SS)
  final String duration;

  /// مدت کل دوره بر حسب ساعت
  final String courseDuration;

  final String studentsCount;

  /// برای رفتن به صفحه جزئیات دوره
  final int? courseId;

  const CourseIntroVideo({
    required this.thumbnail,
    required this.title,
    required this.teacherFirstName,
    required this.teacherLastName,
    required this.teacherAvatar,
    required this.duration,
    required this.courseDuration,
    required this.studentsCount,
    this.courseId,
  });

  String get teacherFullName {
    return '$teacherFirstName $teacherLastName'.trim();
  }

  /// Builds the card out of a `CourseList` entry.
  ///
  /// `CourseList` carries no trailer url, so the cover image is used as the
  /// thumbnail and the badge shows the total length of the course.
  factory CourseIntroVideo.fromCourse(Course course) {
    return CourseIntroVideo(
      thumbnail: course.image,
      title: course.title,
      teacherFirstName: course.instructorFirstName,
      teacherLastName: course.instructorLastName,
      teacherAvatar: course.instructorImage,
      duration: formatSeconds(course.totalDurationSeconds),
      courseDuration: course.duration,
      studentsCount: course.studentsCount.toString(),
      courseId: course.id,
    );
  }

  /// `MM:SS` (or `HH:MM:SS` for long content) from a number of seconds.
  static String formatSeconds(int seconds) {
    if (seconds <= 0) return '00:00';

    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final rest = seconds % 60;

    final mm = minutes.toString().padLeft(2, '0');
    final ss = rest.toString().padLeft(2, '0');

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$mm:$ss';
    }

    return '$mm:$ss';
  }

  factory CourseIntroVideo.fromJson(
    Map<String, dynamic> json,
  ) {
    final seconds =
        Json.asInt(json['duration_seconds']) ??
            Json.asInt(json['intro_duration_seconds']) ??
            0;

    return CourseIntroVideo(
      thumbnail:
          _mediaUrl(json['thumbnail'] ?? json['image']),

      title: Json.asString(json['title']) ?? '',

      teacherFirstName:
          Json.asString(json['teacher_first_name']) ?? '',
      teacherLastName:
          Json.asString(json['teacher_last_name']) ?? '',
      teacherAvatar:
          _mediaUrl(json['teacher_avatar']),

      // The mock value is already `MM:SS`; the backend sends seconds.
      duration:
          Json.asString(json['duration']) ??
              formatSeconds(seconds),

      courseDuration:
          Json.asString(json['course_duration']) ?? '0',
      studentsCount:
          Json.asString(json['students_count']) ?? '0',

      courseId:
          Json.asInt(json['course_id']) ?? Json.asInt(json['id']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'thumbnail': thumbnail,
      'title': title,
      'teacher_first_name': teacherFirstName,
      'teacher_last_name': teacherLastName,
      'teacher_avatar': teacherAvatar,
      'duration': duration,
      'course_duration': courseDuration,
      'students_count': studentsCount,
      if (courseId != null) 'course_id': courseId,
    };
  }

  static String _mediaUrl(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return '';
    return ApiConfig.mediaUrl(raw);
  }
}
