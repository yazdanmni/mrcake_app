import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/network/remote_data.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_format.dart';
import '../../core/utils/persian_date.dart';
import '../../models/course_order.dart';
import '../../repositories/support_repository.dart';
import 'order_details_screen.dart';
import 'widgets/order_status_chip.dart';

/// «سفارش های من» — every order the backend holds for this user.
///
/// This is where a paid registration actually lives. Registering for a paid
/// course creates an order with status `pending` (plus a support ticket and a
/// cart row); an admin approving it marks the order `paid`, and only then does
/// the backend create the enrollment that shows up in «دوره‌های من». Nothing is
/// activated on the device, so this screen is the honest source of truth for
/// "what did I ask for, and where is it?".
///
/// Read straight from `GET v1/payments/orders/` — no local mirror, no cache: an
/// order's status changes the moment it is approved, and a stale
/// «در انتظار پرداخت» would hide a course the user already owns.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<CourseOrder> _orders = const <CourseOrder>[];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    final result = await RemoteLoader.list<CourseOrder>(
      label: 'profile.orders',
      fetch: () => ShopRepository.instance.fetchOrderSummaries(),
      refresh: refresh,
    );

    if (!mounted) return;

    setState(() {
      _orders = result.data;
      _loading = false;
    });
  }

  Future<void> _openOrder(CourseOrder order) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OrderDetailsScreen(order: order),
      ),
    );

    // The status may have moved on while the user was reading the detail.
    if (!mounted) return;
    await _load(refresh: true);
  }

  bool get _hasPending => _orders.any((order) => order.isPending);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _loading
                  ? Center(
                      child: SizedBox(
                        width: 26.w,
                        height: 26.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : _orders.isEmpty
                  ? _EmptyOrders(
                      onGoToCourses: () => AppRouter.toCourses(context),
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () => _load(refresh: true),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(25.w, 18.h, 25.w, 30.h),
                        children: [
                          if (_hasPending) ...[
                            _buildPendingNotice(),
                            SizedBox(height: 16.h),
                          ],
                          ..._orders.map(
                            (order) => Padding(
                              padding: EdgeInsets.only(bottom: 12.h),
                              child: _OrderCard(
                                order: order,
                                onTap: () => _openOrder(order),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      margin: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      height: 58.h,
      decoration: BoxDecoration(
        color: AppColors.sectionBackground,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            splashRadius: 22.r,
            icon: Icon(
              Icons.arrow_back_ios_rounded,
              size: 19.sp,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(width: 4.w),
          Text(
            'سفارش های من',
            style: TextStyle(
              fontFamily: 'pinarb',
              fontSize: 18.sp,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => _load(refresh: true),
            splashRadius: 22.r,
            tooltip: 'به‌روزرسانی',
            icon: Icon(
              Icons.refresh_rounded,
              size: 21.sp,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  /// Explains why a `pending` order is not a course yet.
  Widget _buildPendingNotice() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1.w,
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.hourglass_top_rounded,
            size: 19.sp,
            color: AppColors.primary,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'سفارش‌های «در انتظار پرداخت» پس از تأیید مدیر به «پرداخت شده» تغییر می‌کنند و دوره بلافاصله به «دوره‌های من» در پروفایل شما اضافه می‌شود.',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'bshabnam',
                fontSize: 12.5.sp,
                height: 1.8,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ORDER CARD
// ============================================================================

class _OrderCard extends StatelessWidget {
  final CourseOrder order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: AppColors.field,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------------------------------------------------------------
              // NUMBER + STATUS
              // ---------------------------------------------------------------
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  Expanded(
                    child: Text(
                      order.orderNumber.isEmpty
                          ? 'سفارش #${order.id}'
                          : 'سفارش ${order.orderNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'bshabnam',
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  OrderStatusChip(status: order.status),
                ],
              ),

              SizedBox(height: 8.h),

              Text(
                'تاریخ ثبت: ${PersianDate.formatOrDash(order.createdAt, withTime: true)}',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'bshabnam',
                  fontSize: 11.5.sp,
                  color: AppColors.textSecondary,
                ),
              ),

              SizedBox(height: 12.h),

              Divider(height: 1, color: AppColors.border),

              SizedBox(height: 12.h),

              // ---------------------------------------------------------------
              // COURSES COUNT
              // ---------------------------------------------------------------
              _OrderMetaRow(
                label: 'تعداد دوره',
                value: order.itemsCount > 0
                    ? formatNumber(order.itemsCount)
                    : '—',
              ),

              SizedBox(height: 7.h),

              // ---------------------------------------------------------------
              // AMOUNT
              // ---------------------------------------------------------------
              _OrderMetaRow(
                label: order.isPaid ? 'مبلغ پرداخت شده' : 'مبلغ قابل پرداخت',
                value: formatToman(order.effectiveAmount),
                emphasize: true,
              ),

              if (order.discountAmount > 0) ...[
                SizedBox(height: 7.h),
                _OrderMetaRow(
                  label: 'تخفیف',
                  value: '- ${formatToman(order.discountAmount)}',
                  valueColor: AppColors.success,
                ),
              ],

              if (order.couponCode.isNotEmpty) ...[
                SizedBox(height: 7.h),
                _OrderMetaRow(
                  label: 'کد تخفیف',
                  value: order.couponCode,
                ),
              ],

              if (order.isPaid && order.paymentTime != null) ...[
                SizedBox(height: 7.h),
                _OrderMetaRow(
                  label: 'زمان پرداخت',
                  value: PersianDate.formatOrDash(order.paymentTime),
                ),
              ],

              SizedBox(height: 10.h),

              // ---------------------------------------------------------------
              // AFFORDANCE
              // ---------------------------------------------------------------
              Row(
                textDirection: TextDirection.rtl,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'مشاهده جزئیات',
                    style: TextStyle(
                      fontFamily: 'bshabnam',
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 12.sp,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderMetaRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;
  final Color? valueColor;

  const _OrderMetaRow({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: TextDirection.rtl,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'bshabnam',
            fontSize: 12.sp,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(width: 8.w),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'bshabnam',
              fontSize: emphasize ? 13.5.sp : 12.sp,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// EMPTY
// ============================================================================

class _EmptyOrders extends StatelessWidget {
  final VoidCallback onGoToCourses;

  const _EmptyOrders({required this.onGoToCourses});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.10),
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 30.sp,
                color: AppColors.primary,
              ),
            ),

            SizedBox(height: 16.h),

            Text(
              'هنوز سفارشی ندارید',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'bshabnam',
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),

            SizedBox(height: 8.h),

            Text(
              'با ثبت نام در یک دوره، سفارش شما اینجا نمایش داده می‌شود.',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'bshabnam',
                fontSize: 12.5.sp,
                height: 1.8,
                color: AppColors.textSecondary,
              ),
            ),

            SizedBox(height: 20.h),

            SizedBox(
              height: 46.h,
              child: ElevatedButton(
                onPressed: onGoToCourses,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: 22.w),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                child: Text(
                  'رفتن به دوره‌ها',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'bshabnam',
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
