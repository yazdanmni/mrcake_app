import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/models/teacher_model.dart';
import 'package:mr_cake_project/pages/teacher/widgets/teacher_portfolio_viewer.dart';

import '../../core/network/remote_data.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_feedback.dart';
import '../../data/teacher_data.dart';
import '../../repositories/catalog_repository.dart';
import 'widgets/teacher_portfolio_grid.dart';

class TeacherScreen extends StatefulWidget {
  final int teacherId;

  const TeacherScreen({
    super.key,
    required this.teacherId,
  });

  @override
  State<TeacherScreen> createState() => _TeacherScreenState();
}

class _TeacherScreenState extends State<TeacherScreen> {
  /// ابتدا داده آفلاین (اگر موجود باشد)، سپس پاسخ بک‌اند.
  Teacher? _teacher;

  bool _isLoading = true;

  bool _showFullAbout = false;

  @override
  void initState() {
    super.initState();

    _teacher = TeacherData.getTeacherById(widget.teacherId);

    _load();
  }

  Future<void> _load() async {
    final result = await RemoteLoader.value<Teacher>(
      label: 'teacher.detail',
      seed: _teacher,
      fetch: () async {
        final teacher = await CatalogRepository.instance.fetchTeacher(
          widget.teacherId,
        );

        if (teacher == null) return null;

        // نمونه‌کارها از یک اندپوینت جداگانه می‌آیند.
        final portfolio = await CatalogRepository.instance
            .fetchTeacherPortfolio(teacherId: widget.teacherId);

        return portfolio.isEmpty ? teacher : teacher.withPortfolio(portfolio);
      },
    );

    if (!mounted) return;

    setState(() {
      _teacher = result.data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Teacher? currentTeacher = _teacher;

    if (currentTeacher == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: _isLoading
                ? const InlineLoader(color: AppColors.primary)
                : Text(
                    'صفحه استاد در دسترس نیست',
                    style: TextStyle(
                      fontFamily: 'Shabnam',
                      fontSize: 16.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),

              SizedBox(height: 22.h),

              _buildTeacherProfile(currentTeacher),

              SizedBox(height: 35.h),

              _buildAboutSection(currentTeacher),

              SizedBox(height: 20.h),

              _buildTeacherCoursesButton(),

              SizedBox(height: 27.h),

              _buildPortfolioTitle(),

              SizedBox(height: 18.h),

              TeacherPortfolioGrid(
                items: currentTeacher.portfolio,
                onItemTap: (item) {
                  _openPortfolioViewer(
                    currentTeacher,
                    item,
                  );
                },
              ),

              SizedBox(height: 30.h),
            ],
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
          Text(
            'استاد',
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

  Widget _buildTeacherProfile(Teacher teacher) {
    return Column(
      children: [
        _buildProfileImage(teacher),

        SizedBox(height: 15.h),

        _buildTeacherName(teacher),

        SizedBox(height: 22.h),

        _buildStats(teacher),
      ],
    );
  }

  Widget _buildProfileImage(Teacher teacher) {
    return Container(
      width: 112.w,
      height: 112.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.premium,
          width: 2.w,
        ),
      ),
      child: ClipOval(
        child: Image.network(
          teacher.profileImage,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return Container(
              color: AppColors.field,
              alignment: Alignment.center,
              child: Icon(
                Icons.person_outline_rounded,
                size: 45.sp,
                color: AppColors.textSecondary,
              ),
            );
          },
          loadingBuilder: (
            context,
            child,
            loadingProgress,
          ) {
            if (loadingProgress == null) {
              return child;
            }

            return Container(
              color: AppColors.field,
              alignment: Alignment.center,
              child: SizedBox(
                width: 24.w,
                height: 24.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTeacherName(Teacher teacher) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'استاد ${teacher.fullName}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Shabnam',
              fontSize: 20.sp,
              color: AppColors.textSecondary,
            ),
          ),

          if (teacher.isVerified) ...[
            SizedBox(width: 7.w),
            Icon(
              Icons.verified_rounded,
              size: 21.sp,
              color: Colors.blue,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStats(Teacher teacher) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 25.w,
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatBox(
            title: 'تعداد دوره',
            value: _formatCount(
              teacher.courseCount,
            ),
          ),
          _buildStatBox(
            title: 'سابقه',
            value: '${teacher.experienceYears} سال',
          ),
          _buildStatBox(
            title: 'تعداد هنرجو',
            value: _formatStudents(
              teacher.studentsCount,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required String title,
    required String value,
  }) {
    return Container(
      width: 81.w,
      height: 81.w,
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: AppColors.premium,
          width: 2.w,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'bShabnam',
              fontSize: 15.sp,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 5.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Shabnam',
              fontSize: 11.sp,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(Teacher teacher) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 25.w,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'درباره استاد',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'bShabnam',
              fontSize: 20.sp,
              color: AppColors.textPrimary,
            ),
          ),

          SizedBox(height: 12.h),

          AnimatedContainer(
            duration: const Duration(
              milliseconds: 250,
            ),
            width: double.infinity,
            constraints: BoxConstraints(
              minHeight: 158.h,
            ),
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.field,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: AppColors.premium,
                width: 2.w,
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                Text(
                  teacher.about,
                  textAlign: TextAlign.justify,
                  maxLines: _showFullAbout ? null : 5,
                  overflow: _showFullAbout
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Shabnam',
                    fontSize: 16.sp,
                    color: AppColors.textSecondary,
                    height: 1.8,
                  ),
                ),

                if (!_showFullAbout &&
                    teacher.about.length > 250) ...[
                  SizedBox(height: 8.h),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      behavior:
                          HitTestBehavior.opaque,
                      onTap: () {
                        setState(() {
                          _showFullAbout = true;
                        });
                      },
                      child: Padding(
                        padding: EdgeInsets.all(4.w),
                        child: Text(
                          'بیشتر...',
                          style: TextStyle(
                            fontFamily: 'bShabnam',
                            fontSize: 14.sp,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherCoursesButton() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 25.w,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 64.h,
        child: Material(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16.r),
          child: InkWell(
            onTap: () {},
            borderRadius:
                BorderRadius.circular(16.r),
            child: Center(
              child: Text(
                'دوره‌های استاد',
                style: TextStyle(
                  fontFamily: 'bShabnam',
                  fontSize: 20.sp,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPortfolioTitle() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 25.w,
      ),
      child: Text(
        'نمونه کارهای هنرجو های استاد',
        textAlign: TextAlign.right,
        style: TextStyle(
          fontFamily: 'bShabnam',
          fontSize: 20.sp,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  void _openPortfolioViewer(
    Teacher teacher,
    TeacherPortfolioItem item,
  ) {
    final int index = teacher.portfolio.indexWhere(
      (element) => element.id == item.id,
    );

    if (index == -1) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeacherPortfolioViewer(
          teacher: teacher,
          items: teacher.portfolio,
          initialIndex: index,
        ),
      ),
    );
  }

  String _formatCount(int number) {
    return number.toString();
  }

  String _formatStudents(int number) {
    if (number >= 1000000) {
      final double value = number / 1000000;

      if (value == value.roundToDouble()) {
        return '${value.toInt()}M';
      }

      return '${value.toStringAsFixed(1)}M';
    }

    if (number >= 1000) {
      final double value = number / 1000;

      if (value == value.roundToDouble()) {
        return '${value.toInt()}K';
      }

      return '${value.toStringAsFixed(1)}K';
    }

    return number.toString();
  }
}