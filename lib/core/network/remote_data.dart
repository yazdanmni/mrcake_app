import 'package:flutter/foundation.dart';

import '../app_config.dart';
import 'api_exception.dart';

/// Outcome of a "read from the API, fall back to bundled seed data" call.
///
/// Screens stay 100% unchanged visually: they receive a plain list (or value)
/// and only use [isRemote] / [error] for optional, non-intrusive hints.
class RemoteResult<T> {
  const RemoteResult({
    required this.data,
    required this.isRemote,
    this.error,
  });

  /// Never `null` for lists (empty list instead) and never `null` for values
  /// when a seed was supplied.
  final T data;

  /// `true` when [data] really came from the backend.
  final bool isRemote;

  /// The failure that forced the fallback, when there was one.
  final ApiException? error;

  bool get hasError => error != null;

  /// `true` when the backend answered successfully but with nothing to show.
  bool get isEmptyRemote =>
      isRemote && (data is List ? (data as List).isEmpty : false);

  /// Persian message ready to be shown in a snack bar / placeholder.
  String? get message => error?.message;
}

/// Bridges the repositories and the `setState`-based screens.
///
/// The project deliberately uses **no state management package**, so this is a
/// pair of plain static helpers: call them from `initState`, then `setState`
/// with the result.
///
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   _loadCourses();
/// }
///
/// Future<void> _loadCourses() async {
///   final result = await RemoteLoader.list<Course>(
///     label: 'courses',
///     seed: CoursesData.courses,
///     fetch: () async {
///       final page = await CatalogRepository.instance.fetchCourses();
///       return page.items.map(Course.fromJson).toList();
///     },
///   );
///   if (!mounted) return;
///   setState(() => _courses = result.data);
/// }
/// ```
class RemoteLoader {
  RemoteLoader._();

  /// Loads a list. On failure — or on an empty page while
  /// [AppConfig.useSeedFallback] is on — the [seed] list is returned so the
  /// screen keeps rendering exactly as before.
  ///
  /// Pass `refresh: true` for a user-initiated reload (pull-to-refresh): it
  /// drops the TTL cache first, otherwise the pull would be answered from the
  /// cache and appear to do nothing.
  static Future<RemoteResult<List<T>>> list<T>({
    required String label,
    List<T> seed = const [],
    required Future<List<T>> Function() fetch,
    bool refresh = false,
  }) async {
    if (refresh) RemoteCache.clear();

    try {
      final items = await fetch();

      if (items.isEmpty &&
          AppConfig.useSeedFallback &&
          seed.isNotEmpty) {
        _log(label, 'empty remote page, falling back to seed (${seed.length} items)');
        return RemoteResult<List<T>>(
          data: seed,
          isRemote: false,
        );
      }

      return RemoteResult<List<T>>(data: items, isRemote: true);
    } on ApiException catch (error) {
      _log(label, 'request failed (${error.type.name}): ${error.message}');

      if (AppConfig.useSeedFallback && seed.isNotEmpty) {
        _log(label, 'using seed fallback (${seed.length} items) after ApiException');
        return RemoteResult<List<T>>(
          data: seed,
          isRemote: false,
          error: error,
        );
      }

      return RemoteResult<List<T>>(
        data: const [],
        isRemote: false,
        error: error,
      );
    } catch (error) {
      _log(label, 'unexpected error: $error');

      final apiError = ApiException(
        message: 'خطای غیرمنتظره‌ای رخ داد.',
        type: ApiErrorType.unknown,
      );

      if (AppConfig.useSeedFallback && seed.isNotEmpty) {
        _log(label, 'using seed fallback (${seed.length} items) after unexpected error');
        return RemoteResult<List<T>>(
          data: seed,
          isRemote: false,
          error: apiError,
        );
      }

      return RemoteResult<List<T>>(
        data: const [],
        isRemote: false,
        error: apiError,
      );
    }
  }

  /// Loads a single object (course detail, hero, teacher, …).
  ///
  /// When the request fails and [seed] is provided, the seed is returned.
  /// `refresh: true` bypasses the TTL cache, as in [list].
  static Future<RemoteResult<T?>> value<T>({
    required String label,
    required Future<T?> Function() fetch,
    T? seed, // Keep seed optional, but don't use it for fallback
    bool refresh = false,
  }) async {
    if (refresh) RemoteCache.clear();

    try {
      final value = await fetch();

      if (value == null &&
          AppConfig.useSeedFallback &&
          seed != null) {
        _log(label, 'null remote value, falling back to seed');
        return RemoteResult<T?>(
          data: seed,
          isRemote: false,
        );
      }

      return RemoteResult<T?>(data: value, isRemote: true);
    } on ApiException catch (error) {
      _log(label, 'request failed (${error.type.name}): ${error.message}');

      if (AppConfig.useSeedFallback && seed != null) {
        _log(label, 'using seed fallback after ApiException');
        return RemoteResult<T?>(
          data: seed,
          isRemote: false,
          error: error,
        );
      }

      return RemoteResult<T?>(
        data: null, // Always return null on API error
        isRemote: false,
        error: error,
      );
    } catch (error) {
      _log(label, 'unexpected error: $error');

      final apiError = ApiException(
        message: 'خطای غیرمنتظره‌ای رخ داد.',
        type: ApiErrorType.unknown,
      );

      if (AppConfig.useSeedFallback && seed != null) {
        _log(label, 'using seed fallback after unexpected error');
        return RemoteResult<T?>(
          data: seed,
          isRemote: false,
          error: apiError,
        );
      }

      return RemoteResult<T?>(
        data: null, // Always return null on unexpected error
        isRemote: false,
        error: apiError,
      );
    }
  }

  /// Fire-and-forget variant used for side effects such as
  /// `toggle_favorite` or `mark_lesson`, where a failure must never break the
  /// screen the user is looking at.
  static Future<bool> action(
    String label,
    Future<void> Function() run,
  ) async {
    try {
      await run();
      return true;
    } on ApiException catch (error) {
      _log(label, 'action failed (${error.type.name}): ${error.message}');
      return false;
    } catch (error) {
      _log(label, 'action failed: $error');
      return false;
    }
  }

  static void _log(String label, String message) {
    if (kDebugMode) debugPrint('[REMOTE:$label] $message');
  }
}

/// Tiny in-memory cache so switching tabs does not re-hit the network.
///
/// Keyed by a caller-provided string; entries expire after
/// [AppConfig.catalogueCacheTtl].
///
/// **Only public, non user-specific reads may be cached.** Anything that
/// depends on the logged-in account (enrollments, favourites, progress,
/// reviews, profile) must always hit the network — see [invalidate] for the
/// writes that must drop cached entries.
class RemoteCache {
  RemoteCache._();

  static final Map<String, _CacheEntry> _entries = {};

  static T? read<T>(String key) {
    final entry = _entries[key];
    if (entry == null) return null;

    if (DateTime.now().isAfter(entry.expiresAt)) {
      _entries.remove(key);
      return null;
    }

    final value = entry.value;
    return value is T ? value : null;
  }

  static void write(String key, Object? value) {
    if (AppConfig.catalogueCacheTtl == Duration.zero) return;
    if (value == null) return;

    _entries[key] = _CacheEntry(
      value: value,
      expiresAt: DateTime.now().add(AppConfig.catalogueCacheTtl),
    );
  }

  /// Drops every entry whose key starts with [prefix].
  ///
  /// Called after a write that changes what the catalogue would return, so a
  /// mutation can never be hidden by a stale cached response.
  static void invalidate(String prefix) {
    _entries.removeWhere((key, _) => key.startsWith(prefix));
  }

  static void clear() => _entries.clear();

  static void remove(String key) => _entries.remove(key);

  /// Number of live entries — used by the tests.
  @visibleForTesting
  static int get length => _entries.length;
}

class _CacheEntry {
  const _CacheEntry({required this.value, required this.expiresAt});

  final Object? value;
  final DateTime expiresAt;
}
