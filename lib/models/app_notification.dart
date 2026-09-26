import '../core/network/api_client.dart';

/// One `Notification` from `GET /api/v1/notifications/`.
///
/// The payload is `{id, title, body, type, data, read_at, created_at, user}`.
/// `type` is a free-form string the backend uses as a category; `data` is an
/// untyped blob that carries the ids a notification is *about* — for the
/// unfinished-lesson reminder that is the course and lesson id, which is what
/// lets tapping the row open the lesson, and for a «هدیه‌ها» alert it is the
/// coupon id and its code.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.data = const <String, dynamic>{},
    this.readAt,
    this.createdAt,
  });

  final int id;
  final String title;
  final String body;

  /// The backend's category. `incomplete_lesson` is the one this app itself
  /// writes; anything else is treated as a generic message.
  final String type;

  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime? createdAt;

  bool get isRead => readAt != null;

  /// The course the notification points at, when it names one.
  int? get courseId =>
      Json.asInt(data['course_id']) ?? Json.asInt(data['courseId']);

  /// The lesson the notification points at, when it names one.
  int? get lessonId =>
      Json.asInt(data['lesson_id']) ?? Json.asInt(data['lessonId']);

  /// The coupon the notification points at, when it names one. Written by the
  /// «هدیه‌ها» alerts — see `GiftWatchDog`.
  int? get couponId =>
      Json.asInt(data['coupon_id']) ?? Json.asInt(data['couponId']);

  /// The discount code the notification is about, when it names one.
  String? get couponCode => Json.asString(data['coupon_code']);

  /// `true` when the row can open the lesson it is about.
  ///
  /// A coupon row deliberately carries **no** target: «هدیه‌ها» is where a code
  /// lives, and a notification is not a shortcut into it.
  bool get hasTarget => courseId != null || lessonId != null;

  /// `relative` — «۲ ساعت پیش», «۳ روز پیش».
  String get relativeTime {
    final DateTime? date = createdAt;
    if (date == null) return '';

    final Duration elapsed = DateTime.now().difference(date);

    if (elapsed.inMinutes < 1) return 'همین حالا';
    if (elapsed.inMinutes < 60) {
      return '${_fa(elapsed.inMinutes)} دقیقه پیش';
    }
    if (elapsed.inHours < 24) {
      return '${_fa(elapsed.inHours)} ساعت پیش';
    }
    if (elapsed.inDays < 30) {
      return '${_fa(elapsed.inDays)} روز پیش';
    }
    if (elapsed.inDays < 365) {
      return '${_fa(elapsed.inDays ~/ 30)} ماه پیش';
    }

    return '${_fa(elapsed.inDays ~/ 365)} سال پیش';
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: Json.asInt(json['id']) ?? 0,
      title: Json.asString(json['title']) ?? '',
      body: Json.asString(json['body']) ?? '',
      type: Json.asString(json['type']) ?? '',
      data: Json.asMap(json['data']) ?? const <String, dynamic>{},
      readAt: Json.asDate(json['read_at']),
      createdAt: Json.asDate(json['created_at']),
    );
  }

  static String _fa(int value) {
    const List<String> digits = <String>[
      '۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹',
    ];

    return value
        .toString()
        .split('')
        .map((String d) {
          final int index = int.tryParse(d) ?? -1;
          return index >= 0 ? digits[index] : d;
        })
        .join();
  }
}

/// The values [AppNotification.type] takes for the notifications this app
/// writes itself, so the string is never spelled by hand twice.
class NotificationType {
  NotificationType._();

  /// «ویدیو ناقص دیده شده» — written by the watchdog.
  static const String incompleteLesson = 'incomplete_lesson';

  /// «کد تخفیف فعال شد» / «کد تخفیف در حال انقضا» — a gift from «هدیه‌ها». See
  /// `GiftWatchDog`.
  static const String coupon = 'coupon';

  /// Anything the backend sends that the app does not special-case.
  static const String system = 'system';
}
