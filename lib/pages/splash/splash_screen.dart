import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mr_cake_project/core/app_config.dart';
import 'package:mr_cake_project/core/network/api_config.dart';
import 'package:mr_cake_project/core/network/network_probe.dart';
import 'package:mr_cake_project/core/network/vpn_detector.dart';
import 'package:mr_cake_project/core/router/app_router.dart';
import 'package:mr_cake_project/core/session/session_manager.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';

/// What the splash is currently doing.
enum _SplashPhase { checking, vpnWarning, networkError }

/// The very first screen of the app.
///
/// * always shown when the app starts
/// * its duration follows the real network speed: it waits for a lightweight
///   request against the backend and keeps a minimum display time so the logo
///   never flashes
/// * if a VPN / proxy is detected the error is displayed right here
/// * if the network is down the error + a retry button are displayed here
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  _SplashPhase _phase = _SplashPhase.checking;
  String _statusText = 'در حال بررسی اتصال...';
  String _errorText = '';
  VpnStatus _vpnStatus = VpnStatus.none;

  Timer? _vpnAutoContinueTimer;
  Timer? _safetyTimer;
  bool _navigated = false;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();

    // Hard safety net: whatever happens the user is never stuck on the splash.
    _safetyTimer = Timer(
      ApiConfig.splashMaxDuration + const Duration(seconds: 4),
      _continueToNextScreen,
    );

    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _vpnAutoContinueTimer?.cancel();
    _safetyTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Startup sequence
  // ---------------------------------------------------------------------------

  Future<void> _bootstrap() async {
    final startedAt = DateTime.now();

    if (mounted) {
      setState(() {
        _phase = _SplashPhase.checking;
        _statusText = 'در حال بررسی اتصال...';
        _retrying = false;
      });
    }

    // 1. Restore the persisted session (tokens + cached profile). Local and
    //    fast, but it must be done before any authorised request.
    await SessionManager.instance.init();

    // 2. VPN detection and the network probe run in parallel so the splash
    //    lasts as long as the slowest one, not as long as their sum.
    VpnDetector.enableIpLookup = AppConfig.enableVpnIpLookup;
    final results = await Future.wait<Object>([
      VpnDetector.detect(),
      NetworkProbe.warmUp(),
    ]);

    final vpn = results[0] as VpnStatus;
    final probe = results[1] as ProbeResult;

    // 3. Keep the branding visible for a moment even on a very fast network.
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed < ApiConfig.splashMinDuration) {
      await Future<void>.delayed(ApiConfig.splashMinDuration - elapsed);
    }

    if (!mounted) return;

    // 4. VPN first: the user has to know before any screen misbehaves.
    if (AppConfig.showVpnWarning && vpn.isDetected) {
      setState(() {
        _phase = _SplashPhase.vpnWarning;
        _vpnStatus = vpn;
      });

      if (!AppConfig.blockOnVpn) {
        _vpnAutoContinueTimer = Timer(
          ApiConfig.vpnWarningAutoContinue,
          _continueToNextScreen,
        );
      }
      return;
    }

    // 5. No connection: show the error here instead of a broken login screen.
    if (!probe.reachable) {
      setState(() {
        _phase = _SplashPhase.networkError;
        _errorText =
            probe.error?.message ??
            'اتصال به سرور برقرار نشد. لطفاً اینترنت خود را بررسی کنید.';
      });
      return;
    }

    // 6. Everything is fine: the splash lasted exactly as long as the network
    //    needed it to.
    setState(() => _statusText = probe.quality.label);
    _continueToNextScreen();
  }

  /// Retry after a network failure.
  Future<void> _retry() async {
    if (_retrying) return;
    _retrying = true;
    _vpnAutoContinueTimer?.cancel();
    await _bootstrap();
  }

  void _continueToNextScreen() {
    if (_navigated || !mounted) return;
    _navigated = true;

    _vpnAutoContinueTimer?.cancel();
    _safetyTimer?.cancel();

    final session = SessionManager.instance;

    if (AppConfig.autoLoginWithSavedToken && session.isLoggedIn) {
      AppRouter.toMain(context);
      return;
    }

    AppRouter.toLogin(context, replace: true, initialPhone: session.lastPhone);
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.sizeOf(context).height * 0.6,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset('assets/images/mrcakelogo.svg'),
                      SizedBox(height: 30.h),
                      _buildStatusArea(),
                    ],
                  ),
                ),
              ),
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

  Widget _buildStatusArea() {
    switch (_phase) {
      case _SplashPhase.checking:
        return _buildChecking();
      case _SplashPhase.vpnWarning:
        return _buildVpnWarning();
      case _SplashPhase.networkError:
        return _buildNetworkError();
    }
  }

  Widget _buildChecking() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 26.sp,
          height: 26.sp,
          child: const CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        SizedBox(height: 14.h),
        Text(
          _statusText,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: 'shabnam',
            fontSize: 13.sp,
            height: 1.7,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildVpnWarning() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: AppColors.sectionBackground,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.premium, width: 1.6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              textDirection: TextDirection.rtl,
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: AppColors.premium,
                  size: 22.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  'VPN شناسایی شد',
                  style: TextStyle(
                    fontFamily: 'bshabnam',
                    fontSize: 15.sp,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              _vpnStatus.message,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'shabnam',
                fontSize: 12.sp,
                height: 1.8,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              height: 44.h,
              child: ElevatedButton(
                onPressed: _continueToNextScreen,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  'ادامه',
                  style: TextStyle(
                    fontFamily: 'bshabnam',
                    fontSize: 16.sp,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkError() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: AppColors.sectionBackground,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: const Color(0xFFD9534F).withValues(alpha: 0.45),
            width: 1.6,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              textDirection: TextDirection.rtl,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  color: const Color(0xFFD9534F),
                  size: 22.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  'خطای اتصال',
                  style: TextStyle(
                    fontFamily: 'bshabnam',
                    fontSize: 15.sp,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              _errorText,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'shabnam',
                fontSize: 12.sp,
                height: 1.8,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44.h,
                    child: ElevatedButton(
                      onPressed: _retrying ? null : _retry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.primary.withValues(
                          alpha: 0.6,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: _retrying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.white,
                                ),
                              ),
                            )
                          : Text(
                              'تلاش مجدد',
                              style: TextStyle(
                                fontFamily: 'bshabnam',
                                fontSize: 16.sp,
                                color: AppColors.white,
                              ),
                            ),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: SizedBox(
                    height: 44.h,
                    child: OutlinedButton(
                      onPressed: _continueToNextScreen,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppColors.primary,
                          width: 1.6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        'ادامه',
                        style: TextStyle(
                          fontFamily: 'bshabnam',
                          fontSize: 16.sp,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
