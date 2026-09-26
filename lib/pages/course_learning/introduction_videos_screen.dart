import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/network/remote_data.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../models/course.dart';
import '../../models/course_intro_video.dart';
import '../../repositories/catalog_repository.dart';
import '../course_details/course_details_screen.dart';
import '../home/widgets/course_intro_video_card.dart';

/// «ویدیو های معرفی دوره» — every course trailer in the catalogue.
///
/// This is the expanded version of the home «معرفی دوره ها» carousel: **the very
/// same data** (`GET v1/courses/` plus each course's `GET v1/courses/{id}/`
/// trailer) and **the very same card** ([CourseIntroVideoCard]), laid out as a
/// two-column grid instead of a swipeable strip.
///
/// Reading the two screens together is the point — a change to the card on one
/// is a change on the other, so the two can never drift apart.
///
/// Follows the house layout for a pushed gallery ([StudentsScreen] /
/// [RecipesScreen]): no `AppBar`, a `pinarb` title with the app's premium back
/// pill, `AppColors` throughout, and the shared icon-over-text empty state.
///
/// ⚠️ **The grid carries no section heading.** The screen's own `pinarb` title
/// already says «ویدیو های معرفی دوره», and every card on it is a video — so a
/// «معرفی دوره ها» pill above the grid repeated the header and was removed on
/// request. Do not add it back.
class IntroductionVideosScreen extends StatefulWidget {
  const IntroductionVideosScreen({super.key});

  @override
  State<IntroductionVideosScreen> createState() =>
      _IntroductionVideosScreenState();
}

class _IntroductionVideosScreenState extends State<IntroductionVideosScreen> {
  final CatalogRepository _repository = CatalogRepository.instance;

  List<CourseIntroVideo> _videos = const [];

  bool _isLoading = true;

  /// Set when the teasers could not be read, so the empty state can say *why*
  /// instead of pretending the catalogue has none.
  String? _message;

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
  }

  Future<void> _load({bool refresh = false}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final result = await RemoteLoader.list<CourseIntroVideo>(
      label: 'introductionVideos',
      // No seed: a course without a `video_trailer` has no teaser at all, and a
      // card built from a course with no trailer would open a player that has
      // nothing to play.
      seed: const <CourseIntroVideo>[],
      refresh: refresh,
      fetch: _repository.fetchCourseIntroVideos,
    );

    if (!mounted) return;

    setState(() {
      _videos = result.data;
      _message = result.hasError ? result.message : null;
      _isLoading = false;
    });
  }

  /// Opens the course behind a teaser.
  ///
  /// The card carries the whole [Course] it was built from, so the details
  /// screen paints its real title and teacher on the first frame. A card whose
  /// course could not be resolved would open an empty screen, so it is inert.
  void _openCourse(CourseIntroVideo video) {
    final Course? course = video.course;
    if (course == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CourseDetailsScreen(course: course),
      ),
    );
  }

  /// Opens a teaser in the dedicated player page.
  ///
  /// The **whole grid** travels with the tap, so the player can list the other
  /// trailers underneath and play them in place — the user keeps browsing
  /// without bouncing back through this screen.
  ///
  /// A card whose trailer url is empty is still allowed through: the player has
  /// its own «پخش ویدیو امکان‌پذیر نیست» panel with a retry, which is a better
  /// answer than a card that silently does nothing.
  void _playTeaser(CourseIntroVideo video) {
    AppRouter.toIntroductionVideoPlayer(
      context,
      video: video,
      playlist: _videos,
    );
  }

  /// What to show when there is no teaser to list.
  String get _emptyMessage => _message ?? 'هنوز ویدیوی معرفی دوره‌ای ثبت نشده.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),

            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_videos.isEmpty)
              SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState())
            else ...[
              // No section heading: the screen's own title already frames the
              // grid, and every card on it is a video. See the class doc.
              SliverPadding(
                padding: EdgeInsets.only(
                  top: 4.h,
                  left: 25.w,
                  right: 25.w,
                  bottom: 30.h,
                ),
                sliver: _buildGrid(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  /// The app's screen header: the title on the right, a bordered premium pill
  /// on the left. Identical geometry to «رسپی ها» and «هنرجوها».
  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.only(
        left: 25.w,
        right: 25.w,
        top: 18.h,
        bottom: 18.h,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        textDirection: TextDirection.rtl,
        children: [
          // The title is long enough to collide with the button on a narrow
          // landscape phone, so it yields rather than overflowing.
          Flexible(
            child: Text(
              'ویدیو های معرفی دوره',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'pinarb',
                fontSize: 20.sp,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: AppColors.premium.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: AppColors.premium, width: 1.5.w),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_back_ios_rounded,
                size: 19.sp,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // GRID
  // ==========================================================================

  /// Two columns, each cell a [CourseIntroVideoCard].
  ///
  /// A fixed `mainAxisExtent` rather than an aspect ratio, because **the card's
  /// text block does not scale with the card width** — it is driven by `.sp`,
  /// which follows the screen *width* while `.h` follows the height. An aspect
  /// ratio would clip the title on a tall narrow phone and leave a gap on a
  /// short wide one.
  Widget _buildGrid() {
    return SliverLayoutBuilder(
      builder: (BuildContext context, SliverConstraints constraints) {
        // The cell the card actually gets, after the gutter and the page
        // padding `SliverPadding` already applied.
        final double cellWidth = (constraints.crossAxisExtent - 16.w) / 2;

        // `AspectRatio(222 / 121)` on the card's thumbnail.
        final double thumbnailHeight = cellWidth * 121 / 222;

        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16.w,
            mainAxisSpacing: 24.h,
            mainAxisExtent: thumbnailHeight + _cardInfoHeight(),
          ),          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              final CourseIntroVideo video = _videos[index];

              return CourseIntroVideoCard(
                video: video,
                onTap: () => _playTeaser(video),
                onCourseTap: () => _openCourse(video),
              );
            },
            childCount: _videos.length,
          ),
        );
      },
    );
  }

  /// The height of the card's text block, measured off [CourseIntroVideoCard].
  ///
  /// 10.h gap; a two-line title at `14.sp × 1.35`; 7.h; the teacher line at
  /// `14.sp × 1.2`; 6.h; the duration/students line at `14.sp × 1.2`; then the
  /// 8.h gap and the 30.h «مشاهده دوره» pill the grid adds.
  ///
  /// ## ⚠️ Not a constant — the text scale is the screen *width*, not the height
  ///
  /// Every `.h` term below tracks the screen height while every text line tracks
  /// the screen **width** (`.sp` is `value * scaleWidth` in this project). The
  /// two only agree on the reference device, so a formula written entirely in
  /// `.h` under-reserves on a wide screen: at 1024×768 the text asked for ~45 px
  /// more than the cell had and the card painted a `RenderFlex overflowed`
  /// stripe. Reserving from the **actual glyph sizes** — `.sp` for the lines,
  /// `.h` for the real gaps — is what keeps the two in step on every device.
  ///
  /// [CourseIntroVideoCard] also wraps this block in a `Flexible`, so a small
  /// mis-estimate clips a long title instead of overflowing the cell. That is
  /// deliberate belt-and-braces: this number is a reservation, not a guarantee.
  static double _cardInfoHeight() {
    // `0.25` covers what the engine adds over `fontSize * height` when it
    // rounds each line box to whole pixels.
    const double slack = 1.25;

    final double titleLine = 14.sp * 1.35 * slack;
    final double metaLine = 14.sp * 1.2 * slack;

    return 10.h +
        (titleLine * 2) +
        7.h +
        metaLine +
        6.h +
        metaLine +
        8.h +
        30.h +
        4.h;
  }

  // ==========================================================================
  // EMPTY STATE
  // ==========================================================================

  /// The app-wide empty state — an icon over a centred line — the same shape
  /// the courses screens and «رسپی ها» use.
  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w, vertical: 50.h),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 52.sp,
            color: AppColors.premium,
          ),
          SizedBox(height: 15.h),
          Text(
            _emptyMessage,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'bshabnam',
              fontSize: 16.sp,
              color: AppColors.textPrimary,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}
