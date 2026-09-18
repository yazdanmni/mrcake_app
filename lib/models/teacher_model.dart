class Teacher {
  final int id;
  final String firstName;
  final String lastName;
  final String profileImage;

  final int courseCount;
  final int experienceYears;
  final int studentsCount;

  final bool isVerified;

  final String about;

  final List<TeacherPortfolioItem> portfolio;

  const Teacher({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.profileImage,
    required this.courseCount,
    required this.experienceYears,
    required this.studentsCount,
    required this.isVerified,
    required this.about,
    required this.portfolio,
  });

  String get fullName => '$firstName $lastName';
}

class TeacherPortfolioItem {
  final int id;

  /// تصویر کاور نمونه کار
  final String image;

  /// true = ویدیو
  /// false = عکس
  final bool isVideo;

  /// فقط برای ویدیو
  final String? videoUrl;

  /// توضیحی که استاد برای نمونه کار نوشته
  final String description;

  const TeacherPortfolioItem({
    required this.id,
    required this.image,
    required this.isVideo,
    this.videoUrl,
    required this.description,
  });
}