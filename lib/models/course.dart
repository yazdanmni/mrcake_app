import '../core/network/api_client.dart';
import '../core/network/api_config.dart';

/// A course as returned by `GET /api/v1/courses/` (`CourseList`) and by the
/// featured / latest / free / paid / best_selling / my_courses endpoints.
///
/// The constructor keeps the original mock-data signature so `lib/data/*` and
/// every existing widget keep compiling; [fromJson] understands **both** the
/// mock keys and the real backend keys.
class Course {
  final int id;

  final String image;
  final String title;

  final String instructorFirstName;
  final String instructorLastName;
  final String instructorImage;

  final String price;
  final String currency;

  final String lessons;
  final String duration;

  final int studentsCount;

  /// دسته‌بندی موضوعی دوره
  ///
  /// یک دوره می‌تواند در چند دسته قرار داشته باشد.
  final List<int> categoryIds;

  /// نوع نمایش دوره در سکشن‌ها
  ///
  /// free         → دوره‌های رایگان
  /// professional → دوره‌های حرفه‌ای
  /// single       → تک‌آموزشی
  final CourseType type;

  /// دسترسی به دوره
  ///
  /// free → رایگان
  /// paid → پولی
  final CourseAccess access;

  // ---------------------------------------------------------------------------
  // Extra fields provided by the backend (optional, used by newer widgets).
  // ---------------------------------------------------------------------------

  final String? slug;
  final String? shortDescription;

  /// امتیاز دوره (به صورت رشته، مثل «۴.۵»)
  final String? rating;
  final int reviewsCount;

  /// آیا دوره ویژه است
  final bool featured;

  /// قیمت قبل از تخفیف
  final int? discountPrice;

  /// سطح دوره: beginner | intermediate | advanced | all
  final String? level;

  /// آیا دوره تخفیف دارد
  final bool hasDiscount;

  /// مجموع مدت دوره بر حسب ثانیه (`total_duration_seconds`).
  final int totalDurationSeconds;

  const Course({
    required this.id,
    required this.image,
    required this.title,
    required this.instructorFirstName,
    required this.instructorLastName,
    required this.instructorImage,
    required this.price,
    required this.currency,
    required this.lessons,
    required this.duration,
    required this.studentsCount,
    required this.categoryIds,
    required this.type,
    required this.access,
    this.slug,
    this.shortDescription,
    this.rating,
    this.reviewsCount = 0,
    this.featured = false,
    this.discountPrice,
    this.level,
    this.hasDiscount = false,
    this.totalDurationSeconds = 0,
  });

  String get instructorFullName {
    return '$instructorFirstName $instructorLastName';
  }

  bool get isFree => access == CourseAccess.free;

  /// `true` when [price] is zero or empty.
  bool get isFreeByPrice {
    final digits = price.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty || int.tryParse(digits) == 0;
  }

  // ---------------------------------------------------------------------------
  // JSON
  // ---------------------------------------------------------------------------

  factory Course.fromJson(Map<String, dynamic> json) {
    final teacher = Json.asMap(json['teacher']);
    final category = Json.asMap(json['category']);

    final isFree = Json.asBool(
      json['is_free'],
      fallback: _accessFromJson(json['access']?.toString()) ==
          CourseAccess.free,
    );

    final lessonsCount =
        Json.asInt(json['lessons_count']) ?? _asInt(json['lessons']) ?? 0;

    final categoryIds = _categoryIdsFromJson(json['category_ids']);
    final singleCategoryId = Json.asInt(category?['id']);

    final finalPrice = Json.asInt(json['final_price']) ??
        Json.asInt(json['price']) ??
        _asInt(json['price']) ??
        0;

    final rawPrice =
        Json.asInt(json['discount_price']) ?? Json.asInt(json['price']);

    return Course(
      id: Json.asInt(json['id']) ?? 0,

      image: _mediaUrl(json['image']),

      title: json['title']?.toString() ?? '',

      instructorFirstName:
          teacher?['first_name']?.toString() ??
              json['instructor_first_name']?.toString() ??
              '',

      instructorLastName:
          teacher?['last_name']?.toString() ??
              json['instructor_last_name']?.toString() ??
              '',

      instructorImage: _mediaUrl(
        teacher?['avatar'] ?? json['instructor_image'],
      ),

      price: finalPrice.toString(),

      currency: json['currency']?.toString() ?? 'تومان',

      lessons: lessonsCount.toString(),

      duration: _durationLabel(json, lessonsCount),

      studentsCount: Json.asInt(json['students_count']) ?? 0,

      categoryIds: categoryIds.isNotEmpty
          ? categoryIds
          : (singleCategoryId != null && singleCategoryId > 0
                ? <int>[singleCategoryId]
                : const <int>[]),

      type: _courseTypeFromApi(json, isFree: isFree, lessonsCount: lessonsCount),

      access: isFree ? CourseAccess.free : CourseAccess.paid,

      slug: json['slug']?.toString(),
      shortDescription: json['short_description']?.toString(),
      rating: json['rating']?.toString(),
      reviewsCount: Json.asInt(json['reviews_count']) ?? 0,
      featured: Json.asBool(json['featured']),
      discountPrice: rawPrice,
      level: json['level']?.toString(),
      hasDiscount: Json.asBool(json['has_discount']),
      totalDurationSeconds: Json.asInt(json['total_duration_seconds']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image': image,
      'title': title,

      'instructor_first_name': instructorFirstName,

      'instructor_last_name': instructorLastName,

      'instructor_image': instructorImage,

      'price': price,
      'currency': currency,
      'lessons': lessons,
      'duration': duration,

      'students_count': studentsCount,

      'category_ids': categoryIds,

      'type': type.name,

      'access': access.name,

      if (slug != null) 'slug': slug,
      if (shortDescription != null) 'short_description': shortDescription,
      if (rating != null) 'rating': rating,
      'reviews_count': reviewsCount,
      'featured': featured,
      if (discountPrice != null) 'discount_price': discountPrice,
      if (level != null) 'level': level,
      'has_discount': hasDiscount,
      'total_duration_seconds': totalDurationSeconds,
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

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  /// The UI renders `duration` as «X ساعت».
  ///
  /// `total_duration_seconds` is authoritative; `duration` (minutes) is the
  /// fallback and the mock value (already in hours) is the last resort.
  static String _durationLabel(Map<String, dynamic> json, int lessonsCount) {
    final seconds = Json.asInt(json['total_duration_seconds']) ?? 0;
    if (seconds > 0) {
      final hours = (seconds / 3600).ceil();
      return (hours < 1 ? 1 : hours).toString();
    }

    final minutes = Json.asInt(json['duration']) ?? 0;
    if (minutes > 0) {
      final hours = (minutes / 60).ceil();
      return (hours < 1 ? 1 : hours).toString();
    }

    // Mock payloads already carry the hour count as a string.
    final raw = json['duration']?.toString();
    if (raw != null && raw.isNotEmpty) return raw;

    return lessonsCount > 0 ? '1' : '0';
  }

  /// تبدیل category_ids دریافتی از JSON به List<int>
  static List<int> _categoryIdsFromJson(dynamic value) {
    if (value is List) {
      return value
          .map((item) => _asInt(item))
          .whereType<int>()
          .where((id) => id > 0)
          .toList();
    }

    // اگر API به‌جای آرایه فقط یک category_id فرستاد
    final singleCategory = _asInt(value);

    if (singleCategory != null && singleCategory > 0) {
      return [singleCategory];
    }

    return const [];
  }

  /// The backend has no `type` field, so it is derived from the data:
  /// free → رایگان، a single lesson → تک‌آموزشی، otherwise → حرفه‌ای.
  static CourseType _courseTypeFromApi(
    Map<String, dynamic> json, {
    required bool isFree,
    required int lessonsCount,
  }) {
    final explicit = json['type']?.toString();
    if (explicit != null && explicit.isNotEmpty) {
      return _courseTypeFromJson(explicit);
    }

    if (isFree) return CourseType.free;
    if (lessonsCount <= 1) return CourseType.single;
    return CourseType.professional;
  }

  static CourseType _courseTypeFromJson(String? value) {
    switch (value) {
      case 'professional':
        return CourseType.professional;

      case 'single':
        return CourseType.single;

      case 'free':
      default:
        return CourseType.free;
    }
  }

  static CourseAccess _accessFromJson(String? value) {
    switch (value) {
      case 'paid':
        return CourseAccess.paid;

      case 'free':
      default:
        return CourseAccess.free;
    }
  }
}

enum CourseType {
  free,
  professional,
  single,
}

enum CourseAccess {
  free,
  paid,
}
