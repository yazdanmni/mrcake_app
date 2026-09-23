import '../core/network/api_client.dart';
import '../core/network/api_config.dart';

/// Where a banner is allowed to appear (`BannerTypeEnum`).
enum BannerType {
  homeTop('home_top'),
  homeMiddle('home_middle'),
  homeBottom('home_bottom'),
  courses('courses'),
  recipes('recipes'),
  sidebar('sidebar'),
  popup('popup'),
  other('other');

  const BannerType(this.value);

  final String value;

  static BannerType fromValue(String? value) {
    for (final type in BannerType.values) {
      if (type.value == value) return type;
    }
    return BannerType.other;
  }
}

/// What happens when the user taps a banner (`LinkTypeEnum`).
enum BannerLinkType {
  external('external'),
  course('course'),
  category('category'),
  recipe('recipe'),
  screen('screen'),
  none('none');

  const BannerLinkType(this.value);

  final String value;

  static BannerLinkType fromValue(String? value) {
    for (final type in BannerLinkType.values) {
      if (type.value == value) return type;
    }
    return BannerLinkType.none;
  }
}

/// `BannerPublic` -> `GET /api/v1/banners/`, `GET /api/v1/banners/all_active/`,
/// `GET /api/v1/banners/by_type/?type=home_top`
class BannerModel {
  const BannerModel({
    required this.id,
    required this.image,
    this.title,
    this.subtitle,
    this.description,
    this.icon,
    this.backgroundColor,
    this.linkType = BannerLinkType.none,
    this.linkValue,
  });

  final int id;
  final String image;
  final String? title;
  final String? subtitle;
  final String? description;
  final String? icon;
  final String? backgroundColor;
  final BannerLinkType linkType;
  final String? linkValue;

  String get imageUrl => ApiConfig.mediaUrl(image);
  String? get iconUrl => icon == null || icon!.isEmpty ? null : ApiConfig.mediaUrl(icon);

  factory BannerModel.fromJson(Map<String, dynamic> json) => BannerModel(
    id: Json.asInt(json['id']) ?? 0,
    image: Json.asString(json['image']) ?? '',
    title: Json.asString(json['title']),
    subtitle: Json.asString(json['subtitle']),
    description: Json.asString(json['description']),
    icon: Json.asString(json['icon']),
    backgroundColor: Json.asString(json['background_color']),
    linkType: BannerLinkType.fromValue(Json.asString(json['link_type'])),
    linkValue: Json.asString(json['link_value']),
  );
}

/// `HeroSectionPublic` -> `GET /api/v1/banners/hero/active/`
/// Used by the splash screen warm-up and the home header.
///
/// The endpoint currently answers `{id, image}` only, so [linkType] /
/// [linkValue] stay empty and the hero image is not tappable. They are parsed
/// anyway: the moment the backend adds the same link fields the banners carry,
/// the hero picks them up without a code change.
class HeroSection {
  const HeroSection({
    required this.id,
    this.image,
    this.linkType = BannerLinkType.none,
    this.linkValue,
  });

  final int id;
  final String? image;
  final BannerLinkType linkType;
  final String? linkValue;

  String? get imageUrl =>
      image == null || image!.isEmpty ? null : ApiConfig.mediaUrl(image);

  factory HeroSection.fromJson(Map<String, dynamic> json) => HeroSection(
    id: Json.asInt(json['id']) ?? 0,
    image: Json.asString(json['image']),
    linkType: BannerLinkType.fromValue(Json.asString(json['link_type'])),
    linkValue: Json.asString(json['link_value']),
  );
}

/// `Media` -> `POST /api/v1/media/`
///
/// The file itself is sent as multipart under the `file` key; the response
/// carries the absolute `url` that other endpoints (avatar, portfolio,
/// thumbnails) expect.
class MediaModel {
  const MediaModel({
    required this.id,
    this.url,
    this.path,
    this.name,
    this.originalName,
    this.mimeType,
    this.sizeBytes,
    this.mediaType,
    this.extension,
    this.durationLabel,
    this.width,
    this.height,
  });

  final int id;
  final String? url;
  final String? path;
  final String? name;
  final String? originalName;
  final String? mimeType;
  final int? sizeBytes;
  final String? mediaType;
  final String? extension;
  final String? durationLabel;
  final int? width;
  final int? height;

  /// Absolute url ready to be stored in `avatar` / `image` / `video` fields.
  String? get absoluteUrl {
    final value = url ?? path;
    if (value == null || value.isEmpty) return null;
    return ApiConfig.mediaUrl(value);
  }

  factory MediaModel.fromJson(Map<String, dynamic> json) => MediaModel(
    id: Json.asInt(json['id']) ?? 0,
    url: Json.asString(json['url']),
    path: Json.asString(json['path']),
    name: Json.asString(json['name']),
    originalName: Json.asString(json['original_name']),
    mimeType: Json.asString(json['mime_type']),
    sizeBytes: Json.asInt(json['size_bytes']),
    mediaType: Json.asString(json['media_type']),
    extension: Json.asString(json['extension']),
    durationLabel: Json.asString(json['duration_label']),
    width: Json.asInt(json['width']),
    height: Json.asInt(json['height']),
  );
}
