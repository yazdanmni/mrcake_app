import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';

class ProfileHeader extends StatelessWidget {
  final VoidCallback? onAbout;
  final VoidCallback? onNotification;
  final VoidCallback? onSupport;

  const ProfileHeader({
    super.key,
    this.onAbout,
    this.onNotification,
    this.onSupport,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 150.h,
      child: ClipPath(
        clipper: _HeaderBottomCurveClipper(),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 9,
            sigmaY: 9,
          ),
          child: Container(
            width: double.infinity,
            height: 108.h,
            padding: EdgeInsets.symmetric(horizontal: 25.w),
            decoration: BoxDecoration(
              color: AppColors.sectionBackground.withOpacity(0.82),
            ),
            child: SafeArea(
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  // =========================================================
                  // Center — Logo
                  // =========================================================
              
                  Positioned(
                    top: 17.h,
                    left: 80.w,
                    right: 80.w,
                    child: Center(
                      child: _buildLogo(),
                    ),
                  ),
              
                  // =========================================================
                  // Right — About
                  // =========================================================
              
                  Positioned(
                    top: 25.h,
                    right: 0,
                    child: _HeaderIconButton(
                      icon: Icons.info_outline_rounded,
                      onTap: onAbout,
                    ),
                  ),
              
                  // =========================================================
                  // Left — Notification
                  // =========================================================
              
                  Positioned(
                    top: 25.h,
                    left: 0,
                    child: _HeaderIconButton(
                      icon: Icons.notifications_none_rounded,
                      onTap: onNotification,
                    ),
                  ),
              
                  // =========================================================
                  // Left — Support
                  // =========================================================
              
                  Positioned(
                    top: 25.h,
                    left: 55.w,
                    child: _HeaderIconButton(
                      icon: Icons.headset_mic_outlined,
                      onTap: onSupport,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Logo
  // ===========================================================================

  Widget _buildLogo() {
    return SizedBox(
      width: 125.w,
      height: 70.h,
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'مستر کیک',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'BShabnam',
                  fontSize: 23.sp,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFE7A0B1),
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                'M   A   S   T   E   R   C   A   K   E',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'BShabnam',
                  fontSize: 5.5.sp,
                  letterSpacing: 1.5.w,
                  color: const Color(0xFFE7A0B1),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// Header Icon Button
// =============================================================================

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _HeaderIconButton({
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: SizedBox(
          width: 34.w,
          height: 34.w,
          child: Center(
            child: Icon(
              icon,
              size: 32.sp,
              color: const Color(0xFF5B3930),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Bottom Curve
// =============================================================================

class _HeaderBottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    path.moveTo(0, 0);

    // Top
    path.lineTo(size.width, 0);

    // Right side
    path.lineTo(size.width, size.height * 0.62);

    // Right → center
    path.quadraticBezierTo(
      size.width * 0.98,
      size.height * 0.88,
      size.width * 0.80,
      size.height * 0.96,
    );

    // Center → left
    path.quadraticBezierTo(
      size.width * 0.50,
      size.height * 1.08,
      size.width * 0.20,
      size.height * 0.96,
    );

    // Left side
    path.quadraticBezierTo(
      size.width * 0.02,
      size.height * 0.88,
      0,
      size.height * 0.62,
    );

    path.close();

    return path;
  }

  @override
  bool shouldReclip(
    covariant CustomClipper<Path> oldClipper,
  ) {
    return false;
  }
}