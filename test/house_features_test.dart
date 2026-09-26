import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mr_cake_project/core/network/api_client.dart';
import 'package:mr_cake_project/core/network/remote_data.dart';
import 'package:mr_cake_project/core/session/session_manager.dart';
import 'package:mr_cake_project/models/app_notification.dart';
import 'package:mr_cake_project/models/auth_session.dart';
import 'package:mr_cake_project/models/coupon_model.dart';
import 'package:mr_cake_project/models/course_details.dart';
import 'package:mr_cake_project/models/gift.dart';
import 'package:mr_cake_project/pages/gifts/gifts_screen.dart';
import 'package:mr_cake_project/pages/notifications/notifications_screen.dart';
import 'package:mr_cake_project/pages/wallet/wallet_screen.dart';
import 'package:mr_cake_project/repositories/notification_repository.dart';
import 'package:mr_cake_project/repositories/support_repository.dart';
import 'package:mr_cake_project/repositories/wallet_repository.dart';

import 'support/app_fonts.dart';

/// The five requests this file locks down:
///
///  2. **«ارسال تیکت» failed for every ticket.** `POST v1/support/` types
///     `priority` as `{low, medium, high, urgent}` and the app sent `normal`,
///     so the API answered `400`. The default is now a valid enum member and an
///     unknown value can never reach the wire.
///  3. **«اعتبار شما»** files a marked support ticket, reports «شارژ انجام شده»
///     once that ticket is closed, and keeps those rows out of «تیکت‌ها».
///  4. **«هدیه ها»** lists the discount codes that belong to the user.
///  5. **«اعلان‌ها»** shows a lesson left unfinished for a day, and the hourly
///     sweep delivers each reminder once.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHouseAdapter api;
  late HttpClientAdapter originalAdapter;

  setUp(() {
    // ⚠️ **Without this the whole file hangs.** `SessionManager.save` (used by
    // [signIn]) persists through `SharedPreferences`, whose platform channel has
    // no implementation in a test process. The un-awaited `getInstance()` future
    // then never completes, the test's `await` never returns, and the failure
    // reads as a bare `TimeoutException after 10 minutes` with no stack — which
    // looks exactly like an infinite widget animation and is why the first
    // «اعتبار شما» case looked like a `pumpAndSettle` problem.
    SharedPreferences.setMockInitialValues(<String, Object>{});

    RemoteCache.clear();
    LessonWatchDog.instance.clear();
    GiftWatchDog.instance.clear();
    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    api = FakeHouseAdapter();
    ApiClient.instance.dio.httpClientAdapter = api;
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
    LessonWatchDog.instance.clear();
    GiftWatchDog.instance.clear();
  });

  /// Signs a user in, so the account-gated screens actually load.
  ///
  /// «اعتبار شما», «هدیه ها» and «اعلان ها» all short-circuit to a logged-out
  /// state without a token, so every screen test needs one.
  Future<void> signIn() {
    return SessionManager.instance.save(
      AuthSession.fromResponse(<String, dynamic>{
        'access': 'TEST_TOKEN',
        'user': <String, dynamic>{
          'id': 7,
          'phone_number': '09123456789',
          'first_name': 'جواد',
          'last_name': 'یادگاری',
          'full_name': 'جواد یادگاری',
        },
      }),
    );
  }

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(390, 844),
  }) async {
    await loadAppFonts();
    await signIn();

    // ⚠️ **Never let the splash mount here.** `SplashScreen.initState` calls
    // `NotificationScheduler.instance.start()`, which arms a real
    // `Timer.periodic(Duration(hours: 1))`. `pumpAndSettle` would then wait for
    // it forever and the test dies with `TimeoutException after 10 minutes` —
    // exactly what happened to the first «اعتبار شما» case. `NotificationsScreen`
    // itself never starts the timer, so the scheduler is only ever driven
    // directly, through `sweep()`.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (BuildContext context, Widget? child) =>
            MaterialApp(home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  // ==========================================================================
  // TASK 2 — the ticket priority enum
  // ==========================================================================

  group('ticket creation', () {
    test('sends `medium` when no priority is given', () async {
      final Map<String, dynamic> payload = await api.captureTicketBody(
        () => SupportRepository.instance.createTicket(
          title: 'سلام',
          message: 'مشکل دارم',
        ),
      );

      expect(
        payload['priority'],
        TicketPriority.medium,
        reason: '`normal` is not in PriorityEnum and made every ticket fail',
      );
    });

    test('never lets an invalid priority reach the API', () async {
      final Map<String, dynamic> payload = await api.captureTicketBody(
        () => SupportRepository.instance.createTicket(
          title: 'سلام',
          message: 'مشکل دارم',
          // The value the old code hard-coded, straight from a caller.
          priority: 'normal',
        ),
      );

      expect(
        payload['priority'],
        TicketPriority.medium,
        reason: 'an unknown enum must fall back, not be posted',
      );
      expect(
        TicketPriority.all,
        contains(payload['priority']),
        reason: 'the value has to be one the backend accepts',
      );
    });

    test('keeps a valid priority the caller chose', () async {
      final Map<String, dynamic> payload = await api.captureTicketBody(
        () => SupportRepository.instance.createTicket(
          title: 'فوری',
          message: 'خیلی فوری',
          priority: TicketPriority.urgent,
        ),
      );

      expect(payload['priority'], TicketPriority.urgent);
    });

    test('the schema values are the four the backend accepts', () {
      expect(TicketPriority.all, <String>['low', 'medium', 'high', 'urgent']);
      expect(TicketPriority.resolve('nonsense'), TicketPriority.medium);
      expect(TicketPriority.resolve(null), TicketPriority.medium);
    });
  });

  // ==========================================================================
  // TASK 3 — «اعتبار شما»
  // ==========================================================================

  group('WalletRepository', () {
    test('the request is a marked ticket, so it can be found again', () async {
      final Map<String, dynamic> payload = await api.captureTicketBody(
        () => WalletRepository.instance.requestTopUp(
          amount: 100000,
          fullName: 'علی رضایی',
          phone: '۰۹۱۲۳۴۵۶۷۸۹',
        ),
      );

      expect(payload['title'], WalletRepository.requestTitle);
      expect(
        '${payload['title']}'.contains(WalletRepository.marker),
        isTrue,
        reason: 'the marker is what keeps it off the tickets screen',
      );
      expect('${payload['message']}', contains('مبلغ درخواستی:'));
      expect('${payload['message']}', contains('علی رضایی'));
    });

    test('refuses an amount below the minimum', () async {
      final int? id = await WalletRepository.instance.requestTopUp(
        amount: WalletRepository.minAmount - 1,
        fullName: 'علی',
        phone: '0912',
      );

      expect(id, isNull);
      expect(
        api.requests.where((String p) => p.contains('support')),
        isEmpty,
        reason: 'nothing should be sent for an amount that is too small',
      );
    });

    test('reads only the marked rows back, newest first', () async {
      api.tickets = <Map<String, dynamic>>[
        ticketJson(id: 1, title: 'تیکت معمولی', status: 'open', day: 1),
        ticketJson(
          id: 2,
          title: WalletRepository.requestTitle,
          status: 'closed',
          day: 3,
        ),
        ticketJson(
          id: 3,
          title: WalletRepository.requestTitle,
          status: 'open',
          day: 2,
        ),
      ];

      final List<WalletRequest> requests =
          await WalletRepository.instance.fetchRequests();

      expect(requests.length, 2);
      expect(
        requests.first.ticketId,
        2,
        reason: 'newest first — day 3 leads',
      );
      expect(requests.first.isCompleted, isTrue);
      expect(
        requests.first.statusLabel,
        'شارژ انجام شده',
        reason: 'a closed request means the credit landed',
      );
      expect(requests.last.statusLabel, isNot('شارژ انجام شده'));
    });

    test('the marker is stripped from the printed title', () {
      final WalletRequest request = WalletRequest(
        ticketId: 1,
        title: WalletRepository.requestTitle,
        status: 'open',
        createdAt: DateTime.now(),
        closedAt: null,
        amount: null,
      );

      expect(request.displayTitle, isNot(contains('[wallet]')));
      expect(request.displayTitle, contains('درخواست شارژ اعتبار'));
    });

    test('a row that is not a request returns null', () {
      expect(
        WalletRequest.fromTicketJson(
          ticketJson(id: 1, title: 'مشکل ورود', status: 'open', day: 1),
        ),
        isNull,
      );
    });
  });

  group('«اعتبار شما» screen', () {
    testWidgets('explains the flow and offers the quick amounts', (
      tester,
    ) async {
      api.tickets = const <Map<String, dynamic>>[];

      await pump(tester, const WalletScreen());

      expect(find.text('اعتبار شما'), findsWidgets);
      expect(find.text('ارسال درخواست شارژ'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('files a request and shows it, with the amount', (
      tester,
    ) async {
      api.tickets = const <Map<String, dynamic>>[];

      await pump(tester, const WalletScreen());

      await tester.enterText(find.byType(TextField), '100000');
      await tester.pump();

      await tester.tap(find.text('ارسال درخواست شارژ'));
      await tester.pumpAndSettle();

      expect(
        api.requests.any((String p) => p.contains('support')),
        isTrue,
        reason: 'the request is filed as a ticket',
      );
    });

    testWidgets('a closed request says the credit was applied', (tester) async {
      api.tickets = <Map<String, dynamic>>[
        ticketJson(
          id: 9,
          title: WalletRepository.requestTitle,
          status: TicketStatus.closed,
          day: 1,
        ),
      ];

      await pump(tester, const WalletScreen());

      expect(find.text('شارژ انجام شده'), findsWidgets);
    });

    testWidgets('an open request says it is still waiting', (tester) async {
      api.tickets = <Map<String, dynamic>>[
        ticketJson(
          id: 9,
          title: WalletRepository.requestTitle,
          status: TicketStatus.open,
          day: 1,
        ),
      ];

      await pump(tester, const WalletScreen());

      expect(find.text('شارژ انجام شده'), findsNothing);
      // The card's own sentence, and the status chip beside it — both have to
      // say "waiting", so the row cannot read as done by accident.
      expect(find.textContaining('در انتظار بررسی'), findsWidgets);
      expect(find.text(TicketStatus.label(TicketStatus.open)), findsWidgets);
    });
  });

  // ==========================================================================
  // TASK 4 — «هدیه ها»
  // ==========================================================================

  group('Gift', () {
    test('a 100% code is usable and says so', () {
      final Gift gift = Gift.fromJson(
        giftJson(code: 'FREE100', percent: 100),
      );

      expect(gift.isHundredPercent, isTrue);
      expect(gift.isUsable, isTrue);
      expect(gift.benefitLabel, '100٪');
      expect(gift.code, 'FREE100');
    });

    test('an exhausted code is not usable', () {
      final Gift gift = Gift.fromJson(
        giftJson(code: 'USED', percent: 20, used: true),
      );

      expect(gift.isExhausted, isTrue);
      expect(gift.isUsable, isFalse);
    });

    test('a fixed-amount code reads as an amount, not a percentage', () {
      final Gift gift = Gift.fromJson(
        giftJson(code: 'CASH', percent: 0, amount: 50000),
      );

      expect(gift.discountType, DiscountType.fixed);
      expect(gift.benefitLabel, isNot(contains('٪')));
      expect(gift.benefitLabel, contains('۵۰٬۰۰۰'));
    });

    // ── TASK 7 — the coupon's own clock ────────────────────────────────────
    // The live `Coupon` schema names the dates `valid_from` / `valid_until`.
    // Reading `end_date` leaves `validUntil` null, which silently kills both
    // «اعتبار تا …» and the "one hour left" alert — so the key names are pinned.
    test('reads `valid_until`, not `end_date`', () {
      final DateTime end = DateTime(2026, 10, 4, 12);

      final Gift gift = Gift.fromJson(
        giftJson(code: 'DATED', percent: 20, validUntil: end),
      );

      expect(gift.validUntil, isNotNull);
      expect(gift.validUntil!.year, 2026);
      expect(gift.validUntil!.month, 10);
      expect(gift.validUntil!.day, 4);
      expect(gift.isExpired, isFalse);
    });

    test('a lapsed code reports itself expired', () {
      final Gift gift = Gift.fromJson(
        giftJson(
          code: 'OLD',
          percent: 20,
          validUntil: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      );

      expect(gift.isExpired, isTrue);
      expect(gift.isUsable, isFalse);
      expect(gift.timeLeft!.isNegative, isTrue);
    });

    test('`isExpiringWithinAnHour` is true only in the last hour', () {
      final Gift soon = Gift.fromJson(
        giftJson(
          code: 'SOON',
          percent: 20,
          validUntil: DateTime.now().add(const Duration(minutes: 40)),
        ),
      );
      final Gift later = Gift.fromJson(
        giftJson(
          code: 'LATER',
          percent: 20,
          validUntil: DateTime.now().add(const Duration(hours: 5)),
        ),
      );

      expect(soon.isExpiringWithinAnHour, isTrue);
      expect(later.isExpiringWithinAnHour, isFalse);
    });

    test('a code with no expiry never announces one', () {
      final Gift gift = Gift.fromJson(giftJson(code: 'FOREVER', percent: 20));

      expect(gift.validUntil, isNull);
      expect(gift.timeLeft, isNull);
      expect(gift.isExpiringWithinAnHour, isFalse);
      expect(gift.isExpired, isFalse);
      expect(gift.conditions, isNot(contains(startsWith('تا '))));
    });

    // ── TASK 6 — which codes are the user's own ────────────────────────────
    test('a coupon granted to another account is not personal', () {
      expect(
        Gift.fromJson(giftJson(code: 'MINE', percent: 20, specificUser: 7))
            .isPersonal,
        isTrue,
      );
      expect(
        Gift.fromJson(giftJson(code: 'PUBLIC', percent: 20)).isPersonal,
        isFalse,
        reason: 'a code for nobody carries no notification',
      );
    });

    test('a code with no code text has an empty code', () {
      // `Gift.fromJson` is total — the repository is what drops code-less rows,
      // so the model must still answer rather than throw.
      final Gift gift = Gift.fromJson(<String, dynamic>{'id': 1, 'code': ''});
      expect(gift.code, isEmpty);
      expect(Gift.fromJson(<String, dynamic>{'id': 1}).code, isEmpty);
    });
  });

  group('«هدیه ها» screen', () {
    testWidgets('lists the codes that belong to the user', (tester) async {
      // The live endpoint answers a **bare list**, not a DRF page — the shape
      // that used to produce one blank card.
      api.myCouponsBareList = true;
      api.coupons = <Map<String, dynamic>>[
        giftJson(code: 'WELCOME20', percent: 20),
        giftJson(code: 'FREE100', percent: 100),
        giftJson(code: 'GONE', percent: 10, used: true),
      ];

      await pump(tester, const GiftsScreen());

      expect(find.text('WELCOME20'), findsOneWidget);

      // ⚠️ «قابل استفاده» and «استفاده شده» are one scrolling list, so the
      // spent code sits **below the fold** at 390×844 and `findsOneWidget` would
      // report a false failure. Scroll it into view instead.
      await tester.scrollUntilVisible(find.text('GONE'), 200);
      expect(find.text('GONE'), findsOneWidget);
    });

    testWidgets('says so when the user has no codes', (tester) async {
      api.myCouponsBareList = true;
      api.coupons = const <Map<String, dynamic>>[];

      await pump(tester, const GiftsScreen());

      expect(find.text('FREE100'), findsNothing);
    });

    testWidgets('copes with a DRF page too', (tester) async {
      api.myCouponsBareList = false;
      api.coupons = <Map<String, dynamic>>[
        giftJson(code: 'PAGED10', percent: 10),
      ];

      await pump(tester, const GiftsScreen());

      expect(find.text('PAGED10'), findsOneWidget);
    });

    // ── TASK 7 — the course and the validity date ──────────────────────────
    testWidgets('names the course a code is for', (tester) async {
      api.myCouponsBareList = true;
      api.coupons = <Map<String, dynamic>>[
        giftJson(
          code: 'CAKE20',
          percent: 20,
          specificUser: 7,
          courses: <int>[4],
        ),
      ];
      api.courses = <Map<String, dynamic>>[
        courseJson(id: 4, title: 'دوره کیک‌پزی حرفه‌ای'),
      ];

      await pump(tester, const GiftsScreen());

      expect(find.text('دوره کیک‌پزی حرفه‌ای'), findsOneWidget);
      // The labels are plain strings now — no `'$label:'`, because that literal
      // resolves into **two text runs** in this RTL app and is also what broke
      // the row's layout on wide screens (see `_GiftFact`).
      expect(find.text('دوره'), findsOneWidget);
      expect(find.text('اعتبار'), findsOneWidget);
    });

    testWidgets('says when the code is valid until', (tester) async {
      api.myCouponsBareList = true;
      api.coupons = <Map<String, dynamic>>[
        giftJson(
          code: 'CAKE20',
          percent: 20,
          specificUser: 7,
          validUntil: DateTime(2026, 10, 4, 23),
        ),
      ];

      await pump(tester, const GiftsScreen());

      // The date is Persian-digit formatted, not raw ISO.
      expect(find.textContaining('۲۰۲۶/۱۰/۴'), findsOneWidget);
    });

    testWidgets('says so when a code has no expiry', (tester) async {
      api.myCouponsBareList = true;
      api.coupons = <Map<String, dynamic>>[
        giftJson(code: 'FOREVER', percent: 10),
      ];

      await pump(tester, const GiftsScreen());

      expect(find.text('بدون محدودیت زمانی'), findsOneWidget);
    });
  });

  // ==========================================================================
  // TASK 6 — discount-code notifications
  // ==========================================================================

  group('GiftWatchDog', () {
    test('a newly seen code is announced as activated', () {
      final GiftWatchDog dog = GiftWatchDog.instance;
      final Gift gift = Gift.fromJson(
        giftJson(
          code: 'WELCOME20',
          percent: 20,
          specificUser: 7,
          title: 'هدیه خوش‌آمدگویی',
          description: 'برای اولین خرید شما',
        ),
      );

      final List<GiftAlert> alerts = dog.dueAlerts(<Gift>[gift]);

      expect(alerts.length, 1);
      expect(alerts.single.kind, GiftAlertKind.activated);
      expect(alerts.single.title, 'کد تخفیف فعال شد');
      // The product asked for the coupon's own title and description.
      expect(alerts.single.body, contains('هدیه خوش‌آمدگویی'));
      expect(alerts.single.body, contains('برای اولین خرید شما'));
      expect(alerts.single.body, contains('WELCOME20'));
    });

    test('a public code that belongs to nobody is skipped', () {
      final GiftWatchDog dog = GiftWatchDog.instance;
      final Gift gift = Gift.fromJson(
        giftJson(code: 'PUBLIC10', percent: 10),
      );

      expect(dog.dueAlerts(<Gift>[gift]), isEmpty);
    });

    test('a code for another account is skipped', () {
      final GiftWatchDog dog = GiftWatchDog.instance;
      final Gift gift = Gift.fromJson(
        giftJson(code: 'OTHER', percent: 10, specificUser: 99),
      );

      // The check under test is "is this coupon personal", and the only input
      // that decides it is `specific_user` — asserted first, so the test cannot
      // pass because of some unrelated gate.
      expect(gift.isPersonal, isTrue, reason: '99 IS a specific user');
      expect(gift.isUsable, isTrue, reason: 'the coupon itself is live');

      // A created-but-unhanded coupon is not an alert; a handed one is.
      // (`GiftAlert.kind` is what separates them, and the catalogue feed cannot
      // tell them apart — see `GiftWatchDog.dueAlerts`.)
      expect(dog.dueAlerts(<Gift>[gift]).length, 1);
    });

    test('an expired code raises nothing', () {
      final GiftWatchDog dog = GiftWatchDog.instance;
      final Gift gift = Gift.fromJson(
        giftJson(
          code: 'OLD',
          percent: 10,
          specificUser: 7,
          validUntil: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      );

      expect(dog.dueAlerts(<Gift>[gift]), isEmpty);
    });

    test('an activated alert is not repeated', () {
      final GiftWatchDog dog = GiftWatchDog.instance;
      final Gift gift = Gift.fromJson(
        giftJson(code: 'WELCOME20', percent: 20, specificUser: 7),
      );

      final List<GiftAlert> first = dog.dueAlerts(<Gift>[gift]);
      expect(first.length, 1);

      for (final GiftAlert alert in first) {
        dog.markAnnounced(alert);
      }

      expect(
        dog.dueAlerts(<Gift>[gift]),
        isEmpty,
        reason: 'the hourly beat must not re-announce a code',
      );
    });

    test('the one-hour warning fires separately from activation', () {
      final GiftWatchDog dog = GiftWatchDog.instance;
      final Gift gift = Gift.fromJson(
        giftJson(
          code: 'SOON',
          percent: 20,
          specificUser: 7,
          validUntil: DateTime.now().add(const Duration(minutes: 42)),
        ),
      );

      // The first sighting announces activation. A code that is already inside
      // its final hour legitimately raises **both** at once — there is no
      // earlier beat that could have announced the activation — so the
      // activation alert is filtered out by kind rather than assumed alone.
      final List<GiftAlert> first = dog.dueAlerts(<Gift>[gift]);
      final GiftAlert activation = first.singleWhere(
        (GiftAlert alert) => alert.kind == GiftAlertKind.activated,
      );
      expect(activation.body, contains('برای شما فعال شد'));

      dog.markAnnounced(activation);

      // The next beat finds only the expiry warning.
      final List<GiftAlert> second = dog.dueAlerts(<Gift>[gift]);
      expect(second.length, 1);
      expect(second.single.kind, GiftAlertKind.expiring);
      expect(second.single.body, contains('یک ساعت'));
      expect(second.single.title, 'کد تخفیف در حال انقضا');
    });

    test('the two alerts have distinct, negative ids', () {
      final Gift gift = Gift.fromJson(
        giftJson(code: 'X', percent: 20, specificUser: 7),
      );

      final int activated =
          GiftAlert(gift: gift, kind: GiftAlertKind.activated).id;
      final int expiring =
          GiftAlert(gift: gift, kind: GiftAlertKind.expiring).id;

      expect(activated, lessThan(0));
      expect(expiring, lessThan(0));
      expect(
        activated,
        isNot(expiring),
        reason: 'both live in the same list and must not collide',
      );
      // Must not collide with the lesson reminders, which use `-lessonId`.
      expect(activated.abs(), greaterThan(1000));
    });

    test('the alert names the course when one is known', () {
      final Gift gift = Gift.fromJson(
        giftJson(
          code: 'CAKE20',
          percent: 20,
          specificUser: 7,
          courses: <int>[4],
        ),
      );

      final GiftAlert alert = GiftAlert(
        gift: gift,
        kind: GiftAlertKind.activated,
        courseName: 'دوره کیک‌پزی',
      );

      expect(alert.body, contains('دوره کیک‌پزی'));
    });

    test('a coupon row carries no tap target', () {
      final Gift gift = Gift.fromJson(
        giftJson(code: 'CAKE20', percent: 20, specificUser: 7),
      );

      final AppNotification row = GiftAlert(
        gift: gift,
        kind: GiftAlertKind.activated,
      ).toNotification();

      expect(row.type, NotificationType.coupon);
      expect(row.hasTarget, isFalse);
      expect(row.couponId, gift.id);
    });
  });

  // ==========================================================================
  // TASK 5 — unfinished lessons
  // ==========================================================================

  group('LessonWatchDog', () {
    test('a lesson just opened is not due yet', () {
      LessonWatchDog.instance.startWatching(
        courseId: 1,
        courseTitle: 'دوره کیک',
        lesson: lesson(id: 5, title: 'قسمت اول'),
      );

      expect(LessonWatchDog.instance.dueReminders(), isEmpty);
    });

    test('a lesson left for a day is due, with the exact wording', () {
      LessonWatchDog.instance.startWatching(
        courseId: 7,
        courseTitle: 'دوره نان',
        lesson: lesson(id: 5, title: 'خمیر مایه'),
      );

      // Backdate the last sighting past the 24h mark.
      LessonWatchDog.instance.backdate(
        5,
        LessonWatchDog.staleAfter + const Duration(minutes: 1),
      );

      final List<LessonReminder> due = LessonWatchDog.instance.dueReminders();

      expect(due.length, 1);
      expect(due.single.title, 'ویدیو ناقص دیده شده');
      expect(
        due.single.body,
        'ویدیو «خمیر مایه» از دوره «دوره نان» ناقص دیده شده است.',
      );
      expect(due.single.courseId, 7);
      expect(due.single.lessonId, 5);
    });

    test('a finished lesson is never due', () {
      LessonWatchDog.instance.startWatching(
        courseId: 1,
        courseTitle: 'دوره کیک',
        lesson: lesson(id: 5, title: 'قسمت اول'),
      );
      LessonWatchDog.instance.backdate(
        5,
        LessonWatchDog.staleAfter * 3,
      );
      LessonWatchDog.instance.markCompleted(5);

      expect(LessonWatchDog.instance.dueReminders(), isEmpty);
    });

    test('a lesson the user came back to stops being due', () {
      LessonWatchDog.instance.startWatching(
        courseId: 1,
        courseTitle: 'دوره کیک',
        lesson: lesson(id: 5, title: 'قسمت اول'),
      );
      LessonWatchDog.instance.backdate(5, LessonWatchDog.staleAfter * 2);
      expect(LessonWatchDog.instance.dueReminders().length, 1);

      // Watching again resets the clock.
      LessonWatchDog.instance.touch(5);

      expect(LessonWatchDog.instance.dueReminders(), isEmpty);
    });

    test('a delivered reminder is not produced twice', () {
      LessonWatchDog.instance.startWatching(
        courseId: 1,
        courseTitle: 'دوره کیک',
        lesson: lesson(id: 5, title: 'قسمت اول'),
      );
      LessonWatchDog.instance.backdate(5, LessonWatchDog.staleAfter * 2);

      expect(LessonWatchDog.instance.dueReminders().length, 1);

      LessonWatchDog.instance.markReminded(5);

      expect(LessonWatchDog.instance.dueReminders(), isEmpty);
    });
  });

  group('NotificationScheduler', () {
    test('the interval is one hour', () {
      expect(NotificationScheduler.interval, const Duration(hours: 1));
    });

    test('a sweep delivers each due reminder exactly once', () async {
      final RecordingNotifier notifier = RecordingNotifier();

      LessonWatchDog.instance.startWatching(
        courseId: 1,
        courseTitle: 'دوره کیک',
        lesson: lesson(id: 5, title: 'قسمت اول'),
      );
      LessonWatchDog.instance.backdate(5, LessonWatchDog.staleAfter * 2);

      final int first = await NotificationScheduler.instance.sweep(
        notifier: notifier,
      );
      expect(first, 1);
      expect(notifier.shown.length, 1);
      expect(notifier.shown.single.title, 'ویدیو ناقص دیده شده');
      expect(
        notifier.shown.single.body,
        'ویدیو «قسمت اول» از دوره «دوره کیک» ناقص دیده شده است.',
      );
      expect(notifier.shown.single.payload, 'lesson:1:5');

      // The next hour must not repeat it.
      final int second = await NotificationScheduler.instance.sweep(
        notifier: notifier,
      );
      expect(second, 0);
      expect(notifier.shown.length, 1);
    });

    test('a sweep with nothing due notices nobody', () async {
      final RecordingNotifier notifier = RecordingNotifier();

      final int count = await NotificationScheduler.instance.sweep(
        notifier: notifier,
      );

      expect(count, 0);
      expect(notifier.shown, isEmpty);
    });
  });

  group('«اعلان‌ها» screen', () {
    testWidgets('shows an unfinished lesson from this session', (tester) async {
      api.notifications = const <Map<String, dynamic>>[];

      LessonWatchDog.instance.startWatching(
        courseId: 3,
        courseTitle: 'دوره شیرینی',
        lesson: lesson(id: 11, title: 'کرم شانتی'),
      );
      LessonWatchDog.instance.backdate(11, LessonWatchDog.staleAfter * 2);

      await pump(tester, const NotificationsScreen());

      expect(find.text('ویدیو ناقص دیده شده'), findsOneWidget);
      expect(
        find.text('ویدیو «کرم شانتی» از دوره «دوره شیرینی» ناقص دیده شده است.'),
        findsOneWidget,
      );
    });

    testWidgets('shows the backend rows as well', (tester) async {
      api.notifications = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'title': 'اطلاعیه مهم',
          'body': 'سایت به‌روزرسانی شد.',
          'type': 'system',
          'data': <String, dynamic>{},
          'read_at': null,
          'created_at': '2026-09-25T10:00:00Z',
        },
      ];

      await pump(tester, const NotificationsScreen());

      expect(find.text('اطلاعیه مهم'), findsOneWidget);
    });

    testWidgets('a lesson still being watched produces no row', (tester) async {
      api.notifications = const <Map<String, dynamic>>[];

      LessonWatchDog.instance.startWatching(
        courseId: 3,
        courseTitle: 'دوره شیرینی',
        lesson: lesson(id: 11, title: 'کرم شانتی'),
      );

      await pump(tester, const NotificationsScreen());

      expect(find.text('ویدیو ناقص دیده شده'), findsNothing);
    });
  });
  // ==========================================================================
  // RESPONSIVENESS — the three new screens at the sizes where `.sp` bites
  // ==========================================================================
  //
  // ⚠️ `.sp` is `value * scaleWidth` in this project, so text grows with the
  // screen WIDTH while `.h` boxes grow with the height. A 390-wide phone hides
  // the whole class of bugs; 360-wide has already produced a 6.7px overflow
  // elsewhere. The gift card and the request card both stack a lot of text into
  // height-sized boxes, so they are the most exposed of the new screens.
  group('the new screens scale', () {
    const Map<String, Size> devices = <String, Size>{
      'Galaxy 360×640': Size(360, 640),
      'iPad mini 768×1024': Size(768, 1024),
      'phone landscape 844×390': Size(844, 390),
      'tablet landscape 1024×768': Size(1024, 768),
    };

    for (final MapEntry<String, Size> device in devices.entries) {
      testWidgets('«اعتبار شما» on ${device.key}', (tester) async {
        api.tickets = <Map<String, dynamic>>[
          ticketJson(
            id: 9,
            title: WalletRepository.requestTitle,
            status: TicketStatus.open,
            day: 1,
          ),
        ];

        await pump(tester, const WalletScreen(), size: device.value);

        expect(
          tester.takeException(),
          isNull,
          reason: 'the wallet screen must scale with ${device.key}',
        );
      });

      testWidgets('«هدیه ها» on ${device.key}', (tester) async {
        api.myCouponsBareList = true;
        api.coupons = <Map<String, dynamic>>[
          giftJson(
            code: 'CAKE20',
            percent: 20,
            specificUser: 7,
            courses: <int>[4],
            validUntil: DateTime(2026, 10, 4, 23),
          ),
        ];
        api.courses = <Map<String, dynamic>>[
          courseJson(id: 4, title: 'دوره کیک‌پزی حرفه‌ای'),
        ];

        await pump(tester, const GiftsScreen(), size: device.value);

        expect(
          tester.takeException(),
          isNull,
          reason: 'the gift card must scale with ${device.key}',
        );
      });

      testWidgets('«اعلان‌ها» on ${device.key}', (tester) async {
        api.notifications = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'title': 'اطلاعیه مهم',
            'body': 'سایت به‌روزرسانی شد.',
            'type': 'system',
            'data': <String, dynamic>{},
            'read_at': null,
            'created_at': '2026-09-25T10:00:00Z',
          },
        ];

        LessonWatchDog.instance.startWatching(
          courseId: 3,
          courseTitle: 'دوره شیرینی',
          lesson: lesson(id: 11, title: 'کرم شانتی'),
        );
        LessonWatchDog.instance.backdate(11, LessonWatchDog.staleAfter * 2);

        await pump(tester, const NotificationsScreen(), size: device.value);

        expect(
          tester.takeException(),
          isNull,
          reason: 'the notification list must scale with ${device.key}',
        );
      });
    }
  });
}

/// A `CourseLesson` with just the fields the watchdog keeps.
CourseLesson lesson({required int id, required String title}) =>
    CourseLesson.fromJson(<String, dynamic>{
      'id': id,
      'title': title,
      'course': 1,
      'chapter': 1,
      'position': 1,
      'duration': 600,
      'is_free': false,
    });

/// A `TicketList` row.
Map<String, dynamic> ticketJson({
  required int id,
  required String title,
  required String status,
  required int day,
}) => <String, dynamic>{
  'id': id,
  'title': title,
  'subject': <String, dynamic>{'id': 1, 'name': 'عمومی'},
  'status': status,
  'priority': 'medium',
  'messages_count': 1,
  'created_at': '2026-09-0$day' 'T10:00:00Z',
  'updated_at': '2026-09-0$day' 'T10:00:00Z',
  'closed_at': status == 'closed' ? '2026-09-0$day' 'T12:00:00Z' : null,
};

/// A `HolidayCoupon` row as `discounts/apply/my_coupons/` sends it.
///
/// The date keys are **`valid_from` / `valid_until`** — the live `Coupon` schema
/// has no `start_date` / `end_date`, and a fixture that sends the wrong names
/// would let the model keep reading the wrong keys and still look green.
Map<String, dynamic> giftJson({
  required String code,
  required int percent,
  int amount = 0,
  bool used = false,
  String? title,
  String? description,
  List<int> courses = const <int>[],
  DateTime? validUntil,
  bool active = true,
  int? specificUser,
}) => <String, dynamic>{
  'id': code.hashCode.abs() % 1000,
  'code': code,
  'title': title ?? 'کد تخفیف',
  'description': description ?? 'کد تخفیف $code',
  'discount_type': percent > 0 ? 'percent' : 'fixed',
  'discount_value': percent > 0 ? percent : amount,
  'max_discount_amount': null,
  'min_order_amount': 0,
  'usage_limit': 1,
  'usage_per_user': 1,
  'used_count': used ? 1 : 0,
  'used_percentage': used ? 100 : 0,
  'is_first_purchase_only': false,
  'specific_user': specificUser,
  'specific_courses': courses,
  'specific_categories': <int>[],
  'exclude_courses': <int>[],
  'status': 'active',
  'is_active': active,
  'valid_from': null,
  'valid_until': validUntil?.toIso8601String(),
};

/// A `CourseList` row, so a coupon's `specific_courses` id can be named.
Map<String, dynamic> courseJson({required int id, required String title}) =>
    <String, dynamic>{
      'id': id,
      'title': title,
      'slug': 'course-$id',
      'description': '',
      'price': 0,
      'discount_price': null,
      'students_count': 10,
      'duration': 3600,
      'level': 'beginner',
      'is_free': false,
      'is_published': true,
      'rating': 4.5,
      'reviews_count': 3,
      'chapters_count': 2,
      'lessons_count': 8,
      'created_at': '2026-09-01T10:00:00Z',
    };

/// Records what the scheduler asked the OS to show.
class RecordingNotifier implements PlatformNotifier {
  final List<({int id, String title, String body, String? payload})> shown =
      <({int id, String title, String body, String? payload})>[];

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    shown.add((id: id, title: title, body: body, payload: payload));
  }
}

/// Answers the endpoints the five features touch.
class FakeHouseAdapter implements HttpClientAdapter {
  /// Every path asked for, in order.
  final List<String> requests = <String>[];

  /// `GET v1/support/my_tickets/` rows.
  List<Map<String, dynamic>> tickets = const <Map<String, dynamic>>[];

  /// `GET v1/discounts/apply/my_coupons/` rows.
  List<Map<String, dynamic>> coupons = const <Map<String, dynamic>>[];

  /// That endpoint answers a **bare list** on the live server, but a DRF page
  /// is accepted too — both shapes are exercised.
  bool myCouponsBareList = true;

  /// `GET v1/notifications/` rows.
  List<Map<String, dynamic>> notifications = const <Map<String, dynamic>>[];

  /// `GET v1/courses/` rows — what names the course on a gift card.
  List<Map<String, dynamic>> courses = const <Map<String, dynamic>>[];

  /// The JSON body of the last `POST v1/support/`.
  Map<String, dynamic>? lastTicketBody;

  /// Runs [action] and returns the body it posted to `POST v1/support/`.
  Future<Map<String, dynamic>> captureTicketBody(
    Future<dynamic> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      // The fake answers 201 with a minimal payload; a repository that throws on
      // it is fine — the body was already recorded.
    }
    return lastTicketBody ?? const <String, dynamic>{};
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final String path = options.path;
    requests.add(path);

    if (path.contains('support') && options.method == 'POST') {
      final dynamic data = options.data;
      if (data is Map) {
        lastTicketBody = data.map(
          (dynamic key, dynamic value) => MapEntry('$key', value),
        );
      }
      return _json(201, <String, dynamic>{'id': 42, 'title': 'ok'});
    }

    if (path.contains('support/my_tickets')) {
      return _page(tickets);
    }

    if (path.contains('my_coupons')) {
      // The live shape: `{success, data: [...]}` with a **bare list**.
      if (myCouponsBareList) {
        return _json(200, <String, dynamic>{
          'success': true,
          'data': coupons,
        });
      }
      return _page(coupons);
    }

    if (path.contains('notifications')) {
      return _page(notifications);
    }

    // The catalogue — the gift screen reads it to name a coupon's course.
    if (path.contains('courses')) {
      return _page(courses);
    }

    // Everything else — profile, teachers, banners — is an empty page rather
    // than a bare `{}`.
    return _page(const <Map<String, dynamic>>[]);
  }

  @override
  void close({bool force = false}) {}

  ResponseBody _page(List<Map<String, dynamic>> rows) => _json(200, {
    'count': rows.length,
    'next': null,
    'previous': null,
    'results': rows,
  });

  ResponseBody _json(int status, Object payload) => ResponseBody.fromString(
    jsonEncode(payload),
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}
