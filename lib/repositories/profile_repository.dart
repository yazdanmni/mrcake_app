import 'dart:io';

import '../core/network/api_client.dart';
import '../core/network/api_config.dart';
import '../core/network/api_exception.dart';
import '../models/banner_model.dart';
import '../models/user_model.dart';

/// `POST /api/v1/media/`
///
/// Uploads a file and returns its [MediaModel] (with the absolute `url` used by
/// avatar / portfolio / thumbnail fields).
class MediaRepository {
  MediaRepository._();

  static final MediaRepository instance = MediaRepository._();

  Future<MediaModel> upload(
    File file, {
    String field = 'file',
    Map<String, dynamic>? extra,
    void Function(int sent, int total)? onProgress,
  }) async {
    final data = await ApiClient.instance.upload<dynamic>(
      ApiEndpoints.media,
      filePath: file.path,
      field: field,
      extra: extra,
      onProgress: onProgress,
    );

    final map = Json.asMap(data);
    if (map != null) {
      // The media object may be nested under a key such as `media` or `file`.
      for (final key in const ['media', 'file', 'data']) {
        final nested = Json.asMap(map[key]);
        if (nested != null && nested.containsKey('url')) {
          return MediaModel.fromJson(nested);
        }
      }
      return MediaModel.fromJson(map);
    }

    throw ApiException(
      message: 'پاسخ سرور برای آپلود فایل نامعتبر بود.',
      type: ApiErrorType.unknown,
    );
  }

  /// Uploads and returns only the absolute url.
  Future<String> uploadUrl(File file, {String field = 'file'}) async {
    final media = await upload(file, field: field);
    final url = media.absoluteUrl;
    if (url == null || url.isEmpty) {
      throw ApiException(
        message: 'آدرس فایل آپلود شده دریافت نشد.',
        type: ApiErrorType.unknown,
      );
    }
    return url;
  }

  /// `GET /api/v1/media/{id}/`
  ///
  /// Needed because `ExploreVideo.video_media` and
  /// `TeacherPortfolioItem.media` are **ids**, not urls.
  Future<MediaModel> fetch(int id) async {
    final data = await ApiClient.instance.get<dynamic>(
      '${ApiEndpoints.media}$id/',
    );

    final map = Json.asMap(data);
    if (map == null) {
      throw ApiException(
        message: 'اطلاعات فایل دریافت نشد.',
        type: ApiErrorType.unknown,
      );
    }

    final nested = Json.asMap(map['media']);
    return MediaModel.fromJson(nested ?? map);
  }

  /// Resolves a media id to an absolute url, or `null` when it cannot be read.
  ///
  /// Never throws: a missing thumbnail must not break a whole screen.
  Future<String?> resolveUrl(int? id) async {
    if (id == null || id <= 0) return null;
    try {
      final media = await fetch(id);
      final url = media.absoluteUrl;
      return url == null || url.isEmpty ? null : url;
    } on ApiException {
      return null;
    }
  }

  /// Resolves several media ids at once, keeping the original order.
  Future<List<String?>> resolveUrls(List<int?> ids) async {
    if (ids.isEmpty) return const [];
    return Future.wait(ids.map(resolveUrl));
  }
}

/// Screen -> Endpoint -> Model -> Repository
///
///  CompleteProfileScreen  POST  v1/accounts/profile/complete/ -> UserModel
///  CompleteProfileScreen  POST  v1/media/                     -> MediaModel
///  ProfileScreen          GET   v1/accounts/profile/          -> UserModel
///  ProfileScreen          PATCH v1/accounts/profile/          -> UserModel
///  ProfileScreen          GET   v1/accounts/users/me/         -> UserModel
class ProfileRepository {
  ProfileRepository._();

  static final ProfileRepository instance = ProfileRepository._();

  ApiClient get _api => ApiClient.instance;

  /// `GET /api/v1/accounts/profile/`
  Future<UserModel> fetchProfile() async {
    final data = await _api.get<dynamic>(ApiEndpoints.profile);
    return _toUser(data, endpoint: ApiEndpoints.profile);
  }

  /// `GET /api/v1/accounts/users/me/`
  Future<UserModel> fetchMe() async {
    final data = await _api.get<dynamic>(ApiEndpoints.usersMe);
    return _toUser(data, endpoint: ApiEndpoints.usersMe);
  }

  /// `PATCH /api/v1/accounts/profile/`
  ///
  /// Only the provided fields are sent, matching the `PatchedUser` schema.
  Future<UserModel> updateProfile({
    String? username,
    String? firstName,
    String? lastName,
    String? email,
    String? avatarUrl,
    UserGender? gender,
    DateTime? birthDate,
    String? bio,
  }) async {
    final body = <String, dynamic>{};
    if (username != null) body['username'] = username;
    if (firstName != null) body['first_name'] = firstName;
    if (lastName != null) body['last_name'] = lastName;
    if (email != null) body['email'] = email;
    if (avatarUrl != null) body['avatar'] = avatarUrl;
    if (gender != null) body['gender'] = gender.value;
    if (birthDate != null) {
      body['birth_date'] = birthDate.toIso8601String().split('T').first;
    }
    if (bio != null) body['bio'] = bio;

    if (body.isEmpty) {
      return fetchProfile();
    }

    final data = await _api.patch<dynamic>(ApiEndpoints.profile, body: body);
    return _toUser(data, endpoint: ApiEndpoints.profile);
  }

  /// `POST /api/v1/accounts/profile/complete/`
  ///
  /// [avatar] is optional: when the user picked a picture it is uploaded to
  /// `/media/` first and the resulting url is attached to the profile
  /// afterwards. A failing avatar upload never blocks the registration.
  Future<UserModel> completeProfile({
    required String username,
    required String firstName,
    required String lastName,
    String? email,
    File? avatar,
  }) async {
    String? avatarUrl;
    if (avatar != null) {
      try {
        avatarUrl = await MediaRepository.instance.uploadUrl(avatar);
      } on ApiException {
        // Ignore: the account is more important than the picture.
        avatarUrl = null;
      }
    }

    final body = <String, dynamic>{
      'username': username.trim(),
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
    };
    final cleanEmail = email?.trim();
    if (cleanEmail != null && cleanEmail.isNotEmpty) {
      body['email'] = cleanEmail;
    }

    final data = await _api.post<dynamic>(
      ApiEndpoints.profileComplete,
      body: body,
    );

    UserModel? user;
    try {
      user = _toUser(data, endpoint: ApiEndpoints.profileComplete);
    } on ApiException {
      user = null;
    }

    if (avatarUrl != null) {
      try {
        user = await updateProfile(avatarUrl: avatarUrl);
      } on ApiException {
        // Keep the user we already have.
      }
    }

    return user ?? await fetchProfile();
  }

  UserModel _toUser(dynamic data, {required String endpoint}) {
    final map = Json.asMap(data);
    if (map == null) {
      throw ApiException(
        message: 'پاسخ سرور نامعتبر بود.',
        type: ApiErrorType.unknown,
      );
    }
    for (final key in const ['user', 'profile', 'account']) {
      final nested = Json.asMap(map[key]);
      if (nested != null) return UserModel.fromJson(nested);
    }
    return UserModel.fromJson(map);
  }
}
