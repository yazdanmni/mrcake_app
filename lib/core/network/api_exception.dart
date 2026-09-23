import 'dart:io';

import 'package:dio/dio.dart';

/// High level classification of an API failure.
///
/// Screens use it to decide what to show (retry button, warning card, ...)
/// instead of inspecting raw HTTP codes everywhere.
enum ApiErrorType {
  /// No connection / DNS failure / socket closed.
  network,

  /// The request took too long.
  timeout,

  /// A VPN / proxy was detected and the request could not be trusted.
  vpn,

  /// 401 - the token is missing, invalid or expired.
  unauthorized,

  /// 403 - authenticated but not allowed.
  forbidden,

  /// 404 - the resource does not exist.
  notFound,

  /// 400/422 - the server rejected the payload (field errors available).
  validation,

  /// 5xx - the backend failed.
  server,

  /// Anything else (cancelled request, unknown payload, ...).
  unknown,
}

/// A single, human readable error type shared by the whole app.
///
/// Every repository throws this, every screen catches this. The `message` is
/// always the Persian sentence coming from the backend when available, so the
/// user never sees a raw English Dio error.
class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.errors,
    this.type = ApiErrorType.unknown,
    this.field,
  });

  /// Persian, user facing message.
  final String message;

  /// HTTP status code when the failure came from the server.
  final int? statusCode;

  /// Field level errors, e.g. `{"phone_number": ["..."]}`.
  final Map<String, dynamic>? errors;

  final ApiErrorType type;

  /// The first field that failed validation, when known.
  final String? field;

  bool get isUnauthorized => type == ApiErrorType.unauthorized;
  bool get isNetworkFailure =>
      type == ApiErrorType.network || type == ApiErrorType.timeout;

  // ---------------------------------------------------------------------------
  // Envelope
  // ---------------------------------------------------------------------------

  /// The backend answers with
  /// `{"success": false, "message": "...", "errors": {...}, "status_code": 400}`
  factory ApiException.fromEnvelope(
    Map<String, dynamic> body, {
    int? statusCode,
  }) {
    final code = _asInt(body['status_code']) ?? statusCode;
    final errors = body['errors'];
    final normalizedErrors = errors is Map
        ? errors.map((key, value) => MapEntry(key.toString(), value))
        : null;

    final rawMessage = body['message'];
    final message = _firstMeaningful([
      if (rawMessage is String) rawMessage,
      if (normalizedErrors != null) _firstErrorText(normalizedErrors),
    ]);

    return ApiException(
      message: message ?? _fallbackMessageForStatus(code),
      statusCode: code,
      errors: normalizedErrors,
      type: _typeForStatus(code),
      field: normalizedErrors == null || normalizedErrors.isEmpty
          ? null
          : normalizedErrors.keys.first,
    );
  }

  // ---------------------------------------------------------------------------
  // Dio
  // ---------------------------------------------------------------------------

  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    final body = response?.data;

    // The backend almost always sends the envelope, even for errors.
    if (body is Map) {
      final map = body.map((key, value) => MapEntry(key.toString(), value));
      if (map.containsKey('message') ||
          map.containsKey('success') ||
          map.containsKey('errors')) {
        return ApiException.fromEnvelope(map, statusCode: response?.statusCode);
      }
    }

    final type = _typeForDioError(error);
    return ApiException(
      message: _messageForDioError(error, type),
      statusCode: response?.statusCode,
      type: type,
    );
  }

  static ApiErrorType _typeForDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiErrorType.timeout;
      case DioExceptionType.connectionError:
        return ApiErrorType.network;
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
        return _typeForStatus(error.response?.statusCode);
      case DioExceptionType.cancel:
        return ApiErrorType.unknown;
      case DioExceptionType.unknown:
        final cause = error.error;
        if (cause is SocketException ||
            cause is HttpException ||
            cause is HandshakeException) {
          return ApiErrorType.network;
        }
        return ApiErrorType.unknown;
    }
  }

  static String _messageForDioError(DioException error, ApiErrorType type) {
    switch (type) {
      case ApiErrorType.timeout:
        return 'ارتباط با سرور طول کشید. لطفاً اینترنت خود را بررسی کنید.';
      case ApiErrorType.network:
        return 'اتصال به اینترنت برقرار نیست. اتصال خود را بررسی کنید.';
      case ApiErrorType.server:
        return 'خطای سرور. لطفاً چند لحظه بعد دوباره تلاش کنید.';
      case ApiErrorType.unauthorized:
        return 'نشست شما منقضی شده است. لطفاً دوباره وارد شوید.';
      case ApiErrorType.forbidden:
        return 'شما به این بخش دسترسی ندارید.';
      case ApiErrorType.notFound:
        return 'اطلاعات مورد نظر پیدا نشد.';
      case ApiErrorType.validation:
        return 'اطلاعات ارسال‌شده نامعتبر است.';
      case ApiErrorType.vpn:
        return 'استفاده از VPN یا پروکسی مجاز نیست.';
      case ApiErrorType.unknown:
        return 'خطای غیرمنتظره‌ای رخ داد. لطفاً دوباره تلاش کنید.';
    }
  }

  static ApiErrorType _typeForStatus(int? status) {
    if (status == null) return ApiErrorType.unknown;
    if (status == 401) return ApiErrorType.unauthorized;
    if (status == 403) return ApiErrorType.forbidden;
    if (status == 404) return ApiErrorType.notFound;
    if (status == 400 || status == 422) return ApiErrorType.validation;
    if (status >= 500) return ApiErrorType.server;
    return ApiErrorType.unknown;
  }

  static String _fallbackMessageForStatus(int? status) =>
      _messageForDioError(
        DioException(requestOptions: RequestOptions(path: '')),
        _typeForStatus(status),
      );

  // ---------------------------------------------------------------------------
  // Helpers used by the auth flow to understand *which* field failed.
  // ---------------------------------------------------------------------------

  /// True when the backend said "there is no account with this phone number".
  ///
  /// `send-otp` answers `حساب کاربری با این شماره یافت نشد` and
  /// `login-password` answers `حساب کاربری با این شماره وجود ندارد`.
  bool get isUnknownPhone {
    if (statusCode != null && statusCode != 400) return false;
    final text = _allErrorText();
    if (text.contains('یافت نشد')) return true;
    if (text.contains('وجود ندارد')) return true;
    return false;
  }

  /// True when the OTP the user typed is wrong or expired.
  bool get isInvalidOtp {
    final text = _allErrorText();
    return text.contains('کد تایید اشتباه') ||
        text.contains('کد وارد شده') ||
        text.contains('منقضی') && field == 'otp';
  }

  /// True when the password was rejected.
  bool get isWrongPassword {
    final text = _allErrorText();
    if (text.contains('رمز عبور اشتباه')) return true;
    if (text.contains('رمز عبور') &&
        (text.contains('نادرست') || text.contains('اشتباه'))) {
      return true;
    }
    return field == 'password' && text.contains('رمز');
  }

  String _allErrorText() {
    final buffer = StringBuffer(message);
    final raw = errors;
    if (raw != null) {
      for (final value in raw.values) {
        if (value is List) {
          for (final item in value) {
            buffer.write(' ');
            buffer.write(item.toString());
          }
        } else {
          buffer.write(' ');
          buffer.write(value.toString());
        }
      }
    }
    return buffer.toString();
  }

  static String? _firstErrorText(Map<String, dynamic> errors) {
    for (final value in errors.values) {
      if (value is List && value.isNotEmpty) {
        final first = value.first;
        if (first is String && first.trim().isNotEmpty) return first.trim();
      } else if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static String? _firstMeaningful(List<String?> candidates) {
    for (final candidate in candidates) {
      if (candidate == null) continue;
      final clean = _stripFieldPrefix(candidate);
      if (clean.isNotEmpty) return clean;
    }
    return null;
  }

  /// The backend prefixes the message with the field name, e.g.
  /// `phone_number: یک شماره تماس معتبر وارد نمایید.` -> keep the sentence only.
  static String _stripFieldPrefix(String value) {
    final trimmed = value.trim();
    final separator = trimmed.indexOf(': ');
    if (separator > 0 && separator <= 24) {
      final head = trimmed.substring(0, separator);
      if (!head.contains(' ')) return trimmed.substring(separator + 2).trim();
    }
    return trimmed;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  @override
  String toString() =>
      'ApiException($type, status: $statusCode, message: $message)';
}
