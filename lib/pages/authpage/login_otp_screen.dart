import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:otp_text_field/otp_field.dart';
import 'package:otp_text_field/otp_field_style.dart';
import 'package:otp_text_field/style.dart';

class LoginOtpScreen extends StatefulWidget {
  const new({super.key});

  @override
  State<LoginOtpScreen> createState() => _LoginOtpScreenState();
}

class _LoginOtpScreenState extends State<LoginOtpScreen> {
  Timer? _timer;

  int _secondsRemaining = 119;

  String otpCode = '';

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
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

  void _resendCode() {
    if (_secondsRemaining > 0) return;

    setState(() {
      _secondsRemaining = 119;
    });

    _startTimer();

    // API ارسال مجدد OTP
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

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
                                    '0919*******84',
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
                                    onTap: (){},
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
                                length: 4,
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
                                  setState(() {
                                    otpCode = value;
                                  });
                                },

                                onCompleted: (pin) {
                                  setState(() {
                                    otpCode = pin;
                                  });
                                },
                              ),
                            ),
                            SizedBox(height: 10.h),

                            Center(
                              child: GestureDetector(
                                onTap: _secondsRemaining == 0
                                    ? _resendCode
                                    : null,
                                child: Text(
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
