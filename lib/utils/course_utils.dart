import '../models/course.dart';

class CourseUtils {
  CourseUtils._();

  /// «دوره های محبوب» — the whole list ranked by **student count**, descending.
  ///
  /// The course with the most students comes first and every other course is
  /// placed relative to it; a course nobody has joined yet sinks to the bottom.
  /// [limit] only caps how long the carousel is.
  ///
  /// This used to take `perType` courses out of each [CourseType] bucket, which
  /// produced a *balanced* mix (۲ رایگان + ۲ حرفه‌ای + ۲ تک‌آموزشی) rather than
  /// the most popular courses: the free bucket was always emitted first, so the
  /// actual best-seller could end up behind a course with fewer students.
  static List<Course> getPopularCourses({
    List<Course>? courses,
    int limit = 6,
  }) {
    final ranked = List<Course>.of(courses ?? const <Course>[])
      ..sort(byStudentsDesc);

    return ranked.take(limit).toList(growable: false);
  }

  /// Comparator for "most students first".
  ///
  /// `List.sort` is **not** stable, so the ties are broken explicitly — by
  /// rating, then by id — otherwise two identical responses could shuffle the
  /// carousel between rebuilds.
  static int byStudentsDesc(Course a, Course b) {
    final byStudents = b.studentsCount.compareTo(a.studentsCount);
    if (byStudents != 0) return byStudents;

    final byRating = _rating(b).compareTo(_rating(a));
    if (byRating != 0) return byRating;

    return a.id.compareTo(b.id);
  }

  static double _rating(Course course) =>
      double.tryParse(course.rating ?? '') ?? 0;
}