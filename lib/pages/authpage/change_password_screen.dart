import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/network/api_exception.dart';
import 'package:mr_cake_project/core/router/app_router.dart';
import 'package:mr_cake_project/core/session/session_manager.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/core/utils/app_feedback.dart';
import 'package:mr_cake_project/core/utils/validators.dart';
import 'package:mr_cake_project/repositories/auth_repository.dart';

/// Last step of the "I forgot my password" branch, also reusable from the
/// profile screen for a signed in user.
///
/// Screen -> Endpoint -> Model -> Repository
///   ChangePasswordScreen -> POST v1/accounts/auth/change-password/ -> AuthSession
///                        -> POST v1/accounts/auth/reset-password/  -> AuthSession
///                        -> AuthRepository
///
/// * signed in               -> `change-password` (needs the JWT)
/// * no JWT but phone + OTP  -> `reset-password`
/// * "رد شدن"                -> MainBottomNavigation (the password is optional)
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({
    super.key,
    this.phone,
    this.otp,
    this.allowSkip = true,
  });

  /// Present when the user arrived from the forgot-password OTP screen.
  final String? phone;
  final String? otp;

  /// When false the "رد شدن" link is hidden.
  final bool allowSkip;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _showPassword = false;
  bool _showConfirmPassword = false;

  bool _passwordsNotMatch = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final newPassword = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    final error = Validators.password(newPassword) ??
        Validators.confirmPassword(confirmPassword, newPassword);
    if (error != null) {
      setState(() {
        _passwordsNotMatch =
            newPassword != confirmPassword && confirmPassword.isNotEmpty;
      });
      AppFeedback.error(context, error);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _passwordsNotMatch = false;
    });

    try {
      await _applyNewPassword(
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );

      if (!mounted) return;
      AppFeedback.success(context, 'رمز عبور با موفقیت تغییر کرد.');
      AppRouter.toMain(context);
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Uses the authenticated endpoint when a session exists and falls back to
  /// the OTP based reset when it does not (or when the token was refused).
  Future<void> _applyNewPassword({
    required String newPassword,
    required String confirmPassword,
  }) async {
    final hasSession = SessionManager.instance.isLoggedIn;
    final canReset =
        widget.phone != null &&
        widget.phone!.isNotEmpty &&
        widget.otp != null &&
        widget.otp!.isNotEmpty;

    if (hasSession) {
      try {
        await AuthRepository.instance.changePassword(
          newPassword: newPassword,
          confirmPassword: confirmPassword,
        );
        return;
      } on ApiException catch (error) {
        final canFallback = canReset && !error.isWrongPassword;
        if (!canFallback) rethrow;
      }
    }

    if (canReset) {
      await AuthRepository.instance.resetPassword(
        phone: widget.phone!,
        otp: widget.otp!,
        newPassword: newPassword,
      );
      return;
    }

    throw ApiException(
      message: 'برای تغییر رمز عبور باید دوباره وارد شوید.',
      type: ApiErrorType.unauthorized,
    );
  }

  void _skip() {
    if (SessionManager.instance.isLoggedIn) {
      AppRouter.toMain(context);
      return;
    }
    AppRouter.toLogin(context, replace: true);
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 25.w),
          child: Container(
            width: double.infinity,
            height: 368.h,
            decoration: BoxDecoration(
              color: AppColors.sectionBackground,
              borderRadius: BorderRadius.all(Radius.circular(24.r)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 30.h, bottom: 16.h),
                  child: Text(
                    'رمز عبور جدید خود را وارد کنید',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontFamily: 'shabnam',
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40.w),
                  child: Column(
                    children: [
                      Container(
                        height: 62.h,
                        decoration: BoxDecoration(
                          color: AppColors.field,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                            color: _passwordsNotMatch
                                ? Colors.red
                                : AppColors.border,
                            width: 2,
                          ),
                        ),
                        child: TextField(
                          controller: _passwordController,
                          enabled: !_isSubmitting,
                          obscureText: !_showPassword,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,

                          onChanged: (_) {
                            setState(() {
                              _passwordsNotMatch =
                                  _confirmPasswordController.text.isNotEmpty &&
                                  _passwordController.text !=
                                      _confirmPasswordController.text;
                            });
                          },

                          style: TextStyle(
                            fontFamily: 'bshabnam',
                            fontSize: 16.sp,
                            color: AppColors.textPrimary,
                          ),

                          decoration: InputDecoration(
                            border: InputBorder.none,

                            hintText: 'رمز عبور جدید',

                            hintStyle: TextStyle(
                              fontFamily: 'shabnam',
                              fontSize: 16.sp,
                              color: AppColors.placeholder,
                            ),

                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 17.h,
                            ),

                            prefixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _showPassword = !_showPassword;
                                });
                              },
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppColors.textPrimary,
                                size: 24.sp,
                              ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 9.h),

                      Container(
                        height: 62.h,
                        decoration: BoxDecoration(
                          color: AppColors.field,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                            color: _passwordsNotMatch
                                ? Colors.red
                                : AppColors.border,
                            width: 2,
                          ),
                        ),
                        child: TextField(
                          controller: _confirmPasswordController,
                          enabled: !_isSubmitting,
                          obscureText: !_showConfirmPassword,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,

                          onChanged: (_) {
                            setState(() {
                              _passwordsNotMatch =
                                  _passwordController.text !=
                                  _confirmPasswordController.text;
                            });
                          },

                          style: TextStyle(
                            fontFamily: 'bshabnam',
                            fontSize: 16.sp,
                            color: AppColors.textPrimary,
                          ),

                          decoration: InputDecoration(
                            border: InputBorder.none,

                            hintText: 'تکرار رمز عبور جدید',

                            hintStyle: TextStyle(
                              fontFamily: 'shabnam',
                              fontSize: 16.sp,
                              color: AppColors.placeholder,
                            ),

                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 17.h,
                            ),

                            prefixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _showConfirmPassword = !_showConfirmPassword;
                                });
                              },
                              icon: Icon(
                                _showConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppColors.textPrimary,
                                size: 24.sp,
                              ),
                            ),
                          ),
                        ),
                      ),

                      if (_passwordsNotMatch) ...[
                        SizedBox(height: 8.h),

                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'رمزهای عبور با یکدیگر مطابقت ندارند',
                            style: TextStyle(
                              fontFamily: 'shabnam',
                              fontSize: 14.sp,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 25.h),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40.w),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _isSubmitting ? null : _submit,
                    child: Container(
                      width: double.infinity,
                      height: 62.h,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Center(
                        child: _isSubmitting
                            ? const InlineLoader()
                            : Text(
                                'ورود',
                                style: TextStyle(
                                  fontFamily: 'bshabnam',
                                  fontSize: 20.sp,
                                  color: AppColors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 19.h),
                if (widget.allowSkip)
                  GestureDetector(
                    onTap: _isSubmitting ? null : _skip,
                    child: Text(
                      'رد شدن',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'bShabnam',
                        fontSize: 20.sp,
                        color: AppColors.premium,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
