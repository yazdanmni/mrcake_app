import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/app_config.dart';
import 'package:mr_cake_project/core/network/media_host_overrides.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mr_cake_project/pages/splash/splash_screen.dart';

void main() {
  // Must run before anything creates an HttpClient (i.e. before the first
  // `Image.network`). Off by default — see the class docs for why, and what the
  // real server-side fix is.
  if (AppConfig.allowInsecureMediaHost) {
    HttpOverrides.global = MediaHostHttpOverrides();
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Base design size matches the Figma iPhone frame (390 x 844).
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'مستر کیک',
          // The splash screen is always the entry point. It restores the saved
          // session and then routes to the login screen or to the main
          // navigation (see `AppRouter`).
          home: child,
        );
      },
      child: const SplashScreen(),
    );
  }
}
