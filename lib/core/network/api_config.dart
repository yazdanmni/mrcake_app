/// Central configuration for the Mr. Cake backend.
///
/// Base URL  : https://api.mceiran.website/api/
/// Swagger   : https://api.mceiran.website/api/schema/swagger/
/// Media CDN : https://media.dl.mceiran.website/
class ApiConfig {
  ApiConfig._();

  /// Every request is relative to this URL, therefore all endpoint constants
  /// below start with `v1/` (never with a leading slash, otherwise Dio would
  /// replace the `/api/` part of the base url).
  static const String baseUrl = 'https://api.mceiran.website/api/';

  /// Absolute host used for images / videos returned by the API.
  static const String mediaBaseUrl = 'https://media.dl.mceiran.website/';

  // ---------------------------------------------------------------------------
  // Timeouts
  // ---------------------------------------------------------------------------

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 25);
  static const Duration sendTimeout = Duration(seconds: 40);

  /// Lightweight request used by the splash screen to measure the user's
  /// connection. Kept short so the splash never feels stuck.
  static const Duration probeTimeout = Duration(seconds: 9);

  /// The splash is never shorter than this, so the branding is always visible.
  static const Duration splashMinDuration = Duration(milliseconds: 1500);

  /// Hard ceiling for the splash: even on a dead network the app moves on and
  /// shows the error state instead of freezing.
  static const Duration splashMaxDuration = Duration(seconds: 12);

  /// How long the VPN warning stays on screen before continuing automatically.
  static const Duration vpnWarningAutoContinue = Duration(seconds: 7);

  /// Turns a relative media path coming from the API into an absolute url.
  /// Already absolute urls are returned untouched.
  static String mediaUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final clean = path.startsWith('/') ? path.substring(1) : path;
    return '$mediaBaseUrl$clean';
  }
}

/// All endpoints used by the application, grouped by feature.
///
/// Screen -> Endpoint -> Model -> Repository mapping is documented per group.
class ApiEndpoints {
  ApiEndpoints._();

  // ---------------------------------------------------------------------------
  // accounts / auth
  // SplashScreen, LoginScreen, LoginOtpScreen, LoginPasswordScreen,
  // CompleteProfileScreen, ChangePasswordScreen
  // -> AuthRepository
  // ---------------------------------------------------------------------------

  static const String sendOtp = 'v1/accounts/auth/send-otp/';
  static const String verifyOtp = 'v1/accounts/auth/verify-otp/';
  static const String loginPassword = 'v1/accounts/auth/login-password/';
  static const String changePassword = 'v1/accounts/auth/change-password/';
  static const String resetPassword = 'v1/accounts/auth/reset-password/';
  static const String logout = 'v1/accounts/auth/logout/';

  // ---------------------------------------------------------------------------
  // accounts / profile  -> ProfileRepository
  // ---------------------------------------------------------------------------

  static const String profile = 'v1/accounts/profile/';
  static const String profileComplete = 'v1/accounts/profile/complete/';

  // ---------------------------------------------------------------------------
  // accounts / users + teachers -> ProfileRepository / TeacherRepository
  // ---------------------------------------------------------------------------

  static const String users = 'v1/accounts/users/';
  static const String usersMe = 'v1/accounts/users/me/';
  static const String teachers = 'v1/accounts/teachers/';
  static const String teacherPortfolios = 'v1/accounts/teacher-portfolios/';
  static const String teacherPortfoliosApply =
      'v1/accounts/teacher-portfolios/apply/';

  static String teacherPortfolio(int id) => '$teacherPortfolios$id/';
  static String teacherPortfolioApprove(int id) =>
      '$teacherPortfolios$id/approve/';
  static String teacherPortfolioReject(int id) =>
      '$teacherPortfolios$id/reject/';

  // ---------------------------------------------------------------------------
  // media -> MediaRepository
  // ---------------------------------------------------------------------------

  static const String media = 'v1/media/';

  // ---------------------------------------------------------------------------
  // banners -> BannerRepository
  // HomeScreen / SplashScreen
  // ---------------------------------------------------------------------------

  static const String banners = 'v1/banners/';
  static const String bannersHeroActive = 'v1/banners/hero/active/';
  static const String bannersAllActive = 'v1/banners/all_active/';
  static const String bannersByType = 'v1/banners/by_type/';
  static const String bannersBadges = 'v1/banners/badges/';

  static String bannerClick(int id) => '$banners$id/click/';

  // ---------------------------------------------------------------------------
  // courses -> CourseRepository
  // CoursesScreen, CourseDetailsScreen, CourseLearningScreen
  // ---------------------------------------------------------------------------

  static const String courses = 'v1/courses/';
  static const String coursesFeatured = 'v1/courses/featured/';
  static const String coursesLatest = 'v1/courses/latest/';
  static const String coursesFree = 'v1/courses/free/';
  static const String coursesPaid = 'v1/courses/paid/';
  static const String coursesBestSelling = 'v1/courses/best_selling/';
  static const String coursesMyCourses = 'v1/courses/my_courses/';
  static const String coursesMyFavorites = 'v1/courses/my_favorites/';
  static const String coursesCategories = 'v1/courses/categories/';
  static const String coursesCategoriesTree = 'v1/courses/categories/tree/';
  static const String coursesCategoriesFeatured =
      'v1/courses/categories/featured/';
  static const String coursesChapters = 'v1/courses/chapters/';
  static const String coursesLessons = 'v1/courses/lessons/';
  static const String coursesEnrollments = 'v1/courses/enrollments/';
  static const String coursesReviews = 'v1/courses/reviews/';
  static const String coursesTags = 'v1/courses/tags/';

  static String course(int id) => '$courses$id/';
  static String courseMyProgress(int id) => '$courses$id/my_progress/';
  static String courseToggleFavorite(int id) => '$courses$id/toggle_favorite/';
  static String courseMarkLesson(int id) => '$courses$id/mark_lesson/';
  static String courseTogglePublish(int id) => '$courses$id/toggle_publish/';

  // ---------------------------------------------------------------------------
  // content -> ContentRepository
  // ExploreScreen (reels)
  // ---------------------------------------------------------------------------

  static const String exploreVideos = 'v1/content/explore-videos/';
  static const String contentTeacherPortfolio = 'v1/content/teacher-portfolio/';

  static String exploreVideo(int id) => '$exploreVideos$id/';

  // ---------------------------------------------------------------------------
  // recipes -> RecipeRepository
  // RecipesScreen, RecipeDetailScreen
  // ---------------------------------------------------------------------------

  static const String recipes = 'v1/courses/recipes/';
  static const String recipesFeatured = 'v1/courses/recipes/featured/';

  static String recipe(int id) => '$recipes$id/';
  static String recipeView(int id) => '$recipes$id/view/';

  // ---------------------------------------------------------------------------
  // payments -> CartRepository / OrderRepository
  // ---------------------------------------------------------------------------

  static const String cart = 'v1/payments/cart/';
  static const String cartClear = 'v1/payments/cart/clear/';
  static const String cartSync = 'v1/payments/cart/sync/';
  static const String orders = 'v1/payments/orders/';
  static const String payments = 'v1/payments/payments/';
  static const String paymentsCallback = 'v1/payments/payments/callback/';

  /// The `mock` gateway: completes a payment without a real bank redirect.
  /// `mock_gateway` is the only payment endpoint the schema marks as reachable
  /// **without** a token (it doubles as the server-to-server gateway callback),
  /// but the app always calls it authenticated.
  static const String paymentsMockGateway =
      'v1/payments/payments/mock_gateway/';
  static const String paymentsVerifyMock = 'v1/payments/payments/verify_mock/';

  static String order(int id) => '$orders$id/';
  static String cartItem(int id) => '$cart$id/';
  static String payment(int id) => '$payments$id/';

  // ---------------------------------------------------------------------------
  // discounts -> DiscountRepository
  // ---------------------------------------------------------------------------

  static const String discounts = 'v1/discounts/';
  static const String discountsValidate = 'v1/discounts/apply/validate/';
  static const String discountsMyCoupons = 'v1/discounts/apply/my_coupons/';

  static String discount(int id) => '$discounts$id/';
  static String discountToggleActive(int id) => '$discounts$id/toggle_active/';
  static String discountUsages(int id) => '$discounts$id/usages/';

  // ---------------------------------------------------------------------------
  // notifications -> NotificationRepository
  // ---------------------------------------------------------------------------

  static const String notifications = 'v1/notifications/';

  static String notification(int id) => '$notifications$id/';
  static String notificationRead(int id) => '$notifications$id/read/';

  // ---------------------------------------------------------------------------
  // support -> SupportRepository
  // TicketsScreen
  // ---------------------------------------------------------------------------

  static const String support = 'v1/support/';
  static const String supportMyTickets = 'v1/support/my_tickets/';
  static const String supportSubjects = 'v1/support/subjects/';

  static String supportTicket(int id) => '$support$id/';
  static String supportTicketClose(int id) => '$support$id/close/';
  static String supportTicketSeen(int id) => '$support$id/seen/';
  static String supportTicketSendMessage(int id) => '$support$id/send_message/';

  // ---------------------------------------------------------------------------
  // settings -> SettingsRepository
  // ---------------------------------------------------------------------------

  static const String settings = 'v1/settings/';

  static String setting(String key) => '$settings$key/';
}
