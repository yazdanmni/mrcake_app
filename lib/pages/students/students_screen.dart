import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/network/remote_data.dart';
import '../../core/theme/app_colors.dart';
import '../../models/explore_video.dart';
import '../../models/teacher_model.dart';
import '../../repositories/catalog_repository.dart';
import '../explore/widgets/reels_viewer.dart';
import '../teacher/widgets/teacher_portfolio_grid.dart';

/// «هنرجوها» — the students' works, opened from the home shortcut.
///
/// The screen shows **only نمونه کارها**: the works a teacher published for
/// their students, read from `GET v1/accounts/teacher-portfolios/` — the same
/// endpoint the teacher profile reads — and rendered with the very same
/// [TeacherPortfolioGrid], so the two galleries are pixel-identical.
///
/// Tapping a work opens it in the **Explore-style vertical player**
/// ([ReelsViewer]), swiping through the whole gallery. The teacher profile
/// instead opens its own `TeacherPortfolioViewer`; this page follows Explore.
///
/// The account roster (`GET v1/accounts/users/?role=user`) is deliberately
/// **not** shown here: the page is the gallery, not a people list.
///
/// The gallery is readable by anyone (`security: [{jwtAuth: []}, {}]`), so the
/// screen works for a signed-out visitor too.
class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final CatalogRepository _repository = CatalogRepository.instance;
  final ScrollController _scrollController = ScrollController();

  final List<TeacherPortfolioItem> _portfolio = [];
  int _portfolioPage = 1;
  bool _isLoadingPortfolio = false;
  bool _hasMorePortfolio = true;

  /// Set when the gallery could not be read, so the empty state can explain
  /// *why* instead of just saying there is nothing.
  String? _portfolioMessage;

  /// `teacher profile id -> teacher`, used to caption a work in the viewer.
  ///
  /// Best-effort: the viewer wants a full [Teacher] for the avatar + name, but a
  /// portfolio row does not name its owner (see [_resolveTeacher]). When the
  /// lookup is missing the viewer drops the row rather than inventing a teacher.
  final Map<int, Teacher> _teachers = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadPortfolio(refresh: true);
    _loadTeachers();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPortfolio({bool refresh = false}) async {
    if (refresh) {
      _portfolioPage = 1;
      _hasMorePortfolio = true;
      _portfolio.clear();
    }

    if (!_hasMorePortfolio || _isLoadingPortfolio) return;

    setState(() {
      _isLoadingPortfolio = true;
    });

    try {
      final result = await RemoteLoader.list<TeacherPortfolioItem>(
        label: 'students.portfolio.page$_portfolioPage',
        seed: const [],
        fetch: () => _repository.fetchTeacherPortfolio(page: _portfolioPage),
      );

      if (!mounted) return;

      setState(() {
        _portfolio.addAll(result.data);
        _portfolioMessage = result.message;
        _portfolioPage++;
        _hasMorePortfolio = result.data.isNotEmpty;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPortfolio = false;
        });
      }
    }
  }

  /// Resolves the owner of every work so the viewer can caption it.
  ///
  /// Never surfaces an error: the gallery is perfectly usable without a
  /// caption, so a failure here must not take the screen down.
  Future<void> _loadTeachers() async {
    try {
      final result = await RemoteLoader.list<Teacher>(
        label: 'students.teachers',
        seed: const [],
        fetch: () => _repository.fetchTeachers(),
      );

      if (!mounted) return;

      setState(() {
        _teachers
          ..clear()
          ..addEntries(result.data.map((t) => MapEntry(t.id, t)));
      });
    } catch (_) {
      // A missing caption is not worth an error state.
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels !=
        _scrollController.position.maxScrollExtent) {
      return;
    }

    if (_hasMorePortfolio) _loadPortfolio();
  }

  /// Opens the tapped work in the Explore-style vertical player, swiping
  /// through the whole gallery.
  void _openPortfolio(TeacherPortfolioItem item) {
    final int index = _portfolio.indexWhere(
      (element) => element.id == item.id,
    );

    if (index == -1) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReelsViewer(
          videos: _portfolio.map(_toReel).toList(growable: false),
          initialIndex: index,
        ),
      ),
    );
  }

  /// The owner of a work, for the viewer's instructor chip.
  ///
  /// ⚠️ The `accounts/teacher-portfolios/` payload has **no `teacher` field** —
  /// only the `student` the work belongs to — so `item.teacherId` is always 0
  /// and can never be looked up directly. The gallery spans teachers, but the
  /// backend currently holds a single verified one, so fall back to it: the
  /// alternative is silently losing the chip the teacher profile shows. If
  /// several teachers exist and the row cannot be attributed, return null and
  /// the viewer drops the chip rather than guessing.
  Teacher? _resolveTeacher(TeacherPortfolioItem item) {
    final Teacher? byId = _teachers[item.teacherId];
    if (byId != null) return byId;

    final List<Teacher> verified = _teachers.values
        .where((teacher) => teacher.isVerified)
        .toList(growable: false);

    return verified.length == 1 ? verified.first : null;
  }

  /// Maps a portfolio item onto the model the Explore viewer speaks.
  ///
  /// A work carries one media url: `video` for a video, `image` for a picture.
  /// An **image** work therefore maps to a thumbnail with **no** video url,
  /// which [ReelsViewer] renders as a still rather than as a playback failure.
  ExploreVideo _toReel(TeacherPortfolioItem item) {
    final Teacher? teacher = _resolveTeacher(item);

    return ExploreVideo(
      id: item.id,
      videoUrl: item.videoUrl ?? '',
      thumbnail: item.image,
      title: item.description,
      instructorId: teacher?.id ?? item.teacherId,
      instructorFirstName: teacher?.firstName ?? '',
      instructorLastName: teacher?.lastName ?? '',
      instructorImage: teacher?.profileImage ?? '',
      duration: 0,
      description: item.description,
    );
  }

  /// What to show when the gallery has nothing in it.
  String get _emptyMessage => _portfolioMessage ?? 'هنوز نمونه‌کاری ثبت نشده.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'هنرجوها',
          style: TextStyle(
            fontFamily: 'pinarb',
            fontSize: 20.sp,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
          },
          child: Icon(
            Icons.arrow_back_ios_rounded,
            size: 24.sp,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 12.h),

              // Matches the teacher profile's «نمونه کارهای هنرجو های استاد»
              // heading, so the two galleries read as the same block.
              _buildSectionTitle('نمونه کارهای هنرجوها'),

              SizedBox(height: 18.h),

              if (_portfolio.isNotEmpty)
                TeacherPortfolioGrid(
                  items: _portfolio,
                  onItemTap: _openPortfolio,
                )
              else if (!_isLoadingPortfolio)
                _buildEmptyState(),

              if (_isLoadingPortfolio)
                Padding(
                  padding: EdgeInsets.all(16.h),
                  child: const Center(child: CircularProgressIndicator()),
                ),

              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w),
      child: Text(
        title,
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: 'bShabnam',
          fontSize: 20.sp,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  /// The app-wide empty state — an icon over a centred line — the same shape the
  /// courses screens and «رسپی‌ها» use.
  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w, vertical: 50.h),
      child: Column(
        children: [
          Icon(
            Icons.photo_library_outlined,
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
