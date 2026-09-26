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
  ///
  /// ## ⚠️ File uploads are currently refused by the server
  ///
  /// `POST v1/media/` **drops the connection** for any multipart request that
  /// actually carries a file part, so no upload from this app can succeed right
  /// now. Probed directly against the live host:
  ///
  /// | request                                        | result                    |
  /// |------------------------------------------------|---------------------------|
  /// | `POST` + `name=hello` (a plain text field)      | `401` — reached the app   |
  /// | `POST` + `file=aaaa` (text in the file field)   | `401` — reached the app   |
  /// | `POST` + a real file part (`filename=`, any size) | **HTTP 000, curl 26**   |
  ///
  /// So it is not the field name, the content type, the file size or the auth
  /// header: it is the presence of an uploaded file body. Django never sees the
  /// request, which means the rejection happens in front of it — a proxy/body
  /// limit or the CDN in front of the API. Nothing the client sends can change
  /// that, which is why the failure below is reported as a *server* problem
  /// instead of a generic "try again" the user would retry forever.
  Future<String> uploadUrl(File file, {String field = 'file'}) async {
    final MediaModel media;
    try {
      media = await upload(file, field: field);
    } on ApiException catch (error) {
      throw ApiException(
        message: _uploadMessage(error),
        statusCode: error.statusCode,
        errors: error.errors,
        type: error.type,
      );
    }

    final url = media.absoluteUrl;
    if (url == null || url.isEmpty) {
      throw ApiException(
        message: 'آدرس فایل آپلود شده دریافت نشد.',
        type: ApiErrorType.unknown,
      );
    }
    return url;
  }

  /// Turns a transport-level upload failure into something the user can act on.
  ///
  /// A dropped connection is the symptom the server produces for every file
  /// upload, so it gets its own sentence — "check your internet" would send the
  /// user chasing a problem they do not have.
  static String _uploadMessage(ApiException error) {
    switch (error.type) {
      case ApiErrorType.network:
        return 'ارسال تصویر از سوی سرور پذیرفته نشد. لطفاً بعداً دوباره تلاش کنید '
            'یا موضوع را به پشتیبانی اطلاع دهید.';
      case ApiErrorType.timeout:
        return 'ارسال تصویر طول کشید و نیمه‌کاره ماند. اینترنت را بررسی کنید و '
            'دوباره تلاش کنید.';
      default:
        return error.message;
    }
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
  ///
  /// ⚠️ **`null` here means "we do not know", not "there is no file".** The two
  /// reasons it returns `null` are indistinguishable to a caller and they need
  /// very different UI:
  ///
  /// * the row has no such media (`id` null / non-positive, or the backend
  ///   answered 404) — the item genuinely has nothing to play;
  /// * **the request was rejected with 401.** `GET v1/media/{id}/` is
  ///   `security: [{jwtAuth: []}]` — *auth-only*, unlike the public endpoints
  ///   whose rows carry these ids (`content/explore-videos/` is
  ///   `[{jwtAuth}, {}]`). A guest therefore gets a 401 for every media id and
  ///   can never resolve a url, even though the file itself is on a public CDN.
  ///
  /// That is exactly why «اکسپلور» used to claim «آدرس ویدیو خالی است» for a
  /// video whose file was right there. Use [resolveUrlDetailed] where the
  /// difference matters.
  Future<String?> resolveUrl(int? id) async {
    final resolved = await resolveUrlDetailed(id);
    return resolved.url;
  }

  /// [resolveUrl] plus **why** it failed, so a caller can tell "this item has no
  /// video" apart from "we were not allowed to look".
  Future<MediaResolution> resolveUrlDetailed(int? id) async {
    if (id == null || id <= 0) return const MediaResolution.missing();

    try {
      final media = await fetch(id);
      final url = media.absoluteUrl;

      if (url == null || url.isEmpty) return const MediaResolution.missing();

      return MediaResolution.resolved(url);
    } on ApiException catch (error) {
      // A rejected-but-present token means the session is dead; a guest simply
      // has no token. Either way the id exists and is unreadable *for now*, so
      // the caller must not report "there is no video".
      final bool unauthorized = error.type == ApiErrorType.unauthorized;

      return MediaResolution(
        url: null,
        reason: unauthorized
            ? MediaResolutionReason.unauthorized
            : MediaResolutionReason.missing,
      );
    }
  }

  /// Resolves several media ids at once, keeping the original order.
  Future<List<String?>> resolveUrls(List<int?> ids) {
    if (ids.isEmpty) return Future.value(const <String?>[]);
    return Future.wait(ids.map(resolveUrl));
  }
}

/// Why a media id could not be turned into a url.
enum MediaResolutionReason {
  /// The item has no such media, or the backend answered 404 for the id.
  /// Reporting "there is no video" is correct.
  missing,

  /// `GET v1/media/{id}/` answered **401**. The media exists; this caller is
  /// simply not allowed to look it up. Reporting "there is no video" is wrong —
  /// see [MediaRepository.resolveUrl].
  unauthorized,
}

/// The outcome of resolving one media id.
///
/// Carries the reason rather than a bare `String?`, because every caller that
/// tried to play or show something needs to say *which* of the two failures it
/// hit: "این آیتم ویدیو ندارد" and "برای دیدن این ویدیو وارد شوید" are not the
/// same message and must not collapse into one.
class MediaResolution {
  /// The absolute url, or `null` when it could not be resolved.
  final String? url;

  final MediaResolutionReason reason;

  const MediaResolution({required this.url, required this.reason});

  const MediaResolution.resolved(String this.url)
      : reason = MediaResolutionReason.missing;

  const MediaResolution.missing()
      : url = null,
        reason = MediaResolutionReason.missing;

  const MediaResolution.unauthorized()
      : url = null,
        reason = MediaResolutionReason.unauthorized;

  bool get isResolved => url != null && url!.isNotEmpty;

  bool get isUnauthorized => reason == MediaResolutionReason.unauthorized;
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
  ///
  /// Note: `bannerImageUrl` is kept as a parameter for call-site compatibility.
  /// The backend schema (`PatchedCompleteProfile`) does not currently expose
  /// a writable banner field, so the value is **never forwarded to the API**
  /// and must be persisted client-side (SessionManager cache).
  Future<UserModel> updateProfile({
    String? username,
    String? firstName,
    String? lastName,
    String? email,
    String? avatarUrl,
    String? bannerImageUrl,
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
    // banner_image intentionally not added to body – not in the DRF schema.
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
