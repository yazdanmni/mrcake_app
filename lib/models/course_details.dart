import '../core/network/api_client.dart';
import '../core/network/api_config.dart';

/// `CourseDetail` -> `GET /api/v1/courses/{id}/`
///
/// The constructor keeps the original mock-data signature so
/// `lib/data/course_details_data.dart` and the existing widgets keep
/// compiling; [fromJson] understands **both** the mock keys and the real
/// backend keys (`chapters[].lessons[]`, `video_trailer`, …).
class CourseDetails {
  final int courseId;
  final String description;
  final String introVideo;
  final String introImage;
  final List<CourseChapter> chapters;
  final List<CourseIngredient> ingredients;

  // ---------------------------------------------------------------------------
  // Extra fields provided by the backend (optional).
  // ---------------------------------------------------------------------------

  final String? shortDescription;
  final String? prerequisites;
  final String? whatYouLearn;

  /// `beginner | intermediate | advanced | all`
  final String? level;

  final String rating;
  final int reviewsCount;
  final int studentsCount;
  final int chaptersCount;
  final int lessonsCount;

  /// مجموع مدت دوره بر حسب ثانیه
  final int totalDurationSeconds;

  /// مدت تیزر معرفی بر حسب ثانیه
  final int introDurationSeconds;

  final int? teacherProfileId;

  final bool isEnrolled;
  final bool isFavorite;

  final int? userRating;
  final String? userReviewComment;

  const CourseDetails({
    required this.courseId,
    required this.description,
    required this.introVideo,
    required this.introImage,
    required this.chapters,
    required this.ingredients,
    this.shortDescription,
    this.prerequisites,
    this.whatYouLearn,
    this.level,
    this.rating = '',
    this.reviewsCount = 0,
    this.studentsCount = 0,
    this.chaptersCount = 0,
    this.lessonsCount = 0,
    this.totalDurationSeconds = 0,
    this.introDurationSeconds = 0,
    this.teacherProfileId,
    this.isEnrolled = false,
    this.isFavorite = false,
    this.userRating,
    this.userReviewComment,
  });

  /// کل تعداد قسمت‌ها — از `lessons` استخراج می‌شود اگر بک‌اند عدد نداده باشد.
  int get resolvedLessonsCount {
    if (lessonsCount > 0) return lessonsCount;
    return chapters.fold<int>(0, (sum, chapter) => sum + chapter.lessons.length);
  }

  /// مجموع مدت دوره بر حسب دقیقه.
  int get totalDurationMinutes {
    if (totalDurationSeconds > 0) {
      return (totalDurationSeconds / 60).ceil();
    }
    return 0;
  }

  bool get hasIntroVideo => introVideo.isNotEmpty;

  /// Returns a copy carrying [items] as the chapter list.
  ///
  /// `CourseDetail.chapters` is sometimes empty while the chapters live in
  /// `GET /api/v1/courses/chapters/`, so the repository merges them in.
  CourseDetails copyWithChapters(List<CourseChapter> items) {
    return CourseDetails(
      courseId: courseId,
      description: description,
      introVideo: introVideo,
      introImage: introImage,
      chapters: items,
      ingredients: ingredients,
      shortDescription: shortDescription,
      prerequisites: prerequisites,
      whatYouLearn: whatYouLearn,
      level: level,
      rating: rating,
      reviewsCount: reviewsCount,
      studentsCount: studentsCount,
      chaptersCount: items.isNotEmpty ? items.length : chaptersCount,
      lessonsCount: lessonsCount,
      totalDurationSeconds: totalDurationSeconds,
      introDurationSeconds: introDurationSeconds,
      teacherProfileId: teacherProfileId,
      isEnrolled: isEnrolled,
      isFavorite: isFavorite,
      userRating: userRating,
      userReviewComment: userReviewComment,
    );
  }

  factory CourseDetails.fromJson(Map<String, dynamic> json) {
    final rawChapters = Json.asMapList(json['chapters']);

    final userReview = Json.asMap(json['user_review']);

    return CourseDetails(
      courseId:
          Json.asInt(json['course_id']) ??
              Json.asInt(json['id']) ??
              0,

      description:
          Json.asString(json['description']) ??
              Json.asString(json['short_description']) ??
              '',

      introVideo: _mediaUrl(json['intro_video'] ?? json['video_trailer']),

      introImage: _mediaUrl(json['intro_image'] ?? json['image']),

      chapters: rawChapters.isEmpty
          ? _mockChapters(json['chapters'])
          : rawChapters.asMap().entries
                .map(
                  (entry) => CourseChapter.fromJson(
                    entry.value,
                    fallbackNumber: entry.key + 1,
                  ),
                )
                .toList(growable: false),

      ingredients: Json.asMapList(json['ingredients'])
          .map(CourseIngredient.fromJson)
          .toList(growable: false),

      shortDescription: Json.asString(json['short_description']),
      prerequisites: Json.asString(json['prerequisites']),
      whatYouLearn: Json.asString(json['what_you_learn']),
      level: Json.asString(json['level']),

      rating: Json.asString(json['rating']) ?? '',
      reviewsCount: Json.asInt(json['reviews_count']) ?? 0,
      studentsCount: Json.asInt(json['students_count']) ?? 0,
      chaptersCount:
          Json.asInt(json['chapters_count']) ?? rawChapters.length,
      lessonsCount: Json.asInt(json['lessons_count']) ?? 0,
      totalDurationSeconds: Json.asInt(json['total_duration_seconds']) ?? 0,
      introDurationSeconds: Json.asInt(json['intro_duration_seconds']) ?? 0,

      teacherProfileId: Json.asInt(json['teacher_profile']),

      isEnrolled: Json.asBool(json['is_enrolled']),
      isFavorite: Json.asBool(json['is_favorite']),

      userRating: Json.asInt(userReview?['rating']),
      userReviewComment: Json.asString(userReview?['comment']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'course_id': courseId,
      'description': description,
      'intro_video': introVideo,
      'intro_image': introImage,
      'chapters': chapters.map((e) => e.toJson()).toList(),
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      if (shortDescription != null) 'short_description': shortDescription,
      if (prerequisites != null) 'prerequisites': prerequisites,
      if (whatYouLearn != null) 'what_you_learn': whatYouLearn,
      if (level != null) 'level': level,
      'rating': rating,
      'reviews_count': reviewsCount,
      'students_count': studentsCount,
      'chapters_count': chaptersCount,
      'lessons_count': lessonsCount,
      'total_duration_seconds': totalDurationSeconds,
      'intro_duration_seconds': introDurationSeconds,
      if (teacherProfileId != null) 'teacher_profile': teacherProfileId,
      'is_enrolled': isEnrolled,
      'is_favorite': isFavorite,
    };
  }

  static String _mediaUrl(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return '';
    return ApiConfig.mediaUrl(raw);
  }

  static List<CourseChapter> _mockChapters(dynamic value) {
    if (value is! List) return const <CourseChapter>[];
    return value
        .map((item) => Json.asMap(item))
        .whereType<Map<String, dynamic>>()
        .map(CourseChapter.fromJson)
        .toList(growable: false);
  }
}

// ============================================================================
// CHAPTER
// ============================================================================

/// `ChapterWithLessons` -> `CourseDetail.chapters[]`
class CourseChapter {
  final int id;
  final int number;
  final String title;
  final List<CourseLesson> lessons;

  // ---------------------------------------------------------------------------
  // Extra fields provided by the backend (optional).
  // ---------------------------------------------------------------------------

  final String? description;
  final bool isActive;

  const CourseChapter({
    required this.id,
    required this.number,
    required this.title,
    required this.lessons,
    this.description,
    this.isActive = true,
  });

  int get lessonsCount =>
      lessons.isNotEmpty ? lessons.length : 0;

  factory CourseChapter.fromJson(
    Map<String, dynamic> json, {
    int fallbackNumber = 0,
  }) {
    final rawLessons = Json.asMapList(json['lessons']);

    return CourseChapter(
      id: Json.asInt(json['id']) ?? 0,

      // The API calls it `order`; the widgets were built around `number`.
      number:
          Json.asInt(json['order']) ??
              Json.asInt(json['number']) ??
              fallbackNumber,

      title: Json.asString(json['title']) ?? '',

      lessons: rawLessons.isEmpty
          ? _mockLessons(json['lessons'])
          : rawLessons
                .asMap()
                .entries
                .map(
                  (entry) => CourseLesson.fromJson(
                    entry.value,
                    fallbackOrder: entry.key + 1,
                  ),
                )
                .toList(growable: false),

      description: Json.asString(json['description']),
      isActive: Json.asBool(json['is_active'], fallback: true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'title': title,
      'lessons': lessons.map((e) => e.toJson()).toList(),
      if (description != null) 'description': description,
      'is_active': isActive,
    };
  }

  static List<CourseLesson> _mockLessons(dynamic value) {
    if (value is! List) return const <CourseLesson>[];
    return value
        .map((item) => Json.asMap(item))
        .whereType<Map<String, dynamic>>()
        .map(CourseLesson.fromJson)
        .toList(growable: false);
  }
}

// ============================================================================
// LESSON
// ============================================================================

/// `LessonPublic` -> `CourseDetail.chapters[].lessons[]`
class CourseLesson {
  final int id;
  final String title;
  final String video;
  final String duration;

  /// توضیحات مخصوص همین قسمت
  final String description;

  /// مواد اولیه مخصوص همین قسمت
  final List<CourseIngredient> ingredients;

  // ---------------------------------------------------------------------------
  // Extra fields provided by the backend (optional).
  // ---------------------------------------------------------------------------

  /// `video | text | pdf | audio`
  final String type;

  final String? thumbnail;
  final String? textContent;
  final String? pdfFile;
  final String? audioFile;

  final bool isFree;
  final int order;

  /// مدت زمان بر حسب ثانیه (عدد خام بک‌اند)
  final int durationSeconds;

  const CourseLesson({
    required this.id,
    required this.title,
    required this.video,
    required this.duration,
    required this.description,
    required this.ingredients,
    this.type = 'video',
    this.thumbnail,
    this.textContent,
    this.pdfFile,
    this.audioFile,
    this.isFree = false,
    this.order = 0,
    this.durationSeconds = 0,
  });

  bool get hasVideo => video.isNotEmpty;
  bool get isTextLesson => type == 'text';
  bool get isPdfLesson => type == 'pdf';
  bool get isAudioLesson => type == 'audio';

  factory CourseLesson.fromJson(
    Map<String, dynamic> json, {
    int fallbackOrder = 0,
  }) {
    final seconds =
        Json.asInt(json['duration']) ??
            Json.asInt(json['duration_seconds']) ??
            0;

    return CourseLesson(
      id: Json.asInt(json['id']) ?? 0,

      title: Json.asString(json['title']) ?? '',

      video: _mediaUrl(json['video'] ?? json['video_file'] ?? json['video_url']),

      // The mock data already carries `MM:SS`; the backend sends seconds.
      duration: _durationLabel(json, seconds),

      description: Json.asString(json['description']) ?? '',

      ingredients: Json.asMapList(json['ingredients'])
          .map(CourseIngredient.fromJson)
          .toList(growable: false),

      type: Json.asString(json['type']) ?? 'video',
      thumbnail: _mediaUrlOrNull(json['thumbnail']),
      textContent: Json.asString(json['text_content']),
      pdfFile: _mediaUrlOrNull(json['pdf_file']),
      audioFile: _mediaUrlOrNull(json['audio_file']),
      isFree: Json.asBool(json['is_free']),
      order: Json.asInt(json['order']) ?? fallbackOrder,
      durationSeconds: seconds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'video': video,
      'duration': duration,
      'description': description,
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      'type': type,
      if (thumbnail != null) 'thumbnail': thumbnail,
      if (textContent != null) 'text_content': textContent,
      if (pdfFile != null) 'pdf_file': pdfFile,
      if (audioFile != null) 'audio_file': audioFile,
      'is_free': isFree,
      'order': order,
      'duration_seconds': durationSeconds,
    };
  }

  /// Prefers an explicit `MM:SS` string, otherwise formats the seconds.
  static String _durationLabel(Map<String, dynamic> json, int seconds) {
    final raw = json['duration']?.toString();
    if (raw != null && raw.contains(':')) return raw;

    if (seconds <= 0) return '00:00';

    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${rest.toString().padLeft(2, '0')}';
  }

  static String _mediaUrl(dynamic value) => _mediaUrlOrNull(value) ?? '';

  static String? _mediaUrlOrNull(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return null;
    return ApiConfig.mediaUrl(raw);
  }
}

// ============================================================================
// INGREDIENT
// ============================================================================

class CourseIngredient {
  final int id;
  final String name;
  final String amount;

  final int position;

  const CourseIngredient({
    required this.id,
    required this.name,
    required this.amount,
    this.position = 0,
  });

  factory CourseIngredient.fromJson(Map<String, dynamic> json) {
    return CourseIngredient(
      id: Json.asInt(json['id']) ?? 0,
      name: Json.asString(json['name']) ?? '',
      amount: Json.asString(json['amount']) ?? '',
      position: Json.asInt(json['position']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'position': position,
    };
  }
}
