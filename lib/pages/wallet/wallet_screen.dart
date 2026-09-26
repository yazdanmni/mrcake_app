import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/network/remote_data.dart';
import '../../core/session/session_manager.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_feedback.dart';
import '../../repositories/wallet_repository.dart';
import '../../widgets/house_screen_header.dart';

/// «اعتبار شما» — the in-app credit screen.
///
/// ## What this screen is
///
/// There is **no wallet on this backend**: no balance field, no top-up endpoint,
/// no gateway that can settle one. What exists is the manual flow the app is
/// built around — a top-up request is a **support ticket**, and the ticket's
/// `status` is the request's state.
///
/// So this screen is the *user-facing* half of that: a line explaining what the
/// credit is for, an amount field with the house presets, and one button that
/// files the request automatically. Underneath, the requests the user has
/// already made, each showing whether it is still waiting or has been carried
/// out («شارژ انجام شده»).
///
/// ## Why the requests are not in «تیکت‌ها»
///
/// They are filtered out of the tickets screen by the same marker this screen
/// filters *for* ([WalletRepository.marker]), so bookkeeping never buries a real
/// support conversation.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _amountFocus = FocusNode();

  List<WalletRequest> _requests = const <WalletRequest>[];

  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!SessionManager.instance.isLoggedIn) {
      setState(() => _isLoading = false);
      return;
    }

    final result = await RemoteLoader.list<WalletRequest>(
      label: 'wallet.requests',
      fetch: () => WalletRepository.instance.fetchRequests(),
    );

    if (!mounted) return;

    setState(() {
      _requests = result.data;
      _isLoading = false;
    });
  }

  /// Reads the field as an integer, tolerating Persian digits, separators and
  /// the «تومان» suffix a user might paste in.
  int? get _amount {
    final String raw = _amountController.text.trim();

    if (raw.isEmpty) return null;

    final String digits = _normalize(raw);
    final int? value = int.tryParse(digits);

    if (value == null || value <= 0) return null;
    return value;
  }

  static String _normalize(String value) {
    const String persian = '۰۱۲۳۴۵۶۷۸۹';
    const String arabic = '٠١٢٣٤٥٦٧٨٩';
    const String english = '0123456789';

    String out = value;

    for (int i = 0; i < persian.length; i++) {
      out = out.replaceAll(persian[i], english[i]);
    }
    for (int i = 0; i < arabic.length; i++) {
      out = out.replaceAll(arabic[i], english[i]);
    }

    return out.replaceAll(RegExp(r'[^0-9]'), '');
  }

  void _pickQuickAmount(int amount) {
    setState(() => _amountController.text = '$amount');
    _amountFocus.unfocus();
  }

  Future<void> _submit() async {
    final int? amount = _amount;

    if (amount == null) {
      AppFeedback.error(context, 'مبلغ شارژ را وارد کنید.');
      return;
    }

    if (amount < WalletRepository.minAmount) {
      AppFeedback.error(
        context,
        'حداقل مبلغ شارژ ${_toman(WalletRepository.minAmount)} است.',
      );
      return;
    }

    setState(() => _isSending = true);

    final user = SessionManager.instance.user;

    final int? ticketId = await WalletRepository.instance.requestTopUp(
      amount: amount,
      fullName: user == null
          ? ''
          : '${user.firstName} ${user.lastName}'.trim(),
      phone: user?.phoneNumber ?? '',
    );

    if (!mounted) return;

    setState(() => _isSending = false);

    if (ticketId == null) {
      AppFeedback.error(context, 'ثبت درخواست شارژ ناموفق بود. دوباره تلاش کنید.');
      return;
    }

    _amountController.clear();
    _amountFocus.unfocus();

    AppFeedback.success(
      context,
      'درخواست شارژ ثبت شد. پس از بررسی، اعتبار به حساب شما اضافه می‌شود.',
    );

    await _load();
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
              const HouseScreenHeader(title: 'اعتبار شما'),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.only(bottom: 40.h),
                    children: <Widget>[
                      _IntroCard(),
                      SizedBox(height: 22.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 25.w),
                        child: HouseSectionPill(title: 'شارژ حساب'),
                      ),
                      SizedBox(height: 12.h),
                      _AmountField(
                        controller: _amountController,
                        focusNode: _amountFocus,
                        onChanged: () => setState(() {}),
                      ),
                      SizedBox(height: 12.h),
                      _QuickAmounts(onPick: _pickQuickAmount),
                      SizedBox(height: 18.h),
                      _SubmitButton(
                        enabled: !_isSending,
                        isSending: _isSending,
                        onTap: _submit,
                      ),
                      SizedBox(height: 30.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 25.w),
                        child: HouseSectionPill(
                          title: 'درخواست های من',
                          trailing: _requests.isEmpty
                              ? null
                              : '${_requests.length} درخواست',
                        ),
                      ),
                      SizedBox(height: 12.h),
                      _RequestsSection(
                        isLoading: _isLoading,
                        requests: _requests,
                        isLoggedIn: SessionManager.instance.isLoggedIn,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _toman(int value) {
    final String digits = value.abs().toString();
    final StringBuffer buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('٬');
      buffer.write(_toPersianDigit(digits[i]));
    }

    return '$buffer تومان';
  }

  static String _toPersianDigit(String digit) {
    const List<String> persian = <String>[
      '۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹',
    ];
    final int index = int.tryParse(digit) ?? -1;
    return index >= 0 ? persian[index] : digit;
  }
}

// ============================================================================
// INTRO
// ============================================================================

/// The explanation: what the credit is, and how the top-up works.
class _IntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(25.w, 6.h, 25.w, 0),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.premium, width: 1.5.w),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              textDirection: TextDirection.rtl,
              children: <Widget>[
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: AppColors.premium.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppColors.premium, width: 1.w),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 24.sp,
                    color: AppColors.premium,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    'اعتبار حساب',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'pinarb',
                      fontSize: 17.sp,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            Text(
              'با شارژ اعتبار حساب می‌توانید دوره‌ها را بدون پرداخت مستقیم '
              'تهیه کنید. مبلغ مورد نظر را وارد کنید تا درخواست شارژ به صورت '
              'خودکار برای پشتیبانی ارسال شود؛ پس از تأیید، مبلغ به اعتبار '
              'شما اضافه می‌شود.',
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'bshabnam',
                fontSize: 13.sp,
                color: AppColors.textSecondary,
                height: 1.9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// AMOUNT
// ============================================================================

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w),
      child: Container(
        height: 58.h,
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppColors.premium, width: 1.5.w),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: <Widget>[
            SizedBox(width: 14.w),
            Icon(
              Icons.payments_outlined,
              size: 22.sp,
              color: AppColors.premium,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: (_) => onChanged(),
                keyboardType: TextInputType.number,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                style: TextStyle(
                  fontFamily: 'bshabnam',
                  fontSize: 16.sp,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'مبلغ شارژ (تومان)',
                  hintStyle: TextStyle(
                    fontFamily: 'bshabnam',
                    fontSize: 14.sp,
                    color: AppColors.placeholder,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: Text(
                'تومان',
                style: TextStyle(
                  fontFamily: 'bshabnam',
                  fontSize: 13.sp,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAmounts extends StatelessWidget {
  const _QuickAmounts({required this.onPick});

  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w),
      child: Row(
        textDirection: TextDirection.rtl,
        children: <Widget>[
          for (final int amount in WalletRepository.quickAmounts) ...<Widget>[
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onPick(amount),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  decoration: BoxDecoration(
                    color: AppColors.premium.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: AppColors.premium.withValues(alpha: 0.6),
                      width: 1.w,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _short(amount),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontFamily: 'bshabnam',
                      fontSize: 12.sp,
                      color: AppColors.textPrimary,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
            if (amount != WalletRepository.quickAmounts.last) SizedBox(width: 8.w),
          ],
        ],
      ),
    );
  }

  /// `100000` -> `۱۰۰ هزار`, so four presets fit on one row even at 360 px.
  static String _short(int amount) {
    if (amount % 1000 != 0) return '$amount';

    final int thousands = amount ~/ 1000;

    const List<String> persian = <String>[
      '۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹',
    ];

    final String digits = thousands
        .toString()
        .split('')
        .map((String d) {
          final int index = int.tryParse(d) ?? -1;
          return index >= 0 ? persian[index] : d;
        })
        .join();

    return '$digits هزار';
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.enabled,
    required this.isSending,
    required this.onTap,
  });

  final bool enabled;
  final bool isSending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          height: 54.h,
          decoration: BoxDecoration(
            color: enabled
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14.r),
          ),
          alignment: Alignment.center,
          child: isSending
              ? SizedBox(
                  width: 22.w,
                  height: 22.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2.w,
                    color: AppColors.white,
                  ),
                )
              : Text(
                  'ارسال درخواست شارژ',
                  style: TextStyle(
                    fontFamily: 'bshabnam',
                    fontSize: 17.sp,
                    color: AppColors.white,
                    height: 1.2,
                  ),
                ),
        ),
      ),
    );
  }
}

// ============================================================================
// REQUESTS
// ============================================================================

class _RequestsSection extends StatelessWidget {
  const _RequestsSection({
    required this.isLoading,
    required this.requests,
    required this.isLoggedIn,
  });

  final bool isLoading;
  final List<WalletRequest> requests;
  final bool isLoggedIn;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 40.h),
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
      );
    }

    if (requests.isEmpty) {
      return HouseEmptyState(
        icon: Icons.receipt_long_outlined,
        message: isLoggedIn
            ? 'هنوز درخواست شارژی ثبت نکرده‌اید.\nپس از ثبت، وضعیت آن همین‌جا نمایش داده می‌شود.'
            : 'برای ثبت درخواست شارژ ابتدا وارد حساب خود شوید.',
      );
    }

    return Column(
      children: <Widget>[
        for (int index = 0; index < requests.length; index++)
          Padding(
            padding: EdgeInsets.only(
              left: 25.w,
              right: 25.w,
              bottom: index == requests.length - 1 ? 0 : 10.h,
            ),
            child: _RequestCard(request: requests[index]),
          ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final WalletRequest request;

  @override
  Widget build(BuildContext context) {
    final bool done = request.isCompleted;

    final Color accent = done ? AppColors.success : AppColors.premium;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: accent, width: 1.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            textDirection: TextDirection.rtl,
            children: <Widget>[
              Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: accent, width: 1.w),
                ),
                alignment: Alignment.center,
                child: Icon(
                  done
                      ? Icons.check_circle_outline_rounded
                      : Icons.hourglass_top_rounded,
                  size: 20.sp,
                  color: accent,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      request.displayTitle.isEmpty
                          ? 'درخواست شارژ اعتبار'
                          : request.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'bshabnam',
                        fontSize: 14.sp,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      textDirection: TextDirection.rtl,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            'کد درخواست: ${_toPersian(request.ticketId.toString())}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontFamily: 'bshabnam',
                              fontSize: 11.5.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (request.amount != null) ...<Widget>[
                          SizedBox(width: 10.w),
                          Flexible(
                            child: Text(
                              _toman(request.amount!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                fontFamily: 'bshabnam',
                                fontSize: 11.5.sp,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 12.h),

          // One sentence the user can act on: waiting, or done.
          Text(
            done
                ? 'شارژ انجام شده است.'
                : 'درخواست شما ثبت شده و در انتظار بررسی است.',
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'bshabnam',
              fontSize: 13.sp,
              color: done ? AppColors.success : AppColors.textSecondary,
              height: 1.7,
            ),
          ),

          SizedBox(height: 10.h),

          Row(
            textDirection: TextDirection.rtl,
            children: <Widget>[
              _StatusChip(label: request.statusLabel, color: accent),
            ],
          ),
        ],
      ),
    );
  }

  static String _toman(int value) {
    final String digits = value.abs().toString();
    final StringBuffer buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('٬');
      buffer.write(_toPersian(digits[i]));
    }

    return '$buffer تومان';
  }

  static String _toPersian(String value) {
    const String english = '0123456789';
    const String persian = '۰۱۲۳۴۵۶۷۸۹';

    String out = value;

    for (int i = 0; i < english.length; i++) {
      out = out.replaceAll(english[i], persian[i]);
    }

    return out;
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color, width: 1.w),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'bshabnam',
          fontSize: 11.5.sp,
          color: color,
          height: 1.2,
        ),
      ),
    );
  }
}
