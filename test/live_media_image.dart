// Live image-pipeline test — decodes a real server image through the exact
// class the app uses.
//
// Kept in its own file on purpose: `testWidgets` initialises the widget
// binding, which installs an `HttpOverrides` that blocks real HTTP for the
// **whole file**. Mixing it with the plain `test()`s in `live_api_smoke.dart`
// silently broke nine of them.
//
// Run explicitly:
//
//   NO_PROXY="localhost,127.0.0.1,::1" flutter test test/live_media_image.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_cake_project/core/network/media_host_overrides.dart';
import 'package:mr_cake_project/repositories/catalog_repository.dart';

void main() {
  testWidgets('NetworkImage decodes a real server image end to end',
      (tester) async {
    // `NetworkImage` is the exact class behind `Image.network`, so this proves
    // the app's real image pipeline — not just a bare HttpClient.
    //
    // The widget binding installs its own HttpOverrides that answer 400 to
    // everything; installing ours afterwards is what `main()` does in the app.
    HttpOverrides.global = MediaHostHttpOverrides();
    addTearDown(() => HttpOverrides.global = null);

    // `testWidgets` runs in a fake-async zone; real socket work only completes
    // inside `runAsync`.
    await tester.runAsync(() async {
      // Chain from the API, so the url the *model* produces is what gets
      // decoded — the full path: API -> model -> image loader.
      final categories = await CatalogRepository.instance.fetchCategories();
      final url = categories.first.image;

      // ignore: avoid_print
      print('  category image url -> $url');
      expect(url, isNotNull);
      expect(url, contains('media.dl.mceiran.website'));

      final completer = Completer<ImageInfo>();
      NetworkImage(url!).resolve(ImageConfiguration.empty).addListener(
            ImageStreamListener(
              (info, _) => completer.complete(info),
              onError: (error, _) => completer.completeError(error),
            ),
          );

      final info = await completer.future.timeout(const Duration(seconds: 25));

      // ignore: avoid_print
      print('  decoded -> ${info.image.width} x ${info.image.height}');
      expect(info.image.width, greaterThan(0));
      expect(info.image.height, greaterThan(0));
      info.dispose();
    });
  });
}
