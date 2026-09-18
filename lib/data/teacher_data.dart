import 'package:mr_cake_project/models/teacher_model.dart';


class TeacherData {
  TeacherData._();

  static const List<Teacher> teachers = [
    Teacher(
      id: 1,
      firstName: 'مریم',
      lastName: 'احمدی',
      profileImage:
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=500',
      courseCount: 8,
      experienceYears: 12,
      studentsCount: 2450,
      isVerified: true,
      about:
          'مریم احمدی از مدرسان حرفه‌ای حوزه کیک و شیرینی‌پزی است که سال‌ها در زمینه آموزش تخصصی فعالیت داشته است. او با تمرکز بر آموزش اصولی، تکنیک‌های کاربردی و ارائه آموزش‌های مرحله‌به‌مرحله، به هنرجویان کمک می‌کند مهارت‌های خود را در زمینه کیک و شیرینی‌پزی توسعه دهند.',
      portfolio: [
        TeacherPortfolioItem(
          id: 1,
          image:
              'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=900',
          isVideo: false,
          description:
              'نمونه کار هنرجوی من بعد از گذراندن دوره کیک‌های حرفه‌ای.',
        ),
        TeacherPortfolioItem(
          id: 2,
          image:
              'https://images.unsplash.com/photo-1551024506-0bccd828d307?w=900',
          isVideo: false,
          description:
              'یکی از نمونه کارهای هنرجویان دوره شیرینی‌پزی.',
        ),
        TeacherPortfolioItem(
          id: 3,
          image:
              'https://images.unsplash.com/photo-1588195538326-c5b1e9f80a1b?w=900',
          isVideo: true,
          videoUrl:
              'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
          description:
              'ویدیوی نمونه کار هنرجوی دوره آموزش کیک.',
        ),
        TeacherPortfolioItem(
          id: 4,
          image:
              'https://images.unsplash.com/photo-1603532648955-039310d9ed75?w=900',
          isVideo: false,
          description:
              'نمونه کار هنرجو در اجرای کیک مناسبتی.',
        ),
        TeacherPortfolioItem(
          id: 5,
          image:
              'https://images.unsplash.com/photo-1571115177098-24ec42ed204d?w=900',
          isVideo: true,
          videoUrl:
              'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
          description:
              'اجرای تکنیک‌های آموزش داده شده توسط هنرجوی دوره.',
        ),
        TeacherPortfolioItem(
          id: 6,
          image:
              'https://images.unsplash.com/photo-1486427944299-d1955d23e34d?w=900',
          isVideo: false,
          description:
              'یکی دیگر از نمونه کارهای هنرجویان مستر کیک.',
        ),
      ],
    ),

    // استادهای دیگر می‌توانند وجود داشته باشند،
    // ولی فعلاً صفحه اختصاصی ندارند.
    Teacher(
      id: 2,
      firstName: 'علی',
      lastName: 'رضایی',
      profileImage: 'https://images.unsplash.com/photo-1559620192-032c4bc4674e?w=900',
      courseCount: 3,
      experienceYears: 5,
      studentsCount: 500,
      isVerified: true,
      about: '',
      portfolio: [],
    ),
  ];

  static Teacher? getTeacherById(int id) {
    for (final Teacher teacher in teachers) {
      if (teacher.id == id) {
        return teacher;
      }
    }

    return null;
  }

  static Teacher? getAvailableTeacherPage(int id) {
    if (id != 1) {
      return null;
    }

    return getTeacherById(id);
  }
}