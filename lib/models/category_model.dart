import '../core/network/api_client.dart';
import '../core/network/api_config.dart';

/// Category tile shown in the home grid and in the courses filter row.
///
/// `CategoryPublic` -> `GET /api/v1/courses/categories/`,
/// `GET /api/v1/courses/categories/featured/`,
/// `GET /api/v1/courses/categories/tree/`
///
/// Real payload:
/// ```json
/// {"id":2,"name":"کیک های خامه ای","slug":"کیک-های-خامه-ای",
///  "icon":"https://media.dl.mceiran.website/categories/icons/..jpeg",
///  "banner":null,"parent":1,"order":1,"featured":true}
/// ```
class CategoryModel {
  final int id;
  final String title;
  final String? image;

  final String? slug;

  /// Optional wide artwork used by the category page header.
  final String? banner;

  /// `null` for a root category.
  final int? parentId;

  final int order;
  final bool featured;

  /// Filled in by the tree endpoint only.
  final List<CategoryModel> children;

  const CategoryModel({
    required this.id,
    required this.title,
    this.image,
    this.slug,
    this.banner,
    this.parentId,
    this.order = 0,
    this.featured = false,
    this.children = const <CategoryModel>[],
  });

  bool get isRoot => parentId == null;
  bool get hasChildren => children.isNotEmpty;

  String? get bannerUrl {
    final value = banner;
    if (value == null || value.isEmpty) return null;
    return ApiConfig.mediaUrl(value);
  }

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: Json.asInt(json['id']) ?? 0,

      // The API calls it `name`; the widgets were built around `title`.
      title:
          Json.asString(json['name']) ??
              Json.asString(json['title']) ??
              '',

      image: _image(json),

      slug: Json.asString(json['slug']),

      banner: Json.asString(json['banner']),

      // `parent` is a plain id in the list payload and a nested object in the
      // tree payload, so both shapes are accepted.
      parentId:
          Json.asInt(json['parent']) ??
              Json.asInt(Json.asMap(json['parent'])?['id']),

      order: Json.asInt(json['order']) ?? 0,

      featured: Json.asBool(json['featured']),

      children: _children(json['children']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': title,
      if (image != null) 'icon': image,
      if (slug != null) 'slug': slug,
      if (banner != null) 'banner': banner,
      'parent': parentId,
      'order': order,
      'featured': featured,
      if (children.isNotEmpty)
        'children': children.map((e) => e.toJson()).toList(),
    };
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String? _image(Map<String, dynamic> json) {
    final raw =
        Json.asString(json['icon']) ??
            Json.asString(json['image']) ??
            Json.asString(json['banner']);

    if (raw == null || raw.isEmpty) return null;
    return ApiConfig.mediaUrl(raw);
  }

  static List<CategoryModel> _children(dynamic value) {
    if (value is! List) return const <CategoryModel>[];
    return value
        .map((item) => Json.asMap(item))
        .whereType<Map<String, dynamic>>()
        .map(CategoryModel.fromJson)
        .toList(growable: false);
  }
}
