class Course {
  final String image;
  final String title;

  final String instructorFirstName;
  final String instructorLastName;
  final String instructorImage;

  final String price;
  final String currency;

  final String lessons;
  final String duration;

  const Course({
    required this.image,
    required this.title,
    required this.instructorFirstName,
    required this.instructorLastName,
    required this.instructorImage,
    required this.price,
    required this.currency,
    required this.lessons,
    required this.duration,
  });

  String get instructorFullName {
    return '$instructorFirstName $instructorLastName';
  }

  factory Course.fromJson(
    Map<String, dynamic> json,
  ) {
    return Course(
      image: json['image']?.toString() ?? '',
      title: json['title']?.toString() ?? '',

      instructorFirstName:
          json['instructor_first_name']?.toString() ?? '',

      instructorLastName:
          json['instructor_last_name']?.toString() ?? '',

      instructorImage:
          json['instructor_image']?.toString() ?? '',

      price: json['price']?.toString() ?? '0',

      currency:
          json['currency']?.toString() ?? 'تومان',

      lessons:
          json['lessons']?.toString() ?? '0',

      duration:
          json['duration']?.toString() ?? '0',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'image': image,
      'title': title,
      'instructor_first_name': instructorFirstName,
      'instructor_last_name': instructorLastName,
      'instructor_image': instructorImage,
      'price': price,
      'currency': currency,
      'lessons': lessons,
      'duration': duration,
    };
  }
}