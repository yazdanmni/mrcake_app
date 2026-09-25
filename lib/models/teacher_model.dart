import '../core/network/api_client.dart';
import '../core/network/api_config.dart';

/// `TeacherProfilePublic` -> `GET /api/v1/accounts/teachers/`
/// `GET /api/v1/accounts/teachers/{id}/`
///
/// The constructor keeps the original mock-data signature so
/// `lib/data/teacher_data.dart` and the existing widgets keep compiling;
/// [fromJson] understands **both** the mock keys and the real backend keys.
class Teacher {
  final int id;
  final String firstName;
  final String lastName;
  final String profileImage;

  final int userId;

  final int courseCount;
  final int experienceYears;
  final int studentsCount;

  final bool isVerified;

  final String about;

  final List<TeacherPortfolioItem> portfolio;

  // ---------------------------------------------------------------------------
  // Extra fields provided by the backend (optional).
  // ---------------------------------------------------------------------------

  /// تخصص اصلی استاد (`expertise`)
  final String expertise;

  /// امتیاز استاد به صورت رشته (`rating`)
  final String rating;

  final String? resume;
  final String? bio;

  final String? socialInstagram;
  final String? socialTelegram;

  /// `teacher_profile` id, present on `CourseDetail`.
  final int? teacherProfileId;

  const Teacher({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.profileImage,
    required this.courseCount,
    required this.experienceYears,
    required this.studentsCount,
    required this.isVerified,
    required this.about,
    required this.portfolio,
    required this.userId,
    this.expertise = '',
    this.rating = '',
    this.resume,
    this.bio,
    this.socialInstagram,
    this.socialTelegram,
    this.teacherProfileId,
  });

  String get fullName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? 'استاد مستر کیک' : name;
  }

  /// Returns a copy carrying [items] as the portfolio.
  ///
  /// `TeacherProfilePublic` only exposes a portfolio *hint*; the real items
  /// come from `GET /api/v1/content/teacher-portfolio/`, so the repository
  /// merges them in afterwards.
  Teacher withPortfolio(List<TeacherPortfolioItem> items) {
    return Teacher(
      id: id,
      firstName: firstName,
      lastName: lastName,
      profileImage: profileImage,
      courseCount: courseCount,
      experienceYears: experienceYears,
      studentsCount: studentsCount,
      isVerified: isVerified,
      about: about,
      portfolio: items,
      userId: userId,
      expertise: expertise,
      rating: rating,
      resume: resume,
      bio: bio,
      socialInstagram: socialInstagram,
      socialTelegram: socialTelegram,
      teacherProfileId: teacherProfileId,
    );
  }

  factory Teacher.fromJson(Map<String, dynamic> json) {
    // `user` is the nested `UserPublic` object; the flat mock keys are the
    // fallback so both payload shapes are understood.
    final user = Json.asMap(json['user']);

    final firstName =
        Json.asString(user?['first_name']) ??
            Json.asString(json['first_name']) ??
            '';

    final lastName =
        Json.asString(user?['last_name']) ??
            Json.asString(json['last_name']) ??
            '';

    return Teacher(
      id: Json.asInt(json['id']) ?? 0,

      firstName: firstName,
      lastName: lastName,

      profileImage: _mediaUrl(
        user?['avatar'] ?? json['profile_image'] ?? json['avatar'],
      ),

      userId: Json.asInt(user?['id']) ?? 0,

      courseCount:
          Json.asInt(json['courses_count']) ??
              Json.asInt(json['course_count']) ??
              0,

      experienceYears:
          Json.asInt(json['years_experience']) ??
              Json.asInt(json['experience_years']) ??
              0,

      studentsCount:
          Json.asInt(json['students_count']) ??
              Json.asInt(json['students_count']) ??
              0,

      isVerified: Json.asBool(
        json['is_blue_verified'],
        fallback: Json.asBool(json['is_verified']),
      ),

      about:
          Json.asString(json['about']) ??
              Json.asString(json['resume']) ??
              '',

      portfolio: _portfolio(json['portfolios'] ?? json['portfolio']),

      expertise: Json.asString(json['expertise']) ?? '',
      rating: Json.asString(json['rating']) ?? '',
      resume: Json.asString(json['resume']),
      bio: Json.asString(user?['bio']),
      socialInstagram: Json.asString(json['social_instagram']),
      socialTelegram: Json.asString(json['social_telegram']),
      teacherProfileId: Json.asInt(json['teacher_profile_id']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'profile_image': profileImage,
      'course_count': courseCount,
      'experience_years': experienceYears,
      'students_count': studentsCount,
      'is_verified': isVerified,
      'about': about,
      'portfolio': portfolio.map((e) => e.toJson()).toList(),
      'expertise': expertise,
      'rating': rating,
      if (resume != null) 'resume': resume,
      if (socialInstagram != null) 'social_instagram': socialInstagram,
      if (socialTelegram != null) 'social_telegram': socialTelegram,
    };
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _mediaUrl(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return '';
    return ApiConfig.mediaUrl(raw);
  }

  /// `portfolios` is a plain string in `TeacherProfilePublic` (it is a count /
  /// hint, not the items), so only a real list is mapped here. The items come
  /// from `GET /api/v1/content/teacher-portfolio/`.
  static List<TeacherPortfolioItem> _portfolio(dynamic value) {
    if (value is! List) return const <TeacherPortfolioItem>[];
    return value
        .map((item) => Json.asMap(item))
        .whereType<Map<String, dynamic>>()
        .map(TeacherPortfolioItem.fromJson)
        .toList(growable: false);
  }
}

/// A work in a teacher's portfolio.
///
/// **Two backend resources feed this one model**, because the app reads both:
///
/// * `GET /api/v1/accounts/teacher-portfolios/` -> `TeacherPortfolio`
///   (`{id, student, student_name, title, description, image, video, is_active}`)
///   — the **teacher profile** and the «هنرجوها» gallery read this one. `image`
///   and `video` are **direct urls** and exactly one of them is set.
/// * `GET /api/v1/content/teacher-portfolio/` -> `TeacherPortfolioItem`
///   (`{id, type, description, position, is_published, teacher, media}`) — the
///   older shape, which carries a `type` enum and only a `media` **id** that the
///   repository resolves through `GET /api/v1/media/{id}/`.
///
/// The two are kept in one type so the grid and the viewer are shared and
/// cannot drift apart.
class TeacherPortfolioItem {
  final int id;

  /// تصویر کاور نمونه کار
  final String image;

  /// true = ویدیو
  /// false = عکس
  final bool isVideo;

  /// فقط برای ویدیو
  final String? videoUrl;

  /// توضیحی که استاد برای نمونه کار نوشته
  final String description;

  // ---------------------------------------------------------------------------
  // Fields of the `accounts/teacher-portfolios/` shape.
  // ---------------------------------------------------------------------------

  /// «عنوان نمونه کار» — only the accounts shape has one.
  final String title;

  /// The student the work belongs to (the account **id**).
  final int studentId;

  /// «هنرجو» — the student's name, resolved by the backend.
  final String studentName;

  // ---------------------------------------------------------------------------
  // Extra fields provided by the backend (optional).
  // ---------------------------------------------------------------------------

  /// `media` id — needed to resolve the real file url.
  final int? mediaId;

  final int teacherId;
  final int position;
  final bool isPublished;

  const TeacherPortfolioItem({
    required this.id,
    required this.image,
    required this.isVideo,
    this.videoUrl,
    required this.description,
    this.title = '',
    this.studentId = 0,
    this.studentName = '',
    this.mediaId,
    this.teacherId = 0,
    this.position = 0,
    this.isPublished = true,
  });

  factory TeacherPortfolioItem.fromJson(Map<String, dynamic> json) {
    final type = Json.asString(json['type']);

    final image = _mediaUrl(
      json['image'] ?? json['thumbnail'] ?? json['media_url'],
    );

    final video = Json.asString(json['video'] ?? json['video_url']);

    // ⚠️ `type` exists **only** on the `content/` shape. On the
    // `accounts/teacher-portfolios/` shape the backend distinguishes the two
    // media by which url it filled in, so deriving `isVideo` from `type` alone
    // would mark every accounts row as a picture: a video work would then be
    // rendered from an empty `image` (a placeholder) and its player would never
    // be built. A non-empty `video` url is the signal that is true of both.
    final isVideo = type == 'video' || (video != null && video.isNotEmpty);

    return TeacherPortfolioItem(
      id: Json.asInt(json['id']) ?? 0,
      image: image,
      isVideo: isVideo,
      videoUrl: video == null || video.isEmpty ? null : _mediaUrl(video),
      description: Json.asString(json['description']) ?? '',
      title: Json.asString(json['title']) ?? '',
      studentId: Json.asInt(json['student']) ?? 0,
      studentName: Json.asString(json['student_name']) ?? '',
      mediaId: Json.asInt(json['media']),
      teacherId: Json.asInt(json['teacher']) ?? 0,
      position: Json.asInt(json['position']) ?? 0,
      isPublished: Json.asBool(json['is_published'], fallback: true),
    );
  }

  /// Fills in the urls once the repository has resolved the `media` id.
  TeacherPortfolioItem withMedia({String? image, String? video}) {
    return TeacherPortfolioItem(
      id: id,
      image: image ?? this.image,
      isVideo: isVideo,
      videoUrl: video ?? videoUrl,
      description: description,
      title: title,
      studentId: studentId,
      studentName: studentName,
      mediaId: mediaId,
      teacherId: teacherId,
      position: position,
      isPublished: isPublished,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image': image,
      'is_video': isVideo,
      if (videoUrl != null) 'video_url': videoUrl,
      'description': description,
      if (title.isNotEmpty) 'title': title,
      if (studentId != 0) 'student': studentId,
      if (studentName.isNotEmpty) 'student_name': studentName,
      if (mediaId != null) 'media': mediaId,
      'teacher': teacherId,
      'position': position,
      'is_published': isPublished,
    };
  }

  static String _mediaUrl(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return '';
    return ApiConfig.mediaUrl(raw);
  }
}
