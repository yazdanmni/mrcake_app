import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';

class LoginScreen extends StatelessWidget {
  const new({super.key});

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
                                  keyboardType: TextInputType.phone,
                                  textDirection: TextDirection.ltr,
                                  maxLength: 11,
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
                              padding: EdgeInsets.only(top: 25.h),
                              child: Container(
                                width: MediaQuery.sizeOf(context).width - 50.w,
                                height: 64.h,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                                child: Center(
                                  child: Text('ادامه',
                                  style: TextStyle(
                                    color: AppColors.white,
                                    fontFamily: 'bshabnam',
                                    fontSize: 20.sp,
                                  ),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(top: 10.h),
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
                                  child: Text('رد شدن',
                                  style: TextStyle(
                                    color: AppColors.primary,
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
