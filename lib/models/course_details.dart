class CourseDetails {
  final int courseId;
  final String description;
  final String introVideo;
  final String introImage;
  final List<CourseChapter> chapters;
  final List<CourseIngredient> ingredients;

  const CourseDetails({
    required this.courseId,
    required this.description,
    required this.introVideo,
    required this.introImage,
    required this.chapters,
    required this.ingredients,
  });

  factory CourseDetails.fromJson(Map<String, dynamic> json) {
    return CourseDetails(
      courseId: int.tryParse(
            json['course_id']?.toString() ?? '0',
          ) ??
          0,
      description: json['description']?.toString() ?? '',
      introVideo: json['intro_video']?.toString() ?? '',
      introImage: json['intro_image']?.toString() ?? '',
      chapters: (json['chapters'] as List? ?? [])
          .map(
            (item) => CourseChapter.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      ingredients: (json['ingredients'] as List? ?? [])
          .map(
            (item) => CourseIngredient.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
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
    };
  }
}

// ============================================================================
// CHAPTER
// ============================================================================

class CourseChapter {
  final int id;
  final int number;
  final String title;
  final List<CourseLesson> lessons;

  const CourseChapter({
    required this.id,
    required this.number,
    required this.title,
    required this.lessons,
  });

  factory CourseChapter.fromJson(Map<String, dynamic> json) {
    return CourseChapter(
      id: int.tryParse(
            json['id']?.toString() ?? '0',
          ) ??
          0,
      number: int.tryParse(
            json['number']?.toString() ?? '0',
          ) ??
          0,
      title: json['title']?.toString() ?? '',
      lessons: (json['lessons'] as List? ?? [])
          .map(
            (item) => CourseLesson.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'title': title,
      'lessons': lessons.map((e) => e.toJson()).toList(),
    };
  }
}

// ============================================================================
// LESSON
// ============================================================================

class CourseLesson {
  final int id;
  final String title;
  final String video;
  final String duration;

  /// توضیحات مخصوص همین قسمت
  final String description;

  /// مواد اولیه مخصوص همین قسمت
  final List<CourseIngredient> ingredients;

  const CourseLesson({
    required this.id,
    required this.title,
    required this.video,
    required this.duration,
    required this.description,
    required this.ingredients,
  });

  factory CourseLesson.fromJson(Map<String, dynamic> json) {
    return CourseLesson(
      id: int.tryParse(
            json['id']?.toString() ?? '0',
          ) ??
          0,

      title: json['title']?.toString() ?? '',

      video: json['video']?.toString() ?? '',

      duration: json['duration']?.toString() ?? '0',

      description:
          json['description']?.toString() ?? '',

      ingredients:
          (json['ingredients'] as List? ?? [])
              .map(
                (item) => CourseIngredient.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'video': video,
      'duration': duration,
      'description': description,
      'ingredients':
          ingredients.map((e) => e.toJson()).toList(),
    };
  }
}

// ============================================================================
// INGREDIENT
// ============================================================================

class CourseIngredient {
  final int id;
  final String name;
  final String amount;

  const CourseIngredient({
    required this.id,
    required this.name,
    required this.amount,
  });

  factory CourseIngredient.fromJson(
    Map<String, dynamic> json,
  ) {
    return CourseIngredient(
      id: int.tryParse(
            json['id']?.toString() ?? '0',
          ) ??
          0,
      name: json['name']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
    };
  }
}