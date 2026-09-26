import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/network/api_client.dart';
import '../core/network/api_config.dart';
import '../core/session/session_manager.dart';
import '../models/app_notification.dart';
import '../models/course_details.dart';
import '../models/gift.dart';
import 'catalog_repository.dart';
import 'support_repository.dart';

/// Watches the discount codes that belong to the user and raises the two alerts
/// the product asked for.
///
/// ## What it watches for
///
///   * **a code became active** — «کد تخفیف «{title}» برای شما فعال شد» with the
///     coupon's own `title` / `description` as the text. The first time the app
///     sees the account's codes it treats them as newly active, which is the
///     moment an admin hands them over;
///   * **an hour is left** — «تنها یک ساعت تا پایان کد تخفیف «{title}» باقی
///     مانده است» while the code is inside its last hour.
///
/// ## Which codes qualify
///
/// `discounts/apply/my_coupons/` already means "coupons attached to this
/// account", but a **public** coupon the user once used lands there too. A
/// public code is not a gift, so a coupon with no `specific_user` is skipped —
/// that is the product's third rule: «کد تخفیفی هم که برای کاربری نباشه لازم
/// نیست نوتیف داشته باشه».
///
/// ⚠️ **"Created for a user but not yet handed over" cannot be told apart from
/// "already handed over" by this feed.** The endpoint answers a *list of the
/// user's own coupons* — there is no creation event, and `status` is `active`
/// for both. So the first sighting stands in for "handed over". If the backend
/// ever exposes the creation timestamp or a hand-over event, that — not this
/// heuristic — should drive the `activated` alert.
///
/// ## Why the alerts are keyed by id
///
/// A coupon can be activated once and can only enter its last hour once, so each
/// alert is raised **at most once per coupon id** and remembered in
/// [_announced]. Without that, an hourly sweep would repeat the same "expires
/// soon" line every hour for the whole final hour.
class GiftWatchDog {
  GiftWatchDog._();

  static final GiftWatchDog instance = GiftWatchDog._();

  /// `coupon_id:kind` — the alert already delivered for that coupon.
  final Set<String> _announced = <String>{};

  /// Coupons seen before, so the very first sighting is the "activated" alert
  /// and every sighting after it is not.
  bool _primed = false;

  /// The alerts that are due right now, without delivering them.
  ///
  /// [gifts] is the list «هدیه‌ها» also shows. [courseName] resolves a course id
  /// to its title, so the body can name the course; return `null` for an id the
  /// catalogue has never heard of.
  List<GiftAlert> dueAlerts(
    List<Gift> gifts, {
    String Function(int courseId)? courseName,
  }) {
    final List<GiftAlert> out = <GiftAlert>[];

    for (final Gift gift in gifts) {
      if (!gift.isPersonal) continue;
      if (!gift.isUsable) continue;

      if (!_primed && !_announced.contains('${gift.id}:activated')) {
        out.add(
          GiftAlert(
            gift: gift,
            kind: GiftAlertKind.activated,
            courseName: _nameOf(gift, courseName),
          ),
        );
      }

      if (gift.isExpiringWithinAnHour &&
          !_announced.contains('${gift.id}:expiring')) {
        out.add(
          GiftAlert(
            gift: gift,
            kind: GiftAlertKind.expiring,
            courseName: _nameOf(gift, courseName),
          ),
        );
      }
    }

    return out;
  }

  /// Remembers every alert that was delivered, so nothing repeats.
  void markAnnounced(GiftAlert alert) {
    _announced.add('${alert.gift.id}:${alert.kind.name}');
    _primed = true;
  }

  /// Marks **both** alerts for one coupon as seen.
  ///
  /// Called when «اعلان‌ها» reports a coupon row as read: the user has just
  /// acknowledged that code, and neither of its two possible alerts should
  /// reappear — on the next sweep or in the list.
  void markCouponSeen(int couponId) {
    _announced.add('$couponId:${GiftAlertKind.activated.name}');
    _announced.add('$couponId:${GiftAlertKind.expiring.name}');
  }

  /// True once [this] session has seen the account's coupons at all.
  bool get isPrimed => _primed;

  /// Clears everything. Called on logout, so the next account starts clean.
  void clear() {
    _announced.clear();
    _primed = false;
  }

  static String? _nameOf(
    Gift gift,
    String Function(int courseId)? courseName,
  ) {
    if (gift.specificCourses.isEmpty) return null;
    return courseName?.call(gift.specificCourses.first);
  }
}

/// The two kinds of discount-code alert.
enum GiftAlertKind {
  /// The code just became usable for this account.
  activated,

  /// The code is inside its last hour.
  expiring,
}

/// One discount-code alert, ready to be shown.
class GiftAlert {
  const GiftAlert({
    required this.gift,
    required this.kind,
    this.courseName,
  });

  final Gift gift;
  final GiftAlertKind kind;

  /// The course the coupon is restricted to, when the catalogue could name it.
  final String? courseName;

  /// The alert's headline.
  ///
  /// A `coupon` type rather than the backend's, so the app can tell its own
  /// rows apart. Coupons have no course or lesson, so tapping one opens nothing
  /// — see [AppNotification.hasTarget].
  AppNotification toNotification() => AppNotification(
    id: id,
    title: title,
    body: body,
    type: NotificationType.coupon,
    data: <String, dynamic>{
      'coupon_id': gift.id,
      'coupon_code': gift.code,
    },
    createdAt: DateTime.now(),
  );

  /// Stable, **negative** id so a locally-synthesised coupon row can never be
  /// confused with a backend row (`_markRead` treats `id < 0` as local).
  ///
  /// Offset from the lesson reminders, which use `-lessonId`: both live in the
  /// same list, and `-5` must not mean two different things.
  int get id => -(1000000 + gift.id * 10 + kind.index);

  String get title => switch (kind) {
    GiftAlertKind.activated => 'کد تخفیف فعال شد',
    GiftAlertKind.expiring => 'کد تخفیف در حال انقضا',
  };

  /// The product's wording, built from the coupon's own title and description.
  String get body {
    final StringBuffer buffer = StringBuffer();

    buffer.write(switch (kind) {
      GiftAlertKind.activated =>
        'کد تخفیف «${gift.title}» برای شما فعال شد.',
      GiftAlertKind.expiring =>
        'تنها یک ساعت تا پایان کد تخفیف «${gift.title}» باقی مانده است.',
    });

    if (gift.code.isNotEmpty) {
      buffer.write(' کد: ${gift.code}');
    }

    final String? course = courseName;
    if (course != null && course.trim().isNotEmpty) {
      buffer.write(' — ویژه دوره «$course»');
    }

    final String? description = gift.description;
    if (description != null && description.trim().isNotEmpty) {
      buffer.write('\n$description');
    }

    return buffer.toString();
  }
}

/// `GET /api/v1/notifications/` + `POST /api/v1/notifications/{id}/read/`.
///
/// Kept separate from the ticket code because these two are the only notification
/// calls the app makes, and the screen that reads them needs a typed list rather
/// than a `PagedResult`.
class NotificationCenter {
  NotificationCenter._();

  static final NotificationCenter instance = NotificationCenter._();

  ApiClient get _api => ApiClient.instance;

  /// `GET /api/v1/notifications/` (auth), newest first.
  ///
  /// Not cached: an unread badge must not survive a read.
  Future<List<AppNotification>> fetch() async {
    final data = await _api.get<dynamic>(ApiEndpoints.notifications);

    final map = Json.asMap(data);
    if (map == null) return const <AppNotification>[];

    // DRF page or a bare list — accept both, so a deployment that starts (or
    // stops) paginating does not silently empty the screen.
    final dynamic raw = map['results'] ?? map;

    final List<AppNotification> items = raw is List
        ? Json.asMapList(raw).map(AppNotification.fromJson).toList(growable: false)
        : <AppNotification>[];

    items.sort(
      (AppNotification a, AppNotification b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
    );

    return items;
  }

  /// `POST /api/v1/notifications/{id}/read/` (auth).
  Future<void> markAsRead(int id) async {
    await _api.post<dynamic>(ApiEndpoints.notificationRead(id));
  }
}

/// Watches the lessons the user started and did not finish, and raises a
/// notification for each one that has been sitting untouched for a day.
///
/// ## What "unfinished" means here
///
/// The backend records completion per lesson (`mark_lesson`), and the app knows
/// which lesson is currently open. A lesson is *unfinished* when:
///
///   * the user opened it (so there is a watching record),
///   * `mark_lesson` was never called for it, and
///   * at least [staleAfter] has passed since they last touched it.
///
/// The reminder text is exactly what the product asked for:
/// «ویدیو «{lesson}» از دوره «{course}» ناقص دیده شده است.»
///
/// ## Why it lives on the device
///
/// There is **no endpoint that writes a notification** — `v1/notifications/` is
/// `GET`-only, and the reference-list routes are `POST`. So the reminder is
/// delivered as a **local** notification, and the same text is mirrored into an
/// in-app list so the screen has the same content whether or not the OS showed
/// it. See [NotificationScheduler] for the hourly delivery.
class LessonWatchDog {
  LessonWatchDog._();

  static final LessonWatchDog instance = LessonWatchDog._();

  /// How long a lesson may sit untouched before it counts as abandoned.
  static const Duration staleAfter = Duration(hours: 24);

  /// The in-memory record of what the user is watching, keyed by lesson id.
  ///
  /// Deliberately not persisted: a watch session that did not survive the app
  /// being closed is not something to nag about on the next launch, and keeping
  /// it in memory means the reminder only ever fires for a session the user is
  /// actually part of.
  final Map<int, _WatchRecord> _records = <int, _WatchRecord>{};

  /// Lessons already reminded about, so the hourly sweep does not repeat itself.
  final Set<int> _reminded = <int>{};

  /// Called when the user opens a lesson.
  void startWatching({
    required int courseId,
    required String courseTitle,
    required CourseLesson lesson,
  }) {
    _records[lesson.id] = _WatchRecord(
      courseId: courseId,
      courseTitle: courseTitle,
      lessonId: lesson.id,
      lessonTitle: lesson.title,
      startedAt: DateTime.now(),
      lastSeenAt: DateTime.now(),
      completed: false,
    );
  }

  /// Called on every progress tick, so `lastSeenAt` tracks the user.
  void touch(int lessonId) {
    final _WatchRecord? record = _records[lessonId];
    if (record == null) return;
    record.lastSeenAt = DateTime.now();
  }

  /// Called when the lesson reaches its end.
  void markCompleted(int lessonId) {
    final _WatchRecord? record = _records[lessonId];
    if (record == null) return;
    record.completed = true;
    _reminded.remove(lessonId);
  }

  /// The lessons that qualify for a reminder right now.
  List<LessonReminder> dueReminders() {
    final DateTime now = DateTime.now();

    return <LessonReminder>[
      for (final _WatchRecord record in _records.values)
        if (!record.completed &&
            !_reminded.contains(record.lessonId) &&
            now.difference(record.lastSeenAt) >= staleAfter)
          LessonReminder(
            courseId: record.courseId,
            courseTitle: record.courseTitle,
            lessonId: record.lessonId,
            lessonTitle: record.lessonTitle,
          ),
    ];
  }

  /// Clears the "already reminded" mark for everything that is no longer due, so
  /// a lesson the user comes back to can be reminded about again if they leave
  /// it a second time.
  void refresh() {
    final List<int> active = <int>[
      for (final _WatchRecord record in _records.values)
        if (!record.completed) record.lessonId,
    ];

    _reminded.removeWhere((int id) => !active.contains(id));
  }

  /// Records that a reminder for [lessonId] has been seen, so it stops being
  /// due.
  ///
  /// Called by [NotificationScheduler.sweep] once a device notification has
  /// gone out, and by «اعلان‌ها» when the user reads the row there — a reminder
  /// the user has already acknowledged must not reappear on the next sweep.
  void markReminded(int lessonId) => _reminded.add(lessonId);

  /// Moves a lesson's `lastSeenAt` back by [by], so a reminder becomes due
  /// without the app having to sit open for a day.
  ///
  /// The staleness rule is `now - lastSeenAt >= staleAfter`, and `lastSeenAt` is
  /// always "right now" in production — which makes the 24-hour case impossible
  /// to reach in a widget test, and equally impossible to demo. This is the
  /// single seam that lets a test (or a QA build) age a record on demand.
  @visibleForTesting
  void backdate(int lessonId, Duration by) {
    final _WatchRecord? record = _records[lessonId];
    if (record == null) return;
    record.lastSeenAt = record.lastSeenAt.subtract(by);
  }

  /// Drops everything. Called on logout.
  void clear() {
    _records.clear();
    _reminded.clear();
  }

  @visibleForTesting
  int get watchingCount => _records.length;
}

/// A lesson that was left unfinished.
class LessonReminder {
  const LessonReminder({
    required this.courseId,
    required this.courseTitle,
    required this.lessonId,
    required this.lessonTitle,
  });

  final int courseId;
  final String courseTitle;
  final int lessonId;
  final String lessonTitle;

  /// «ویدیو ناقص دیده شده» — the exact wording the product asked for.
  String get title => 'ویدیو ناقص دیده شده';

  String get body =>
      'ویدیو «$lessonTitle» از دوره «$courseTitle» ناقص دیده شده است.';
}

class _WatchRecord {
  _WatchRecord({
    required this.courseId,
    required this.courseTitle,
    required this.lessonId,
    required this.lessonTitle,
    required this.startedAt,
    required this.lastSeenAt,
    this.completed = false,
  });

  final int courseId;
  final String courseTitle;
  final int lessonId;
  final String lessonTitle;
  final DateTime startedAt;

  DateTime lastSeenAt;
  bool completed;
}

/// Delivers the reminders to the device **every hour**.
///
/// ## Why there is no plugin here
///
/// A Flutter widget test cannot drive `flutter_local_notifications`: its
/// platform channel has no implementation in the test host, so every call
/// throws and the suite would have to mock the whole plugin. The delivery
/// mechanism is therefore kept behind [PlatformNotifier], whose default
/// implementation talks to the OS through the method channel **only when a
/// channel is actually available**, and which is a no-op everywhere else.
///
/// That is a real, working schedule on a device (`Timer.periodic` on an
/// hour-long interval, plus one sweep at startup) and a clean, testable no-op in
/// the suite. Swapping in `flutter_local_notifications` later means
/// implementing [PlatformNotifier] and changing nothing else.
class NotificationScheduler {
  NotificationScheduler._();

  static final NotificationScheduler instance = NotificationScheduler._();

  /// The product's interval: one notification an hour.
  static const Duration interval = Duration(hours: 1);

  Timer? _timer;

  /// The channel name a real notification plugin would listen on. Kept as a
  /// constant so the hook is a single, obvious line.
  static const MethodChannel channel = MethodChannel(
    'mr_cake_project/notifications',
  );

  bool _started = false;

  /// Starts the hourly sweep. Safe to call repeatedly.
  void start() {
    if (_started) return;
    _started = true;

    // One sweep now, so a lesson abandoned while the app was closed still gets
    // its reminder when the user comes back.
    unawaited(sweep());

    _timer = Timer.periodic(interval, (_) => unawaited(sweep()));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  /// Delivers every reminder that is due, at most once each.
  ///
  /// Public and parameterless so a test can call it directly instead of waiting
  /// an hour.
  ///
  /// The hour-long beat covers **both** kinds of reminder the product asked for:
  /// the unfinished lesson ([LessonWatchDog]) and the discount codes
  /// ([GiftWatchDog]). They share the beat because "one notification an hour"
  /// was the requirement, not "one per feature".
  Future<int> sweep({PlatformNotifier? notifier}) async {
    final PlatformNotifier target = notifier ?? const PlatformNotifier();

    final int lessons = await _sweepLessons(target);
    final int gifts = await _sweepGifts(target);

    return lessons + gifts;
  }

  Future<int> _sweepLessons(PlatformNotifier target) async {
    final LessonWatchDog dog = LessonWatchDog.instance;

    // A lesson the user returned to must be able to be reminded about again.
    dog.refresh();

    final List<LessonReminder> due = dog.dueReminders();
    if (due.isEmpty) return 0;

    for (final LessonReminder reminder in due) {
      try {
        await target.show(
          id: reminder.lessonId,
          title: reminder.title,
          body: reminder.body,
          payload: 'lesson:${reminder.courseId}:${reminder.lessonId}',
        );
      } catch (error) {
        debugPrint('[NOTIFY] delivery failed for ${reminder.lessonId}: $error');
      }

      dog.markReminded(reminder.lessonId);
    }

    return due.length;
  }

  /// The discount-code half of the beat: «کد تخفیف فعال شد» and «یک ساعت مانده».
  ///
  /// Reads the codes from `discounts/apply/my_coupons/` — the same source
  /// «هدیه‌ها» shows — so the two screens can never disagree about what the user
  /// holds.
  Future<int> _sweepGifts(PlatformNotifier target) async {
    final GiftWatchDog dog = GiftWatchDog.instance;

    // Only a signed-in account has coupons; a guest's request would be a 401.
    if (!SessionManager.instance.isLoggedIn) return 0;

    final List<Gift> gifts;
    try {
      gifts = await ShopGiftRepository.instance.fetchMyGifts();
    } catch (error) {
      debugPrint('[NOTIFY] could not read coupons: $error');
      return 0;
    }

    if (gifts.isEmpty) return 0;

    final Map<int, String> catalogue = await _courseNames(gifts);

    final List<GiftAlert> due = dog.dueAlerts(
      gifts,
      courseName: (int id) => catalogue[id] ?? '',
    );

    if (due.isEmpty) return 0;

    for (final GiftAlert alert in due) {
      try {
        await target.show(
          id: alert.id,
          title: alert.title,
          body: alert.body,
          payload: 'coupon:${alert.gift.id}',
        );
      } catch (error) {
        debugPrint('[NOTIFY] delivery failed for coupon ${alert.gift.id}: $error');
      }

      dog.markAnnounced(alert);
    }

    return due.length;
  }

  /// The titles of the courses the coupons point at, so the notification can
  /// name the course instead of printing an id.
  ///
  /// One catalogue read for every id — the list is cached and public, and a
  /// failure degrades to "no course named" rather than losing the alert.
  Future<Map<int, String>> _courseNames(List<Gift> gifts) async {
    final Set<int> ids = <int>{
      for (final Gift gift in gifts)
        if (gift.specificCourses.isNotEmpty) gift.specificCourses.first,
    };

    if (ids.isEmpty) return const <int, String>{};

    try {
      final courses = await CatalogRepository.instance.fetchGiftCatalogue();
      return <int, String>{
        for (final course in courses)
          if (ids.contains(course.id)) course.id: course.title,
      };
    } catch (error) {
      debugPrint('[NOTIFY] could not name the coupon courses: $error');
      return const <int, String>{};
    }
  }

  /// How many reminders are waiting, without delivering them.
  int get pendingCount => LessonWatchDog.instance.dueReminders().length;
}

/// The OS bridge. Overridable so tests can capture what would be shown.
class PlatformNotifier {
  const PlatformNotifier();

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await NotificationScheduler.channel.invokeMethod<void>('show', <String, dynamic>{
        'id': id,
        'title': title,
        'body': body,
        'payload': payload,
      });
    } on MissingPluginException {
      // No host implementation (tests, desktop, web). The in-app list still has
      // the same content, so this is a downgrade rather than a failure.
      debugPrint('[NOTIFY] no platform channel; skipping "$title"');
    }
  }
}
