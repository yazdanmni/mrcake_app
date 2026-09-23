import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/network/api_exception.dart';
import 'package:mr_cake_project/core/router/app_router.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/core/utils/app_feedback.dart';
import 'package:mr_cake_project/core/utils/validators.dart';
import 'package:mr_cake_project/repositories/auth_repository.dart';

/// Shown when the phone number already has an account.
///
/// Screen -> Endpoint -> Model -> Repository
///   LoginPasswordScreen -> POST v1/accounts/auth/login-password/ -> AuthSession
///                       -> POST v1/accounts/auth/send-otp/       -> bool
///                       -> AuthRepository
///
/// Branches:
///   * correct password          -> MainBottomNavigation
///   * "ورود با کد تایید"         -> LoginOtpScreen(purpose: login)
///   * "رمز عبورتان را گم کردید؟" -> LoginOtpScreen(purpose: forgot_password)
///                                  and then ChangePasswordScreen (skippable)
class LoginPasswordScreen extends StatefulWidget {
  const LoginPasswordScreen({super.key, required this.phone});

  final String phone;

  @override
  State<LoginPasswordScreen> createState() => _LoginPasswordScreenState();
}

class _LoginPasswordScreenState extends State<LoginPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _login() async {
    if (_isLoading) return;

    final password = _passwordController.text;
    final error = Validators.password(password);
    if (error != null) {
      setState(() => _hasError = true);
      AppFeedback.error(context, error);
      _passwordFocus.requestFocus();
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final session = await AuthRepository.instance.loginWithPassword(
        phone: widget.phone,
        password: password,
      );
      if (!mounted) return;

      if (session.hasToken) {
        AppRouter.toMain(context);
      } else {
        AppFeedback.error(context, 'ورود انجام نشد. لطفاً دوباره تلاش کنید.');
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _hasError = error.isWrongPassword);
      AppFeedback.error(context, error.message);
    } catch (_) {
      if (!mounted) return;
      AppFeedback.error(
        context,
        'خطای غیرمنتظره‌ای رخ داد. لطفاً دوباره تلاش کنید.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// "ورود با کد تایید" – login without the password.
  Future<void> _loginWithOtp() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await AuthRepository.instance.sendOtp(
        phone: widget.phone,
        purpose: OtpPurpose.login,
      );
      if (!mounted) return;
      AppRouter.toOtpScreen(
        context,
        phone: widget.phone,
        purpose: OtpPurpose.login,
        otpAlreadySent: true,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, error.message);
    } catch (_) {
      if (!mounted) return;
      AppFeedback.error(context, 'ارسال کد ناموفق بود. لطفاً دوباره تلاش کنید.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// "رمز عبورتان را گم کردید؟" – OTP first, then the new password screen.
  Future<void> _forgotPassword() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await AuthRepository.instance.sendOtp(
        phone: widget.phone,
        purpose: OtpPurpose.forgotPassword,
      );
      if (!mounted) return;
      AppRouter.toOtpScreen(
        context,
        phone: widget.phone,
        purpose: OtpPurpose.forgotPassword,
        otpAlreadySent: true,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, error.message);
    } catch (_) {
      if (!mounted) return;
      AppFeedback.error(context, 'ارسال کد ناموفق بود. لطفاً دوباره تلاش کنید.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                                'شما از قبل حساب دارید، برای ورود رمز خود را وارد کنید',
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
                                  controller: _passwordController,
                                  focusNode: _passwordFocus,
                                  enabled: !_isLoading,
                                  keyboardType: TextInputType.text,
                                  textDirection: TextDirection.rtl,

                                  obscureText: !_isPasswordVisible,

                                  onChanged: (_) {
                                    if (_hasError) {
                                      setState(() => _hasError = false);
                                    }
                                  },
                                  onFieldSubmitted: (_) => _login(),

                                  style: TextStyle(
                                    fontFamily: 'bshabnam',
                                    fontSize: 16.sp,
                                    color: AppColors.textPrimary,
                                  ),

                                  decoration: InputDecoration(
                                    hintText: 'رمز عبور',
                                    hintTextDirection: TextDirection.rtl,

                                    hintStyle: TextStyle(
                                      fontFamily: 'shabnam',
                                      fontSize: 16.sp,
                                      color: AppColors.placeholder,
                                    ),

                                    prefixIcon: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _isPasswordVisible =
                                              !_isPasswordVisible;
                                        });
                                      },
                                      icon: Icon(
                                        _isPasswordVisible
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_off_rounded,
                                        color: AppColors.textSecondary,
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
                              padding: EdgeInsets.only(top: 1.h),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  GestureDetector(
                                    onTap: _isLoading ? null : _loginWithOtp,
                                    child: Text(
                                      'ورود با کد تایید',
                                      style: TextStyle(
                                        fontFamily: 'shabnam',
                                        fontSize: 14.sp,
                                        color: AppColors.premium,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8.w),

                                  Text(
                                    '|',
                                    style: TextStyle(
                                      fontFamily: 'bshabnam',
                                      fontSize: 14.sp,
                                      color: AppColors.premium,
                                    ),
                                  ),

                                  SizedBox(width: 8.w),
                                  GestureDetector(
                                    onTap: _isLoading ? null : _forgotPassword,
                                    child: Text(
                                      'رمز عبورتان را گم کردید؟',
                                      style: TextStyle(
                                        fontFamily: 'shabnam',
                                        fontSize: 14.sp,
                                        color: AppColors.premium,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(top: 25.h),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _isLoading ? null : _login,
                                child: Container(
                                  width: MediaQuery.sizeOf(context).width - 50.w,
                                  height: 64.h,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(16.r),
                                  ),
                                  child: Center(
                                    child: _isLoading
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
