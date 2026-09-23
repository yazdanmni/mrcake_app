import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/network/remote_data.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/models/category_model.dart';
import 'package:mr_cake_project/models/course.dart';
import 'package:mr_cake_project/pages/course_details/course_details_screen.dart';
import 'package:mr_cake_project/pages/courses/widgets/course_section.dart';
import 'package:mr_cake_project/repositories/catalog_repository.dart';

class CourseCategoriesScreen extends StatefulWidget {
  final int? categoryId;
  final String? categoryTitle;

  const CourseCategoriesScreen({super.key, this.categoryId, this.categoryTitle});

  @override
  State<CourseCategoriesScreen> createState() => _CourseCategoriesScreenState();
}

class _CourseCategoriesScreenState extends State<CourseCategoriesScreen> {
  final CatalogRepository _repository = CatalogRepository.instance;

  List<CategoryModel> _categories = const [];
  List<Course> _courses = const [];

  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    if (widget.categoryId != null) {
      _selectedCategoryId = widget.categoryId;
      // No need to call _applyFilter here, _load() will handle it.
    }
    _load();
  }

  // ============================================================
  // LOADING
  // ============================================================

  Future<void> _load() async {
    final categoriesRequest = RemoteLoader.list<CategoryModel>(
      label: 'categories.tree',
      fetch: () async {
        // The tree endpoint also carries the children, so it is preferred and
        // the flat list is the fallback when the tree is unavailable.
        final tree = await _repository.fetchCategoryTree();
        if (tree.isNotEmpty) return tree;
        return _repository.fetchCategories();
      },
    );

    final coursesRequest = RemoteLoader.list<Course>(
      label: 'categories.courses',
      fetch: () => _repository.fetchCourses(),
    );

    final categories = await categoriesRequest;
    final courses = await coursesRequest;

    if (!mounted) return;

    setState(() {
      _categories = categories.data;
      _courses = courses.data;
    });
  }

  /// Re-queries the backend for the selected category. The local seed is
  /// filtered too, so the fallback matches the active chip.
  Future<void> _applyFilter() async {
    final result = await RemoteLoader.list<Course>(
      label: 'categories.filtered',
      fetch: () => _repository.fetchCourses(categoryId: _selectedCategoryId),
    );

    if (!mounted) return;
    setState(() => _courses = result.data);
  }

  // ============================================================
  // FILTERING
  // ============================================================

  List<Course> get _filteredCourses {
    if (_selectedCategoryId == null) return _courses;

    return _courses
        .where((course) => course.categoryIds.contains(_selectedCategoryId))
        .toList(growable: false);
  }

  List<Course> get _freeCourses {
    return _filteredCourses
        .where((course) => course.type == CourseType.free)
        .toList();
  }

  List<Course> get _professionalCourses {
    return _filteredCourses
        .where((course) => course.type == CourseType.professional)
        .toList();
  }

  List<Course> get _singleCourses {
    return _filteredCourses
        .where((course) => course.type == CourseType.single)
        .toList();
  }

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
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),

              if (widget.categoryId == null)
                SliverToBoxAdapter(child: _buildCategories()),

              SliverToBoxAdapter(child: _buildCourseSections()),

              SliverToBoxAdapter(child: SizedBox(height: 30.h)),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

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
        children: [
          Text(
            widget.categoryTitle ?? 'دسته‌بندی دوره‌ها',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'pinarb',
              fontSize: 20.sp,
              color: AppColors.textPrimary,
            ),
          ),

          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.of(context).pop();
            },
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
                Icons.arrow_forward_ios_rounded,
                size: 19.sp,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CATEGORIES
  // ============================================================

  Widget _buildCategories() {
    return SizedBox(
      height: 94.h,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _categories.length + 1,
        separatorBuilder: (BuildContext context, int index) {
          return SizedBox(width: 10.w);
        },
        itemBuilder: (BuildContext context, int index) {
          // اولین گزینه = همه
          if (index == 0) {
            return _CategoryItem(
              title: 'همه',
              image: null,
              isSelected: _selectedCategoryId == null,
              onTap: () {
                setState(() {
                  _selectedCategoryId = null;
                });
                _applyFilter();
              },
            );
          }

          final CategoryModel category = _categories[index - 1];

          return _CategoryItem(
            title: category.title,
            image: category.image,
            isSelected: _selectedCategoryId == category.id,
            onTap: () {
              setState(() {
                _selectedCategoryId = category.id;
              });
              _applyFilter();
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // COURSE SECTIONS
  // ============================================================

  Widget _buildCourseSections() {
    return Column(
      children: [
        if (_freeCourses.isNotEmpty)
          CourseSection(
            title: 'از اینجا شروع کن',
            courses: _freeCourses,
            onCourseTap: _openCourse,
            onViewAll: () {
              // TODO:
              // مشاهده همه دوره‌های رایگان
            },
          ),

        if (_professionalCourses.isNotEmpty)
          CourseSection(
            title: 'حرفه ای شو',
            courses: _professionalCourses,
            onCourseTap: _openCourse,
            onViewAll: () {
              // TODO:
              // مشاهده همه دوره‌های حرفه‌ای
            },
          ),

        if (_singleCourses.isNotEmpty)
          CourseSection(
            title: 'تک‌آموزشی',
            courses: _singleCourses,
            onCourseTap: _openCourse,
            onViewAll: () {
              // TODO:
              // مشاهده همه تک‌آموزشی‌ها
            },
          ),

        if (_filteredCourses.isEmpty) _buildEmptyState(),
      ],
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w, vertical: 70.h),
      child: Column(
        children: [
          Icon(Icons.menu_book_outlined, size: 52.sp, color: AppColors.premium),
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

// ================================================================
// CATEGORY ITEM
// ================================================================

class _CategoryItem extends StatelessWidget {
  final String title;
  final String? image;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryItem({
    required this.title,
    required this.image,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: 82.w,
        height: 88.h,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.premium
              : AppColors.premium.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: AppColors.premium, width: 2.w),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.premium.withValues(alpha: 0.18),
                    blurRadius: 12.r,
                    offset: Offset(0, 5.h),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (image != null && image!.isNotEmpty)
                  Image.network(
                    image!,
                    width: 34.w,
                    height: 34.w,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.category_outlined,
                        size: 28.sp,
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textPrimary,
                      );
                    },
                  )
                else
                  Icon(
                    Icons.grid_view_rounded,
                    size: 28.sp,
                    color: isSelected ? AppColors.textPrimary : AppColors.textPrimary,
                  ),

                SizedBox(height: 6.h),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'shabnam',
                      fontSize: 13.sp,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
