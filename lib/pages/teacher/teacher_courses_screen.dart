import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/network/remote_data.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/models/course.dart';
import 'package:mr_cake_project/pages/course_details/course_details_screen.dart';
import 'package:mr_cake_project/pages/home/widgets/course_card.dart';
import 'package:mr_cake_project/repositories/catalog_repository.dart';

class TeacherCoursesScreen extends StatefulWidget {
  const TeacherCoursesScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
  });

  final int teacherId;
  final String teacherName;

  @override
  State<TeacherCoursesScreen> createState() => _TeacherCoursesScreenState();
}

class _TeacherCoursesScreenState extends State<TeacherCoursesScreen> {
  final CatalogRepository _repository = CatalogRepository.instance;

  List<Course> _courses = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      if (refresh) {
        _courses = const [];
        _isLoading = true;
      }
      _errorMessage = null;
    });

    try {
      final result = await RemoteLoader.list<Course>(
        label: 'teacher.courses.${widget.teacherId}',
        seed: const [],
        fetch: () => _repository.fetchCourses(teacherId: widget.teacherId),
        refresh: refresh,
      );

      if (!mounted) return;

      setState(() {
        _courses = result.data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => _load(refresh: true),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                SizedBox(height: 10.h),
                if (_isLoading)
                  _buildLoadingState()
                else if (_errorMessage != null)
                  _buildErrorState(_errorMessage!)
                else if (_courses.isEmpty)
                  _buildEmptyState()
                else
                  _buildCoursesGrid(),
                SizedBox(height: 30.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
          Expanded(
            child: Text(
              'دوره‌های استاد ${widget.teacherName}',
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'pinarb',
                fontSize: 20.sp,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          SizedBox(width: 15.w),
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
                border: Border.all(
                  color: AppColors.premium,
                  width: 1.5.w,
                ),
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

  Widget _buildLoadingState() {
    return Padding(
      padding: EdgeInsets.only(top: 80.h),
      child: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w, vertical: 60.h),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 52.sp,
            color: AppColors.primary,
          ),
          SizedBox(height: 15.h),
          Text(
            'خطا در بارگذاری دوره‌ها:\n$error',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'bshabnam',
              fontSize: 15.sp,
              color: AppColors.textPrimary,
              height: 1.8,
            ),
          ),
          SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            height: 50.h,
            child: Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14.r),
              child: InkWell(
                onTap: () => _load(refresh: true),
                borderRadius: BorderRadius.circular(14.r),
                child: Center(
                  child: Text(
                    'تلاش دوباره',
                    style: TextStyle(
                      fontFamily: 'bShabnam',
                      fontSize: 16.sp,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
            'استاد ${widget.teacherName} هنوز دوره‌ای در پلتفرم مستر کیک ثبت نکرده است.\n\nبه‌زودی دوره‌های جذاب و تخصصی این استاد به این بخش اضافه خواهد شد.',
            textAlign: TextAlign.center,
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

  Widget _buildCoursesGrid() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 20.w,
          mainAxisSpacing: 22.h,
          mainAxisExtent: 267.h,
        ),
        itemCount: _courses.length,
        itemBuilder: (BuildContext context, int index) {
          final Course course = _courses[index];
          return CourseCard(
            course: course,
            onTap: () => _openCourse(course),
          );
        },
      ),
    );
  }

  void _openCourse(Course course) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CourseDetailsScreen(course: course),
      ),
    );
  }
}
