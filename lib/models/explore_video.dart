import '../core/network/api_client.dart';
import '../core/network/api_config.dart';

/// `ExploreVideo` -> `GET /api/v1/content/explore-videos/`
///
/// Real payload:
/// ```json
/// {"id":1,"title":"..","description":"..","duration_seconds":90,
///  "status":"published","published_at":"..","teacher":3,
///  "video_media":12,"thumbnail_media":13,"is_active":true}
/// ```
///
/// `video_media` / `thumbnail_media` are **media ids**, and `teacher` is a
/// user id — none of them is a url. The repository resolves them through
/// `GET /api/v1/media/{id}/` and `GET /api/v1/accounts/users/{id}/` and then
/// calls [withMedia] / [withInstructor].
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

  // ---------------------------------------------------------------------------
  // Extra fields provided by the backend (optional).
  // ---------------------------------------------------------------------------

  final String description;
  final String status;
  final bool isActive;

  /// `video_media` id — needed to resolve [videoUrl].
  final int? videoMediaId;

  /// `thumbnail_media` id — needed to resolve [thumbnail].
  final int? thumbnailMediaId;
  final int? courseId;

  /// `true` when [videoUrl] is empty **because the media lookup was rejected**
  /// rather than because the reel has no video.
  ///
  /// `GET v1/content/explore-videos/` is public but hands out media **ids**, and
  /// `GET v1/media/{id}/` is auth-only: a guest is refused every id, so the url
  /// stays empty on a video whose file is sitting on the public CDN. Without
  /// this flag the player can only say «آدرس ویدیو خالی است» — which is a lie —
  /// instead of telling the user to sign in. Never set by [ExploreVideo.fromJson];
  /// only
  /// [ExploreVideo.withMedia] when the repository passes the reason along.
  final bool videoNeedsAuth;

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
    this.description = '',
    this.status = 'published',
    this.isActive = true,
    this.videoMediaId,
    this.thumbnailMediaId,
    this.courseId, // Added courseId to constructor
    this.videoNeedsAuth = false,
  });

  String get instructorFullName {
    return '$instructorFirstName $instructorLastName'.trim();
  }

  bool get isPublished => status == 'published';

  /// `MM:SS` — used by the reels overlay.
  String get durationLabel {
    if (duration <= 0) return '00:00';
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  factory ExploreVideo.fromJson(Map<String, dynamic> json) {
    return ExploreVideo(
      id: Json.asInt(json['id']) ?? 0,

      videoUrl: _mediaUrl(json['video_url']),

      thumbnail: _mediaUrl(json['thumbnail'] ?? json['thumbnail_url']),

      title: Json.asString(json['title']) ?? '',

      instructorId:
          Json.asInt(json['teacher']) ??
              Json.asInt(json['instructor_id']) ??
              0,

      instructorFirstName: Json.asString(json['instructor_first_name']) ?? '',
      instructorLastName: Json.asString(json['instructor_last_name']) ?? '',
      instructorImage: _mediaUrl(json['instructor_image']),

      duration:
          Json.asInt(json['duration_seconds']) ??
              Json.asInt(json['duration']) ??
              0,

      description: Json.asString(json['description']) ?? '',
      status: Json.asString(json['status']) ?? 'published',
      isActive: Json.asBool(json['is_active'], fallback: true),
      videoMediaId: Json.asInt(json['video_media']),
      thumbnailMediaId: Json.asInt(json['thumbnail_media']),
      courseId: Json.asInt(json['course_id']),
    );
  }

  /// Fills in the urls once the repository has resolved the media ids.
  ///
  /// [needsAuth] is set when the lookup was **refused** rather than empty — see
  /// [videoNeedsAuth]. It is deliberately not recomputed here: only the caller
  /// that made the request knows why it failed.
  ExploreVideo withMedia({
    String? videoUrl,
    String? thumbnail,
    bool needsAuth = false,
  }) {
    return ExploreVideo(
      id: id,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnail: thumbnail ?? this.thumbnail,
      title: title,
      instructorId: instructorId,
      instructorFirstName: instructorFirstName,
      instructorLastName: instructorLastName,
      instructorImage: instructorImage,
      duration: duration,
      description: description,
      status: status,
      isActive: isActive,
      videoMediaId: videoMediaId,
      thumbnailMediaId: thumbnailMediaId,
      courseId: courseId, // Pass courseId
      videoNeedsAuth: needsAuth || videoNeedsAuth,
    );
  }

  /// Fills in the instructor once the repository has resolved `teacher`.
  ExploreVideo withInstructor({
    int? id,
    String? firstName,
    String? lastName,
    String? image,
  }) {
    return ExploreVideo(
      id: this.id,
      videoUrl: videoUrl,
      thumbnail: thumbnail,
      title: title,
      instructorId: id ?? instructorId,
      instructorFirstName: firstName ?? instructorFirstName,
      instructorLastName: lastName ?? instructorLastName,
      instructorImage: image ?? instructorImage,
      duration: duration,
      description: description,
      status: status,
      isActive: isActive,
      videoMediaId: videoMediaId,
      thumbnailMediaId: thumbnailMediaId,
      courseId: courseId, // Pass courseId
      videoNeedsAuth: videoNeedsAuth,
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
      'description': description,
      'status': status,
      'is_active': isActive,
      if (videoMediaId != null) 'video_media': videoMediaId,
      if (thumbnailMediaId != null) 'thumbnail_media': thumbnailMediaId,
      if (courseId != null) 'course_id': courseId,
    };
  }

  static String _mediaUrl(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return '';
    return ApiConfig.mediaUrl(raw);
  }
}
