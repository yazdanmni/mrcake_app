import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/network/remote_data.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/core/router/app_router.dart';
import 'package:mr_cake_project/models/teacher_model.dart';
import 'package:mr_cake_project/repositories/catalog_repository.dart';

import 'dart:async';

class TeachersListScreen extends StatefulWidget {
  const TeachersListScreen({super.key});

  @override
  State<TeachersListScreen> createState() => _TeachersListScreenState();
}

class _TeachersListScreenState extends State<TeachersListScreen> {
  final CatalogRepository _repository = CatalogRepository.instance;
  final ScrollController _scrollController = ScrollController();

  List<Teacher> _teachers = [];
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMoreTeachers = true;

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMoreTeachers = true;
      _teachers.clear();
    }

    if (!_hasMoreTeachers || _isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final newTeachers = await RemoteLoader.list<Teacher>(
        label: 'teachers.page$_currentPage',
        seed: const [], // Added missing seed parameter
        fetch: () => _repository.fetchTeachers(page: _currentPage),
      );

      if (!mounted) return;

      setState(() {
        _teachers.addAll(newTeachers.data);
        _currentPage++;
        _hasMoreTeachers = newTeachers.data.isNotEmpty;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent &&
        !_isLoadingMore &&
        _hasMoreTeachers) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'استادان',
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
            children: [
              if (_teachers.isEmpty && !_isLoadingMore)
                Padding(
                  padding: EdgeInsets.all(25.w),
                  child: Center(
                    child: Text(
                      'استادی یافت نشد.',
                      style: TextStyle(
                        fontFamily: 'shabnam',
                        fontSize: 16.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 25.w, vertical: 10.h),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 20.w,
                    mainAxisSpacing: 20.h,
                    mainAxisExtent: 220.h,
                  ),
                  itemCount: _teachers.length,
                  itemBuilder: (BuildContext context, int index) {
                    final teacher = _teachers[index];
                    return _buildTeacherCard(teacher);
                  },
                ),
              if (_isLoadingMore)
                Padding(
                  padding: EdgeInsets.all(16.h),
                  child: const CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherCard(Teacher teacher) {
    return GestureDetector(
      onTap: () {
        AppRouter.toTeacherDetail(
          context,
          teacherId: teacher.id,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: AppColors.border,
            width: 2.w,
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: 10.h),
            ClipOval(
              child: Image.network(
                teacher.profileImage,
                width: 80.w,
                height: 80.w,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Container(
                    color: AppColors.field,
                    alignment: Alignment.center,
                    width: 80.w,
                    height: 80.w,
                    child: Icon(
                      Icons.person_outline_rounded,
                      size: 40.sp,
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
                    width: 80.w,
                    height: 80.w,
                    child: SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 10.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (teacher.isVerified)
              Icon(
                Icons.verified_rounded,
                size: 18.sp,
                color: Colors.blue,
              ),
                Text(
                  'استاد ${teacher.lastName}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'bShabnam',
                    fontSize: 16.sp,
                    color: AppColors.textPrimary,
                  ),
                ),
                
              ],
            ),
            if (teacher.expertise.isNotEmpty)
            Text(
                teacher.expertise,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'shabnam',
                  fontSize: 14.sp,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                teacher.about.characters.take(40).toString() + (teacher.about.length > 10 ? '...' : ''),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'shabnam',
                  fontSize: 14.sp,
                  color: AppColors.textSecondary,
                ),
              ),
            
          ],
        ),
      ),
    );
  }
}
