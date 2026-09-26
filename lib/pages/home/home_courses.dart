import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mr_cake_project/core/network/remote_data.dart';
import 'package:mr_cake_project/data/courses_data.dart';
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
  // مرتب‌شده بر اساس تعداد هنرجو (نزولی): پرطرفدارترین دوره اول لیست
  // ================================================================

  /// سقف تعداد کارت‌ها — همان تعدادی که انتخاب «۲ از هر دسته» قبلاً می‌ساخت.
  static const int _popularLimit = 6;

  List<Course> get popularCourses => CourseUtils.getPopularCourses(
    courses: _courses,
    limit: _popularLimit,
  );

  Future<void> _load() async {
    final result = await RemoteLoader.list<Course>(
      label: 'home.popular',
      seed: CoursesData.courses,
      fetch: () async {
        // The backend already ranks by student count, so the first item is the
        // course with the most students and the rest follow it in order.
        final ranked =
            await CatalogRepository.instance.fetchCoursesByStudents();
        if (ranked.isNotEmpty) return ranked;

        // Older deployments may ignore `ordering`: the full catalogue is still
        // sorted locally by `CourseUtils.getPopularCourses`.
        //
        // `best_selling/` is deliberately not used any more: it is auth-only
        // (a guest gets 401) and its order is exactly what the explicit
        // `-students_count` ranking replaces.
        return CatalogRepository.instance.fetchCourses();
      },
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
              //
              // **Not** wrapped in a plain `IgnorePointer` any more. The
              // `PageView` above is `Positioned.fill` and `SizedBox.expand()`s
              // every page, so it covers the whole carousel: it eats the tap
              // before it can ever reach a card, and `IgnorePointer` on this
              // layer only guarantees that. Taps are reported from *there*
              // instead — see the swipe engine below.

              _CardsLayer(
                courses: courses,
                page: _page,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                onCourseTap: widget.onCourseTap,
              ),

              // ==================================================
              // SWIPE ENGINE
              // ==================================================
              //
              // The layer that actually sits on top owns every gesture: it has
              // to, because it is the only thing that can both drive the page
              // and receive a tap. `onTap` is therefore decided here, from the
              // page the carousel has settled on — the centred card.
              //
              // This is the whole reason a tap used to do nothing: the cards
              // were pointer-ignoring underneath an opaque full-size
              // `PageView`, so «دوره های محبوب» was decorative. The visible
              // consequence of getting it wrong is not a crash but a card that
              // silently refuses to open.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openCenteredCourse(courses),
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: courses.length,
                    physics: const BouncingScrollPhysics(),
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
              ),
            ],
          ),
        );
      },
    );
  }

  /// Opens the course currently centred in the carousel.
  ///
  /// [page] can land between two cards while a swipe is in flight, so the index
  /// is rounded to whichever card is closest to the centre — the one under the
  /// user's finger. Out-of-range guards are not defensive noise: `onTap` fires
  /// on the frame the gesture ends, and the list can still be swapped by an
  /// in-flight refresh.
  void _openCenteredCourse(List<Course> courses) {
    final ValueChanged<Course>? onCourseTap = widget.onCourseTap;

    if (onCourseTap == null || courses.isEmpty) return;

    final int index = _page.round();

    if (index < 0 || index >= courses.length) return;

    onCourseTap(courses[index]);
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

  /// Passed down so the **card itself** keeps its pressed/ripple feedback, and
  /// so `CourseCard` stays a normal tappable widget. The tap is *not* reported
  /// from here: this layer sits under an opaque full-size `PageView`, so a tap
  /// on it can never arrive. [HomeCourses._openCenteredCourse] owns that.
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
                onTap: () {
                    onCourseTap?.call(
                      courses[item.index],
                    );
                  },
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
