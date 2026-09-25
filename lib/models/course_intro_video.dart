import '../core/network/api_client.dart';
import '../core/network/api_config.dart';
import 'course.dart';
import 'course_details.dart';

/// Promo card content for the "معرفی دوره ها" carousel on the home screen.
///
/// Built from `GET /api/v1/courses/` plus each course's
/// `GET /api/v1/courses/{id}/` trailer (`video_trailer`).
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

  /// آدرس تیزر (`CourseDetail.video_trailer`). خالی یعنی هنوز hydrate نشده.
  final String videoUrl;

  /// خود دوره برای باز کردن `CourseDetailsScreen` بدون از دست دادن عنوان و استاد.
  final Course? course;

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
    this.videoUrl = '',
    this.course,
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
      course: course,
    );
  }

  /// Combines the list row with `GET /api/v1/courses/{id}/` so the card can
  /// show the real teaser (`video_trailer` + `intro_duration_seconds`).
  factory CourseIntroVideo.fromCourseDetails({
    required Course course,
    required CourseDetails details,
  }) {
    return CourseIntroVideo(
      thumbnail: details.introImage.isNotEmpty
          ? details.introImage
          : course.image,
      title: course.title,
      teacherFirstName: course.instructorFirstName,
      teacherLastName: course.instructorLastName,
      teacherAvatar: course.instructorImage,
      duration: formatSeconds(details.introDurationSeconds),
      courseDuration: course.duration,
      studentsCount: course.studentsCount.toString(),
      courseId: course.id,
      videoUrl: details.introVideo,
      course: course,
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
      thumbnail: _mediaUrl(json['thumbnail'] ?? json['image']),

      videoUrl: _mediaUrl(json['video_url'] ?? json['video_trailer']),

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
      if (videoUrl.isNotEmpty) 'video_url': videoUrl,
    };
  }

  static String _mediaUrl(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return '';
    return ApiConfig.mediaUrl(raw);
  }
}
