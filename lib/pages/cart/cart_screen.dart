import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_format.dart';
import '../../models/cart_item.dart';
import '../../repositories/catalog_repository.dart';
import '../../repositories/support_repository.dart';

/// «سبد خرید» — the courses whose enrollment request is still waiting.
///
/// A paid registration never charges anything in this app: it creates an order
/// (which is what shows up in «سفارش ها»), files a support ticket on the user's
/// behalf, and parks the course here. So a cart row is not a basket waiting for a
/// checkout button, it is **a request waiting for an admin** — the screen says so,
/// and there is deliberately no "pay" action.
///
/// Everything on this screen comes from `GET v1/payments/cart/`. Nothing is
/// mirrored on the device: the app never activates a course by itself, and the
/// user must see exactly what the backend holds.
///
/// A course that has become an enrollment (the order was settled) is filtered
/// out — at that point it belongs to «دوره‌های من», not here.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<CartItem> _items = const <CartItem>[];

  bool _loading = true;

  /// Removals in flight, keyed by course id, so the row can show a spinner and
  /// cannot be tapped twice.
  final Set<int> _removing = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<CartItem> remote = const <CartItem>[];
    Set<int> enrolled = <int>{};

    try {
      final cart = await ShopRepository.instance.fetchCart();
      remote = cart.items;
    } catch (error) {
      debugPrint('[Cart] remote fetch failed: $error');
    }

    try {
      // `my_courses/`, not `enrollments/`: the latter is declared in the OpenAPI
      // schema but the live server answers `404 یافت نشد.` for it.
      final myCourses = await CatalogRepository.instance.fetchMyCourses();
      enrolled = myCourses.map((course) => course.id).toSet();
    } catch (error) {
      debugPrint('[Cart] enrollment check failed: $error');
    }

    if (!mounted) return;

    setState(() {
      _items = remote
          .where((item) => !enrolled.contains(item.courseId))
          .toList(growable: false);
      _loading = false;
    });
  }

  Future<void> _remove(CartItem item) async {
    if (_removing.contains(item.courseId)) return;

    setState(() => _removing.add(item.courseId));

    // There is no local copy to fall back on, so a failed delete must leave the
    // row on screen rather than pretend it worked and have it reappear on the
    // next load.
    try {
      if (item.id > 0) {
        await ShopRepository.instance.removeCartItem(item.id);
      }
    } catch (error) {
      debugPrint('[Cart] remote remove failed: $error');

      if (!mounted) return;
      setState(() => _removing.remove(item.courseId));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16.w),
          backgroundColor: AppColors.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
          content: Text(
            'حذف از سبد خرید ناموفق بود. دوباره تلاش کنید.',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'BShabnam',
              fontSize: 13.sp,
              color: Colors.white,
            ),
          ),
        ),
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _removing.remove(item.courseId);
      _items = _items
          .where((row) => row.courseId != item.courseId)
          .toList(growable: false);
    });
  }

  int get _total => _items.fold<int>(0, (sum, item) => sum + item.lineTotal);

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
                  : _items.isEmpty
                  ? _EmptyCart(onGoToCourses: () => AppRouter.toCourses(context))
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(25.w, 18.h, 25.w, 30.h),
                        children: [
                          _buildPendingNotice(),
                          SizedBox(height: 16.h),
                          ..._items.map(
                            (item) => Padding(
                              padding: EdgeInsets.only(bottom: 12.h),
                              child: _CartRow(
                                item: item,
                                isRemoving: _removing.contains(item.courseId),
                                onRemove: () => _remove(item),
                              ),
                            ),
                          ),
                          SizedBox(height: 6.h),
                          _buildSummary(),
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
            'سبد خرید',
            style: TextStyle(
              fontFamily: 'pinarb',
              fontSize: 18.sp,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// Explains why the rows are sitting here instead of being paid for.
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
              'این دوره‌ها در انتظار تأیید پرداخت هستند. پس از تأیید سفارش، به «دوره‌های من» در پروفایل شما اضافه می‌شوند.',
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

  Widget _buildSummary() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        textDirection: TextDirection.rtl,
        children: [
          Text(
            'جمع مبلغ دوره‌ها',
            style: TextStyle(
              fontFamily: 'bshabnam',
              fontSize: 13.sp,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            formatToman(_total),
            style: TextStyle(
              fontFamily: 'bshabnam',
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// `formatToman` lives in `core/utils/currency_format.dart` — the cart, the
// orders screens and the checkout dialog all render amounts the same way.

// ============================================================================
// ROW
// ============================================================================

class _CartRow extends StatelessWidget {
  final CartItem item;
  final bool isRemoving;
  final VoidCallback onRemove;

  const _CartRow({
    required this.item,
    required this.isRemoving,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final course = item.course;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14.r),
            child: SizedBox(
              width: 82.w,
              height: 82.w,
              child: course == null
                  ? Container(
                      color: AppColors.background,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.menu_book_outlined,
                        size: 24.sp,
                        color: AppColors.textSecondary,
                      ),
                    )
                  : Image.network(
                      course.image,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppColors.background,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: 22.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
            ),
          ),

          SizedBox(width: 12.w),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course?.title ?? 'دوره #${item.courseId}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'bshabnam',
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),

                SizedBox(height: 6.h),

                _StatusChip(pending: true),

                SizedBox(height: 6.h),

                Text(
                  formatToman(item.lineTotal),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'bshabnam',
                    fontSize: 11.5.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(width: 6.w),

          isRemoving
              ? SizedBox(
                  width: 20.w,
                  height: 20.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : IconButton(
                  onPressed: onRemove,
                  splashRadius: 20.r,
                  tooltip: 'حذف از سبد خرید',
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 20.sp,
                    color: AppColors.error,
                  ),
                ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool pending;

  const _StatusChip({required this.pending});

  @override
  Widget build(BuildContext context) {
    final color = pending ? AppColors.premium : AppColors.success;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        pending ? 'در انتظار تأیید' : 'تأیید شده',
        style: TextStyle(
          fontFamily: 'bshabnam',
          fontSize: 10.5.sp,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY
// ============================================================================

class _EmptyCart extends StatelessWidget {
  final VoidCallback onGoToCourses;

  const _EmptyCart({required this.onGoToCourses});

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
                Icons.shopping_bag_outlined,
                size: 30.sp,
                color: AppColors.primary,
              ),
            ),

            SizedBox(height: 16.h),

            Text(
              'سبد خرید شما خالی است',
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
              'درخواست ثبت نام دوره‌های پولی تا تأیید مدیر اینجا نمایش داده می‌شود.',
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
