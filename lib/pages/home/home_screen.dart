import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/network/remote_data.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/data/categories_data.dart';
import 'package:mr_cake_project/data/courses_data.dart';
import 'package:mr_cake_project/models/banner_model.dart' as api;
import 'package:mr_cake_project/models/category_model.dart';
import 'package:mr_cake_project/models/course.dart';
import 'package:mr_cake_project/models/course_intro_video.dart';
import 'package:mr_cake_project/pages/course_details/course_details_screen.dart';
import 'package:mr_cake_project/pages/home/home_courses.dart';
import 'package:mr_cake_project/pages/home/widgets/course_intro_videos.dart';
import 'package:mr_cake_project/pages/home/widgets/home_banner.dart';
import 'package:mr_cake_project/pages/home/widgets/home_categories.dart';
import 'package:mr_cake_project/pages/home/widgets/home_header.dart';
import 'package:mr_cake_project/pages/home/widgets/home_hero.dart';
import 'package:mr_cake_project/pages/home/widgets/home_quick_actions.dart';
import 'package:mr_cake_project/repositories/catalog_repository.dart';
import 'package:mr_cake_project/core/router/app_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CatalogRepository _repository = CatalogRepository.instance;

  // Seed content is rendered first, then replaced by the backend response.
  List<CategoryModel> _categories = const [];
  List<Course> _courses = const [];

  /// Teasers for the «معرفی دوره ها» carousel.
  ///
  /// Same source and same card as the standalone
  /// [IntroductionVideosScreen] — no seed, because a course without a
  /// `video_trailer` has no teaser at all and a fake one would open a broken
  /// player.
  List<CourseIntroVideo> _introVideos = const [];

  // `null` keeps the bundled hero asset; the API image replaces it on load.
  String? _heroImageUrl;
  String? _heroLinkUrl;

  // Temporary mock banners until the backend endpoint is ready.
  List<BannerModel> _banners = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ================================================================
  // LOADING
  // ================================================================

  /// [refresh] is set by the pull-to-refresh gesture: it drops the response
  /// cache first, otherwise the pull would be served from the cache and appear
  /// to do nothing.
  Future<void> _load({bool refresh = false}) async {
    final categoriesRequest = RemoteLoader.list<CategoryModel>(
      label: 'home.categories',
      seed: CategoriesData.categories,
      refresh: refresh,
      fetch: () async {
        // `featured` is the curated home grid; the full list is the fallback.
        final featured = await _repository.fetchFeaturedCategories();
        if (featured.isNotEmpty) return featured;
        return _repository.fetchCategories();
      },
    );

    final coursesRequest = RemoteLoader.list<Course>(
      label: 'home.courses',
      seed: CoursesData.courses,
      refresh: refresh,
      fetch: () async {
        var courses = await _repository.fetchFeaturedCourses();
        if (courses.isNotEmpty) return courses;

        courses = await _repository.fetchBestSellingCourses();
        if (courses.isNotEmpty) return courses;

        return _repository.fetchCourses(); // Fallback to general courses
      },
    );

    final bannersRequest = RemoteLoader.list<api.BannerModel>(
      label: 'home.banners',
      // No seed: when the backend has no banner we keep the mock carousel
      // declared above instead of clearing it.
      seed: const <api.BannerModel>[],
      refresh: refresh,
      fetch: _repository.fetchHomeBanners,
    );

    final heroRequest = RemoteLoader.value<api.HeroSection>(
      label: 'home.hero',
      // No seed: a failed request keeps whatever hero is already on screen,
      // which starts out as the bundled asset.
      refresh: refresh,
      fetch: _repository.fetchActiveHero,
    );

    // Teasers: `GET v1/courses/` plus each course's `GET v1/courses/{id}/`
    // trailer, already assembled by the repository. No seed — the only courses
    // that belong in this carousel are the ones that actually have a trailer.
    final introVideosRequest = RemoteLoader.list<CourseIntroVideo>(
      label: 'home.introVideos',
      seed: const <CourseIntroVideo>[],
      refresh: refresh,
      fetch: _repository.fetchCourseIntroVideos,
    );

    final categories = await categoriesRequest;
    final courses = await coursesRequest;
    final banners = await bannersRequest;
    final hero = await heroRequest;
    final introVideos = await introVideosRequest;

    if (!mounted) return;

    setState(() {
      _categories = categories.data;
      _courses = courses.data;
      _introVideos = introVideos.data;

      // A failed refresh leaves the previous hero (image and link) untouched.
      final heroSection = hero.data;
      if (heroSection != null) {
        final heroImage = heroSection.imageUrl;
        if (heroImage != null && heroImage.isNotEmpty) {
          _heroImageUrl = heroImage;
        }
        // `null` when the API sends no hero link: the image then stays inert.
        _heroLinkUrl = heroSection.linkValue;
      }

      if (banners.data.isNotEmpty) {
        _banners = banners.data
            .map(
              (banner) => BannerModel(
                imageUrl: banner.imageUrl,
                title: banner.title,
                subtitle: banner.subtitle,
                // Tapping the slide opens this in the device browser.
                linkUrl: banner.linkValue,
              ),
            )
            .toList(growable: false);
      }
    });
  }

  // ================================================================
  // NAVIGATION
  // ================================================================

  void _openCourse(Course course) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CourseDetailsScreen(course: course),
      ),
    );
  }

  /// Opens a teaser card.
  ///
  /// The card carries the whole [Course] it was built from, so the details
  /// screen opens with its real title and teacher even before the backend
  /// answers. A card whose course could not be resolved is inert rather than
  /// opening an empty screen.
  void _openIntroVideo(CourseIntroVideo video) {
    final Course? course = video.course;
    if (course == null) return;

    _openCourse(course);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => _load(refresh: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Stack(
            children: [
              ClipPath(
                clipper: BottomCurveClipper(),
                child: Container(
                  width: double.infinity,
                  height: 560.h,
                  color: AppColors.sectionBackground,
                ),
              ),
              // The content column, pinned to the viewport width.
              //
              // Without this the `Stack` sizes itself to this child in the cross
              // axis, and a `Column` that contains a **horizontal** list (the
              // teaser carousel, the promo banner) reports an unbounded width —
              // which widens the whole `Stack` past the screen and silently
              // shrinks every other section's cells.
              SizedBox(
                width: double.infinity,
                child: SafeArea(
                  child: Column(
                    children: [
                      SizedBox(height: 10.h),
                      HomeHeader(),
                      SizedBox(height: 22.h),
                      HomeHero(imageUrl: _heroImageUrl, linkUrl: _heroLinkUrl),
                      SizedBox(height: 22.h),
                      HomeCategories(categories: _categories),
                      // Scrollable promo banner with glass page indicator.
                      SizedBox(height: 29.h),
                      HomeBanner(banners: _banners),
                    SizedBox(height: 30.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 25.w),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        textDirection: TextDirection.rtl,
                        children: [
                          Container(
                            width: 123.w,
                            height: 33.h,
                            decoration: BoxDecoration(
                              color: AppColors.premium,
                              borderRadius: BorderRadius.all(
                                Radius.circular(8.r),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'دوره های محبوب',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontFamily: 'bshabnam',
                                  color: AppColors.white,
                                ),
                              ),
                            ),
                          ),

                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 25.h),
                      child: HomeCourses(onCourseTap: _openCourse),
                    ),
                    Padding(
                      padding: EdgeInsets.only(
                        top: 25.h,
                        left: 25.w,
                        right: 25.w,
                        bottom: 25.h,
                      ),
                      child: HomeQuickActions(
                        onCoursesTap: () {
                          AppRouter.toCourses(context);
                        },
                        onTeachersTap: () {
                          AppRouter.toTeachers(context);
                        },
                        onStudentsTap: () {
                          AppRouter.toStudents(context);
                        },
                        onRecipesTap: () {
                          AppRouter.toRecipes(context);
                        },
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        textDirection: TextDirection.rtl,
                        children: [
                          Container(
                            width: 123.w,
                            height: 33.h,
                            decoration: BoxDecoration(
                              color: AppColors.premium,
                              borderRadius: BorderRadius.all(
                                Radius.circular(8.r),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'معرفی دوره ها',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontFamily: 'bshabnam',
                                  color: AppColors.white,
                                ),
                              ),
                            ),
                          ),
                          _ViewAllButton(
                            onTap: () => AppRouter.toIntroductionVideos(context),
                          ),
                        ],
                      ),
                    ),

                    // The trailers themselves, in the very same carousel and
                    // card the «ویدیو های معرفی دوره» screen uses. Renders
                    // nothing at all while the list is empty, so the section
                    // header never sits above an empty strip.
                    if (_introVideos.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 18.h),
                        child: CourseIntroVideos(
                          videos: _introVideos,
                          onVideoTap: _openIntroVideo,
                        ),
                      ),

                    // Keeps the scroll view tall enough to stay pullable when
                    // the teaser list is empty.
                    SizedBox(height: 25.h),
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

/// «مشاهده همه» — the small primary pill at the end of every section header.
///
/// It used to be a bare `Container` with no gesture attached, so tapping it did
/// nothing at all. The geometry, colours and typography are unchanged; only the
/// tap handler is new.
class _ViewAllButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ViewAllButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      // The pill is mostly padding around a short label, so the whole box has
      // to be hit-testable.
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 95.w,
        height: 33.h,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.all(
            Radius.circular(8.r),
          ),
        ),
        child: Center(
          child: Text(
            'مشاهده همه',
            style: TextStyle(
              fontSize: 16.sp,
              fontFamily: 'bshabnam',
              color: AppColors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    final curveHeight = 40.h;

    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height - curveHeight);

    path.quadraticBezierTo(
      size.width / 2,
      size.height + curveHeight * 0.5,
      0,
      size.height - curveHeight,
    );

    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) {
    return false;
  }
}
