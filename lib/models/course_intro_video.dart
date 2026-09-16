class CourseIntroVideo {
  final String thumbnail;
  final String title;

  final String teacherFirstName;
  final String teacherLastName;
  final String teacherAvatar;

  final String duration;

  final String courseDuration;
  final String studentsCount;

  const CourseIntroVideo({
    required this.thumbnail,
    required this.title,
    required this.teacherFirstName,
    required this.teacherLastName,
    required this.teacherAvatar,
    required this.duration,
    required this.courseDuration,
    required this.studentsCount,
  });

  String get teacherFullName {
    return '$teacherFirstName $teacherLastName';
  }

  factory CourseIntroVideo.fromJson(
    Map<String, dynamic> json,
  ) {
    return CourseIntroVideo(
      thumbnail:
          json['thumbnail']?.toString() ?? '',
      title:
          json['title']?.toString() ?? '',

      teacherFirstName:
          json['teacher_first_name']?.toString() ?? '',
      teacherLastName:
          json['teacher_last_name']?.toString() ?? '',
      teacherAvatar:
          json['teacher_avatar']?.toString() ?? '',

      duration:
          json['duration']?.toString() ?? '00:00',

      courseDuration:
          json['course_duration']?.toString() ?? '0',
      studentsCount:
          json['students_count']?.toString() ?? '0',
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
    };
  }
}