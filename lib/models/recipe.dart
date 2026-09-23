import '../core/network/api_client.dart';
import '../core/network/api_config.dart';

/// `RecipeList` -> `GET /api/v1/courses/recipes/`
/// `RecipeDetail` -> `GET /api/v1/courses/recipes/{id}/`
///
/// The constructor keeps the original mock-data signature so
/// `lib/data/recipes_data.dart` and the existing widgets keep compiling;
/// [fromJson] understands **both** the mock keys and the real backend keys.
class Recipe {
  final int id;

  /// The mock data shipped a `teacherId`; the API exposes the author through
  /// `created_by`, whose id is mapped onto this field.
  final int teacherId;

  final String title;
  final String image;
  final String description;

  final List<RecipeIngredient> ingredients;

  /// Step bodies. The API calls them `step_items[].body`.
  final List<String> steps;

  /// `easy | medium | hard` (mock) or `beginner | intermediate | advanced |
  /// all` (backend `DifficultyEnum`).
  final String difficulty;

  // ---------------------------------------------------------------------------
  // Extra fields provided by the backend (optional).
  // ---------------------------------------------------------------------------

  final String? slug;
  final String? shortDescription;

  final int? categoryId;
  final String? categoryTitle;

  final int? courseId;
  final String? courseTitle;

  /// دقیقه
  final int preparationTime;

  /// دقیقه
  final int cookingTime;

  /// تعداد نفرات
  final int servings;

  final bool featured;
  final int viewsCount;
  final bool isActive;

  final String? createdAt;

  /// نویسنده دستور پخت (`created_by`)
  final String authorName;
  final String authorAvatar;

  /// متن خام مواد اولیه (`ingredients`) که بک‌اند به صورت رشته می‌فرستد.
  final String? ingredientsText;

  /// توضیحات کامل / مراحل متنی (`content`)
  final String? content;

  const Recipe({
    required this.id,
    required this.teacherId,
    required this.title,
    required this.image,
    required this.description,
    required this.ingredients,
    required this.steps,
    required this.difficulty,
    this.slug,
    this.shortDescription,
    this.categoryId,
    this.categoryTitle,
    this.courseId,
    this.courseTitle,
    this.preparationTime = 0,
    this.cookingTime = 0,
    this.servings = 0,
    this.featured = false,
    this.viewsCount = 0,
    this.isActive = true,
    this.createdAt,
    this.authorName = '',
    this.authorAvatar = '',
    this.ingredientsText,
    this.content,
  });

  /// مجموع زمان آماده‌سازی و پخت (دقیقه)
  int get totalTime => preparationTime + cookingTime;

  bool get hasTimes => totalTime > 0;

  int get readingTime {
    final String content = [
      title,
      description,
      ...ingredients.map(
        (item) => '${item.name} ${item.amount}',
      ),
      ...steps,
    ].join(' ');

    final int wordCount = content
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;

    final int minutes = (wordCount / 180).ceil();

    return minutes < 1 ? 1 : minutes;
  }

  String get difficultyTitle {
    switch (difficulty) {
      case 'easy':
      case 'beginner':
        return 'آسان';

      case 'hard':
      case 'advanced':
        return 'سخت';

      case 'all':
        return 'همه سطوح';

      case 'medium':
      case 'intermediate':
      default:
        return 'متوسط';
    }
  }

  // ---------------------------------------------------------------------------
  // JSON
  // ---------------------------------------------------------------------------

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final category = Json.asMap(json['category']);
    final author = Json.asMap(json['created_by']);

    final ingredientItems = Json.asMapList(json['ingredient_items']);
    final stepItems = Json.asMapList(json['step_items']);

    return Recipe(
      id: Json.asInt(json['id']) ?? 0,

      teacherId:
          Json.asInt(json['teacher_id']) ??
              Json.asInt(author?['id']) ??
              0,

      title: Json.asString(json['title']) ?? '',

      image: _mediaUrl(json['image']),

      description:
          Json.asString(json['description']) ??
              Json.asString(json['short_description']) ??
              '',

      ingredients: ingredientItems.isEmpty
          ? _mockIngredients(json['ingredients'])
          : ingredientItems.map(RecipeIngredient.fromJson).toList(),

      steps: stepItems.isEmpty
          ? _mockSteps(json['steps'])
          : stepItems
                .map(
                  (item) =>
                      Json.asString(item['body']) ??
                      Json.asString(item['title']) ??
                      '',
                )
                .where((step) => step.isNotEmpty)
                .toList(growable: false),

      difficulty: Json.asString(json['difficulty']) ?? 'medium',

      slug: Json.asString(json['slug']),
      shortDescription: Json.asString(json['short_description']),

      categoryId: Json.asInt(category?['id']),
      categoryTitle: Json.asString(category?['name']),

      courseId: Json.asInt(json['course']),
      courseTitle: Json.asString(json['course_title']),

      preparationTime: Json.asInt(json['preparation_time']) ?? 0,
      cookingTime: Json.asInt(json['cooking_time']) ?? 0,
      servings: Json.asInt(json['servings']) ?? 0,

      featured: Json.asBool(json['featured']),
      viewsCount: Json.asInt(json['views_count']) ?? 0,
      isActive: Json.asBool(json['is_active'], fallback: true),
      createdAt: Json.asString(json['created_at']),

      authorName:
          Json.asString(author?['full_name']) ??
              _join(
                Json.asString(author?['first_name']),
                Json.asString(author?['last_name']),
              ),

      authorAvatar: _mediaUrl(author?['avatar']),

      ingredientsText: Json.asString(json['ingredients']),
      content: Json.asString(json['content']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'teacher_id': teacherId,
      'title': title,
      'image': image,
      'description': description,
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      'steps': steps,
      'difficulty': difficulty,
      if (slug != null) 'slug': slug,
      if (shortDescription != null) 'short_description': shortDescription,
      if (categoryId != null) 'category': categoryId,
      if (courseId != null) 'course': courseId,
      'preparation_time': preparationTime,
      'cooking_time': cookingTime,
      'servings': servings,
      'featured': featured,
      'views_count': viewsCount,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      'author_name': authorName,
      'author_avatar': authorAvatar,
      if (ingredientsText != null) 'ingredients_text': ingredientsText,
      if (content != null) 'content': content,
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

  static String _join(String? first, String? last) {
    final parts = [first, last].whereType<String>().where((p) => p.isNotEmpty);
    return parts.join(' ');
  }

  /// Mock payloads carry `[{name, amount}]`; the backend carries a plain
  /// string. Both are accepted so the detail screen never renders blank.
  static List<RecipeIngredient> _mockIngredients(dynamic value) {
    if (value is List) {
      return value
          .map((item) => Json.asMap(item))
          .whereType<Map<String, dynamic>>()
          .map(RecipeIngredient.fromJson)
          .toList(growable: false);
    }

    final text = value?.toString();
    if (text == null || text.trim().isEmpty) {
      return const <RecipeIngredient>[];
    }

    // «آرد: ۲ پیمانه» / «آرد - ۲ پیمانه» / «آرد، ۲ پیمانه»
    return text
        .split(RegExp(r'[\n,،]'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) {
          final match = RegExp(r'^(.+?)\s*[:\-–]\s*(.+)$').firstMatch(line);
          if (match == null) {
            return RecipeIngredient(name: line, amount: '');
          }
          return RecipeIngredient(
            name: match.group(1)!.trim(),
            amount: match.group(2)!.trim(),
          );
        })
        .toList(growable: false);
  }

  static List<String> _mockSteps(dynamic value) {
    if (value is! List) return const <String>[];
    return value
        .map((item) => item?.toString() ?? '')
        .where((step) => step.isNotEmpty)
        .toList(growable: false);
  }
}

class RecipeIngredient {
  final String name;
  final String amount;

  final int? id;
  final int position;

  const RecipeIngredient({
    required this.name,
    required this.amount,
    this.id,
    this.position = 0,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      name: Json.asString(json['name']) ?? '',
      amount: Json.asString(json['amount']) ?? '',
      id: Json.asInt(json['id']),
      position: Json.asInt(json['position']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'name': name,
    'amount': amount,
    'position': position,
  };
}
