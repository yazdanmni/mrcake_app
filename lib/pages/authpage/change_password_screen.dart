import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';

class ChangePasswordScreen extends StatefulWidget {
  const new({super.key});

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

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

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
                  child: Container(
                    width: double.infinity,
                    height: 62.h,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Center(
                      child: Text(
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
                SizedBox(height: 19.h),
                GestureDetector(
                  onTap: () {},
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
