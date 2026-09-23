import '../core/network/api_client.dart';
import 'user_model.dart';

/// The result of a successful authentication call.
///
/// The backend is not fully consistent about where it puts the JWT and the
/// user object (`data.access`, `data.tokens.access`, `data.token`, ...), so
/// [fromResponse] walks the payload and picks the first plausible value. This
/// keeps the app working even if the backend tweaks its serializer.
class AuthSession {
  const AuthSession({
    this.accessToken,
    this.refreshToken,
    this.user,
    this.isNewAccount = false,
  });

  static const AuthSession empty = AuthSession();

  final String? accessToken;
  final String? refreshToken;
  final UserModel? user;

  /// True when the backend flagged this sign-in as a brand new account.
  final bool isNewAccount;

  bool get hasToken => accessToken != null && accessToken!.isNotEmpty;

  factory AuthSession.fromResponse(dynamic payload) {
    final data = _unwrap(payload);

    final access = _findString(data, const [
      'access',
      'access_token',
      'accessToken',
      'token',
      'key',
      'jwt',
    ]);

    final refresh = _findString(data, const [
      'refresh',
      'refresh_token',
      'refreshToken',
    ]);

    final userMap = _findUser(data);
    final user = userMap == null ? null : UserModel.fromJson(userMap);

    return AuthSession(
      accessToken: access,
      refreshToken: refresh,
      user: user,
      isNewAccount: _resolveIsNew(data),
    );
  }

  AuthSession copyWith({UserModel? user, String? accessToken, String? refreshToken}) =>
      AuthSession(
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken ?? this.refreshToken,
        user: user ?? this.user,
        isNewAccount: isNewAccount,
      );

  // ---------------------------------------------------------------------------
  // Payload walking helpers
  // ---------------------------------------------------------------------------

  static dynamic _unwrap(dynamic payload) {
    final map = Json.asMap(payload);
    if (map == null) return payload;
    if (map.containsKey('data')) return map['data'];
    return map;
  }

  static String? _findString(dynamic node, List<String> keys, [int depth = 0]) {
    if (depth > 4) return null;

    final map = Json.asMap(node);
    if (map != null) {
      for (final key in keys) {
        final value = map[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      for (final value in map.values) {
        final found = _findString(value, keys, depth + 1);
        if (found != null) return found;
      }
      return null;
    }

    if (node is List) {
      for (final value in node) {
        final found = _findString(value, keys, depth + 1);
        if (found != null) return found;
      }
    }
    return null;
  }

  static bool? _findBool(dynamic node, List<String> keys, [int depth = 0]) {
    if (depth > 3) return null;
    final map = Json.asMap(node);
    if (map == null) return null;
    for (final key in keys) {
      final value = map[key];
      if (value is bool) return value;
    }
    return null;
  }

  /// The backend may expose "this is a fresh account" either as
  /// `is_new_user: true` or as `is_registered: false`.
  static bool _resolveIsNew(dynamic data) {
    final isNew = _findBool(data, const ['is_new_user', 'is_new']);
    if (isNew != null) return isNew;

    final isRegistered = _findBool(data, const [
      'is_registered',
      'is_profile_complete',
    ]);
    if (isRegistered != null) return !isRegistered;

    return false;
  }

  static Map<String, dynamic>? _findUser(dynamic data) {
    final map = Json.asMap(data);
    if (map == null) return null;

    // 1. Explicit containers.
    for (final key in const ['user', 'profile', 'account', 'me']) {
      final nested = Json.asMap(map[key]);
      if (nested != null && _looksLikeUser(nested)) return nested;
    }

    // 2. The payload itself is the user.
    if (_looksLikeUser(map)) return map;

    // 3. Search one level deeper.
    for (final value in map.values) {
      final nested = Json.asMap(value);
      if (nested != null && _looksLikeUser(nested)) return nested;
    }
    return null;
  }

  /// A real user object always carries an `id` (it is a required field of the
  /// `User` schema). Requiring it stops payloads such as the `send-otp`
  /// response (`{phone_number, purpose}`) from being mistaken for a user.
  static bool _looksLikeUser(Map<String, dynamic> map) {
    if (!map.containsKey('id')) return false;
    return map.containsKey('phone_number') ||
        map.containsKey('role') ||
        map.containsKey('username') ||
        map.containsKey('first_name') ||
        map.containsKey('full_name');
  }
}
