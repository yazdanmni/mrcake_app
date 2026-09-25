import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/pages/courses/courses_screen.dart';
import 'package:mr_cake_project/pages/explore/explore_screen.dart';
import 'package:mr_cake_project/pages/home/home_screen.dart';

import '../core/theme/app_colors.dart';

import '../pages/search/screen/search_screen.dart';
import '../pages/profile/profile_screen.dart';

class MainBottomNavigation extends StatefulWidget {
  const MainBottomNavigation({super.key});

  @override
  State<MainBottomNavigation> createState() =>
      _MainBottomNavigationState();
}

class _MainBottomNavigationState extends State<MainBottomNavigation>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 2;
  int _previousIndex = 2;

  late final AnimationController _controller;

  late Animation<double> _circleAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _iconScaleAnimation;
  late Animation<double> _rotationAnimation;

  /// Index of the profile tab, and the reason [_buildPages] rebuilds the list on
  /// every tab change: the tabs live in an `IndexedStack`, so the profile is
  /// built once and kept alive. Passing `visible` gives
  /// `ProfileScreen.didUpdateWidget` something to react to, which is how
  /// «دوره‌های من» learns it must re-read the server after the user registers
  /// for (or is approved for) a course.
  static const int _profileIndex = 4;

  List<Widget> _buildPages() => <Widget>[
    const ExploreScreen(),
    const CoursesScreen(),
    const HomeScreen(),
    const SearchScreen(),
    ProfileScreen(visible: _currentIndex == _profileIndex),
  ];

  final List<_NavigationItem> _items = const [
    _NavigationItem(
      icon: Icons.explore_rounded,
      label: 'اکسپلور',
    ),
    _NavigationItem(
      icon: Icons.menu_book_rounded,
      label: 'دوره‌ها',
    ),
    _NavigationItem(
      icon: Icons.home_rounded,
      label: 'خانه',
    ),
    _NavigationItem(
      icon: Icons.search_rounded,
      label: 'جستجو',
    ),
    _NavigationItem(
      icon: Icons.person_rounded,
      label: 'پروفایل',
    ),
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    // حرکت عمودی بسیار کم برای حالت طبیعی
    _circleAnimation = TweenSequence<double>(
      [
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 4,
            end: -3,
          ).chain(
            CurveTween(
              curve: Curves.easeOut,
            ),
          ),
          weight: 35,
        ),
        TweenSequenceItem(
          tween: Tween<double>(
            begin: -3,
            end: 1.5,
          ).chain(
            CurveTween(
              curve: Curves.easeInOut,
            ),
          ),
          weight: 25,
        ),
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 1.5,
            end: 0,
          ).chain(
            CurveTween(
              curve: Curves.elasticOut,
            ),
          ),
          weight: 40,
        ),
      ],
    ).animate(_controller);

    _scaleAnimation = TweenSequence<double>(
      [
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 0.88,
            end: 1.07,
          ).chain(
            CurveTween(
              curve: Curves.easeOut,
            ),
          ),
          weight: 45,
        ),
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 1.07,
            end: 0.97,
          ).chain(
            CurveTween(
              curve: Curves.easeInOut,
            ),
          ),
          weight: 25,
        ),
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 0.97,
            end: 1.0,
          ).chain(
            CurveTween(
              curve: Curves.elasticOut,
            ),
          ),
          weight: 30,
        ),
      ],
    ).animate(_controller);

    _iconScaleAnimation = TweenSequence<double>(
      [
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 0.72,
            end: 1.12,
          ).chain(
            CurveTween(
              curve: Curves.easeOutBack,
            ),
          ),
          weight: 55,
        ),
        TweenSequenceItem(
          tween: Tween<double>(
            begin: 1.12,
            end: 1.0,
          ).chain(
            CurveTween(
              curve: Curves.elasticOut,
            ),
          ),
          weight: 45,
        ),
      ],
    ).animate(_controller);

    _rotationAnimation = Tween<double>(
      begin: -0.08,
      end: 0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changePage(int index) {
    if (index == _currentIndex) return;

    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
    });

    _controller.forward(from: 0);
  }

  // مرکز دقیق هر آیتم
  double _getNotchCenter(double itemWidth) {
    final start =
        (_previousIndex * itemWidth) + (itemWidth / 2);

    final end =
        (_currentIndex * itemWidth) + (itemWidth / 2);

    final progress = Curves.easeInOutCubic.transform(
      _controller.value,
    );

    return start + ((end - start) * progress);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,

      body: IndexedStack(
        index: _currentIndex,
        children: _buildPages(),
      ),

      bottomNavigationBar: SafeArea(
        top: false,
        minimum: EdgeInsets.only(
          left: 12.w,
          right: 12.w,
          bottom: 6.h,
        ),
        child: SizedBox(
          height: 106.h,
          child: LayoutBuilder(
            builder: (
              BuildContext context,
              BoxConstraints constraints,
            ) {
              final itemWidth =
                  constraints.maxWidth / 5;

              return AnimatedBuilder(
                animation: _controller,
                builder: (
                  BuildContext context,
                  Widget? child,
                ) {
                  final notchCenter =
                      _getNotchCenter(itemWidth);

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // ===================================================
                      // REAL NAVIGATION BAR
                      // ===================================================

                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 78.h,
                        child: CustomPaint(
                          painter: _BottomNavigationPainter(
                            color: AppColors.primary,

                            // ناچ جمع‌تر
                            notchWidth: 70.w,

                            // ناچ عمیق‌تر
                            notchDepth: 43.h,

                            // گردی گوشه‌های ناچ
                            notchRadius: 25.r,

                            // مرکز دقیق ناچ
                            notchCenterX: notchCenter,
                          ),
                        ),
                      ),

                      // ===================================================
                      // NAVIGATION ITEMS
                      // ===================================================

                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 78.h,
                        child: Row(
                          children: List.generate(
                            5,
                            (index) {
                              final selected =
                                  index == _currentIndex;

                              return SizedBox(
                                width: itemWidth,
                                height: 78.h,
                                child: GestureDetector(
                                  behavior:
                                      HitTestBehavior.opaque,
                                  onTap: () =>
                                      _changePage(index),

                                  child: selected
                                      ? const SizedBox()
                                      : Column(
                                          mainAxisSize:
                                              MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              _items[index].icon,
                                              size: 30.sp,
                                              color:
                                                  Colors.white,
                                            ),

                                            SizedBox(
                                              height: 3.h,
                                            ),

                                            Text(
                                              _items[index].label,
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow
                                                      .ellipsis,
                                              style:
                                                  TextStyle(
                                                fontFamily:
                                                    'BShabnam',
                                                fontSize: 11.sp,
                                                fontWeight:
                                                    FontWeight.w500,
                                                color:
                                                    Colors.white,
                                                height: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // ===================================================
                      // PREMIUM CIRCLE
                      // ===================================================

                      Positioned(
                        left:
                            notchCenter - 30.w,

                        // دایره دقیقاً داخل مرکز ناچ
                        top:
                            13.h +
                            _circleAnimation.value.h,

                        child: Transform.scale(
                          scale:
                              _scaleAnimation.value,

                          child: Transform.rotate(
                            angle:
                                _rotationAnimation.value,

                            child: Container(
                              width: 60.w,
                              height: 60.w,

                              decoration:
                                  BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    AppColors.premium,

                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors
                                        .premium
                                        .withValues(alpha: 
                                      0.30,
                                    ),
                                    blurRadius: 17.r,
                                    spreadRadius: 1.r,
                                    offset:
                                        Offset(0, 5.h),
                                  ),
                                ],
                              ),

                              alignment:
                                  Alignment.center,

                              child: Transform.scale(
                                scale:
                                    _iconScaleAnimation
                                        .value,

                                child: Icon(
                                  _items[_currentIndex]
                                      .icon,
                                  size: 30.sp,
                                  color:
                                      Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// NAVIGATION ITEM
// ===========================================================================

class _NavigationItem {
  final IconData icon;
  final String label;

  const _NavigationItem({
    required this.icon,
    required this.label,
  });
}

// ===========================================================================
// REAL NOTCH
// ===========================================================================

class _BottomNavigationPainter extends CustomPainter {
  final Color color;

  final double notchCenterX;
  final double notchWidth;
  final double notchDepth;
  final double notchRadius;

  const _BottomNavigationPainter({
    required this.color,
    required this.notchCenterX,
    required this.notchWidth,
    required this.notchDepth,
    required this.notchRadius,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final path = Path();

    final left = 0.0;
    final right = size.width;
    final top = 0.0;
    final bottom = size.height;

    // =========================================================
    // ناچ باریک
    // =========================================================

    final notchLeft =
        notchCenterX - (notchWidth / 2);

    final notchRight =
        notchCenterX + (notchWidth / 2);

    // =========================================================
    // LEFT
    // =========================================================

    path.moveTo(
      left,
      top + 16.r,
    );

    path.quadraticBezierTo(
      left,
      top,
      16.r,
      top,
    );

    // =========================================================
    // BEFORE NOTCH
    // =========================================================

    path.lineTo(
      notchLeft - notchRadius,
      top,
    );

    path.quadraticBezierTo(
      notchLeft - 4.w,
      top,
      notchLeft,
      top + 9.h,
    );

  
    path.cubicTo(
      notchLeft + 3.w,
      top + 34.h,
      notchCenterX - 19.w,
      top + notchDepth,
      notchCenterX,
      top + notchDepth,
    );

    path.cubicTo(
      notchCenterX + 19.w,
      top + notchDepth,
      notchRight - 5.w,
      top + 34.h,
      notchRight,
      top + 9.h,
    );

    path.quadraticBezierTo(
      notchRight + 4.w,
      top,
      notchRight + notchRadius,
      top,
    );

    // =========================================================
    // RIGHT
    // =========================================================

    path.lineTo(
      right - 16.r,
      top,
    );

    path.quadraticBezierTo(
      right,
      top,
      right,
      top + 16.r,
    );

    // =========================================================
    // RIGHT BOTTOM
    // =========================================================

    path.lineTo(
      right,
      bottom - 16.r,
    );

    path.quadraticBezierTo(
      right,
      bottom,
      right - 16.r,
      bottom,
    );

    // =========================================================
    // BOTTOM
    // =========================================================

    path.lineTo(
      16.r,
      bottom,
    );

    path.quadraticBezierTo(
      left,
      bottom,
      left,
      bottom - 16.r,
    );

    path.close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(
      path,
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _BottomNavigationPainter oldDelegate,
  ) {
    return oldDelegate.notchCenterX !=
            notchCenterX ||
        oldDelegate.notchWidth != notchWidth ||
        oldDelegate.notchDepth != notchDepth ||
        oldDelegate.notchRadius != notchRadius ||
        oldDelegate.color != color;
  }
}