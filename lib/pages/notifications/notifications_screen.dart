import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/network/remote_data.dart';
import '../../core/session/session_manager.dart';
import '../../core/theme/app_colors.dart';
import '../../models/app_notification.dart';
import '../../models/gift.dart';
import '../../repositories/notification_repository.dart';
import '../../repositories/support_repository.dart';
import '../../widgets/house_screen_header.dart';
/// «اعلان‌ها» — every notification the backend holds for this user.
///
/// ## What lands here
///
/// `GET /api/v1/notifications/`, newest first. Two kinds of row are expected:
///
///   * **`incomplete_lesson`** — the reminder
///     [LessonWatchDog] writes when a lesson was left unfinished, carrying the
///     course and lesson id in `data`. Tapping it opens that lesson straight
///     away, which is the whole point of the reminder;
///   * **anything else** — an announcement, shown as plain title + body.
///
/// Unread rows carry a premium dot and a tinted plate; reading one fires
/// `POST v1/notifications/{id}/read/` and updates the row in place, so the count
/// the user just cleared does not reappear on the next visit.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _items = const <AppNotification>[];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!SessionManager.instance.isLoggedIn) {
      setState(() => _isLoading = false);
      return;
    }

    final result = await RemoteLoader.list<AppNotification>(
      label: 'notifications.list',
      fetch: () => NotificationCenter.instance.fetch(),
    );

    if (!mounted) return;

    final List<AppNotification> merged = await _withLocalRows(result.data);

    if (!mounted) return;

    setState(() {
      _items = merged;
      _isLoading = false;
    });
  }

  /// The backend list with this session's local rows folded in.
  ///
  /// ## Why the merge is needed
  ///
  /// `v1/notifications/` is **read-only** — there is no endpoint that writes a
  /// notification. The two reminders the product asked for are therefore
  /// produced on the device and can only ever reach the OS as a local
  /// notification; without this merge they would fire on the phone but the rows
  /// would never appear in «اعلان‌ها»:
  ///
  ///   * [LessonWatchDog] — «ویدیو ناقص دیده شده»;
  ///   * [GiftWatchDog] — «کد تخفیف فعال شد» / «کد تخفیف در حال انقضا», the
  ///     discount codes «هدیه‌ها» shows.
  ///
  /// The local rows carry **negative ids**, which keeps them from colliding with
  /// the backend's own sequential ids and tells [_markRead] to update the row in
  /// place rather than POST a read receipt for an id the server has never seen.
  Future<List<AppNotification>> _withLocalRows(
    List<AppNotification> remote,
  ) async {
    final List<AppNotification> local = <AppNotification>[
      ..._lessonRows(remote),
      ...await _couponRows(remote),
    ];

    if (local.isEmpty) return remote;

    // The newest local row leads the list.
    local.sort(
      (AppNotification a, AppNotification b) => (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0)),
    );

    return <AppNotification>[...local, ...remote];
  }

  List<AppNotification> _lessonRows(List<AppNotification> remote) {
    final List<LessonReminder> due = LessonWatchDog.instance.dueReminders();
    if (due.isEmpty) return const <AppNotification>[];

    // A reminder the backend already knows about (a future deployment that does
    // write them) must not be listed twice — matched on the lesson id it names.
    final Set<int> alreadyListed = <int>{
      for (final AppNotification item in remote)
        if (item.lessonId != null) item.lessonId!,
    };

    return <AppNotification>[
      for (final LessonReminder reminder in due)
        if (!alreadyListed.contains(reminder.lessonId))
          AppNotification(
            // Negative: never a real backend id, so `_markRead` knows to keep
            // this one local.
            id: -reminder.lessonId,
            title: reminder.title,
            body: reminder.body,
            type: NotificationType.incompleteLesson,
            data: <String, dynamic>{
              'course_id': reminder.courseId,
              'lesson_id': reminder.lessonId,
            },
            createdAt: DateTime.now(),
          ),
    ];
  }

  /// The «هدیه‌ها» codes that have an alert to show.
  ///
  /// ⚠️ **A read here must not consume the alert.** «اعلان‌ها» can be opened
  /// before the hourly sweep has run, and an alert swallowed by the list would
  /// never reach the phone. Reading the codes therefore only *projects* the
  /// alerts (`dueAlerts`); marking them delivered stays with
  /// [NotificationScheduler.sweep] and [_markRead].
  Future<List<AppNotification>> _couponRows(
    List<AppNotification> remote,
  ) async {
    final List<Gift> gifts;
    try {
      gifts = await ShopGiftRepository.instance.fetchMyGifts();
    } catch (_) {
      // A gift fetch that fails must not cost the user the lesson reminders.
      return const <AppNotification>[];
    }

    if (gifts.isEmpty) return const <AppNotification>[];

    // A coupon the list already names must not be duplicated.
    final Set<int> alreadyListed = <int>{
      for (final AppNotification item in remote)
        if (item.couponId != null) item.couponId!,
    };

    return <AppNotification>[
      for (final GiftAlert alert in GiftWatchDog.instance.dueAlerts(gifts))
        if (!alreadyListed.contains(alert.gift.id)) alert.toNotification(),
    ];
  }

  int get _unreadCount =>
      _items.where((AppNotification item) => !item.isRead).length;

  /// Marks one row read, locally and on the server.
  ///
  /// The list updates first: waiting for the round trip would make the tap feel
  /// broken on a slow connection, and a failed POST only means the row comes
  /// back unread after a refresh — never lost data.
  ///
  /// A locally-synthesised reminder (a negative id) has no server row, so it is
  /// recorded as read in the watchdog instead of being POSTed.
  Future<void> _markRead(AppNotification notification) async {
    if (notification.isRead) return;

    final bool isLocal = notification.id < 0;

    setState(() {
      _items = <AppNotification>[
        for (final AppNotification item in _items)
          if (item.id == notification.id)
            AppNotification(
              id: item.id,
              title: item.title,
              body: item.body,
              type: item.type,
              data: item.data,
              readAt: DateTime.now(),
              createdAt: item.createdAt,
            )
          else
            item,
      ];
    });

    if (isLocal) {
      // A local row has no server counterpart, so "read" is recorded in
      // whichever watchdog produced it — that is what keeps it out of the list
      // from now on.
      final int? lessonId = notification.lessonId;
      if (lessonId != null) LessonWatchDog.instance.markReminded(lessonId);

      final int? couponId = notification.couponId;
      if (couponId != null) GiftWatchDog.instance.markCouponSeen(couponId);

      return;
    }

    await NotificationCenter.instance.markAsRead(notification.id);
  }

  Future<void> _markAllRead() async {
    final List<AppNotification> unread = _items
        .where((AppNotification item) => !item.isRead)
        .toList(growable: false);

    if (unread.isEmpty) return;

    for (final AppNotification notification in unread) {
      await _markRead(notification);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              HouseScreenHeader(
                title: 'اعلان‌ها',
                subtitle: _unreadCount > 0
                    ? '$_unreadCount اعلان خوانده‌نشده'
                    : 'همه اعلان‌ها خوانده شده‌اند',
                trailing: _unreadCount > 0
                    ? _MarkAllButton(onTap: _markAllRead)
                    : null,
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: _buildBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(vertical: 60.h),
            child: Center(
              child: SizedBox(
                width: 26.w,
                height: 26.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2.w,
                  color: AppColors.premium,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          HouseEmptyState(
            icon: Icons.notifications_none_rounded,
            message: SessionManager.instance.isLoggedIn
                ? 'اعلان جدیدی وجود ندارد.'
                : 'برای دیدن اعلان‌ها ابتدا وارد حساب شوید.',
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(25.w, 6.h, 25.w, 40.h),
      itemCount: _items.length,
      itemBuilder: (BuildContext context, int index) {
        final AppNotification item = _items[index];

        return Padding(
          padding: EdgeInsets.only(bottom: index == _items.length - 1 ? 0 : 10.h),
          child: _NotificationCard(
            notification: item,
            onTap: () => _markRead(item),
          ),
        );
      },
    );
  }
}

// ============================================================================
// MARK ALL
// ============================================================================

class _MarkAllButton extends StatelessWidget {
  const _MarkAllButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: AppColors.premium.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: AppColors.premium, width: 1.w),
        ),
        child: Text(
          'خواندن همه',
          style: TextStyle(
            fontFamily: 'bshabnam',
            fontSize: 12.sp,
            color: AppColors.textPrimary,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CARD
// ============================================================================

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool unread = !notification.isRead;

    final bool isReminder =
        notification.type == NotificationType.incompleteLesson;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            // An unread row is tinted so the difference is visible at a glance
            // without a badge to decode.
            color: unread
                ? AppColors.premium.withValues(alpha: 0.07)
                : AppColors.field,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: unread ? AppColors.premium : AppColors.border,
              width: unread ? 1.5.w : 1.w,
            ),
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: AppColors.premium.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11.r),
                  border: Border.all(color: AppColors.premium, width: 1.w),
                ),
                alignment: Alignment.center,
                child: Icon(
                  isReminder
                      ? Icons.play_circle_outline_rounded
                      : Icons.notifications_none_rounded,
                  size: 21.sp,
                  color: AppColors.premium,
                ),
              ),

              SizedBox(width: 12.w),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      textDirection: TextDirection.rtl,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            notification.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontFamily: 'bshabnam',
                              fontSize: 14.sp,
                              fontWeight: unread
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                        if (unread) ...<Widget>[
                          SizedBox(width: 8.w),
                          Container(
                            width: 8.w,
                            height: 8.w,
                            decoration: const BoxDecoration(
                              color: AppColors.premium,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),

                    if (notification.body.isNotEmpty) ...<Widget>[
                      SizedBox(height: 6.h),
                      Text(
                        notification.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: 'bshabnam',
                          fontSize: 12.5.sp,
                          color: AppColors.textSecondary,
                          height: 1.8,
                        ),
                      ),
                    ],

                    if (notification.relativeTime.isNotEmpty) ...<Widget>[
                      SizedBox(height: 8.h),
                      Row(
                        textDirection: TextDirection.rtl,
                        children: <Widget>[
                          Icon(
                            Icons.schedule_rounded,
                            size: 13.sp,
                            color: AppColors.placeholder,
                          ),
                          SizedBox(width: 5.w),
                          Flexible(
                            child: Text(
                              notification.relativeTime,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: 'bshabnam',
                                fontSize: 11.sp,
                                color: AppColors.placeholder,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
