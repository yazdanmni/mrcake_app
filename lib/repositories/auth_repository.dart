import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
import '../core/network/api_config.dart';
import '../core/network/api_exception.dart';
import '../core/session/session_manager.dart';
import '../models/auth_session.dart';

/// `PurposeEnum` of the `send-otp` / `verify-otp` endpoints.
enum OtpPurpose {
  /// Brand new user: the OTP creates the account.
  registration('registration'),

  /// Existing user signing in with a one time code.
  login('login'),

  /// Existing user who forgot the password.
  forgotPassword('forgot_password'),

  /// Signed in user changing the password.
  passwordChange('password_change'),

  /// Generic purpose used by the backend default.
  auth('auth'),

  /// Verification purpose.
  verify('verify');

  const OtpPurpose(this.apiValue);

  final String apiValue;

  /// Purposes the backend only accepts for accounts that already exist.
  bool get requiresExistingAccount =>
      this == OtpPurpose.forgotPassword || this == OtpPurpose.passwordChange;

  /// Purposes that create a new account when the phone is unknown.
  bool get createsAccount =>
      this == OtpPurpose.registration;

  String get screenTitle {
    switch (this) {
      case OtpPurpose.registration:
        return 'کد تایید را وارد کنید';
      case OtpPurpose.forgotPassword:
      case OtpPurpose.passwordChange:
        return 'کد بازیابی رمز عبور';
      case OtpPurpose.login:
        return 'کد ورود را وارد کنید';
      case OtpPurpose.auth:
      case OtpPurpose.verify:
        return 'کد تایید را وارد کنید';
    }
  }
}

/// The outcome of the "does this phone number have an account?" probe.
class AccountProbeResult {
  const AccountProbeResult({required this.exists, this.otpAlreadySent = false});

  final bool exists;

  /// True when the probe itself triggered an OTP (so the OTP screen can skip
  /// sending a second SMS).
  final bool otpAlreadySent;
}

/// Screen -> Endpoint -> Model -> Repository
///
///  LoginScreen            POST v1/accounts/auth/send-otp/          -> bool
///  LoginOtpScreen         POST v1/accounts/auth/verify-otp/        -> AuthSession
///  LoginPasswordScreen    POST v1/accounts/auth/login-password/    -> AuthSession
///  ChangePasswordScreen   POST v1/accounts/auth/change-password/   -> void
///                         POST v1/accounts/auth/reset-password/    -> AuthSession
///  MainBottomNavigation   POST v1/accounts/auth/logout/            -> void
class AuthRepository {
  AuthRepository._();

  static final AuthRepository instance = AuthRepository._();

  ApiClient get _api => ApiClient.instance;

  final _AccountProbeCache _probeCache = _AccountProbeCache();

  /// In-memory record of "an OTP was just sent for this phone/purpose", used to
  /// avoid paying for a second SMS when the user taps a link right after the
  /// probe.
  final Map<String, DateTime> _lastOtpSentAt = <String, DateTime>{};

  static const Duration _otpReuseWindow = Duration(minutes: 3);

  // ---------------------------------------------------------------------------
  // send-otp
  // ---------------------------------------------------------------------------

  /// Sends (or re-sends) an OTP.
  ///
  /// Returns `true` when the backend accepted the request.
  Future<bool> sendOtp({
    required String phone,
    OtpPurpose purpose = OtpPurpose.auth,
  }) async {
    await _api.post<dynamic>(
      ApiEndpoints.sendOtp,
      body: {'phone_number': phone, 'purpose': purpose.apiValue},
    );
    _lastOtpSentAt[_otpKey(phone, purpose)] = DateTime.now();
    return true;
  }

  /// True when an OTP was requested for this phone/purpose a few seconds ago
  /// and can therefore be reused instead of sending a new SMS.
  bool hasFreshOtp({required String phone, required OtpPurpose purpose}) {
    final sentAt = _lastOtpSentAt[_otpKey(phone, purpose)];
    if (sentAt == null) return false;
    return DateTime.now().difference(sentAt) < _otpReuseWindow;
  }

  void markOtpSent({required String phone, required OtpPurpose purpose}) {
    _lastOtpSentAt[_otpKey(phone, purpose)] = DateTime.now();
  }

  // ---------------------------------------------------------------------------
  // Account existence probe
  // ---------------------------------------------------------------------------

  /// Answers the core question of the login screen:
  /// * `true`  -> the number already has an account  -> password screen
  /// * `false` -> first time on the app              -> OTP screen
  ///
  /// The backend exposes this implicitly: `send-otp` with
  /// `purpose=forgot_password` answers
  /// `حساب کاربری با این شماره یافت نشد` (HTTP 400) for unknown numbers, and
  /// succeeds for known ones. We use that probe instead of `login-password`
  /// because it never guesses a password and therefore cannot lock an account.
  ///
  /// Results are cached for [_AccountProbeCache.ttl] so the SMS is only sent
  /// once per phone number per device.
  Future<AccountProbeResult> checkAccountExists(String phone) async {
    final cached = await _probeCache.read(phone);
    if (cached != null) {
      return AccountProbeResult(exists: cached);
    }

    try {
      await sendOtp(phone: phone, purpose: OtpPurpose.forgotPassword);
      await _probeCache.write(phone, true);
      return const AccountProbeResult(exists: true, otpAlreadySent: true);
    } on ApiException catch (error) {
      if (error.isUnknownPhone) {
        await _probeCache.write(phone, false);
        return const AccountProbeResult(exists: false);
      }
      rethrow;
    }
  }

  /// Drops the cached probe for a phone number (used when the user retries
  /// after an unexpected error).
  Future<void> invalidateProbe(String phone) => _probeCache.remove(phone);

  // ---------------------------------------------------------------------------
  // verify-otp
  // ---------------------------------------------------------------------------

  /// Verifies the OTP and, when the backend returns a JWT, stores the session.
  Future<AuthSession> verifyOtp({
    required String phone,
    required String otp,
    OtpPurpose purpose = OtpPurpose.auth,
  }) async {
    final data = await _api.post<dynamic>(
      ApiEndpoints.verifyOtp,
      body: {
        'phone_number': phone,
        'otp': otp,
        'purpose': purpose.apiValue,
      },
    );

    final session = AuthSession.fromResponse(data);

    if (session.hasToken) {
      await SessionManager.instance.save(session, phone: phone);
      _lastOtpSentAt.remove(_otpKey(phone, purpose));
      if (purpose == OtpPurpose.registration) {
        await _probeCache.write(phone, true);
      }
    }

    return session;
  }

  // ---------------------------------------------------------------------------
  // login-password
  // ---------------------------------------------------------------------------

  Future<AuthSession> loginWithPassword({
    required String phone,
    required String password,
  }) async {
    final data = await _api.post<dynamic>(
      ApiEndpoints.loginPassword,
      body: {'phone_number': phone, 'password': password},
    );

    final session = AuthSession.fromResponse(data);
    if (session.hasToken) {
      await SessionManager.instance.save(session, phone: phone);
      await _probeCache.write(phone, true);
    }
    return session;
  }

  // ---------------------------------------------------------------------------
  // change-password (authenticated)
  // ---------------------------------------------------------------------------

  Future<AuthSession> changePassword({
    required String newPassword,
    required String confirmPassword,
  }) async {
    final data = await _api.post<dynamic>(
      ApiEndpoints.changePassword,
      body: {
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      },
    );

    final session = AuthSession.fromResponse(data);
    if (session.user != null) {
      await SessionManager.instance.updateUser(session.user!);
    }
    return session;
  }

  // ---------------------------------------------------------------------------
  // reset-password (phone + otp, no session required)
  // ---------------------------------------------------------------------------

  Future<AuthSession> resetPassword({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    final data = await _api.post<dynamic>(
      ApiEndpoints.resetPassword,
      body: {
        'phone_number': phone,
        'otp': otp,
        'new_password': newPassword,
      },
    );

    final session = AuthSession.fromResponse(data);
    if (session.hasToken) {
      await SessionManager.instance.save(session, phone: phone);
    }
    return session;
  }

  // ---------------------------------------------------------------------------
  // logout
  // ---------------------------------------------------------------------------

  /// Best effort: the local session is always cleared, even when the network
  /// call fails, so the user is never stuck inside the app.
  Future<void> logout() async {
    try {
      await _api.post<dynamic>(ApiEndpoints.logout);
    } on ApiException catch (error) {
      debugPrint('[Auth] logout call failed: $error');
    } finally {
      await SessionManager.instance.clear();
    }
  }

  String _otpKey(String phone, OtpPurpose purpose) => '$phone|${purpose.apiValue}';
}

/// Persists "this phone has an account" so the SMS probe runs only once.
class _AccountProbeCache {
  static const String _storageKey = 'mr_cake.auth.account_probe';
  static const Duration ttl = Duration(hours: 12);

  final Map<String, _ProbeEntry> _memory = <String, _ProbeEntry>{};
  SharedPreferences? _prefs;

  Future<bool?> read(String phone) async {
    final cached = _memory[phone];
    if (cached != null && !cached.isExpired) return cached.exists;

    try {
      final prefs = _prefs ??= await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      final map = Json.asMap(decoded);
      if (map == null) return null;

      for (final entry in map.entries) {
        final value = Json.asMap(entry.value);
        if (value == null) continue;
        final exists = Json.asBool(value['exists']);
        final at = Json.asInt(value['at']) ?? 0;
        _memory[entry.key] = _ProbeEntry(
          exists: exists,
          storedAt: DateTime.fromMillisecondsSinceEpoch(at),
        );
      }

      final restored = _memory[phone];
      if (restored != null && !restored.isExpired) return restored.exists;
    } catch (error) {
      debugPrint('[Auth] probe cache read failed: $error');
    }
    return null;
  }

  Future<void> write(String phone, bool exists) async {
    _memory[phone] = _ProbeEntry(exists: exists, storedAt: DateTime.now());
    try {
      final prefs = _prefs ??= await SharedPreferences.getInstance();
      final payload = <String, dynamic>{
        for (final entry in _memory.entries)
          if (!entry.value.isExpired)
            entry.key: {
              'exists': entry.value.exists,
              'at': entry.value.storedAt.millisecondsSinceEpoch,
            },
      };
      await prefs.setString(_storageKey, jsonEncode(payload));
    } catch (error) {
      debugPrint('[Auth] probe cache write failed: $error');
    }
  }

  Future<void> remove(String phone) async {
    _memory.remove(phone);
    try {
      final prefs = _prefs ??= await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final map = Json.asMap(jsonDecode(raw));
      if (map == null) return;
      map.remove(phone);
      await prefs.setString(_storageKey, jsonEncode(map));
    } catch (error) {
      debugPrint('[Auth] probe cache remove failed: $error');
    }
  }
}

class _ProbeEntry {
  const _ProbeEntry({required this.exists, required this.storedAt});

  final bool exists;
  final DateTime storedAt;

  bool get isExpired =>
      DateTime.now().difference(storedAt) > _AccountProbeCache.ttl;
}
