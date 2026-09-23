import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/network/api_exception.dart';
import 'package:mr_cake_project/core/router/app_router.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/core/utils/app_feedback.dart';
import 'package:mr_cake_project/core/utils/validators.dart';
import 'package:mr_cake_project/repositories/auth_repository.dart';

/// First step of the auth flow: the phone number.
///
/// Screen -> Endpoint -> Model -> Repository
///   LoginScreen -> POST v1/accounts/auth/send-otp/ -> AccountProbeResult
///               -> AuthRepository
///
/// Branching (exactly as requested):
///   * phone already registered  -> LoginPasswordScreen
///   * phone never seen before   -> LoginOtpScreen (registration purpose)
///   * "رد شدن"                  -> MainBottomNavigation (guest mode)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialPhone});

  /// Prefilled with the phone of the last successful sign-in.
  final String? initialPhone;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _phoneController;
  final FocusNode _phoneFocus = FocusNode();

  bool _isChecking = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(
      text: Validators.normalizePhone(widget.initialPhone ?? ''),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _onContinue() async {
    if (_isChecking) return;

    final phone = Validators.normalizePhone(_phoneController.text);
    final error = Validators.phone(phone);
    if (error != null) {
      setState(() => _hasError = true);
      AppFeedback.error(context, error);
      _phoneFocus.requestFocus();
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isChecking = true;
      _hasError = false;
    });

    try {
      final probe = await AuthRepository.instance.checkAccountExists(phone);
      if (!mounted) return;

      if (probe.exists) {
        // Returning user -> password screen.
        AppRouter.toPasswordScreen(context, phone: phone);
      } else {
        // First time on the app -> OTP screen, then complete profile.
        await AuthRepository.instance.sendOtp(
          phone: phone,
          purpose: OtpPurpose.registration,
        );
        if (!mounted) return;
        AppRouter.toOtpScreen(
          context,
          phone: phone,
          purpose: OtpPurpose.registration,
          otpAlreadySent: true,
        );
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, error.message);
    } catch (_) {
      if (!mounted) return;
      AppFeedback.error(
        context,
        'خطای غیرمنتظره‌ای رخ داد. لطفاً دوباره تلاش کنید.',
      );
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  void _onSkip() {
    AppRouter.toMain(context);
  }

  // ---------------------------------------------------------------------------
  // UI (identical to the original design, only wired)
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
                        right: 25.w,
                        top: 23.h,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                Image.asset(
                                  'assets/images/welcomhand.png',
                                  width: 30.w,
                                  height: 30.h,
                                ),
                                SizedBox(width: 10.w),
                                Text(
                                  'خوش اومدی',
                                  style: TextStyle(
                                    fontFamily: 'pinarb',
                                    fontSize: 20.sp,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: EdgeInsets.only(top: 5.h),
                              child: Text(
                                'برای ورود یا ثبت نام، شماره موبایل خود را وارد کنید',
                                style: TextStyle(
                                  fontFamily: 'shabnam',
                                  fontSize: 16.sp,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(top: 37.h),
                              child: SizedBox(
                                height: 70.h,
                                width: MediaQuery.sizeOf(context).width - 50.w,
                                child: TextFormField(
                                  controller: _phoneController,
                                  focusNode: _phoneFocus,
                                  enabled: !_isChecking,
                                  keyboardType: TextInputType.phone,
                                  textDirection: TextDirection.ltr,
                                  maxLength: 11,
                                  onChanged: (_) {
                                    if (_hasError) {
                                      setState(() => _hasError = false);
                                    }
                                  },
                                  onFieldSubmitted: (_) => _onContinue(),
                                  style: TextStyle(
                                    fontFamily: 'bshabnam',
                                    fontSize: 16.sp,
                                    color: AppColors.textPrimary,
                                  ),

                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],

                                  decoration: InputDecoration(
                                    hintText: 'شماره موبایل',
                                    hintTextDirection: TextDirection.rtl,
                                    hintStyle: TextStyle(
                                      fontFamily: 'shabnam',
                                      fontSize: 16.sp,
                                      color: AppColors.placeholder,
                                    ),

                                    prefixIcon: Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 15.h,
                                      ),
                                      child: Image.asset(
                                        'assets/images/mobile_icon.png',
                                        width: 34.w,
                                        height: 34.h,
                                      ),
                                    ),

                                    filled: true,
                                    fillColor: AppColors.field,

                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16.w,
                                      vertical: 18.h,
                                    ),

                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14.r),
                                      borderSide: BorderSide(
                                        color: _hasError
                                            ? Colors.red
                                            : AppColors.border,
                                        width: 2.w,
                                      ),
                                    ),

                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14.r),
                                      borderSide: BorderSide(
                                        color: _hasError
                                            ? Colors.red
                                            : AppColors.textPrimary,
                                        width: 2.w,
                                      ),
                                    ),

                                    disabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14.r),
                                      borderSide: BorderSide(
                                        color: AppColors.border,
                                        width: 2.w,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(top: 25.h),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _isChecking ? null : _onContinue,
                                child: Container(
                                  width: MediaQuery.sizeOf(context).width - 50.w,
                                  height: 64.h,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(16.r),
                                  ),
                                  child: Center(
                                    child: _isChecking
                                        ? const InlineLoader()
                                        : Text(
                                            'ادامه',
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
                            Padding(
                              padding: EdgeInsets.only(top: 10.h),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _isChecking ? null : _onSkip,
                                child: Container(
                                  width: MediaQuery.sizeOf(context).width - 50.w,
                                  height: 64.h,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: AppColors.primary,
                                      width: 2.w,
                                    ),
                                    borderRadius: BorderRadius.circular(16.r),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'رد شدن',
                                      style: TextStyle(
                                        color: AppColors.primary,
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
