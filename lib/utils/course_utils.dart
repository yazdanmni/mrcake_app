import '../models/course.dart';

class CourseUtils {
  CourseUtils._();

  static List<Course> getPopularCourses({
    List<Course>? courses,
    int perType = 2,
  }) {
    final source = courses ?? const <Course>[];

    final freeCourses = source
        .where((course) => course.type == CourseType.free)
        .toList()
      ..sort(
        (a, b) => b.studentsCount.compareTo(a.studentsCount),
      );

    final professionalCourses = source
        .where((course) => course.type == CourseType.professional)
        .toList()
      ..sort(
        (a, b) => b.studentsCount.compareTo(a.studentsCount),
      );

    final singleCourses = source
        .where((course) => course.type == CourseType.single)
        .toList()
      ..sort(
        (a, b) => b.studentsCount.compareTo(a.studentsCount),
      );

    return [
      ...freeCourses.take(perType),
      ...professionalCourses.take(perType),
      ...singleCourses.take(perType),
    ];
  }
}