import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/auth_session.dart';
import '../../models/user_model.dart';
import '../network/api_client.dart';
import '../network/remote_data.dart';

/// Holds the JWT + the cached profile of the signed in user.
///
/// This is a plain [ChangeNotifier] (core Flutter, no state management
/// package) so any widget can listen with `AnimatedBuilder` / `ListenableBuilder`
/// when it needs to react to a login or a logout.
class SessionManager extends ChangeNotifier {
  SessionManager._();

  static final SessionManager instance = SessionManager._();

  static const String _kAccessToken = 'mr_cake.auth.access_token';
  static const String _kRefreshToken = 'mr_cake.auth.refresh_token';
  static const String _kUser = 'mr_cake.auth.user';
  static const String _kLastPhone = 'mr_cake.auth.last_phone';

  SharedPreferences? _prefs;

  String? _accessToken;
  String? _refreshToken;
  UserModel? _user;
  String? _lastPhone;
  bool _initialized = false;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  UserModel? get user => _user;

  /// Phone number used during the last successful sign-in. The login screen
  /// prefills it so the user does not retype it every time.
  String? get lastPhone => _lastPhone;

  bool get isInitialized => _initialized;
  bool get isLoggedIn => _accessToken != null && _accessToken!.isNotEmpty;
  bool get isGuest => !isLoggedIn;

  /// Reads the persisted session. Must be awaited once, from the splash screen,
  /// before any request is made.
  Future<void> init() async {
    if (_initialized) return;

    ApiClient.instance.accessTokenProvider = () => _accessToken;
    ApiClient.instance.onUnauthorized = () async {
      // The backend refused the token: drop it so the next screen shows the
      // login form again. No navigation happens here on purpose.
      if (isLoggedIn) await clear(keepPhone: true);
    };

    try {
      final prefs = _prefs ??= await SharedPreferences.getInstance();
      _accessToken = prefs.getString(_kAccessToken);
      _refreshToken = prefs.getString(_kRefreshToken);
      _lastPhone = prefs.getString(_kLastPhone);

      final rawUser = prefs.getString(_kUser);
      if (rawUser != null && rawUser.isNotEmpty) {
        final decoded = jsonDecode(rawUser);
        final map = Json.asMap(decoded);
        if (map != null) _user = UserModel.fromJson(map);
      }
    } catch (error) {
      debugPrint('[Session] init failed: $error');
    }

    _initialized = true;
    notifyListeners();
  }

  /// Persists the result of a successful auth call.
  Future<void> save(AuthSession session, {String? phone}) async {
    if (session.accessToken != null && session.accessToken!.isNotEmpty) {
      _accessToken = session.accessToken;
    }
    if (session.refreshToken != null && session.refreshToken!.isNotEmpty) {
      _refreshToken = session.refreshToken;
    }
    if (session.user != null) {
      _user = session.user;
    }
    if (phone != null && phone.isNotEmpty) {
      _lastPhone = phone;
    }

    // A different account must never inherit the previous one's cached
    // catalogue (course detail carries `is_enrolled` / `is_favorite`).
    RemoteCache.clear();

    notifyListeners();
    await _persist();
  }

  /// Updates the cached profile without touching the tokens.
  Future<void> updateUser(UserModel user) async {
    _user = user;
    notifyListeners();
    await _persist();
  }

  /// Clears the session (logout).
  Future<void> clear({bool keepPhone = true}) async {
    _accessToken = null;
    _refreshToken = null;
    _user = null;
    if (!keepPhone) _lastPhone = null;

    // Drop every cached response: it was fetched with the token that just went
    // away, and part of it is account-specific.
    RemoteCache.clear();

    notifyListeners();

    try {
      final prefs = _prefs ??= await SharedPreferences.getInstance();
      await prefs.remove(_kAccessToken);
      await prefs.remove(_kRefreshToken);
      await prefs.remove(_kUser);
      if (!keepPhone) await prefs.remove(_kLastPhone);
    } catch (error) {
      debugPrint('[Session] clear failed: $error');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = _prefs ??= await SharedPreferences.getInstance();

      if (_accessToken == null) {
        await prefs.remove(_kAccessToken);
      } else {
        await prefs.setString(_kAccessToken, _accessToken!);
      }

      if (_refreshToken == null) {
        await prefs.remove(_kRefreshToken);
      } else {
        await prefs.setString(_kRefreshToken, _refreshToken!);
      }

      if (_user == null) {
        await prefs.remove(_kUser);
      } else {
        await prefs.setString(_kUser, jsonEncode(_user!.toJson()));
      }

      if (_lastPhone == null) {
        await prefs.remove(_kLastPhone);
      } else {
        await prefs.setString(_kLastPhone, _lastPhone!);
      }
    } catch (error) {
      debugPrint('[Session] persist failed: $error');
    }
  }
}
