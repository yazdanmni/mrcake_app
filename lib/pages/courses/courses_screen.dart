import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/data/categories_data.dart';
import 'package:mr_cake_project/data/courses_data.dart';
import 'package:mr_cake_project/models/course.dart';
import 'package:mr_cake_project/pages/course_details/course_details_screen.dart';
import 'package:mr_cake_project/pages/courses/widgets/course_section.dart';
import 'package:mr_cake_project/pages/courses/widgets/courses_category.dart';
import 'package:mr_cake_project/pages/courses/widgets/courses_header.dart';
import 'package:mr_cake_project/pages/courses/widgets/courses_search.dart';

class CoursesScreen extends StatefulWidget {
  const new({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final categories = CategoriesData.categories;
  // ============================================================
  // COURSES BY TYPE
  // ============================================================

  final List<Course> freeCourses = CoursesData.courses
      .where((course) => course.type == CourseType.free)
      .toList();

  final List<Course> professionalCourses = CoursesData.courses
      .where((course) => course.type == CourseType.professional)
      .toList();

  final List<Course> singleCourses = CoursesData.courses
      .where((course) => course.type == CourseType.single)
      .toList();
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
          child: SingleChildScrollView(
            child: Column(
              children: [
                CoursesHeader(
                  onCartTap: () {
                    // Handle cart tap action here
                  },
                ),
                CoursesSearch(
                  onChanged: (value) {
                    // Handle search input change here
                  },
                ),
                // Add other widgets for the courses screen here
                SizedBox(height: 16.h),
                CoursesCategories(
                  categories: categories,
                  onCategorySelected: (category) {
                    if (category == null) {
                      // همه دوره‌ها
                      return;
                    }

                    // فعلاً فقط برای تست
                    debugPrint('Category ID: ${category.id}');
                    debugPrint('Category Title: ${category.title}');

                    // بعداً اینجا AJAX
                  },
                ),
                CourseSection(
                  title: 'از اینجا شروع کن',
                  courses: freeCourses,
                  onCourseTap: (course) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CourseDetailsScreen(course: course),
                      ),
                    );
                  },
                  onViewAll: () {},
                ),

                CourseSection(
                  title: 'حرفه‌ای شو',
                  courses: professionalCourses,
                  onCourseTap: (course) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CourseDetailsScreen(course: course),
                      ),
                    );
                  },
                  onViewAll: () {},
                ),

                CourseSection(
                  title: 'تک آموزشی',
                  courses: singleCourses,
                  onCourseTap: (course) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CourseDetailsScreen(course: course),
                      ),
                    );
                  },
                  onViewAll: () {},
                ),
                SizedBox(height: 25.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
