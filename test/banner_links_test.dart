import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_cake_project/core/utils/external_link.dart';
import 'package:mr_cake_project/models/banner_model.dart' as api;
import 'package:mr_cake_project/pages/home/widgets/home_banner.dart';
import 'package:mr_cake_project/pages/home/widgets/home_hero.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

/// Captures what the app hands to the OS instead of really opening a browser.
class _FakeUrlLauncher extends UrlLauncherPlatform {
  final List<String> launched = <String>[];
  bool accepts = true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launched.add(url);
    return accepts;
  }
}

Widget _wrap(Widget child) => ScreenUtilInit(
  designSize: const Size(376, 812),
  builder: (context, _) => MaterialApp(home: Scaffold(body: child)),
);

void main() {
  late _FakeUrlLauncher launcher;
  late TestFlutterView view;

  setUp(() {
    launcher = _FakeUrlLauncher();
    UrlLauncherPlatform.instance = launcher;

    // The default 800x600 test surface is landscape, which makes ScreenUtil
    // scale width and height very differently from a real phone and produces
    // bogus overflows. Pin a portrait phone instead.
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    view = binding.platformDispatcher.implicitView!;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 3;
  });

  tearDown(() => view.reset());

  // ==========================================================================
  // ExternalLink — the value coming from the API is free text.
  // ==========================================================================

  group('ExternalLink.parse', () {
    test('keeps absolute web urls', () {
      expect(
        ExternalLink.parse('https://yazdanmni.ir')?.toString(),
        'https://yazdanmni.ir',
      );
      expect(
        ExternalLink.parse('http://example.com/a?b=1')?.toString(),
        'http://example.com/a?b=1',
      );
    });

    test('adds https to a bare domain', () {
      expect(
        ExternalLink.parse('yazdanmni.ir')?.toString(),
        'https://yazdanmni.ir',
      );
      expect(
        ExternalLink.parse('www.example.com/promo')?.toString(),
        'https://www.example.com/promo',
      );
    });

    test('trims the value before parsing', () {
      expect(
        ExternalLink.parse('  https://yazdanmni.ir  ')?.toString(),
        'https://yazdanmni.ir',
      );
    });

    test('accepts dialer and mail schemes', () {
      expect(ExternalLink.parse('tel:+989121234567')?.scheme, 'tel');
      expect(ExternalLink.parse('mailto:a@b.com')?.scheme, 'mailto');
    });

    test('refuses values that are not external targets', () {
      // Ids / slugs belong to in-app targets (course, category, screen).
      expect(ExternalLink.parse('12'), isNull);
      expect(ExternalLink.parse('my-course'), isNull);
      expect(ExternalLink.parse(''), isNull);
      expect(ExternalLink.parse('   '), isNull);
      expect(ExternalLink.parse(null), isNull);
      // Scheme without a host would open an empty tab.
      expect(ExternalLink.parse('https:'), isNull);
      expect(ExternalLink.parse('https://'), isNull);
      // Anything that is not a link must never reach the OS.
      expect(ExternalLink.parse('javascript:alert(1)'), isNull);
      expect(ExternalLink.parse('file:///etc/passwd'), isNull);
    });

    test('isOpenable mirrors parse', () {
      expect(ExternalLink.isOpenable('yazdanmni.ir'), isTrue);
      expect(ExternalLink.isOpenable('12'), isFalse);
      expect(ExternalLink.isOpenable(null), isFalse);
    });
  });

  // ==========================================================================
  // Models — the API fields the screens read.
  // ==========================================================================

  group('banner link fields', () {
    test('BannerModel reads link_value', () {
      final banner = api.BannerModel.fromJson(const {
        'id': 1,
        'image': 'https://media.dl.mceiran.website/banners/images/1.webp',
        'title': 't',
        'link_type': 'none',
        'link_value': 'https://yazdanmni.ir',
      });

      expect(banner.linkValue, 'https://yazdanmni.ir');
      expect(ExternalLink.isOpenable(banner.linkValue), isTrue);
    });

    test('HeroSection tolerates the link fields being absent', () {
      // The live endpoint answers {id, image} only, so the hero stays inert
      // instead of crashing on a missing key.
      final hero = api.HeroSection.fromJson(const {
        'id': 2,
        'image': 'https://media.dl.mceiran.website/hero/home_hero.png',
      });

      expect(hero.linkValue, isNull);
      expect(hero.linkType, api.BannerLinkType.none);
      expect(ExternalLink.isOpenable(hero.linkValue), isFalse);
    });
  });

  // ==========================================================================
  // Banner carousel
  // ==========================================================================

  group('HomeBanner tap', () {
    testWidgets('opens the banner link outside the app', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HomeBanner(
            banners: const [
              BannerModel(
                imageUrl: 'https://media.dl.mceiran.website/banners/1.webp',
                title: 'title',
                subtitle: 'subtitle',
                linkUrl: 'yazdanmni.ir',
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(PageView));
      await tester.pump();

      expect(launcher.launched, ['https://yazdanmni.ir']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a banner without a link stays inert', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HomeBanner(
            banners: const [
              BannerModel(
                imageUrl: 'https://media.dl.mceiran.website/banners/1.webp',
                title: 'title',
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(PageView));
      await tester.pump();

      expect(launcher.launched, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a non-url link_value never reaches the OS', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HomeBanner(
            banners: const [
              BannerModel(
                imageUrl: 'https://media.dl.mceiran.website/banners/1.webp',
                linkUrl: '12',
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(PageView));
      await tester.pump();

      expect(launcher.launched, isEmpty);
    });

    testWidgets('still swipes between slides', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HomeBanner(
            banners: const [
              BannerModel(imageUrl: 'https://x/1.webp', linkUrl: 'a.com'),
              BannerModel(imageUrl: 'https://x/2.webp', linkUrl: 'b.com'),
            ],
          ),
        ),
      );
      await tester.pump();

      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();

      // A swipe must scroll, not open a link.
      expect(launcher.launched, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  // ==========================================================================
  // Hero
  // ==========================================================================

  group('HomeHero', () {
    testWidgets('renders the bundled asset without layout errors', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const HomeHero()));
      await tester.pump();

      // Regression guard: the illustration used to be a Positioned inside a
      // Column, which throws "Incorrect use of ParentDataWidget".
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders the api image without layout errors', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const HomeHero(
            imageUrl: 'https://media.dl.mceiran.website/hero/home_hero.png',
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping the illustration opens the hero link', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const HomeHero(
            imageUrl: 'https://media.dl.mceiran.website/hero/home_hero.png',
            linkUrl: 'https://yazdanmni.ir',
          ),
        ),
      );
      await tester.pump();

      final heroRect = tester.getRect(find.byType(AspectRatio));
      // Upper half of the box = the illustration, not the CTA underneath it.
      await tester.tapAt(Offset(heroRect.center.dx, heroRect.top + 40));
      await tester.pump();

      expect(launcher.launched, ['https://yazdanmni.ir']);
    });

    testWidgets('the CTA button does not open the hero link', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const HomeHero(
            imageUrl: 'https://media.dl.mceiran.website/hero/home_hero.png',
            linkUrl: 'https://yazdanmni.ir',
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('شروع یادگیری'));
      await tester.pump();

      expect(launcher.launched, isEmpty);
    });

    testWidgets('an api without a hero link leaves the image inert', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const HomeHero(
            imageUrl: 'https://media.dl.mceiran.website/hero/home_hero.png',
          ),
        ),
      );
      await tester.pump();

      final heroRect = tester.getRect(find.byType(AspectRatio));
      await tester.tapAt(Offset(heroRect.center.dx, heroRect.top + 40));
      await tester.pump();

      expect(launcher.launched, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}
