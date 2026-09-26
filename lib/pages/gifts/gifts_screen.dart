import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/network/remote_data.dart';
import '../../core/session/session_manager.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_feedback.dart';
import '../../models/course.dart';
import '../../models/gift.dart';
import '../../repositories/catalog_repository.dart';
import '../../repositories/support_repository.dart';
import '../../widgets/house_screen_header.dart';

/// «هدیه‌ها» — the discount codes that belong to this user.
///
/// ## Where they come from
///
/// `GET /api/v1/discounts/apply/my_coupons/`. That endpoint answers the app's
/// envelope with a **bare list** (`{"success": true, "data": []}`), so the
/// repository reads it as a list — never through `PagedResult`, which would turn
/// an empty body into one blank card.
///
/// ## What the screen shows
///
/// The *benefit*, not the record: the headline is what the code is worth
/// (`۲۰٪` or `۵۰٬۰۰۰ تومان`), then the code itself, then **which course it is
/// for and until when it is valid**, then its other conditions. A code stays
/// visible once it is spent or expired — hiding it would make a gift the user
/// was given simply vanish — but it is greyed and marked, so the difference
/// between "usable" and "used" is never ambiguous.
class GiftsScreen extends StatefulWidget {
  const GiftsScreen({super.key});

  @override
  State<GiftsScreen> createState() => _GiftsScreenState();
}

class _GiftsScreenState extends State<GiftsScreen> {
  List<Gift> _gifts = const <Gift>[];

  /// Course id -> title, so a `specific_courses` id can be printed by name.
  ///
  /// A coupon carries only ids. The catalogue is fetched once for the whole
  /// screen (cached and public) instead of once per coupon, and a failure
  /// degrades to a neutral «دوره‌های منتخب» rather than breaking the list.
  Map<int, String> _courseNames = const <int, String>{};

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

    final result = await RemoteLoader.list<Gift>(
      label: 'gifts.mine',
      fetch: () => ShopGiftRepository.instance.fetchMyGifts(),
    );

    final Map<int, String> names = await _resolveCourseNames(result.data);

    if (!mounted) return;

    setState(() {
      _gifts = result.data;
      _courseNames = names;
      _isLoading = false;
    });
  }

  /// Names the courses the loaded coupons point at.
  ///
  /// Only the ids actually referenced are looked up, and every failure path
  /// returns an empty map: the card then says «دوره‌های منتخب» instead of a
  /// number, which is honest and still readable.
  Future<Map<int, String>> _resolveCourseNames(List<Gift> gifts) async {
    final Set<int> ids = <int>{
      for (final Gift gift in gifts) ...gift.specificCourses,
    };

    if (ids.isEmpty) return const <int, String>{};

    try {
      final List<Course> courses =
          await CatalogRepository.instance.fetchGiftCatalogue();

      return <int, String>{
        for (final Course course in courses)
          if (ids.contains(course.id)) course.id: course.title,
      };
    } catch (_) {
      return const <int, String>{};
    }
  }

  /// `(course label, validity label)` for one card, already formatted.
  ({String course, String validity}) _labelsFor(Gift gift) {
    // ── which course ───────────────────────────────────────────────────────
    final String course;
    if (gift.specificCourses.isEmpty) {
      course = gift.specificCategories.isNotEmpty
          ? 'دوره‌های دسته‌بندی مشخص'
          : 'همه دوره‌ها';
    } else if (gift.specificCourses.length == 1) {
      final int id = gift.specificCourses.first;
      course = _courseNames[id] ?? 'دوره شماره ${_fa(id)}';
    } else {
      // Name what can be named and count the rest.
      final List<String> known = <String>[
        for (final int id in gift.specificCourses)
          if (_courseNames[id] != null) _courseNames[id]!,
      ];
      course = known.isEmpty
          ? '${_fa(gift.specificCourses.length)} دوره مشخص'
          : '${known.first} و ${_fa(gift.specificCourses.length - 1)} دوره دیگر';
    }

    // ── until when ─────────────────────────────────────────────────────────
    final String validity;
    final DateTime? end = gift.validUntil;
    if (end == null) {
      validity = gift.isExpired ? 'منقضی شده' : 'بدون محدودیت زمانی';
    } else {
      final String date = _faDate(end);
      if (gift.isExpired) {
        validity = 'مهلت استفاده تا $date (گذشته)';
      } else {
        final Duration? left = gift.timeLeft;
        final String remaining = left == null || left.inDays <= 0
            ? 'امروز آخرین روز'
            : '${_fa(left.inDays)} روز مانده';
        validity = 'اعتبار تا $date ($remaining)';
      }
    }

    return (course: course, validity: validity);
  }

  List<Gift> get _usable =>
      _gifts.where((Gift gift) => gift.isUsable).toList(growable: false);

  List<Gift> get _inactive =>
      _gifts.where((Gift gift) => !gift.isUsable).toList(growable: false);

  Future<void> _copy(Gift gift) async {
    if (gift.code.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: gift.code));

    if (!mounted) return;
    AppFeedback.success(context, 'کد ${gift.code} کپی شد.');
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
                title: 'هدیه‌ها',
                subtitle: _gifts.isEmpty
                    ? null
                    : 'کدهای تخفیف مخصوص حساب شما',
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

    if (_gifts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          HouseEmptyState(
            icon: Icons.card_giftcard_outlined,
            message: SessionManager.instance.isLoggedIn
                ? 'در حال حاضر کد تخفیفی برای حساب شما ثبت نشده است.\n'
                      'هدیه‌های شما پس از ثبت، همین‌جا نمایش داده می‌شوند.'
                : 'برای دیدن کدهای تخفیف خود ابتدا وارد حساب شوید.',
          ),
        ],
      );
    }

    final List<Gift> usable = _usable;
    final List<Gift> inactive = _inactive;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.only(bottom: 40.h),
      children: <Widget>[
        SizedBox(height: 6.h),

        if (usable.isNotEmpty) ...<Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 25.w),
            child: HouseSectionPill(
              title: 'قابل استفاده',
              trailing: '${usable.length} کد',
            ),
          ),
          SizedBox(height: 12.h),
          for (final Gift gift in usable)
            Padding(
              padding: EdgeInsets.fromLTRB(25.w, 0, 25.w, 12.h),
              child: _GiftCard(
                gift: gift,
                labels: _labelsFor(gift),
                onCopy: () => _copy(gift),
              ),
            ),
        ],

        if (inactive.isNotEmpty) ...<Widget>[
          if (usable.isNotEmpty) SizedBox(height: 12.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 25.w),
            child: HouseSectionPill(
              title: 'استفاده شده',
              trailing: '${inactive.length} کد',
            ),
          ),
          SizedBox(height: 12.h),
          for (final Gift gift in inactive)
            Padding(
              padding: EdgeInsets.fromLTRB(25.w, 0, 25.w, 12.h),
              child: _GiftCard(
                gift: gift,
                labels: _labelsFor(gift),
                onCopy: () => _copy(gift),
              ),
            ),
        ],
      ],
    );
  }
}

/// `7` -> `۷`. Shared by every figure the gift cards print.
String _fa(int value) => value
    .toString()
    .split('')
    .map((String d) {
      final int index = int.tryParse(d) ?? -1;
      return index >= 0 ? _persianDigits[index] : d;
    })
    .join();

/// `2026-10-04` -> `۱۴۰۵/۰۷/۱۲`, so a validity date reads the way the rest of
/// the app's numbers do. Gregorian, because that is what the backend sends.
String _faDate(DateTime date) =>
    '${_fa(date.year)}/${_fa(date.month)}/${_fa(date.day)}';

const List<String> _persianDigits = <String>[
  '۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹',
];

// ============================================================================
// GIFT CARD
// ============================================================================

class _GiftCard extends StatelessWidget {
  const _GiftCard({
    required this.gift,
    required this.labels,
    required this.onCopy,
  });

  final Gift gift;

  /// The two facts the coupon cannot be trusted to render itself: the course it
  /// is for, and until when it is valid. Pre-formatted by the screen so the card
  /// stays dumb.
  final ({String course, String validity}) labels;

  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final bool active = gift.isUsable;

    final Color accent = active ? AppColors.premium : AppColors.placeholder;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: accent, width: active ? 1.5.w : 1.w),
      ),
      child: Column(
        children: <Widget>[
          // ── the value ───────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 12.h),
            child: Row(
              textDirection: TextDirection.rtl,
              children: <Widget>[
                Container(
                  width: 52.w,
                  height: 52.w,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: accent, width: 1.w),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    active
                        ? Icons.card_giftcard_rounded
                        : Icons.card_giftcard_outlined,
                    size: 26.sp,
                    color: accent,
                  ),
                ),

                SizedBox(width: 12.w),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        gift.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: 'bshabnam',
                          fontSize: 15.sp,
                          color: active
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '${gift.benefitLabel} — ${gift.benefitDescription}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: 'bshabnam',
                          fontSize: 13.sp,
                          color: active
                              ? AppColors.premium
                              : AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                if (!active) ...<Widget>[
                  SizedBox(width: 8.w),
                  _StatusChip(
                    label: gift.isExpired
                        ? 'منقضی'
                        : (gift.isExhausted ? 'استفاده شده' : 'غیرفعال'),
                  ),
                ],
              ],
            ),
          ),

          // ── the code ────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: DottedDivider(color: accent.withValues(alpha: 0.55)),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 14.h),
            child: Row(
              textDirection: TextDirection.rtl,
              children: <Widget>[
                Expanded(
                  child: Container(
                    height: 46.h,
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.6),
                        width: 1.w,
                      ),
                    ),
                    alignment: Alignment.centerRight,
                    child: Text(
                      gift.code.isEmpty ? '—' : gift.code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontFamily: 'bshabnam',
                        fontSize: 15.sp,
                        letterSpacing: 1.2.w,
                        color: active
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        height: 1,
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 10.w),

                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: active ? onCopy : null,
                  child: Container(
                    height: 46.h,
                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.primary
                          : AppColors.placeholder.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      textDirection: TextDirection.rtl,
                      children: <Widget>[
                        Icon(
                          Icons.copy_rounded,
                          size: 16.sp,
                          color: AppColors.white,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          'کپی',
                          style: TextStyle(
                            fontFamily: 'bshabnam',
                            fontSize: 13.sp,
                            color: AppColors.white,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── conditions ──────────────────────────────────────────────────
          if (gift.conditions.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
              child: Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.start,
                  textDirection: TextDirection.rtl,
                  spacing: 6.w,
                  runSpacing: 6.h,
                  children: <Widget>[
                    for (final String condition in gift.conditions)
                      _ConditionChip(
                        label: condition,
                        active: active,
                      ),
                  ],
                ),
              ),
            ),

          // ── which course, and until when ─────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
            child: Column(
              children: <Widget>[
                _GiftFact(
                  icon: Icons.school_outlined,
                  label: 'دوره',
                  value: labels.course,
                  active: active,
                ),
                SizedBox(height: 8.h),
                _GiftFact(
                  icon: Icons.event_available_outlined,
                  label: 'اعتبار',
                  value: labels.validity,
                  active: active && !gift.isExpired,
                  urgent: active && gift.isExpiringWithinAnHour,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One labelled fact line on a gift card — «دوره: …», «اعتبار: …».
///
/// ⚠️ These are stacked vertically (label above value), **not** laid out as one
/// `Row`. `'$label:'` is resolved into **two text runs** in this RTL app — the
/// label and the colon — and the run holding the colon cannot be shrunk by a
/// `Flexible`, so a `Row` overflows on wide screens, where `.sp` (which tracks
/// `scaleWidth`) makes the label far larger than its `.h` reservation. Values
/// also routinely wrap («اعتبار تا ۲۰۲۶/۱۰/۴ (۳ روز مانده)»), which a single line
/// cannot hold at any size.
class _GiftFact extends StatelessWidget {
  const _GiftFact({
    required this.icon,
    required this.label,
    required this.value,
    required this.active,
    this.urgent = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool active;

  /// The value is inside its final hour — it is tinted like an alert.
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final Color color = urgent
        ? AppColors.error
        : (active ? AppColors.textSecondary : AppColors.placeholder);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: (urgent ? AppColors.error : color).withValues(alpha: 0.5),
          width: 1.w,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            textDirection: TextDirection.rtl,
            children: <Widget>[
              Icon(icon, size: 15.sp, color: color),
              SizedBox(width: 7.w),
              // `Expanded` + ellipsis: the label is bounded by the row, so it can
              // never grow the row, whatever the screen width.
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'bshabnam',
                    fontSize: 11.5.sp,
                    color: color,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 5.h),
          // Free to wrap onto as many lines as it needs, so a long course title
          // or a date with its remaining time is never clipped away.
          Text(
            value,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'bshabnam',
              fontSize: 12.sp,
              color: urgent ? AppColors.error : AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConditionChip extends StatelessWidget {
  const _ConditionChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final Color color = active ? AppColors.textSecondary : AppColors.placeholder;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.w),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: 'bshabnam',
          fontSize: 11.sp,
          color: color,
          height: 1.2,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.5),
          width: 1.w,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'bshabnam',
          fontSize: 11.sp,
          color: AppColors.error,
          height: 1.2,
        ),
      ),
    );
  }
}

/// A row of dashes — the perforation a paper voucher has.
///
/// ⚠️ The dash count is derived from the **scaled** dash width, not from the raw
/// `maxWidth`. The two live in different units in this project (`.w`/`.sp` track
/// `scaleWidth`, which is > 1 on a wide screen), so a count computed from raw
/// pixels and then painted with `.w`-sized dashes overflows by a margin that
/// grows with the screen — measured at 51px on a 768-wide iPad and 370px at
/// 1024×768. A `Wrap` would also avoid the arithmetic, but the divider is
/// deliberately one line.
class DottedDivider extends StatelessWidget {
  const DottedDivider({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Painted size, in the same units the layout is measured in.
        final double dashWidth = 5.w;
        final double gap = 4.w;

        final int count = (constraints.maxWidth / (dashWidth + gap))
            .floor()
            .clamp(1, 200);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            for (int i = 0; i < count; i++)
              Container(
                width: dashWidth,
                height: 1.w,
                color: color,
              ),
          ],
        );
      },
    );
  }
}
