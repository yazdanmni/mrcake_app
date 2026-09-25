import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/course_intro_video.dart';
import '../repositories/catalog_repository.dart';

/// Teasers for «معرفی دوره ها»: `video_trailer` on `GET /api/v1/courses/{id}/`.
final introductionVideosProvider =
    FutureProvider<List<CourseIntroVideo>>((ref) async {
  return CatalogRepository.instance.fetchCourseIntroVideos();
});
