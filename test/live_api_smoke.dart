// Live API smoke test — hits the REAL backend.
//
// Deliberately NOT named `*_test.dart`, so `flutter test` does not pick it up
// and the normal suite stays offline and deterministic. Run it explicitly:
//
//   NO_PROXY="localhost,127.0.0.1,::1" flutter test test/live_api_smoke.dart
//
// What it proves that `flutter analyze` / unit tests cannot: that Dio, the
// envelope unwrapping, `PagedResult` and the `fromJson` mappers all work
// against the responses the backend actually sends.
//
// Only unauthenticated endpoints are exercised — the production database has no
// user accounts, so every auth-only call would 401.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mr_cake_project/core/network/api_config.dart';
import 'package:mr_cake_project/core/network/api_exception.dart';
import 'package:mr_cake_project/core/network/media_host_overrides.dart';
import 'package:mr_cake_project/core/network/remote_data.dart';
import 'package:mr_cake_project/models/course.dart';
import 'package:mr_cake_project/repositories/catalog_repository.dart';

final _repo = CatalogRepository.instance;

void report(String label, Object? value) =>
    // ignore: avoid_print
    print('  $label -> $value');

void main() {
  setUp(RemoteCache.clear);
  tearDown(RemoteCache.clear);

  group('LIVE categories', () {
    test('fetchCategories maps the real payload', () async {
      final categories = await _repo.fetchCategories();
      report('count', categories.length);
      for (final c in categories) {
        report('  ${c.id}', 'title="${c.title}" image="${c.image}" '
            'slug=${c.slug} root=${c.isRoot}');
      }

      expect(categories, isNotEmpty);
      expect(categories.first.title, isNotEmpty);
      // `name` -> `title` and `icon` -> `image` are the mappings that matter.
      expect(categories.first.image, contains('media.dl.mceiran.website'));
    });

    test('fetchFeaturedCategories unwraps the envelope', () async {
      final featured = await _repo.fetchFeaturedCategories();
      report('count', featured.length);
      for (final c in featured) {
        report('  ${c.id}', 'title="${c.title}"');
      }
      expect(featured, isNotEmpty);
    });

    test('fetchCategoryTree reads children', () async {
      final tree = await _repo.fetchCategoryTree();
      report('roots', tree.length);
      for (final c in tree) {
        report('  ${c.id}', '"${c.title}" children=${c.children.length}');
      }
      expect(tree, isNotEmpty);
    });
  });

  group('LIVE banners', () {
    test('fetchActiveHero', () async {
      final hero = await _repo.fetchActiveHero();
      report('hero', hero == null ? 'null' : 'id=${hero.id} '
          'image=${hero.image}');
      expect(hero, isNotNull);
    });

    test('fetchHomeBanners does not 401 for a guest', () async {
      final banners = await _repo.fetchHomeBanners();
      report('count', banners.length);
      for (final b in banners) {
        report('  ${b.id}', '${b.title} / ${b.imageUrl}');
      }

      // The point is that this must NOT throw the 401 that the auth-only
      // `all_active` endpoint returns. How many banners exist depends on the
      // live database, so assert on the mapping instead of the count.
      for (final b in banners) {
        expect(b.imageUrl, contains('media.'));
      }
    });

    test('fetchActiveBanners IS auth-required (documents the 401)', () async {
      Object? caught;
      try {
        await _repo.fetchActiveBanners();
      } catch (error) {
        caught = error;
      }

      report('caught', caught.runtimeType);
      if (caught is ApiException) {
        report('  type', caught.type);
        report('  status', caught.statusCode);
      }
      expect(caught, isA<ApiException>());
      expect((caught! as ApiException).statusCode, 401);
    });
  });

  group('LIVE error handling', () {
    test('the 500 on courses/ becomes an ApiException, not a crash', () async {
      Object? caught;
      try {
        await _repo.fetchCourses();
      } catch (error) {
        caught = error;
      }

      report('caught', caught.runtimeType);
      if (caught is ApiException) {
        report('  type', caught.type);
        report('  status', caught.statusCode);
        report('  message', caught.message);
      }
      expect(caught, isA<ApiException>());
    });

    test('RemoteLoader keeps the seed when that 500 happens', () async {
      final result = await RemoteLoader.list<Course>(
        label: 'live.smoke',
        seed: const [],
        fetch: _repo.fetchCourses,
      );

      report('isRemote', result.isRemote);
      report('hasError', result.hasError);
      report('message', result.message);

      expect(result.hasError, isTrue);
      expect(result.isRemote, isFalse);
    });

    test('RemoteLoader survives an empty page from teachers/', () async {
      final result = await RemoteLoader.list<String>(
        label: 'live.smoke.teachers',
        seed: const ['seed'],
        fetch: () async {
          final teachers = await _repo.fetchTeachers();
          return teachers.map((t) => t.fullName).toList();
        },
      );

      report('data', result.data);
      report('isRemote', result.isRemote);
      // Either the real rows or the seed — but never an empty list, which is
      // the whole point of the fallback. The database may or may not have
      // teachers at any given moment.
      expect(result.data, isNotEmpty);
    });
  });

  group('LIVE caching', () {
    test('a second call is served from the cache', () async {
      final first = await _repo.fetchCategories();
      final second = await _repo.fetchCategories();

      report('entries after two calls', RemoteCache.length);
      report('same length', first.length == second.length);

      // The key is registered once, so the second call never hit the network.
      expect(RemoteCache.length, 1);
    });
  });

  group('LIVE media host TLS', () {
    final mediaUrl =
        '${ApiConfig.mediaBaseUrl}categories/icons/2026/09/21/cake.png';

    test('strict TLS REJECTS the media host (certificate does not cover it)',
        () async {
      final client = HttpClient();
      Object? caught;
      try {
        final request = await client.getUrl(Uri.parse(mediaUrl));
        final response = await request.close();
        await response.drain<void>();
      } catch (error) {
        caught = error;
      } finally {
        client.close(force: true);
      }

      report('caught', caught?.runtimeType);
      report('detail', caught);
      // This is the whole reason server media is invisible in the app: the
      // certificate's SAN list contains only `alvand.irandns.com`.
      expect(caught, isNotNull);
    });

    test('MediaHostHttpOverrides lets exactly that host through', () async {
      final client = MediaHostHttpOverrides().createHttpClient(null);
      final request = await client.getUrl(Uri.parse(mediaUrl));
      final response = await request.close();
      final bytes = await response.fold<int>(0, (sum, chunk) => sum + chunk.length);
      client.close(force: true);

      report('status', response.statusCode);
      report('content-type', response.headers.contentType);
      report('bytes', bytes);

      // The file is fine — only the certificate is wrong.
      expect(response.statusCode, 200);
      expect(bytes, greaterThan(1000));
    });

    test('the allowed host is the media host and nothing else', () {
      report('allowedHost', MediaHostHttpOverrides.allowedHost);
      expect(MediaHostHttpOverrides.allowedHost, 'media.dl.mceiran.website');
      expect(
        Uri.parse(ApiConfig.baseUrl).host,
        isNot(MediaHostHttpOverrides.allowedHost),
      );
    });
  });
}
