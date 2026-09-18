import '../models/course_details.dart';

class CourseDetailsData {
  CourseDetailsData._();

  static const Map<int, CourseDetails> details = {
    1: CourseDetails(
      courseId: 1,
      description:
          'در این دوره از پایه با اصول پخت یک کیک اسفنجی حرفه‌ای آشنا می‌شوید و تمام نکات مهم برای داشتن یک کیک سبک، خوش‌طعم و با بافت مناسب را یاد می‌گیرید.',
      introVideo:
          'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      introImage:
          'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=1200',
      chapters: [
        CourseChapter(
          id: 1,
          number: 1,
          title: 'شروع تئوری',
          lessons: [
            CourseLesson(
              id: 1,
              title: 'بهترین نوع آرد',
              video: '',
              duration: '08:20',
            ),
            CourseLesson(
              id: 2,
              title: 'انواع آرد و ملات',
              video: '',
              duration: '10:15',
            ),
          ],
        ),
        CourseChapter(
          id: 2,
          number: 2,
          title: 'فرم دهی خامه',
          lessons: [
            CourseLesson(
              id: 3,
              title: 'تست خامه',
              video: '',
              duration: '12:30',
            ),
            CourseLesson(
              id: 4,
              title: 'فرم دهی خامه',
              video: '',
              duration: '14:10',
            ),
          ],
        ),
        CourseChapter(
          id: 3,
          number: 3,
          title: 'کیک اسفنجی',
          lessons: [
            CourseLesson(
              id: 5,
              title: 'انتخاب قالب',
              video: '',
              duration: '09:40',
            ),
            CourseLesson(
              id: 6,
              title: 'آماده سازی قالب',
              video: '',
              duration: '11:20',
            ),
            CourseLesson(
              id: 7,
              title: 'خارج کردن از قالب',
              video: '',
              duration: '08:50',
            ),
          ],
        ),
        CourseChapter(
          id: 4,
          number: 4,
          title: 'صحبت های پایانی',
          lessons: [
            CourseLesson(
              id: 8,
              title: 'نکات پخت و سرو',
              video: '',
              duration: '07:30',
            ),
            CourseLesson(
              id: 9,
              title: 'روش های نوین',
              video: '',
              duration: '06:45',
            ),
          ],
        ),
      ],
      ingredients: [
        CourseIngredient(
          id: 1,
          name: 'آرد',
          amount: '250 گرم',
        ),
        CourseIngredient(
          id: 2,
          name: 'تخم مرغ',
          amount: '4 عدد',
        ),
        CourseIngredient(
          id: 3,
          name: 'شکر',
          amount: '180 گرم',
        ),
      ],
    ),

    2: CourseDetails(
      courseId: 2,
      description:
          'در این دوره اصول اولیه شیرینی‌پزی، آماده‌سازی مواد و نکات مهم پخت شیرینی را یاد می‌گیرید.',
      introVideo:
          'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      introImage:
          'https://images.unsplash.com/photo-1551024506-0bccd828d307?w=1200',
      chapters: [
        CourseChapter(
          id: 10,
          number: 1,
          title: 'آشنایی با مواد اولیه',
          lessons: [
            CourseLesson(
              id: 10,
              title: 'معرفی مواد اولیه',
              video: '',
              duration: '08:30',
            ),
            CourseLesson(
              id: 11,
              title: 'انتخاب مواد مناسب',
              video: '',
              duration: '10:20',
            ),
          ],
        ),
        CourseChapter(
          id: 11,
          number: 2,
          title: 'اصول پخت',
          lessons: [
            CourseLesson(
              id: 12,
              title: 'دمای مناسب فر',
              video: '',
              duration: '12:10',
            ),
            CourseLesson(
              id: 13,
              title: 'زمان بندی پخت',
              video: '',
              duration: '09:40',
            ),
          ],
        ),
      ],
      ingredients: [
        CourseIngredient(
          id: 10,
          name: 'آرد',
          amount: '300 گرم',
        ),
        CourseIngredient(
          id: 11,
          name: 'کره',
          amount: '150 گرم',
        ),
      ],
    ),
  };

  static CourseDetails getByCourseId(int courseId) {
    return details[courseId] ??
        const CourseDetails(
          courseId: 0,
          description: '',
          introVideo: '',
          introImage: '',
          chapters: [],
          ingredients: [],
        );
  }
}