import '../models/course.dart';

class CoursesData {
  CoursesData._();

  static const List<Course> courses = [
    // =========================================================
    // 1 — رایگان — کیک
    // =========================================================

    Course(
      id: 1,
      image:
          'media.dl.mceiran.website/media/images/2026/09/0d3f035df0504f7d8e573b5df8960d44.jpg',
      title: 'آموزش مقدماتی کیک‌پزی',
      instructorFirstName: 'مریم',
      instructorLastName: 'احمدی',
      instructorImage: 'https://i.pravatar.cc/300?img=47',
      instructorId: 1,
      price: '0',
      currency: 'تومان',
      lessons: '12',
      duration: '60',
      studentsCount: 2450,
      type: CourseType.free,
      access: CourseAccess.free,
      categoryIds: [1],
    ),

    // =========================================================
    // 2 — رایگان — شیرینی
    // =========================================================

    Course(
      id: 2,
      image:
          'media.dl.mceiran.website/media/images/2026/09/0d3f035df0504f7d8e573b5df8960d44.jpg',
      title: 'اصول اولیه شیرینی‌پزی',
      instructorFirstName: 'سارا',
      instructorLastName: 'محمدی',
      instructorImage: 'https://i.pravatar.cc/300?img=32',
      instructorId: 2,
      price: '0',
      currency: 'تومان',
      lessons: '10',
      duration: '50',
      studentsCount: 1850,
      type: CourseType.free,
      access: CourseAccess.free,
      categoryIds: [2],
    ),

    // =========================================================
    // 3 — حرفه‌ای — کیک
    // =========================================================

    Course(
      id: 3,
      image:
          'media.dl.mceiran.website/media/images/2026/09/0d3f035df0504f7d8e573b5df8960d44.jpg',
      title: 'آموزش جامع کیک‌های حرفه‌ای',
      instructorFirstName: 'نگار',
      instructorLastName: 'کریمی',
      instructorImage: 'https://i.pravatar.cc/300?img=44',
      instructorId: 3,
      price: '2490000',
      currency: 'تومان',
      lessons: '24',
      duration: '120',
      studentsCount: 3200,
      type: CourseType.professional,
      access: CourseAccess.paid,
      categoryIds: [1],
    ),

    // =========================================================
    // 4 — حرفه‌ای — دسر + شیرینی
    // =========================================================

    Course(
      id: 4,
      image:
          'media.dl.mceiran.website/media/images/2026/09/0d3f035df0504f7d8e573b5df8960d44.jpg',
      title: 'دوره تخصصی دسر و شیرینی مدرن',
      instructorFirstName: 'الهام',
      instructorLastName: 'رضایی',
      instructorImage: 'https://i.pravatar.cc/300?img=49',
      instructorId: 4,
      price: '1890000',
      currency: 'تومان',
      lessons: '18',
      duration: '95',
      studentsCount: 2750,
      type: CourseType.professional,
      access: CourseAccess.paid,
      categoryIds: [2, 3],
    ),

    // =========================================================
    // 5 — حرفه‌ای — کیک
    // =========================================================

    Course(
      id: 5,
      image:
          'media.dl.mceiran.website/media/images/2026/09/0d3f035df0504f7d8e573b5df8960d44.jpg',
      title: 'آموزش کیک‌های مجلسی و لوکس',
      instructorFirstName: 'مریم',
      instructorLastName: 'احمدی',
      instructorImage: 'https://i.pravatar.cc/300?img=47',
      instructorId: 1,
      price: '2990000',
      currency: 'تومان',
      lessons: '28',
      duration: '140',
      studentsCount: 4100,
      type: CourseType.professional,
      access: CourseAccess.paid,
      categoryIds: [1],
    ),

    // =========================================================
    // 6 — تک آموزشی / رایگان — خامه
    // =========================================================

    Course(
      id: 6,
      image:
          'media.dl.mceiran.website/media/images/2026/09/0d3f035df0504f7d8e573b5df8960d44.jpg',
      title: 'آموزش خامه‌کشی حرفه‌ای',
      instructorFirstName: 'سارا',
      instructorLastName: 'محمدی',
      instructorImage: 'https://i.pravatar.cc/300?img=32',
      instructorId: 2,
      price: '0',
      currency: 'تومان',
      lessons: '1',
      duration: '35',
      studentsCount: 1650,
      type: CourseType.single,
      access: CourseAccess.free,
      categoryIds: [5],
    ),

    // =========================================================
    // 7 — تک آموزشی / پولی — کیک + خامه
    // =========================================================

    Course(
      id: 7,
      image:
          'media.dl.mceiran.website/media/images/2026/09/0d3f035df0504f7d8e573b5df8960d44.jpg',
      title: 'آموزش دیزاین کیک با خامه',
      instructorFirstName: 'نگار',
      instructorLastName: 'کریمی',
      instructorImage: 'https://i.pravatar.cc/300?img=44',
      instructorId: 3,
      price: '490000',
      currency: 'تومان',
      lessons: '1',
      duration: '40',
      studentsCount: 980,
      type: CourseType.single,
      access: CourseAccess.paid,
      categoryIds: [1, 5],
    ),

    // =========================================================
    // 8 — تک آموزشی / پولی — کیک
    // =========================================================

    Course(
      id: 8,
      image:
          'media.dl.mceiran.website/media/images/2026/09/0d3f035df0504f7d8e573b5df8960d44.jpg',
      title: 'آموزش تزیین کاپ‌کیک',
      instructorFirstName: 'الهام',
      instructorLastName: 'رضایی',
      instructorImage: 'https://i.pravatar.cc/300?img=49',
      instructorId: 4,
      price: '390000',
      currency: 'تومان',
      lessons: '1',
      duration: '30',
      studentsCount: 1250,
      type: CourseType.single,
      access: CourseAccess.paid,
      categoryIds: [1],
    ),

    // =========================================================
    // 9 — تک آموزشی / رایگان — کیک
    // =========================================================

    Course(
      id: 9,
      image:
          'media.dl.mceiran.website/media/images/2026/09/0d3f035df0504f7d8e573b5df8960d44.jpg',
      title: 'آموزش پخت کیک اسفنجی',
      instructorFirstName: 'مریم',
      instructorLastName: 'احمدی',
      instructorImage: 'https://i.pravatar.cc/300?img=47',
      instructorId: 1,
      price: '0',
      currency: 'تومان',
      lessons: '1',
      duration: '25',
      studentsCount: 2900,
      type: CourseType.single,
      access: CourseAccess.free,
      categoryIds: [1],
    ),

    // =========================================================
    // 10 — حرفه‌ای — شیرینی
    // =========================================================

    Course(
      id: 10,
      image:
          'media.dl.mceiran.website/media/images/2026/09/0d3f035df0504f7d8e573b5df8960d44.jpg',
      title: 'آموزش تخصصی شیرینی‌های خاص',
      instructorFirstName: 'سارا',
      instructorLastName: 'محمدی',
      instructorImage: 'https://i.pravatar.cc/300?img=32',
      instructorId: 2,
      price: '2190000',
      currency: 'تومان',
      lessons: '21',
      duration: '105',
      studentsCount: 3600,
      type: CourseType.professional,
      access: CourseAccess.paid,
      categoryIds: [2],
    ),
  ];

  // =========================================================
  // فیلتر دوره‌ها بر اساس دسته‌بندی
  // null = همه
  // =========================================================

  static List<Course> coursesByCategory(int? categoryId) {
    if (categoryId == null) {
      return courses;
    }

    return courses
        .where(
          (course) => course.categoryIds.contains(categoryId),
        )
        .toList();
  }
}
