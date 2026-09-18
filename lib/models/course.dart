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
  /// 1 → کیک
  /// 2 → شیرینی
  /// 3 → دسر
  /// 4 → نان
  /// 5 → خامه
  /// 6 → کروسان
  /// 7 → کاکائو
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
  });

  String get instructorFullName {
    return '$instructorFirstName $instructorLastName';
  }

  factory Course.fromJson(
    Map<String, dynamic> json,
  ) {
    return Course(
      id: int.tryParse(
            json['id']?.toString() ?? '0',
          ) ??
          0,

      image: json['image']?.toString() ?? '',

      title: json['title']?.toString() ?? '',

      instructorFirstName:
          json['instructor_first_name']?.toString() ?? '',

      instructorLastName:
          json['instructor_last_name']?.toString() ?? '',

      instructorImage:
          json['instructor_image']?.toString() ?? '',

      price:
          json['price']?.toString() ?? '0',

      currency:
          json['currency']?.toString() ?? 'تومان',

      lessons:
          json['lessons']?.toString() ?? '0',

      duration:
          json['duration']?.toString() ?? '0',

      studentsCount:
          int.tryParse(
                json['students_count']?.toString() ?? '0',
              ) ??
              0,

      categoryIds:
          _categoryIdsFromJson(
            json['category_ids'],
          ),

      type: _courseTypeFromJson(
        json['type']?.toString(),
      ),

      access: _courseAccessFromJson(
        json['access']?.toString(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image': image,
      'title': title,

      'instructor_first_name':
          instructorFirstName,

      'instructor_last_name':
          instructorLastName,

      'instructor_image':
          instructorImage,

      'price': price,
      'currency': currency,
      'lessons': lessons,
      'duration': duration,

      'students_count':
          studentsCount,

      'category_ids':
          categoryIds,

      'type':
          type.name,

      'access':
          access.name,
    };
  }

  /// تبدیل category_ids دریافتی از JSON
  /// به List<int>
  static List<int> _categoryIdsFromJson(
    dynamic value,
  ) {
    if (value is List) {
      return value
          .map(
            (item) => int.tryParse(
              item.toString(),
            ),
          )
          .whereType<int>()
          .where(
            (id) => id > 0,
          )
          .toList();
    }

    // اگر API به‌جای آرایه فقط یک category_id فرستاد
    final int? singleCategory =
        int.tryParse(
          value?.toString() ?? '',
        );

    if (singleCategory != null &&
        singleCategory > 0) {
      return [singleCategory];
    }

    return const [];
  }

  static CourseType _courseTypeFromJson(
    String? value,
  ) {
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

  static CourseAccess _courseAccessFromJson(
    String? value,
  ) {
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