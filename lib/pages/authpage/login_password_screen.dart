import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';

class LoginPasswordScreen extends StatefulWidget {
  const new({super.key});

  @override
  State<LoginPasswordScreen> createState() => _LoginPasswordScreenState();
}

class _LoginPasswordScreenState extends State<LoginPasswordScreen> {
  bool _isPasswordVisible = false;

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
                                  keyboardType: TextInputType.text,
                                  textDirection: TextDirection.rtl,

                                  obscureText: !_isPasswordVisible,

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

                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 18,
                                    ),

                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: AppColors.border,
                                        width: 2.w,
                                      ),
                                    ),

                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: AppColors.textPrimary,
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
                                    onTap: () {
                                      // ورود با کد تایید
                                    },
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
                                    onTap: () {
                                      // فراموشی رمز
                                    },
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
                              child: Container(
                                width: MediaQuery.sizeOf(context).width - 50.w,
                                height: 64.h,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                                child: Center(
                                  child: Text(
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
