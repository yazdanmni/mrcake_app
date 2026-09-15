import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const new({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SvgPicture.asset('assets/images/mrcakelogo.svg'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 25, right: 25, bottom: 30),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ساخته شده با ❤️ یزدان',
                  style: TextStyle(
                    fontFamily: 'shabnam',
                    fontSize: 14.sp,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'نسخه: 1.0.0',
                  style: TextStyle(
                    fontFamily: 'shabnam',
                    fontSize: 14.sp,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
