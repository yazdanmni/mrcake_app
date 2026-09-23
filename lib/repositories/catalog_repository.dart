import '../core/network/api_client.dart';
import '../core/network/api_config.dart';
import '../core/network/api_exception.dart';
import '../core/network/remote_data.dart';
import '../models/banner_model.dart';
import '../models/category_model.dart';
import '../models/course.dart';
import '../models/course_details.dart';
import '../models/enrollment.dart';
import '../models/explore_video.dart';
import '../models/recipe.dart';
import '../models/teacher_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'profile_repository.dart';

/// A DRF page (`{count, next, previous, results}`) or a plain list, normalised.
///
/// Some endpoints answer with `{links, count, total_pages, current_page,
/// results}` and others with `{count, next, previous, results}`; both are
/// understood here.
class PagedResult {
  const PagedResult({
    required this.items,
    this.count = 0,
    this.next,
    this.previous,
    this.totalPages,
    this.currentPage,
  });

  final List<Map<String, dynamic>> items;
  final int count;
  final String? next;
  final String? previous;
  final int? totalPages;
  final int? currentPage;

  bool get hasMore => next != null && next!.isNotEmpty;
  bool get isEmpty => items.isEmpty;

  static const PagedResult empty = PagedResult(items: []);

  factory PagedResult.from(dynamic data) {
    if (data is List) {
      final items = Json.asMapList(data);
      return PagedResult(items: items, count: items.length);
    }

    final map = Json.asMap(data);
    if (map == null) return PagedResult.empty;

    final rawResults = map['results'];
    if (rawResults is List) {
      final items = Json.asMapList(rawResults);
      return PagedResult(
        items: items,
        count: Json.asInt(map['count']) ?? items.length,
        next: Json.asString(map['next']),
        previous: Json.asString(map['previous']),
        totalPages: Json.asInt(map['total_pages']),
        currentPage: Json.asInt(map['current_page']),
      );
    }

    // Single object response: wrap it so callers always get a list.
    return PagedResult(items: [map], count: 1);
  }

  /// Maps every raw item with [mapper].
  List<T> map<T>(T Function(Map<String, dynamic> json) mapper) =>
      items.map(mapper).toList(growable: false);
}

/// Screen -> Endpoint -> Model -> Repository
///
///  SplashScreen        GET v1/banners/hero/active/          -> `HeroSection`
///  HomeScreen          GET v1/banners/all_active/           -> `BannerModel`
///  HomeScreen          GET v1/banners/by_type/?type=..      -> `BannerModel`
///  HomeScreen          GET v1/courses/featured/             -> `Course`
///  HomeScreen          GET v1/courses/best_selling/         -> `Course`
///  HomeScreen          GET v1/courses/categories/featured/  -> `CategoryModel`
///  CoursesScreen       GET v1/courses/                      -> `Course`
///  CourseCategories    GET v1/courses/categories/tree/      -> `CategoryModel`
///  CourseDetails       GET v1/courses/{id}/                 -> `CourseDetails`
///  CourseLearning      GET v1/courses/chapters/             -> `CourseChapter`
///  CourseLearning      GET v1/courses/lessons/              -> `CourseLesson`
///  ExploreScreen       GET v1/content/explore-videos/       -> `ExploreVideo`
///  RecipesScreen       GET v1/courses/recipes/              -> `Recipe`
///  RecipeDetail        GET v1/courses/recipes/{id}/         -> `Recipe`
///  TeacherScreen       GET v1/accounts/teachers/            -> `Teacher`
///  TeacherScreen       GET v1/content/teacher-portfolio/    -> `TeacherPortfolioItem`
///  ProfileScreen       GET v1/courses/enrollments/          -> `Enrollment`
class CatalogRepository {
  CatalogRepository._();

  static final CatalogRepository instance = CatalogRepository._();

  ApiClient get _api => ApiClient.instance;

  // ---------------------------------------------------------------------------
  // banners
  // ---------------------------------------------------------------------------

  /// `GET /api/v1/banners/hero/active/` -> `HeroSectionPublic`
  Future<HeroSection?> fetchActiveHero() async {
    final data = await _api.get<dynamic>(ApiEndpoints.bannersHeroActive);
    final map = Json.asMap(data);
    if (map == null || map.isEmpty) return null;
    return HeroSection.fromJson(map);
  }

  /// `GET /api/v1/banners/` -> page of `BannerPublic`
  ///
  /// Public — the schema marks it `security: [{jwtAuth: []}, {}]`, unlike
  /// [fetchActiveBanners].
  Future<List<BannerModel>> fetchBanners() async {
    final data = await _api.get<dynamic>(ApiEndpoints.banners);
    return PagedResult.from(data).map(BannerModel.fromJson);
  }

  /// `GET /api/v1/banners/all_active/` -> `List<BannerPublic>`
  ///
  /// **Auth-required** (`security: [{jwtAuth: []}]`): calling it without a
  /// token answers `401 اطلاعات برای اعتبارسنجی ارسال نشده است`. Only reach for
  /// it when the user is signed in.
  Future<List<BannerModel>> fetchActiveBanners() async {
    final data = await _api.get<dynamic>(ApiEndpoints.bannersAllActive);
    return PagedResult.from(data).map(BannerModel.fromJson);
  }

  /// `GET /api/v1/banners/by_type/?type=home_top` -> `List<BannerPublic>`
  Future<List<BannerModel>> fetchBannersByType(BannerType type) async {
    final data = await _api.get<dynamic>(
      ApiEndpoints.bannersByType,
      query: {'type': type.value},
    );
    return PagedResult.from(data).map(BannerModel.fromJson);
  }

  /// Home carousel: tries `by_type` first, then falls back to the public
  /// `banners/` list so the carousel is filled even before the type is
  /// configured.
  ///
  /// The fallback is deliberately **not** [fetchActiveBanners]: that endpoint is
  /// auth-required, so using it here made a guest opening the home screen take a
  /// 401 — which the interceptor then treated as a dead session.
  Future<List<BannerModel>> fetchHomeBanners() async {
    final typed = await fetchBannersByType(BannerType.homeTop);
    if (typed.isNotEmpty) return typed;

    try {
      return await fetchBanners();
    } on ApiException {
      // "No banners yet" is a normal state, not an error worth surfacing.
      return const [];
    }
  }

  /// `POST /api/v1/banners/{id}/click/`
  Future<void> reportBannerClick(int id) async {
    await _api.post<dynamic>(ApiEndpoints.bannerClick(id));
  }

  /// `GET /api/v1/banners/badges/` -> `List<PromoBadge>`
  Future<PagedResult> fetchBadges() async {
    final data = await _api.get<dynamic>(ApiEndpoints.bannersBadges);
    return PagedResult.from(data);
  }

  // ---------------------------------------------------------------------------
  // courses
  // ---------------------------------------------------------------------------

  /// `GET /api/v1/courses/` -> page of `CourseList`
  Future<PagedResult> fetchCoursePage({
    int page = 1,
    int? pageSize,
    String? search,
    int? categoryId,
    String? ordering,
    int? teacherId,
  }) => _page(
    ApiEndpoints.courses,
    query: {
      'page': page,
      if (pageSize != null) 'page_size': pageSize,
      if (search != null && search.isNotEmpty) 'search': search,
      if (categoryId != null) 'category': categoryId,
      if (ordering != null && ordering.isNotEmpty) 'ordering': ordering,
      if (teacherId != null) 'teacher': teacherId,
    },
  );

  /// Typed variant used by the screens.
  Future<List<Course>> fetchCourses({
    int page = 1,
    int? pageSize,
    String? search,
    int? categoryId,
    String? ordering,
    int? teacherId,
  }) async {
    final result = await fetchCoursePage(
      page: page,
      pageSize: pageSize,
      search: search,
      categoryId: categoryId,
      ordering: ordering,
    );
    return result.map(Course.fromJson);
  }

  Future<List<Course>> fetchFeaturedCourses({int page = 1}) =>
      _courses(ApiEndpoints.coursesFeatured, page: page);

  Future<List<Course>> fetchLatestCourses({int page = 1}) =>
      _courses(ApiEndpoints.coursesLatest, page: page);

  Future<List<Course>> fetchFreeCourses({int page = 1}) =>
      _courses(ApiEndpoints.coursesFree, page: page);

  Future<List<Course>> fetchPaidCourses({int page = 1}) =>
      _courses(ApiEndpoints.coursesPaid, page: page);

  Future<List<Course>> fetchBestSellingCourses({int page = 1}) =>
      _courses(ApiEndpoints.coursesBestSelling, page: page);

  /// `GET /api/v1/courses/my_courses/` (auth)
  ///
  /// Not cached: the list changes as soon as the user enrols in something.
  Future<List<Course>> fetchMyCourses({int page = 1}) =>
      _courses(ApiEndpoints.coursesMyCourses, page: page, cache: false);

  /// `GET /api/v1/courses/my_favorites/` (auth)
  ///
  /// Not cached: it changes the moment a favourite is toggled.
  Future<List<Course>> fetchMyFavorites({int page = 1}) =>
      _courses(ApiEndpoints.coursesMyFavorites, page: page, cache: false);

  /// `GET /api/v1/courses/{id}/` -> `CourseDetail`
  Future<Map<String, dynamic>> fetchCourseRaw(int id) =>
      _object(ApiEndpoints.course(id));

  /// `GET /api/v1/courses/{id}/` typed as [CourseDetails].
  ///
  /// Cached: `CourseDetailsScreen` loads it and `CourseLearningScreen` loads it
  /// again immediately after, so without the cache opening a course costs two
  /// identical round trips.
  ///
  /// The payload carries the user-specific `is_enrolled` / `is_favorite` /
  /// `user_review` flags, so every write that can change them calls
  /// [invalidateCatalogueCache].
  Future<CourseDetails?> fetchCourseDetails(int id) =>
      _cached<CourseDetails?>('course-detail:$id', () async {
        final data = await _api.get<dynamic>(ApiEndpoints.course(id));
        final map = Json.asMap(data);
        if (map == null || map.isEmpty) return null;
        return CourseDetails.fromJson(map);
      });

  /// `GET /api/v1/courses/{id}/my_progress/` (auth)
  Future<Map<String, dynamic>> fetchCourseProgress(int id) =>
      _object(ApiEndpoints.courseMyProgress(id));

  /// `POST /api/v1/courses/{id}/toggle_favorite/` (auth)
  Future<void> toggleFavorite(int id) async {
    await _api.post<dynamic>(ApiEndpoints.courseToggleFavorite(id));
    // The cached course detail still carries the old `is_favorite`.
    invalidateCatalogueCache();
  }

  /// `POST /api/v1/courses/{id}/mark_lesson/` (auth)
  Future<void> markLesson({
    required int courseId,
    required int lessonId,
    bool completed = true,
  }) async {
    await _api.post<dynamic>(
      ApiEndpoints.courseMarkLesson(courseId),
      body: {'lesson': lessonId, 'is_completed': completed},
    );
    // Progress is part of the course detail payload.
    invalidateCatalogueCache();
  }

  /// `GET /api/v1/courses/categories/` -> page of `CategoryPublic`
  Future<List<CategoryModel>> fetchCategories({int page = 1}) =>
      _categories(ApiEndpoints.coursesCategories, page: page);

  /// `GET /api/v1/courses/categories/featured/`
  Future<List<CategoryModel>> fetchFeaturedCategories() =>
      _categories(ApiEndpoints.coursesCategoriesFeatured);

  /// `GET /api/v1/courses/categories/tree/`
  Future<List<CategoryModel>> fetchCategoryTree() =>
      _categories(ApiEndpoints.coursesCategoriesTree);

  /// `GET /api/v1/courses/chapters/?course={id}` -> page of `Chapter`
  Future<PagedResult> fetchChapterPage({int? courseId}) => _page(
    ApiEndpoints.coursesChapters,
    query: {'course': courseId},
  );

  /// Typed chapters, each carrying its lessons when the backend inlines them.
  Future<List<CourseChapter>> fetchChapters({int? courseId}) async {
    final result = await fetchChapterPage(courseId: courseId);
    return result.items
        .asMap()
        .entries
        .map(
          (entry) => CourseChapter.fromJson(
            entry.value,
            fallbackNumber: entry.key + 1,
          ),
        )
        .toList(growable: false);
  }

  /// `GET /api/v1/courses/lessons/?chapter={id}` -> page of `Lesson`
  Future<PagedResult> fetchLessonPage({int? chapterId, int? courseId}) => _page(
    ApiEndpoints.coursesLessons,
    query: {'chapter': chapterId, 'course': courseId},
  );

  /// Typed lessons for one chapter.
  Future<List<CourseLesson>> fetchLessons({
    int? chapterId,
    int? courseId,
  }) async {
    final result = await fetchLessonPage(
      chapterId: chapterId,
      courseId: courseId,
    );
    return result.items
        .asMap()
        .entries
        .map(
          (entry) => CourseLesson.fromJson(
            entry.value,
            fallbackOrder: entry.key + 1,
          ),
        )
        .toList(growable: false);
  }

  /// `GET /api/v1/courses/lessons/{id}/` -> `LessonPublic`
  Future<CourseLesson?> fetchLesson(int id) => _cached<CourseLesson?>(
    'lesson:$id',
    () async {
      final data = await _api.get<dynamic>(
        '${ApiEndpoints.coursesLessons}$id/',
      );
      final map = Json.asMap(data);
      if (map == null || map.isEmpty) return null;
      return CourseLesson.fromJson(map);
    },
  );

  /// `GET /api/v1/courses/chapters/{id}/` -> `ChapterWithLessons`
  Future<CourseChapter?> fetchChapter(int id) => _cached<CourseChapter?>(
    'chapter:$id',
    () async {
      final data = await _api.get<dynamic>(
        '${ApiEndpoints.coursesChapters}$id/',
      );
      final map = Json.asMap(data);
      if (map == null || map.isEmpty) return null;
      return CourseChapter.fromJson(map);
    },
  );

  /// `GET /api/v1/courses/reviews/?course={id}` -> page of `CourseReview`
  Future<PagedResult> fetchReviews({int? courseId, int page = 1}) => _page(
    ApiEndpoints.coursesReviews,
    query: {'course': courseId, 'page': page},
  );

  /// `POST /api/v1/courses/reviews/` (auth)
  Future<Map<String, dynamic>> submitReview({
    required int courseId,
    required int rating,
    String? comment,
  }) async {
    final result = await _object(
      ApiEndpoints.coursesReviews,
      method: _HttpMethod.post,
      body: {
        'course': courseId,
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      },
    );
    // The cached course detail still holds the previous `user_review`.
    RemoteCache.invalidate('course-detail:');
    return result;
  }

  /// `GET /api/v1/courses/tags/` -> page of `Tag`
  Future<PagedResult> fetchTags({int page = 1}) =>
      _page(ApiEndpoints.coursesTags, query: {'page': page});

  /// `GET /api/v1/courses/enrollments/` (auth) -> page of `Enrollment`
  Future<List<Enrollment>> fetchEnrollments({int page = 1}) async {
    final result = await _page(
      ApiEndpoints.coursesEnrollments,
      query: {'page': page},
    );
    return result.map(Enrollment.fromJson);
  }

  // ---------------------------------------------------------------------------
  // recipes
  // ---------------------------------------------------------------------------

  /// `GET /api/v1/courses/recipes/` -> page of `RecipeList`
  Future<List<Recipe>> fetchRecipes({int page = 1, String? search}) async {
    final result = await _page(
      ApiEndpoints.recipes,
      query: {
        'page': page,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    return result.map(Recipe.fromJson);
  }

  Future<List<Recipe>> fetchFeaturedRecipes({int page = 1}) async {
    final result = await _page(
      ApiEndpoints.recipesFeatured,
      query: {'page': page},
    );
    return result.map(Recipe.fromJson);
  }

  /// `GET /api/v1/courses/recipes/{id}/` -> `RecipeDetail`
  Future<Recipe?> fetchRecipe(int id) =>
      _cached<Recipe?>('recipe:$id', () async {
        final data = await _api.get<dynamic>(ApiEndpoints.recipe(id));
        final map = Json.asMap(data);
        if (map == null || map.isEmpty) return null;
        return Recipe.fromJson(map);
      });

  /// `GET /api/v1/courses/recipes/{id}/view/` -> increments the view counter.
  Future<Map<String, dynamic>> registerRecipeView(int id) async {
    final result = await _object(ApiEndpoints.recipeView(id));
    // The cached recipe still holds the previous `views_count`.
    RemoteCache.invalidate('recipe:');
    return result;
  }

  // ---------------------------------------------------------------------------
  // explore / reels
  // ---------------------------------------------------------------------------

  /// `GET /api/v1/content/explore-videos/` -> page of `ExploreVideo`
  ///
  /// `video_media` / `thumbnail_media` / `teacher` are ids, so they are
  /// resolved into urls and a name before the list is returned. Pass
  /// [resolveMedia] = `false` to skip those extra requests.
  Future<List<ExploreVideo>> fetchExploreVideos({
    int page = 1,
    bool resolveMedia = true,
  }) => _cached<List<ExploreVideo>>(
    'explore:p$page:m$resolveMedia',
    () async {
      final result = await _page(
        ApiEndpoints.exploreVideos,
        query: {'page': page},
      );

      final videos = result.map(ExploreVideo.fromJson);
      if (!resolveMedia || videos.isEmpty) return videos;

      return Future.wait(videos.map(_hydrateVideo));
    },
  );

  /// `GET /api/v1/content/teacher-portfolio/` -> page of `TeacherPortfolioItem`
  Future<List<TeacherPortfolioItem>> fetchTeacherPortfolio({
    int page = 1,
    int? teacherId,
    bool resolveMedia = true,
  }) => _cached<List<TeacherPortfolioItem>>(
    'portfolio:p$page:t$teacherId:m$resolveMedia',
    () async {
      final result = await _page(
        ApiEndpoints.contentTeacherPortfolio,
        query: {'page': page, 'teacher': teacherId},
      );

      final items = result.map(TeacherPortfolioItem.fromJson);
      if (!resolveMedia || items.isEmpty) return items;

      return Future.wait(items.map(_hydratePortfolioItem));
    },
  );

  // ---------------------------------------------------------------------------
  // teachers
  // ---------------------------------------------------------------------------

  /// `GET /api/v1/accounts/teachers/` -> page of `TeacherProfilePublic`
  Future<List<Teacher>> fetchTeachers({int page = 1, String? search}) =>
      _cached<List<Teacher>>(
        'teachers:p$page:s${search ?? ''}',
        () async {
          final result = await _page(
            ApiEndpoints.teachers,
            query: {
              'page': page,
              if (search != null && search.isNotEmpty) 'search': search,
            },
          );
          return result.map(Teacher.fromJson);
        },
      );

  /// `GET /api/v1/accounts/teachers/` -> page of `TeacherProfilePublic`
  /// Returns the single verified teacher.
  /// Assumes only one teacher is verified in the system.
  Future<Teacher?> fetchSingleVerifiedTeacher() async {
    final allTeachers = await fetchTeachers(); // Fetch all teachers
    try {
      return allTeachers.firstWhere((teacher) => teacher.isVerified);
    } catch (e) {
      // No verified teacher found or multiple found, handle as per requirement.
      // For now, return null if none found, or log if multiple found.
      print('No single verified teacher found: $e'); // Replace with proper logging
      return null;
    }
  }

  /// `GET /api/v1/accounts/teachers/{id}/`
  Future<Teacher?> fetchTeacher(int id) =>
      _cached<Teacher?>('teacher:$id', () async {
        final data = await _api.get<dynamic>('${ApiEndpoints.teachers}$id/');
        final map = Json.asMap(data);
        if (map == null || map.isEmpty) return null;
        return Teacher.fromJson(map);
      });

  /// `GET /api/v1/accounts/users/{id}/` -> builds a [Teacher] out of a user.
  ///
  /// A recipe author arrives as `created_by`, which is a **user** id, while
  /// `GET accounts/teachers/{id}/` expects a *teacher profile* id. The caller
  /// therefore tries the profile first and falls back to this.
  Future<Teacher?> fetchTeacherByUserId(int userId) =>
      _cached<Teacher?>('teacher-user:$userId', () async {
        final data = await _api.get<dynamic>('${ApiEndpoints.users}$userId/');
        final map = Json.asMap(data);
        if (map == null || map.isEmpty) return null;

        final user = Json.asMap(map['user']) ?? map;
        return Teacher.fromJson(user);
      });

  // ---------------------------------------------------------------------------
  // settings
  // ---------------------------------------------------------------------------

  /// `GET /api/v1/settings/` -> page of `AppSetting`
  Future<PagedResult> fetchSettings() => _page(ApiEndpoints.settings);

  /// `GET /api/v1/settings/{key}/`
  Future<Map<String, dynamic>> fetchSetting(String key) =>
      _object(ApiEndpoints.setting(key));

  // ---------------------------------------------------------------------------
  // internals
  // ---------------------------------------------------------------------------

  /// Reads a **public** catalogue endpoint through the in-memory TTL cache
  /// ([AppConfig.catalogueCacheTtl]).
  ///
  /// Never use this for anything that depends on the logged-in account: a
  /// cached `is_enrolled` / favourite / progress value would outlive the action
  /// that changed it. Those endpoints pass `cache: false`.
  Future<T> _cached<T>(String key, Future<T> Function() fetch) async {
    final hit = RemoteCache.read<T>(key);
    if (hit != null) return hit;

    final value = await fetch();
    RemoteCache.write(key, value);
    return value;
  }

  Future<List<Course>> _courses(
    String path, {
    int page = 1,
    bool cache = true,
  }) async {
    Future<List<Course>> load() async {
      final result = await _page(path, query: {'page': page});
      return result.map(Course.fromJson);
    }

    if (!cache) return load();
    return _cached<List<Course>>('courses:$path:p$page', load);
  }

  Future<List<CategoryModel>> _categories(
    String path, {
    int? page,
    bool cache = true,
  }) async {
    Future<List<CategoryModel>> load() async {
      final result = await _page(path, query: {'page': page});
      return result.map(CategoryModel.fromJson);
    }

    if (!cache) return load();
    return _cached<List<CategoryModel>>('categories:$path:p$page', load);
  }

  Future<PagedResult> _page(String path, {Map<String, dynamic>? query}) async {
    final data = await _api.get<dynamic>(path, query: query);
    return PagedResult.from(data);
  }

  Future<Map<String, dynamic>> _object(
    String path, {
    _HttpMethod method = _HttpMethod.get,
    Map<String, dynamic>? body,
    bool cache = false,
  }) async {
    Future<Map<String, dynamic>> load() async {
      final dynamic data;
      switch (method) {
        case _HttpMethod.get:
          data = await _api.get<dynamic>(path);
        case _HttpMethod.post:
          data = await _api.post<dynamic>(path, body: body);
      }
      return Json.asMap(data) ?? <String, dynamic>{};
    }

    if (!cache || method != _HttpMethod.get) return load();
    return _cached<Map<String, dynamic>>('object:$path', load);
  }

  /// Drops cached catalogue reads. Called after any write that changes what the
  /// catalogue returns, and whenever the session changes.
  static void invalidateCatalogueCache() => RemoteCache.clear();

  /// Fills in the video / thumbnail urls and the instructor of a reel.
  Future<ExploreVideo> _hydrateVideo(ExploreVideo video) async {
    final media = await Future.wait([
      MediaRepository.instance.resolveUrl(video.videoMediaId),
      MediaRepository.instance.resolveUrl(video.thumbnailMediaId),
    ]);

    var hydrated = video.withMedia(
      videoUrl: media[0],
      thumbnail: media[1],
    );

    if (hydrated.instructorFirstName.isEmpty && hydrated.instructorId > 0) {
      hydrated = await _withInstructor(hydrated);
    }

    return hydrated;
  }

  Future<ExploreVideo> _withInstructor(ExploreVideo video) async {
    try {
      final data = await _api.get<dynamic>(
        '${ApiEndpoints.users}${video.instructorId}/',
      );
      final user = Json.asMap(data);
      if (user == null) return video;

      final nested = Json.asMap(user['user']) ?? user;

      return video.withInstructor(
        id: Json.asInt(nested['id']) ?? video.instructorId,
        firstName: Json.asString(nested['first_name']) ?? '',
        lastName: Json.asString(nested['last_name']) ?? '',
        image: ApiConfig.mediaUrl(
          Json.asString(nested['avatar']) ?? '',
        ),
      );
    } catch (_) {
      // The reel still plays without the instructor badge.
      return video;
    }
  }

  /// Fills in the file url of a portfolio item.
  Future<TeacherPortfolioItem> _hydratePortfolioItem(
    TeacherPortfolioItem item,
  ) async {
    final url = await MediaRepository.instance.resolveUrl(item.mediaId);
    if (url == null || url.isEmpty) return item;

    return item.isVideo
        ? item.withMedia(image: item.image, video: url)
        : item.withMedia(image: url);
  }
}

enum _HttpMethod { get, post }

final catalogRepositoryProvider = Provider((ref) => CatalogRepository.instance);
