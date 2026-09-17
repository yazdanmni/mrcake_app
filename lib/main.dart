import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/navigation/main_bottom_navigation.dart';
import 'package:mr_cake_project/pages/profile/profile_screen.dart';
import 'package:mr_cake_project/pages/search/screen/search_screen.dart';

void main() {
  runApp(const MyApp());
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
          home: child,
        );
      },
      child: const MainBottomNavigation(),
    );
  }
}
