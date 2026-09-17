class ExploreVideo {
  final int id;

  /// آدرس ویدیو
  final String videoUrl;

  /// تصویر کاور ویدیو
  final String thumbnail;

  /// موضوع/عنوان ویدیو
  final String title;

  /// اطلاعات استاد
  final int instructorId;
  final String instructorFirstName;
  final String instructorLastName;
  final String instructorImage;

  /// مدت زمان ویدیو بر حسب ثانیه
  final int duration;

  const ExploreVideo({
    required this.id,
    required this.videoUrl,
    required this.thumbnail,
    required this.title,
    required this.instructorId,
    required this.instructorFirstName,
    required this.instructorLastName,
    required this.instructorImage,
    required this.duration,
  });

  String get instructorFullName {
    return '$instructorFirstName $instructorLastName';
  }

  factory ExploreVideo.fromJson(Map<String, dynamic> json) {
    return ExploreVideo(
      id: int.tryParse(
            json['id']?.toString() ?? '0',
          ) ??
          0,
      videoUrl: json['video_url']?.toString() ?? '',
      thumbnail: json['thumbnail']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      instructorId: int.tryParse(
            json['instructor_id']?.toString() ?? '0',
          ) ??
          0,
      instructorFirstName:
          json['instructor_first_name']?.toString() ?? '',
      instructorLastName:
          json['instructor_last_name']?.toString() ?? '',
      instructorImage:
          json['instructor_image']?.toString() ?? '',
      duration: int.tryParse(
            json['duration']?.toString() ?? '0',
          ) ??
          0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'video_url': videoUrl,
      'thumbnail': thumbnail,
      'title': title,
      'instructor_id': instructorId,
      'instructor_first_name': instructorFirstName,
      'instructor_last_name': instructorLastName,
      'instructor_image': instructorImage,
      'duration': duration,
    };
  }
}