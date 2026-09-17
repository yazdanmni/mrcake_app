enum CourseType {
  free,
  professional,
  single,
}

enum CourseAccess {
  free,
  paid,
}

class Course {
  final int id;

  final String image;
  final String title;

  final String instructorFirstName;
  final String instructorLastName;
  final String instructorImage;

  final String price;
  final String currency;

  final String lessons;
  final String duration;

  final int studentsCount;

  final CourseType type;
  final CourseAccess access;

  const Course({
    required this.id,
    required this.image,
    required this.title,
    required this.instructorFirstName,
    required this.instructorLastName,
    required this.instructorImage,
    required this.price,
    required this.currency,
    required this.lessons,
    required this.duration,
    required this.studentsCount,
    required this.type,
    required this.access,
  });

  String get instructorFullName {
    return '$instructorFirstName $instructorLastName';
  }

  factory Course.fromJson(
    Map<String, dynamic> json,
  ) {
    return Course(
      id: int.tryParse(
            json['id']?.toString() ?? '0',
          ) ??
          0,

      image: json['image']?.toString() ?? '',

      title: json['title']?.toString() ?? '',

      instructorFirstName:
          json['instructor_first_name']?.toString() ?? '',

      instructorLastName:
          json['instructor_last_name']?.toString() ?? '',

      instructorImage:
          json['instructor_image']?.toString() ?? '',

      price:
          json['price']?.toString() ?? '0',

      currency:
          json['currency']?.toString() ?? 'تومان',

      lessons:
          json['lessons']?.toString() ?? '0',

      duration:
          json['duration']?.toString() ?? '0',

      studentsCount: int.tryParse(
            json['students_count']?.toString() ?? '0',
          ) ??
          0,

      type: _courseTypeFromJson(
        json['type']?.toString(),
      ),

      access: _courseAccessFromJson(
        json['access']?.toString(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,

      'image': image,
      'title': title,

      'instructor_first_name':
          instructorFirstName,

      'instructor_last_name':
          instructorLastName,

      'instructor_image':
          instructorImage,

      'price': price,
      'currency': currency,

      'lessons': lessons,
      'duration': duration,

      'students_count':
          studentsCount,

      'type':
          type.name,

      'access':
          access.name,
    };
  }

  static CourseType _courseTypeFromJson(
    String? value,
  ) {
    switch (value) {
      case 'professional':
        return CourseType.professional;

      case 'single':
        return CourseType.single;

      case 'free':
      default:
        return CourseType.free;
    }
  }

  static CourseAccess _courseAccessFromJson(
    String? value,
  ) {
    switch (value) {
      case 'paid':
        return CourseAccess.paid;

      case 'free':
      default:
        return CourseAccess.free;
    }
  }
}