import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mr_cake_project/pages/home/widgets/home_quick_actions.dart';

import 'support/app_fonts.dart';

/// The four home quick-action buttons («دوره‌ها»، «استاد»، «هنرجوها»،
/// «رسپی‌ها») must survive every phone size without a `RenderFlex overflowed`
/// stripe.
///
/// They used to be laid out as four `Expanded`s wrapping an `Ink` that carried
/// a **fixed** `width: 85.w` next to `height: 85.h`. Width came from the screen
/// width and height from the screen height, so on any device where the two
/// disagree — a narrow phone, a tablet, and above all landscape — the icon
/// circle (`37.w`) plus the label no longer fitted in the 85.h-tall box and the
/// card overflowed. The fix sizes the icon against the card's own height, so
/// the column can never ask for more room than the card has.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Every size the layout has to survive: narrow and wide phones, a small
  /// tablet, and both landscape cases, which is where the old code broke worst.
  ///
  /// 360×640 matters most: `.sp` is `value * scaleWidth` in this project, so on
  /// a 360-wide phone the label is *wider* than the height-scaled card can hold
  /// — the overflow the user actually saw on a real phone, and one that a
  /// 390-wide test device hides.
  const Map<String, Size> devices = <String, Size>{
    'Galaxy 360×640': Size(360, 640),
    'iPhone SE 320×568': Size(320, 568),
    'iPhone 13 mini 375×812': Size(375, 812),
    'iPhone 13 390×844 (design)': Size(390, 844),
    'Pixel 7 412×915': Size(412, 915),
    'iPad mini 768×1024': Size(768, 1024),
    'phone landscape 844×390': Size(844, 390),
    'tablet landscape 1024×768': Size(1024, 768),
  };

  /// Mirrors the home screen: `HomeQuickActions` lives in a
  /// `Padding(horizontal: 25.w)` inside the page's column.
  Future<void> pumpQuickActions(WidgetTester tester, Size size) async {
    // The real fonts, so a `RenderFlex overflowed` here is a genuine one — see
    // `support/app_fonts.dart`.
    await loadAppFonts();

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (BuildContext context, Widget? child) => MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.symmetric(horizontal: 25.w),
              child: HomeQuickActions(
                onCoursesTap: () {},
                onTeachersTap: () {},
                onStudentsTap: () {},
                onRecipesTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The four cards, in the order the row lays them out.
  List<Rect> cardRects(WidgetTester tester) {
    final rects = <Rect>[];
    for (final element in find
        .byType(Ink)
        .evaluate()
        .toList()) {
      rects.add(tester.getRect(find.byWidget(element.widget)));
    }
    return rects;
  }

  group('HomeQuickActions responsiveness', () {
    for (final MapEntry<String, Size> device in devices.entries) {
      testWidgets('lays out without overflow on ${device.key}', (
        tester,
      ) async {
        await pumpQuickActions(tester, device.value);

        expect(
          tester.takeException(),
          isNull,
          reason:
              'a RenderFlex overflow means the cards do not fit '
              '${device.key}',
        );
      });
    }

    testWidgets('the four cards fill the row and never overlap', (
      tester,
    ) async {
      await pumpQuickActions(tester, const Size(390, 844));

      final rects = cardRects(tester);
      expect(rects, hasLength(4));

      for (var i = 0; i < rects.length; i++) {
        expect(rects[i].width, greaterThan(0));
        expect(rects[i].height, greaterThan(0));

        if (i == 0) continue;
        expect(
          rects[i].right,
          lessThanOrEqualTo(rects[i - 1].left + 0.01),
          reason: 'cards $i and ${i - 1} overlap (RTL row)',
        );
      }
    });

    testWidgets('narrow phones get narrower cards, not a broken layout', (
      tester,
    ) async {
      await pumpQuickActions(tester, const Size(320, 568));
      final narrow = cardRects(tester).first.width;

      await pumpQuickActions(tester, const Size(412, 915));
      final wide = cardRects(tester).first.width;

      expect(
        narrow,
        lessThan(wide),
        reason: 'the card is driven by the available width, not a constant',
      );
    });

    testWidgets('a card keeps its 85-tall proportions at the design size', (
      tester,
    ) async {
      await pumpQuickActions(tester, const Size(390, 844));

      // The row is RTL, so the first card sits against the **right** edge and
      // the last one against the left edge.
      final rects = cardRects(tester);
      expect(rects.first.right, closeTo(365, 0.5));
      expect(rects.last.left, closeTo(25, 0.5));
      for (final rect in rects) {
        expect(rect.height, closeTo(85, 0.5));
      }
    });

    testWidgets('the icon circle is still the original 37 at the design size', (
      tester,
    ) async {
      // The fix clamps the icon against the card's height, which must not
      // change a single pixel on a normal phone: 37 stays the smaller of the
      // two, so the card looks exactly as it did before.
      await pumpQuickActions(tester, const Size(390, 844));

      final Finder circle = find
          .ancestor(
            of: find.byIcon(Icons.auto_stories_rounded),
            matching: find.byType(Container),
          )
          .first;

      final Size size = tester.getSize(circle);
      expect(size.width, closeTo(37, 0.01));
      expect(size.height, closeTo(37, 0.01));
      expect(
        tester.getSize(find.byIcon(Icons.auto_stories_rounded)).height,
        closeTo(22, 0.01),
      );
    });

    for (final MapEntry<String, Size> device in devices.entries) {
      testWidgets('the label is never squeezed on ${device.key}', (
        tester,
      ) async {
        // Not overflowing is not enough: the label sits inside a `Flexible`, so
        // a reservation that is a fraction too small would clip the glyphs
        // instead of reporting an overflow. Its rendered height has to equal the
        // height the same text has when nothing constrains it — measured with a
        // `TextPainter` so the assertion does not depend on the constants in the
        // widget, nor on the engine rounding a line box to whole pixels.
        await pumpQuickActions(tester, device.value);

        for (final String title in <String>[
          'دوره‌ها',
          'استاد',
          'هنرجوها',
          'رسپی‌ها',
        ]) {
          final Finder label = find.text(title);
          final TextStyle style = tester.widget<Text>(label).style!;

          final TextPainter painter = TextPainter(
            text: TextSpan(text: title, style: style),
            textDirection: TextDirection.rtl,
            maxLines: 1,
          )..layout();
          addTearDown(painter.dispose);

          expect(
            tester.getSize(label).height,
            greaterThanOrEqualTo(painter.height - 0.01),
            reason: '«$title» is being clipped on ${device.key}',
          );
        }
      });
    }

    testWidgets('a big system font shrinks the icon, not the label', (
      tester,
    ) async {
      // `.sp` is scaled again by the platform's text scaler, so a user with
      // large accessibility fonts needs the icon to give up room rather than
      // have the label clipped.
      await loadAppFonts();

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (BuildContext context, Widget? child) => MaterialApp(
            builder: (BuildContext context, Widget? inner) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.5),
              ),
              child: inner!,
            ),
            home: Scaffold(
              body: Padding(
                padding: EdgeInsets.symmetric(horizontal: 25.w),
                child: HomeQuickActions(
                  onCoursesTap: () {},
                  onTeachersTap: () {},
                  onStudentsTap: () {},
                  onRecipesTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final Finder label = find.text('هنرجوها');
      final TextStyle style = tester.widget<Text>(label).style!;
      final TextPainter painter = TextPainter(
        text: TextSpan(text: 'هنرجوها', style: style),
        textDirection: TextDirection.rtl,
        maxLines: 1,
      )..layout();
      addTearDown(painter.dispose);

      expect(
        tester.getSize(label).height,
        greaterThanOrEqualTo(painter.height - 0.01),
        reason: 'the label must survive a 1.5× system font scale',
      );
    });
  });
}
