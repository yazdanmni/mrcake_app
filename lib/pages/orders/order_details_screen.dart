import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_format.dart';
import '../../core/utils/persian_date.dart';
import '../../models/course_order.dart';
import '../../repositories/support_repository.dart';
import 'widgets/order_status_chip.dart';

/// The detail of one order — `GET v1/payments/orders/{id}/`.
///
/// The list payload (`OrderList`) carries no `items[]`, so the course an order
/// was placed for can only be named here. [order] arrives as a seed from the
/// list screen and is replaced by the full payload as soon as it lands, which
/// means the header (number, status, amounts) is on screen immediately instead
/// of behind a spinner.
class OrderDetailsScreen extends StatefulWidget {
  final CourseOrder order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late CourseOrder _order;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _load();
  }

  Future<void> _load() async {
    try {
      final fresh = await ShopRepository.instance.fetchOrderDetails(_order.id);

      if (!mounted) return;

      if (fresh != null) {
        setState(() {
          _order = fresh;
          _loading = false;
        });
        return;
      }
    } catch (error) {
      debugPrint('[Orders] detail ${_order.id} failed: $error');
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(25.w, 18.h, 25.w, 30.h),
                  children: [
                    _buildStatusCard(),

                    if (_order.isPending) ...[
                      SizedBox(height: 16.h),
                      _buildPendingNotice(),
                    ],

                    SizedBox(height: 22.h),

                    _SectionTitle(
                      title: 'دوره‌های این سفارش',
                      trailing: _order.itemsCount > 0
                          ? formatNumber(_order.itemsCount)
                          : null,
                    ),

                    SizedBox(height: 10.h),

                    if (_loading && _order.items.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 22.h),
                        child: Center(
                          child: SizedBox(
                            width: 22.w,
                            height: 22.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      )
                    else if (_order.items.isEmpty)
                      _EmptyLines()
                    else
                      ..._order.items.map(
                        (line) => Padding(
                          padding: EdgeInsets.only(bottom: 10.h),
                          child: _OrderLineCard(line: line),
                        ),
                      ),

                    SizedBox(height: 22.h),

                    _SectionTitle(title: 'جزئیات پرداخت'),

                    SizedBox(height: 10.h),

                    _buildBreakdown(),
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
          Expanded(
            child: Text(
              'جزئیات سفارش',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'pinarb',
                fontSize: 18.sp,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Order number, status and the two timestamps that matter.
  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: Text(
                  _order.orderNumber.isEmpty
                      ? 'سفارش #${_order.id}'
                      : 'سفارش ${_order.orderNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'bshabnam',
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              OrderStatusChip(status: _order.status),
            ],
          ),

          SizedBox(height: 12.h),

          _DetailRow(
            label: 'تاریخ ثبت سفارش',
            value: PersianDate.formatOrDash(_order.createdAt, withTime: true),
          ),

          if (_order.paymentTime != null) ...[
            SizedBox(height: 7.h),
            _DetailRow(
              label: 'زمان پرداخت',
              value: PersianDate.formatOrDash(_order.paymentTime, withTime: true),
            ),
          ],

          if (_order.paymentGateway.isNotEmpty) ...[
            SizedBox(height: 7.h),
            _DetailRow(
              label: 'درگاه پرداخت',
              value: OrderGateway.label(_order.paymentGateway),
            ),
          ],
        ],
      ),
    );
  }

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
              'درخواست شما همراه با نام و شماره تماس‌تان برای بررسی ارسال شده است. پس از تأیید پرداخت این سفارش، دوره به «دوره‌های من» اضافه می‌شود.',
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

  Widget _buildBreakdown() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        children: [
          _DetailRow(
            label: 'جمع کل اقلام',
            value: formatToman(_order.subtotal),
          ),

          if (_order.discountAmount > 0) ...[
            SizedBox(height: 9.h),
            _DetailRow(
              label: 'مبلغ تخفیف',
              value: '- ${formatToman(_order.discountAmount)}',
              valueColor: AppColors.success,
            ),
          ],

          if (_order.taxAmount > 0) ...[
            SizedBox(height: 9.h),
            _DetailRow(
              label: 'مالیات',
              value: formatToman(_order.taxAmount),
            ),
          ],

          SizedBox(height: 11.h),
          Divider(height: 1, color: AppColors.border),
          SizedBox(height: 11.h),

          _DetailRow(
            label: 'مبلغ نهایی',
            value: formatToman(_order.totalAmount),
            emphasize: true,
          ),

          SizedBox(height: 9.h),

          _DetailRow(
            label: 'مبلغ پرداخت شده',
            value: formatToman(_order.paidAmount),
            valueColor: _order.isPaid ? AppColors.success : null,
          ),

          if (_order.couponCode.isNotEmpty) ...[
            SizedBox(height: 9.h),
            _DetailRow(label: 'کد تخفیف', value: _order.couponCode),
          ],

          if ((_order.description ?? '').isNotEmpty) ...[
            SizedBox(height: 11.h),
            Divider(height: 1, color: AppColors.border),
            SizedBox(height: 11.h),
            _DetailRow(label: 'توضیحات', value: _order.description!),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// PIECES
// ============================================================================

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;

  const _SectionTitle({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        Container(
          width: 4.w,
          height: 18.h,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          title,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: 'bshabnam',
            fontSize: 14.5.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          Text(
            trailing!,
            style: TextStyle(
              fontFamily: 'bshabnam',
              fontSize: 12.sp,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _OrderLineCard extends StatelessWidget {
  final CourseOrderLine line;

  const _OrderLineCard({required this.line});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.menu_book_outlined,
                size: 17.sp,
                color: AppColors.primary,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  line.courseTitle.isEmpty ? 'دوره' : line.courseTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'bshabnam',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    height: 1.6,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 9.h),

          _DetailRow(
            label: 'قیمت',
            value: formatToman(line.unitPrice),
          ),

          if (line.discountPerItem > 0) ...[
            SizedBox(height: 6.h),
            _DetailRow(
              label: 'تخفیف',
              value: '- ${formatToman(line.discountPerItem)}',
              valueColor: AppColors.success,
            ),
          ],

          if (line.quantity > 1) ...[
            SizedBox(height: 6.h),
            _DetailRow(
              label: 'تعداد',
              value: formatNumber(line.quantity),
            ),
          ],

          SizedBox(height: 6.h),

          _DetailRow(
            label: 'جمع این قلم',
            value: formatToman(line.lineTotal),
            emphasize: true,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'bshabnam',
            fontSize: 12.sp,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.left,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'bshabnam',
              fontSize: emphasize ? 13.5.sp : 12.sp,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              height: 1.6,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyLines extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 26.sp,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 10.h),
          Text(
            'اقلام این سفارش از سرور دریافت نشد.',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'bshabnam',
              fontSize: 12.5.sp,
              height: 1.8,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
