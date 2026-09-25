import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/network/remote_data.dart';
import 'package:mr_cake_project/core/router/app_router.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/data/categories_data.dart';
import 'package:mr_cake_project/data/courses_data.dart';
import 'package:mr_cake_project/models/category_model.dart';
import 'package:mr_cake_project/models/course.dart';
import 'package:mr_cake_project/pages/course_details/course_details_screen.dart';
import 'package:mr_cake_project/pages/courses/widgets/course_section.dart';
import 'package:mr_cake_project/pages/courses/widgets/courses_category.dart';
import 'package:mr_cake_project/pages/courses/widgets/courses_header.dart';
import 'package:mr_cake_project/pages/courses/widgets/courses_search.dart';
import 'package:mr_cake_project/repositories/catalog_repository.dart';

class CoursesScreen extends StatefulWidget {
  final int? categoryId;
  const CoursesScreen({super.key, this.categoryId});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final CatalogRepository _repository = CatalogRepository.instance;

  /// The bundled seed data is shown first so the screen is never blank, then
  /// replaced by the backend response (see [RemoteLoader]).
  List<CategoryModel> _categories = const [];
  List<Course> _courses = const [];

  int? _selectedCategoryId;
  String _search = '';

  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.categoryId;
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ============================================================
  // LOADING
  // ============================================================

  /// [refresh] is set by the pull-to-refresh gesture: it drops the response
  /// cache first, otherwise the pull would be served from the cache and appear
  /// to do nothing.
  Future<void> _load({bool refresh = false}) async {
    // Both requests are started before the first `await` so they run in
    // parallel.
    final categoriesRequest = RemoteLoader.list<CategoryModel>(
      label: 'courses.categories',
      seed: CategoriesData.categories,
      fetch: _repository.fetchCategories,
      refresh: refresh,
    );

    final coursesRequest = RemoteLoader.list<Course>(
      label: 'courses.list',
      seed: CoursesData.courses,
      fetch: () => _repository.fetchCourses(),
      refresh: refresh,
    );

    final categories = await categoriesRequest;
    final courses = await coursesRequest;

    if (!mounted) return;

    setState(() {
      _categories = categories.data;
      _courses = courses.data;
    });
  }

  /// Re-queries the backend whenever the category chip or the search box
  /// changes. The seed data is filtered locally so the fallback matches the
  /// active filter instead of showing everything.
  Future<void> _applyFilters() async {
    final localSeed = CoursesData.coursesByCategory(_selectedCategoryId);
    final List<Course> filteredSeed;

    if (_search.isNotEmpty) {
      final normalizedQuery = _search.toLowerCase();
      filteredSeed = localSeed.where((course) {
        return course.title.toLowerCase().contains(normalizedQuery) ||
            course.instructorFullName.toLowerCase().contains(normalizedQuery);
      }).toList(growable: false);
    } else {
      filteredSeed = localSeed;
    }

    final result = await RemoteLoader.list<Course>(
      label: 'courses.filtered',
      seed: filteredSeed,
      fetch: () => _repository.fetchCourses(
        categoryId: _selectedCategoryId,
        search: _search.isEmpty ? null : _search,
      ),
    );

    if (!mounted) return;
    setState(() => _courses = result.data);
  }

  void _onCategorySelected(CategoryModel? category) {
    setState(() => _selectedCategoryId = category?.id);
    _applyFilters();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() => _search = value.trim());
      _applyFilters();
    });
  }

  // ============================================================
  // COURSES BY TYPE
  // ============================================================

  List<Course> get _freeCourses => _courses
      .where((course) => course.type == CourseType.free)
      .toList(growable: false);

  List<Course> get _professionalCourses => _courses
      .where((course) => course.type == CourseType.professional)
      .toList(growable: false);

  List<Course> get _singleCourses => _courses
      .where((course) => course.type == CourseType.single)
      .toList(growable: false);

  void _openCourse(Course course) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CourseDetailsScreen(course: course),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.sectionBackground,
            borderRadius: BorderRadius.only(topRight: Radius.circular(40.r)),
          ),
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => _load(refresh: true),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  CoursesHeader(
                    onCartTap: () => AppRouter.toCart(context),
                  ),
                  CoursesSearch(
                    onChanged: _onSearchChanged,
                  ),
                  SizedBox(height: 16.h),
                  CoursesCategories(
                    categories: _categories,
                    onCategorySelected: _onCategorySelected,
                  ),
                  CourseSection(
                    title: 'از اینجا شروع کن',
                    courses: _freeCourses,
                    onCourseTap: _openCourse,
                    onViewAll: () {},
                  ),
                  CourseSection(
                    title: 'حرفه‌ای شو',
                    courses: _professionalCourses,
                    onCourseTap: _openCourse,
                    onViewAll: () {},
                  ),
                  CourseSection(
                    title: 'تک آموزشی',
                    courses: _singleCourses,
                    onCourseTap: _openCourse,
                    onViewAll: () {},
                  ),
                  if (_courses.isEmpty) _buildEmptyState(),
                  SizedBox(height: 25.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Shown only when the backend really has nothing to offer for the active
  /// filter — the seed fallback normally keeps this invisible.
  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w, vertical: 60.h),
      child: Column(
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 52.sp,
            color: AppColors.premium,
          ),
          SizedBox(height: 15.h),
          Text(
            'اگه عاشق دنیای شیرینی‌پزی هستی، اینجا کم‌کم خونه‌ی آموزشیت میشه. ❤️\n\nبه‌زودی کلی آموزش، دوره، تکنیک‌های کاربردی و رسپی‌های جذاب به این بخش اضافه میشه…\n\nصبر کن، چیزای خیلی خفنی در راهه! 🔥',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'bshabnam',
              fontSize: 16.sp,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
