import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_config.dart';
import 'api_exception.dart';

/// The single Dio instance of the application.
///
/// Responsibilities:
///  * builds the `https://api.mceiran.website/api/` base url
///  * injects `Authorization: Bearer <token>` on every request
///  * unwraps the `{success, message, data}` envelope
///  * converts every failure into a [ApiException] with a Persian message
///
/// No state management package is used: this is a plain singleton and the
/// screens talk to it through the repositories.
class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        sendTimeout: ApiConfig.sendTimeout,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        // We validate status codes ourselves so the envelope of error
        // responses (400/401/...) can be parsed instead of being thrown away.
        validateStatus: (_) => true,
        responseType: ResponseType.json,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = accessTokenProvider?.call();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          final status = response.statusCode ?? 0;
          if (status >= 200 && status < 300) {
            handler.next(response);
            return;
          }
          if (status == 401) {
            // Only a rejected *token* means the session is dead. A 401 from an
            // endpoint that merely requires auth — reached by a guest — must
            // not clear anything, otherwise browsing a screen that happens to
            // call an auth-only endpoint logs the user out and wipes the
            // response cache for no reason.
            final sentToken = response.requestOptions.headers['Authorization'];
            if (sentToken is String && sentToken.isNotEmpty) {
              unawaited(onUnauthorized?.call());
            }
          }
          handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
            ),
            true,
          );
        },
        onError: (error, handler) => handler.next(error),
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          request: false,
          requestHeader: false,
          requestBody: false,
          responseHeader: false,
          responseBody: false,
          logPrint: (object) => debugPrint('[API] $object'),
        ),
      );
    }
  }

  static final ApiClient instance = ApiClient._internal();

  late final Dio _dio;

  Dio get dio => _dio;

  /// Wired by `SessionManager` at startup.
  String? Function()? accessTokenProvider;

  /// Wired by `SessionManager` at startup, called when the backend answers 401.
  Future<void> Function()? onUnauthorized;

  // ---------------------------------------------------------------------------
  // Public helpers
  // ---------------------------------------------------------------------------

  /// GET and unwrap the envelope.
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    Duration? timeout,
    T Function(dynamic data)? parser,
  }) =>
      _send<T>(
        () => _dio.get(path, queryParameters: query, cancelToken: _token),
        parser: parser,
        timeout: timeout,
      );

  /// POST and unwrap the envelope.
  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Duration? timeout,
    T Function(dynamic data)? parser,
  }) =>
      _send<T>(
        () => _dio.post(
          path,
          data: body,
          queryParameters: query,
          cancelToken: _token,
        ),
        parser: parser,
        timeout: timeout,
      );

  /// PATCH and unwrap the envelope.
  Future<T> patch<T>(
    String path, {
    Object? body,
    Duration? timeout,
    T Function(dynamic data)? parser,
  }) =>
      _send<T>(
        () => _dio.patch(path, data: body, cancelToken: _token),
        parser: parser,
        timeout: timeout,
      );

  /// PUT and unwrap the envelope.
  Future<T> put<T>(
    String path, {
    Object? body,
    Duration? timeout,
    T Function(dynamic data)? parser,
  }) =>
      _send<T>(
        () => _dio.put(path, data: body, cancelToken: _token),
        parser: parser,
        timeout: timeout,
      );

  /// DELETE and unwrap the envelope.
  Future<T> delete<T>(
    String path, {
    Object? body,
    Duration? timeout,
    T Function(dynamic data)? parser,
  }) =>
      _send<T>(
        () => _dio.delete(path, data: body, cancelToken: _token),
        parser: parser,
        timeout: timeout,
      );

  /// Multipart upload (used for avatars / portfolios).
  Future<T> upload<T>(
    String path, {
    required String filePath,
    String field = 'file',
    Map<String, dynamic>? extra,
    Duration? timeout,
    T Function(dynamic data)? parser,
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final form = FormData.fromMap({
        ...?extra,
        field: await MultipartFile.fromFile(filePath),
      });
      return await _send<T>(
        () => _dio.post(
          path,
          data: form,
          cancelToken: _token,
          onSendProgress: onProgress,
        ),
        parser: parser,
        timeout: timeout,
      );
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(
        message: 'ارسال فایل ناموفق بود. لطفاً دوباره تلاش کنید.',
        type: ApiErrorType.unknown,
      );
    }
  }

  /// Raw Dio call for edge cases (e.g. streaming a video file).
  Future<Response<dynamic>> raw(
    Future<Response<dynamic>> Function(Dio dio) request,
  ) async {
    try {
      final response = await request(_dio);
      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) return response;
      final data = response.data;
      if (data is Map) {
        throw ApiException.fromEnvelope(
          data.map((key, value) => MapEntry(key.toString(), value)),
          statusCode: status,
        );
      }
      throw ApiException(
        message: 'درخواست ناموفق بود.',
        statusCode: status,
        type: status == 401
            ? ApiErrorType.unauthorized
            : status >= 500
            ? ApiErrorType.server
            : ApiErrorType.unknown,
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// Cancels every in-flight request (used when the session is dropped).
  void cancelAll() {
    if (!_token.isCancelled) _token.cancel('session reset');
  }

  void resetCancelToken() {
    if (_token.isCancelled) _token = CancelToken();
  }

  CancelToken _token = CancelToken();

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<T> _send<T>(
    Future<Response<dynamic>> Function() request, {
    T Function(dynamic data)? parser,
    Duration? timeout,
  }) async {
    resetCancelToken();
    try {
      final future = request();
      final response = timeout == null ? await future : await future.timeout(timeout);
      final unwrapped = unwrapEnvelope(response.data);
      if (parser != null) return parser(unwrapped);
      return unwrapped as T;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException(
        message: 'ارتباط با سرور طول کشید. لطفاً اینترنت خود را بررسی کنید.',
        type: ApiErrorType.timeout,
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    } on SocketException {
      throw ApiException(
        message: 'اتصال به اینترنت برقرار نیست. اتصال خود را بررسی کنید.',
        type: ApiErrorType.network,
      );
    } catch (error) {
      debugPrint('[API] unexpected error: $error');
      throw ApiException(
        message: 'خطای غیرمنتظره‌ای رخ داد. لطفاً دوباره تلاش کنید.',
        type: ApiErrorType.unknown,
      );
    }
  }

  /// Unwraps `{"success": true, "message": "...", "data": ...}`.
  ///
  /// Some endpoints (list endpoints) answer with a plain DRF page object
  /// `{"count": n, "results": [...]}`, those are returned untouched so the
  /// repositories can read them directly.
  static dynamic unwrapEnvelope(dynamic body) {
    if (body is Map) {
      final map = body.map((key, value) => MapEntry(key.toString(), value));
      final success = map['success'];
      if (success == false) {
        throw ApiException.fromEnvelope(map);
      }
      if (map.containsKey('data')) return map['data'];
      return map;
    }
    return body;
  }
}

/// Reads a value out of a decoded JSON map without crashing on null / wrong
/// types. Used by every `fromJson` implementation.
class Json {
  Json._();

  static Map<String, dynamic>? asMap(dynamic value) {
    if (value is Map) {
      return value.map((key, entry) => MapEntry(key.toString(), entry));
    }
    return null;
  }

  static List<Map<String, dynamic>> asMapList(dynamic value) {
    if (value is List) {
      return value
          .map(asMap)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    }
    return const [];
  }

  /// Reads a JSON array of ids.
  ///
  /// The coupon payloads carry `specific_courses` / `specific_categories` /
  /// `exclude_courses` as arrays of integers, and a malformed entry must not
  /// sink the whole coupon — non-numeric entries are dropped rather than
  /// throwing.
  static List<int> asIntList(dynamic value) {
    if (value is! List) return const <int>[];

    return value
        .map(asInt)
        .whereType<int>()
        .toList(growable: false);
  }

  static String? asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static int? asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static bool asBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true' || lower == '1') return true;
      if (lower == 'false' || lower == '0') return false;
    }
    return fallback;
  }

  static DateTime? asDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }
}
