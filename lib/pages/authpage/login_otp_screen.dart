import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/network/api_exception.dart';
import 'package:mr_cake_project/core/router/app_router.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/core/utils/app_feedback.dart';
import 'package:mr_cake_project/repositories/auth_repository.dart';
import 'package:otp_text_field/otp_field.dart';
import 'package:otp_text_field/otp_field_style.dart';
import 'package:otp_text_field/style.dart';

/// Second step: the one time password.
///
/// Screen -> Endpoint -> Model -> Repository
///   LoginOtpScreen -> POST v1/accounts/auth/verify-otp/ -> AuthSession
///                  -> POST v1/accounts/auth/send-otp/   -> bool (resend)
///                  -> AuthRepository
///
/// What happens after a successful verification depends on [purpose]:
///   * `registration`    -> CompleteProfileScreen   (first time user)
///   * `forgot_password` -> ChangePasswordScreen    (can be skipped)
///   * `login` / `auth`  -> MainBottomNavigation
class LoginOtpScreen extends StatefulWidget {
  const LoginOtpScreen({
    super.key,
    required this.phone,
    this.purpose = OtpPurpose.auth,
    this.otpAlreadySent = true,
  });

  final String phone;
  final OtpPurpose purpose;

  /// When true no SMS is sent on open because the caller already sent one.
  final bool otpAlreadySent;

  @override
  State<LoginOtpScreen> createState() => _LoginOtpScreenState();
}

class _LoginOtpScreenState extends State<LoginOtpScreen> {
  static const int _otpLength = 4;
  static const int _resendSeconds = 119;

  Timer? _timer;
  int _secondsRemaining = _resendSeconds;

  String _otpCode = '';
  Key _otpFieldKey = UniqueKey();

  bool _isVerifying = false;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    if (!widget.otpAlreadySent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_sendOtp(silent: true));
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Timer
  // ---------------------------------------------------------------------------

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _timerText {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get _maskedPhone {
    final phone = widget.phone;
    if (phone.length < 8) return phone;
    return '${phone.substring(0, 4)}*******${phone.substring(phone.length - 2)}';
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _resendCode() async {
    if (_secondsRemaining > 0 || _isResending) return;
    await _sendOtp(silent: false);
  }

  Future<void> _sendOtp({required bool silent}) async {
    if (!mounted) return;
    setState(() => _isResending = true);
    try {
      await AuthRepository.instance.sendOtp(
        phone: widget.phone,
        purpose: widget.purpose,
      );
      if (!mounted) return;

      setState(() {
        _secondsRemaining = _resendSeconds;
        _otpCode = '';
        _otpFieldKey = UniqueKey();
      });
      _startTimer();

      if (!silent) {
        AppFeedback.success(context, 'کد تایید دوباره ارسال شد.');
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, error.message);
    } catch (_) {
      if (!mounted) return;
      AppFeedback.error(context, 'ارسال کد ناموفق بود. لطفاً دوباره تلاش کنید.');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verify() async {
    if (_isVerifying) return;

    if (_otpCode.trim().length < _otpLength) {
      AppFeedback.error(context, 'کد تایید $_otpLength رقمی را وارد کنید.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isVerifying = true);

    try {
      final session = await AuthRepository.instance.verifyOtp(
        phone: widget.phone,
        otp: _otpCode.trim(),
        purpose: widget.purpose,
      );

      if (!mounted) return;

      // The backend normally returns a JWT here. If it does not, the user
      // still has to be able to continue, so we only branch on the purpose.
      switch (widget.purpose) {
        case OtpPurpose.registration:
          // First time user: finish the profile before entering the app.
          AppRouter.toCompleteProfile(context, replace: true);
        case OtpPurpose.forgotPassword:
        case OtpPurpose.passwordChange:
          // Verified: pick a new password (or skip it).
          AppRouter.toChangePassword(
            context,
            phone: widget.phone,
            otp: _otpCode.trim(),
            allowSkip: true,
            // The OTP is consumed, so the user must not be able to come back
            // to this screen and re-submit the same code.
            replace: true,
          );
        case OtpPurpose.login:
        case OtpPurpose.auth:
        case OtpPurpose.verify:
          if (session.hasToken) {
            AppRouter.toMain(context);
          } else {
            AppFeedback.error(
              context,
              'ورود انجام نشد. لطفاً دوباره تلاش کنید.',
            );
          }
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, error.message);

      if (error.isInvalidOtp) {
        setState(() {
          _otpCode = '';
          _otpFieldKey = UniqueKey();
        });
      }
    } catch (_) {
      if (!mounted) return;
      AppFeedback.error(
        context,
        'خطای غیرمنتظره‌ای رخ داد. لطفاً دوباره تلاش کنید.',
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _editPhone() {
    // Back to the login screen (the phone number stays in its field), skipping
    // any intermediate screen such as the password form.
    Navigator.of(context).popUntil(
      (route) => route.settings.name == AppRoutes.login || route.isFirst,
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            children: [
              Image.asset(
                'assets/images/welcomjavadimg.png',
                width: double.infinity,
                height: 410.h,
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  width: double.infinity,
                  height: 390.h,
                  decoration: BoxDecoration(
                    color: AppColors.sectionBackground,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24.r),
                      topRight: Radius.circular(24.r),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 25.w,
                        right: 25.w,
                        top: 23.h,
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              textDirection: TextDirection.rtl,
                              children: [
                                Text(
                                  'خوش اومدی',
                                  style: TextStyle(
                                    fontFamily: 'pinarb',
                                    fontSize: 20.sp,
                                    color: AppColors.textPrimary,
                                  ),
                                ),

                                SizedBox(width: 10.w),

                                Image.asset(
                                  'assets/images/welcomhand.png',
                                  width: 30.w,
                                  height: 30.h,
                                ),
                              ],
                            ),
                            Padding(
                              padding: EdgeInsets.only(top: 5.h),
                              child: Row(
                                textDirection: TextDirection.rtl,
                                children: [
                                  Text(
                                    'کد ارسال شده به شماره',
                                    style: TextStyle(
                                      fontFamily: 'shabnam',
                                      fontSize: 16.sp,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  SizedBox(width: 3.w),
                                  Text(
                                    _maskedPhone,
                                    style: TextStyle(
                                      fontFamily: 'bshabnam',
                                      fontSize: 16.sp,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  SizedBox(width: 3.w),
                                  Text(
                                    'را وارد کنید',
                                    style: TextStyle(
                                      fontFamily: 'shabnam',
                                      fontSize: 16.sp,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                GestureDetector(
                                  onTap: _isVerifying ? null : _editPhone,
                                  child: Text(
                                    'ویرایش؟',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontFamily: 'Shabnam',
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.premium,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 23.h),

                            Center(
                              child: OTPTextField(
                                key: _otpFieldKey,
                                length: _otpLength,
                                width: 270.w,
                                fieldWidth: 60.w,
                                spaceBetween: 10.w,

                                textFieldAlignment: MainAxisAlignment.center,

                                fieldStyle: FieldStyle.box,
                                outlineBorderRadius: 14.r,

                                keyboardType: TextInputType.number,
                                autofocus: true,

                                style: TextStyle(
                                  fontFamily: 'BShabnam',
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),

                                otpFieldStyle: OtpFieldStyle(
                                  backgroundColor: AppColors.field,
                                  borderColor: AppColors.border,
                                  focusBorderColor: AppColors.premium,
                                ),

                                onChanged: (value) {
                                  setState(() => _otpCode = value);
                                },

                                onCompleted: (pin) {
                                  setState(() => _otpCode = pin);
                                },
                              ),
                            ),
                            SizedBox(height: 10.h),

                            Center(
                              child: GestureDetector(
                                onTap: _secondsRemaining == 0 && !_isResending
                                    ? _resendCode
                                    : null,
                                child: _isResending
                                    ? SizedBox(
                                        width: 18.sp,
                                        height: 18.sp,
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                AppColors.premium,
                                              ),
                                        ),
                                      )
                                    : Text(
                                        _secondsRemaining == 0
                                            ? 'ارسال مجدد'
                                            : 'ارسال مجدد در $_timerText',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: 'BShabnam',
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.premium,
                                        ),
                                      ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(top: 25.h),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _isVerifying ? null : _verify,
                                child: Container(
                                  width: MediaQuery.sizeOf(context).width - 50.w,
                                  height: 64.h,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(16.r),
                                  ),
                                  child: Center(
                                    child: _isVerifying
                                        ? const InlineLoader()
                                        : Text(
                                            'ورود',
                                            style: TextStyle(
                                              color: AppColors.white,
                                              fontFamily: 'bshabnam',
                                              fontSize: 20.sp,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
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
}
