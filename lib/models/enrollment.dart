class Enrollment {
  final int id;
  final int userId;
  final int courseId;
  final double progress;

  const Enrollment({
    required this.id,
    required this.userId,
    required this.courseId,
    this.progress = 0,
  });
}
