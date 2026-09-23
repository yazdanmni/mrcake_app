import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mr_cake_project/core/network/remote_data.dart';
import 'package:mr_cake_project/repositories/catalog_repository.dart';
import 'package:mr_cake_project/utils/course_utils.dart';

import '../../models/course.dart';
import 'widgets/course_card.dart';

class HomeCourses extends StatefulWidget {
  final ValueChanged<Course>? onCourseTap;

  const HomeCourses({
    super.key,
    this.onCourseTap,
  });

  @override
  State<HomeCourses> createState() => _HomeCoursesState();
}

class _HomeCoursesState extends State<HomeCourses> {
  late final PageController _pageController;

  double _page = 1.0;

  /// Seed data is rendered immediately, then replaced by the backend answer.
  List<Course> _courses = const [];

  @override
  void initState() {
    super.initState();

    _pageController = PageController(
      initialPage: 1,
      viewportFraction: 0.72,
    );

    _pageController.addListener(_pageListener);

    _load();
  }

  // ================================================================
  // POPULAR COURSES
  // از هر دسته 2 دوره با بیشترین تعداد هنرجو
  // ================================================================

  List<Course> get popularCourses => CourseUtils.getPopularCourses(
    courses: _courses,
    perType: 2,
  );

  Future<void> _load() async {
    final result = await RemoteLoader.list<Course>(
      label: 'home.popular',
      fetch: CatalogRepository.instance.fetchBestSellingCourses,
    );

    if (!mounted) return;
    setState(() => _courses = result.data);
  }

  void _pageListener() {
    if (!_pageController.hasClients) {
      return;
    }

    final double? currentPage = _pageController.page;

    if (currentPage == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _page = currentPage;
    });
  }

  @override
  void dispose() {
    _pageController.removeListener(_pageListener);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final courses = popularCourses;

    if (courses.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        final double cardWidth =
            _getCardWidth(constraints.maxWidth);

        final double cardHeight =
            cardWidth * 267 / 180;

        final double carouselHeight =
            cardHeight + 24;

        return SizedBox(
          width: double.infinity,
          height: carouselHeight,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // ==================================================
              // CARDS
              // ==================================================

              IgnorePointer(
                child: _CardsLayer(
                  courses: courses,
                  page: _page,
                  cardWidth: cardWidth,
                  cardHeight: cardHeight,
                  onCourseTap: widget.onCourseTap,
                ),
              ),

              // ==================================================
              // SWIPE ENGINE
              // ==================================================

              Positioned.fill(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: courses.length,
                  physics:
                      const BouncingScrollPhysics(),
                  clipBehavior: Clip.none,
                  padEnds: true,
                  itemBuilder: (
                    BuildContext context,
                    int index,
                  ) {
                    return const SizedBox.expand();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _getCardWidth(
    double availableWidth,
  ) {
    if (availableWidth <= 320) {
      return 145;
    }

    if (availableWidth <= 360) {
      return 155;
    }

    if (availableWidth <= 390) {
      return 170;
    }

    if (availableWidth <= 430) {
      return 180;
    }

    return math.min(
      190,
      availableWidth * 0.42,
    );
  }
}

// ================================================================
// CARDS LAYER
// ================================================================

class _CardsLayer extends StatelessWidget {
  final List<Course> courses;
  final double page;
  final double cardWidth;
  final double cardHeight;
  final ValueChanged<Course>? onCourseTap;

  const _CardsLayer({
    required this.courses,
    required this.page,
    required this.cardWidth,
    required this.cardHeight,
    this.onCourseTap,
  });

  @override
  Widget build(BuildContext context) {
    final int centerIndex = page.round();

    final List<_VisibleCard> visibleCards = [];

    for (int index = 0;
        index < courses.length;
        index++) {
      final double distance = index - page;

      if (distance.abs() <= 1.25) {
        visibleCards.add(
          _VisibleCard(
            index: index,
            distance: distance,
          ),
        );
      }
    }

    // کارت‌های دورتر اول رسم می‌شوند
    // کارت وسط روی آن‌ها قرار می‌گیرد.

    visibleCards.sort(
      (
        _VisibleCard a,
        _VisibleCard b,
      ) {
        return b.distance
            .abs()
            .compareTo(
              a.distance.abs(),
            );
      },
    );

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        for (final _VisibleCard item
            in visibleCards)
          _buildCard(
            item,
            centerIndex,
          ),
      ],
    );
  }

  Widget _buildCard(
    _VisibleCard item,
    int centerIndex,
  ) {
    final double distance = item.distance;

    final double absoluteDistance =
        distance.abs();

    final double normalized =
        absoluteDistance.clamp(
      0.0,
      1.0,
    );

    // ==========================================================
    // HORIZONTAL POSITION
    // ==========================================================

    final double sideOffset =
        cardWidth * 0.62;

    final double x =
        distance * sideOffset;

    // ==========================================================
    // VERTICAL POSITION
    // ==========================================================

    final double y =
        normalized * 9;

    // ==========================================================
    // SCALE
    // ==========================================================

    final double scale =
        1.0 - (normalized * 0.055);

    // ==========================================================
    // ROTATION
    // ==========================================================

    final double rotation =
        distance.clamp(
              -1.0,
              1.0,
            ) *
            0.075;

    // ==========================================================
    // OPACITY
    // ==========================================================

    final double opacity =
        1.0 - (normalized * 0.10);

    // ==========================================================
    // CENTER CARD
    // ==========================================================

    final bool isCenter =
        absoluteDistance < 0.5;

    return Transform.translate(
      offset: Offset(
        x,
        y,
      ),
      child: Transform.rotate(
        angle: rotation,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: Opacity(
            opacity: opacity,
            child: SizedBox(
              width: cardWidth,
              height: cardHeight,
              child: CourseCard(
                course: courses[item.index],
                width: cardWidth,
                height: cardHeight,
                onTap: isCenter
                    ? () {
                        onCourseTap?.call(
                          courses[item.index],
                        );
                      }
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// VISIBLE CARD DATA
// ================================================================

class _VisibleCard {
  final int index;
  final double distance;

  const _VisibleCard({
    required this.index,
    required this.distance,
  });
}
