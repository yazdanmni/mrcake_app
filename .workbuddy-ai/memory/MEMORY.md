# Mr. Cake — project memory

Flutter app, Iranian cake/cooking course platform.
Backend `https://api.mceiran.website/api/`; schema `…/api/schema/` (YAML by
default — append `?format=json`). Media host `media.dl.mceiran.website`.
Repo `github.com/yazdanmni/mrcake_app`.

## Architecture (do not fight these)

- **No state management.** Screens are `StatefulWidget` + `setState`;
  `flutter_riverpod` is a leftover dep and the last Riverpod screen was removed
  2026-09-26 — **do not reintroduce**.
- **Layering** `pages/ → repositories/ → ApiClient` (one Dio singleton);
  repositories are singletons `XRepository.instance`.
- **Envelope** `{success, message, data}` unwrapped by `ApiClient.unwrapEnvelope`;
  DRF pages `{count, next, previous, results}` pass through untouched. Read with
  `Json.asMap/asInt/asString/asBool` — never raw casts.
  ⚠️ `PagedResult.from({})` treats an **empty map as a single object**
  (`items: [{}], count: 1`) — test fakes must return a real empty DRF page for
  "nothing", and 404 (not `{}`) for a missing detail row.
- **Reads** go through `RemoteLoader.list|value|action` + `RemoteCache` (TTL 5 min
  = `AppConfig.catalogueCacheTtl`). Only *public* reads may be cached;
  account-specific always hits the network. User-initiated refresh passes
  `refresh: true`. `RemoteLoader.action(label, run, {onError})` — `onError`
  surfaces the real `ApiException.message` instead of a generic string.
  `AppConfig.useSeedFallback = true` shows bundled seed data when the backend
  errors or returns an empty page — pass `seed: const []` where a fake row would
  open a broken screen.
- **Auth:** `ApiClient` sends `Authorization: Bearer` only when
  `accessTokenProvider` yields a token; `onUnauthorized` fires only if a token
  *was* sent, so a guest's 401 never logs anyone out.
  ⚠️ **Media lookups are auth-only** (`v1/media/{id}/` → 401), while the CDN
  (`media.dl.mceiran.website`) is public. Any public list that returns media
  **ids** (explore videos, portfolio) renders media-blind for a guest — see the
  `MediaResolution` pattern below.
- **UI scale** `ScreenUtilInit` designSize `390×844`; use `.w/.h/.sp/.r`.
  ⚠️ **`.sp` = `value * scaleWidth`** (`fontSizeResolver` defaults to
  `FontSizeResolvers.width`, bypassing `minTextAdapt`), so **text grows with the
  screen WIDTH while `.h` boxes grow with the height** — on 1024×768 `scaleText` =
  0.910 but `16.sp` = 42.01. Consequences: (a) never fix a `width` on a child of
  `Expanded`; (b) cap text inside a height-sized box (`min(16.sp, boxH * share)`);
  (c) **`Ink` applies its decoration border as padding** — content =
  `height - 2*(padding + border)`; (d) a font paints a line box taller than
  `fontSize * height` and the engine rounds to whole px → reserve ~1.25×;
  (e) wrap text in `Flexible` so a short reservation clips instead of overflowing;
  (f) a fixed-height square cell holding a wrapping label needs `maxLines: 1` +
  ellipsis; (g) **any height reserved as a bare `const double` is a bug** — derive
  it from the same `.sp` values the text uses (bit `course_intro_videos.dart`).
  **Test at 360×640, 768×1024, 844×390, 1024×768** — a 390-wide phone hides this
  whole class (360-wide overflowed by 6.7px).
- **Widget tests: load the real fonts** (`test/support/app_fonts.dart`,
  `await loadAppFonts()`). `flutter test` does not load pubspec fonts, so Persian
  glyphs become squares (wider/taller than reality), which both *creates* false
  `RenderFlex overflowed` and *hides* real ones; the failure then reads *"Multiple
  exceptions (N) were detected"* rather than a failed `expect()`. **Never swallow
  `overflowed by` in `FlutterError.onError`** — it also swallows the genuine
  overflow and makes `expect(tester.takeException(), isNull)` vacuous. Use
  `ignoreNetworkImageErrors()` for image failures and call it *inside* each test
  body (`testWidgets` installs its own `FlutterError.onError` when the body
  starts). To assert "not clipped", compare against a `TextPainter` built from the
  widget's own style, not `fontSize * height`. Enlarging
  `tester.view.physicalSize` does not help — ScreenUtil scales the text too.
  Fakes: `FakeApiAdapter implements HttpClientAdapter`, routed by path.
  ⚠️ **A test process has no video decoder** — `VideoPlayerController.initialize()`
  throws `UnimplementedError`. Copy `FakeVideoPlatform extends VideoPlayerPlatform`
  from `test/teacher_portfolio_test.dart` and install it in `setUp`; without it the
  player never mounts and you get `Bad state: No element`.
  ⚠️ **A route push needs two pumps**: `tester.pump()` runs the handler that
  pushes, a second `tester.pump(Duration)` builds the new route. One pump leaves
  the pushed route on the stack but unbuilt → `Bad state: No element`, which
  misleadingly reads as "the tap did nothing".
  ⚠️ After a push, the route **underneath stays mounted**, so
  `find.text('X')` can match twice — scope with `find.descendant(of: find.byType(
  ThePushedScreen), …)`.
  ⚠️ **A test that triggers a real network call leaks a pending timer** and dies
  with `'!timersPending'` at teardown. Widget-test-only services need a probe that
  fails *before* the download tier (see `VideoThumbnailService._probeNative`).
  ⚠️ `flutter test` fails with `WebSocketException: Invalid WebSocket upgrade
  request` when a proxy is set — not a code bug. Run:
  `env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy NO_PROXY=localhost,127.0.0.1 flutter test`
- Palette `lib/core/theme/app_colors.dart` (the `lib/core/common/app_colors.dart`
  one is dead). Fonts `bshabnam` / `pinarb` / `BShabnam`.
- **Screen header pattern** (house style, copy verbatim): plate
  `Scaffold(backgroundColor: AppColors.background) > SafeArea`; header row with a
  `pinarb 20.sp` title inside `Flexible` + ellipsis, and a back pill `44.w × 44.w`,
  `premium @ 0.12` fill, `radius 14.r`, `Border.all(premium, 1.5.w)`,
  `arrow_back_ios_rounded 19.sp`. Section titles are a pill `33.h`, `premium`,
  `radius 8.r`, `bshabnam 16.sp` white. Empty state = `52.sp` premium icon + `15.h`
  + `bshabnam 16.sp` `textPrimary` `height: 1.8`, padding `h 25.w / v 50.h`.
  References: `courses_header.dart`, `recipes_screen.dart`, `students_screen.dart`,
  `introduction_videos_screen.dart`.
- **Back buttons:** `Navigator.canPop(context)` is the "was this pushed?"
  discriminator, because `MainBottomNavigation` is installed with
  `pushAndRemoveUntil(_, (_) => false)` → as a tab it is the only route
  (`canPop == false`). `CoursesScreen` is the one screen that is *both* tab and
  push target; `CoursesHeader` renders the arrow only when `canPop`. Screens that
  are only ever pushed (`StudentsScreen`, `RecipesScreen`,
  `IntroductionVideosScreen`) always show one.
- ⚠️ **A `Positioned.fill` `PageView` over content swallows every tap.** A
  full-size transparent `PageView` on top of a card layer makes the carousel
  decorative; the top layer must own the gesture and report the tap itself. A
  `GestureDetector(behavior: HitTestBehavior.opaque)` + `SizedBox.expand()` pages
  is the fix; `IgnorePointer` on the layer beneath is then safe.
  (`ClipRect` prevents *paint* overflow but **not** `RenderFlex` layout overflow.)

## Domain rules

- **A paid course registration is a REQUEST, not a payment.** No gateway works
  (`mock_gateway` → `404 شناسه پرداخت یافت نشد` for every body). Paid → the app
  files a support ticket on the user's behalf (name/family/phone auto-filled) and
  parks the course in the **cart** until an admin approves. Only a free course or a
  **100 % coupon** enrolls immediately.
- ⚠️ **`v1/courses/enrollments/` does not exist live** although declared in the
  OpenAPI schema. Use **`my_courses/`** (answers `CourseList` directly); pointing
  «دوره‌های من» / cart at `enrollments/` produced «دوره یافت نشد». `enrollments/` is
  kept only as a best-effort `progress_percent` source inside `try/catch`.
- Free/100 % enrollment = `POST v1/payments/orders/` with `course_ids`
  (+ optional `coupon_code`); `enrollments/` is GET-only.
- **The created order has the last word on free vs paid.** Read
  `OrderDetail.total_amount`; never branch on `CouponValidation.isFree` (the
  validator can decode to an empty map). `total <= 0` → enroll, **no** ticket, no
  cart row.
- **Course ranking:** `GET v1/courses/?ordering=-students_count` — the live backend
  honours DRF `ordering` and it is **public** (`best_selling/` → 401 for a guest).
  Home «دوره های محبوب» uses it; `CourseUtils.getPopularCourses` re-sorts locally
  (students desc, ties by rating then id — `List.sort` is not stable).
- **Tapping a «دوره های محبوب» card opens that course** — the tap is reported by
  the top carousel layer (`_openCenteredCourse`, `_page.round()` →
  `courses[index]`), not by the `CourseCard` underneath.
- **Course intro teasers (تیزر):** `CatalogRepository.fetchCourseIntroVideos()`
  = `GET v1/courses/` then each course's `GET v1/courses/{id}/` trailer, assembled
  into `CourseIntroVideo` via `CourseIntroVideo.fromCourseDetails`, filtered on
  `details.hasIntroVideo`. Cached under `'course-intros:p$page'`. Consumed by
  **both** the home «معرفی دوره ها» carousel and `IntroductionVideosScreen` — they
  share `CourseIntroVideoCard` so they cannot drift. Tapping a teaser opens the
  YouTube-style `IntroductionVideoPlayerScreen`.
- **«هنرجوها» is the نمونه کارها gallery, NOT a roster.** `StudentsScreen` reads
  `GET v1/content/teacher-portfolio/` with **no** `teacher` filter, renders it with
  the teacher profile's own `TeacherPortfolioGrid`, opens works in `ReelsViewer`.
  **Both media types** supported; parity with the teacher profile's works block is
  a standing requirement. The account roster was built then removed — **do not
  re-add it** (`CatalogRepository.fetchStudents` is kept but has no UI caller).
- ⚠️ **A null query value becomes a bare key in Dio**: `{'teacher': null}` →
  `?teacher` with no `=`, and DRF answers an empty integer filter with **400**.
  Drop the entry instead.
- **Teacher portfolio:** `GET v1/content/teacher-portfolio/` filters `is_published`
  `ordering` `page` `page_size` `search` `teacher` `type` — **public**. Item has
  `teacher` (owner profile id, readOnly) + `media` (resolved via `v1/media/{id}/`)
  and no student field; `type` is `image|video`.
  ⚠️ **A `video` work has no cover image** — the payload has no cover field, so
  `image` stays empty and `TeacherPortfolioItemCard` paints its
  `play_arrow_rounded` badge (gated on `item.isVideo`) over the
  `Icons.image_outlined` **placeholder**. A poster frame needs a backend field, not
  a client fix; don't "fix" one screen only.
- **`ReelsViewer`** (Explore's vertical player, `PageView`) is shared with
  «هنرجوها»; speaks `ExploreVideo` and has an **image mode** (empty `videoUrl` +
  thumbnail → full-bleed still, no play toggle, no progress bar).
  ⚠️ **Media ids a guest cannot resolve are NOT "no video".**
  `MediaRepository.resolveUrlDetailed` returns a `MediaResolution` whose `reason`
  is `missing` or `unauthorized`; `ExploreVideo.videoNeedsAuth` carries it from
  `CatalogRepository._hydrateVideo` into `ReelsViewer`, which then says
  «برای پخش این ویدیو وارد حساب خود شوید» + «ورود به حساب» instead of the false
  «آدرس ویدیو خالی است.» + a futile «تلاش مجدد». `SessionManager.save/clear` call
  `RemoteCache.clear()`, so signing in re-hydrates the ids with a token.
- **Recipes:** `v1/courses/recipes/` filters `category` `course` `difficulty`
  `featured` `is_active` `ordering` `page_size` `search` — **no `course__isnull`**,
  so "recipes with no course" is filtered in-app (`Recipe.courseId == null`).
  `RecipeList.course` is a plain nullable integer. When filtering a paginated list,
  advance on what the **backend** returned, never on what survived the filter.
- **Support tickets:** `POST v1/support/` — `priority` enum is
  `{low, medium, high, urgent}`; the app used to send `'normal'` (invalid) so every
  ticket failed with `400`. There is no endpoint to mark a ticket read/closed, and
  `v1/notifications/` is **read-only** (list + mark-read only).
- **Discount codes («هدیه ها»):** source `GET v1/discounts/apply/my_coupons/`
  → `{"success":true,"data":[...]}` **bare list, not a DRF page** — parse with a
  plain `List`, never `PagedResult`. The coupon object is the `Coupon` schema:
  `id, code, title, description, discount_type, discount_value,
  max_discount_amount, min_order_amount, usage_limit, usage_per_user, used_count,
  used_percentage, is_first_purchase_only, specific_user, specific_courses,
  specific_categories, exclude_courses, status, valid_from, valid_until, is_active,
  created_at, updated_at`. ⚠️ the date fields are **`valid_from` / `valid_until`**
  — **not** `start_date` / `end_date`. `specific_user` is null for a public coupon
  and set for one granted to a single account.
  ⚠️ **There is no "handed over" event.** The feed is a flat list of the user's
  own coupons and `status` is `active` whether or not an admin has released it,
  so "the code was just activated for you" can only be approximated by *first
  sighting*. A `specific_user == null` coupon is public and gets **no** notice.
- **«هدیه ها» names the course by reading the catalogue.**
  `CatalogRepository.fetchGiftCatalogue()` = `GET v1/courses/?page_size=100`
  (cached, public), so a `specific_courses` id can be printed as a title without
  one request per id. A coupon's own `title`/`description` are the text the
  discount-code notifications use.
- **`v1/notifications/` is read-only** (list + `{id}/read/` only — there is no
  endpoint that *writes* a notification). Every reminder the app raises itself is
  therefore synthesised locally and merged into the list with a **negative id**,
  and `_markRead` treats `id < 0` as local. Two producers: `LessonWatchDog`
  (uses `-lessonId`) and `GiftWatchDog` (uses `-(1000000 + couponId*10 + kind)`
  so the two ranges can never collide). Both share the **hourly**
  `NotificationScheduler.sweep`. ⚠️ Reading «اعلان ها» must not *consume* an
  alert — only the sweep and `_markRead` mark one delivered, otherwise an alert
  seen in the list never reaches the phone.
- `v1/payments/cart/` and `v1/discounts/apply/validate/` have **no body** in the
  schema. `GET cart` is public and returns one object
  `{items, total_items, unique_courses, subtotal, total}` — parse with
  `CartSummary`, **not** `PagedResult`. `v1/discounts/apply/validate/` returns
  `{...}` that can decode to an **empty map** — never branch on it.
- **Nothing is activated on the device.** `EnrollmentStore` / `CartStore` were
  **deleted** (2026-09-24) — do not reintroduce. «دوره‌های من» reads `my_courses/`
  only; cart reads `payments/cart/` only.
- Orders: `GET v1/payments/orders/` (list) / `/{id}/` (detail, the only payload with
  `items[]`); `status` = `pending|paid|failed|canceled|refunded`. Not cached.
- **Navigation:** profile course tap → `CourseLearningScreen` **directly**;
  course-details student button + free-registration CTA → same screen.
  `CourseLearningScreen.open(context, {course, details})` — `details` optional
  (`CourseDetails.seedFrom(course)` when the caller has none).

## Landmines

- ⚠️ **Never run `git stash` or `git gc` in this repo.** A `git stash push` fired
  `gc --auto`, killed mid-repack, destroying `.git/objects/pack/*` + `.git/refs/`.
  Use `git worktree add --detach <path> HEAD` for a clean-HEAD comparison. On
  Windows the worktree path must be **native** (`C:/Users/...`), never MSYS
  `/c/...` — the latter becomes `C:/c/Users/...` and must be undone with
  `git worktree prune`.
- ⚠️ **`POST v1/media/` drops the connection for ANY multipart request carrying a
  real file part** — probed live: a text field → 401 (reaches Django); a real file
  part (`filename=`, any size, any field name, any content-type) → **HTTP 000 /
  curl 26 (read error)**. Django never sees it → proxy/CDN rejection in front of
  the API. **No client change can make uploads succeed**; the app only reports the
  real reason. The rest of `v1/media/` (GET/`{id}/`) is fine.

## Testing gotchas

- ⚠️ **Any test that signs a user in must call
  `SharedPreferences.setMockInitialValues({})` first.** In a test process the
  platform channel has no implementation, so `SessionManager.save` →
  `_persist()` → `getInstance()` never completes and the `await` never returns.
  The failure is a bare `TimeoutException after 10 minutes` with **no stack**,
  which looks exactly like an infinite animation and sends you chasing
  `pumpAndSettle` for nothing.
- ⚠️ **A bare `pumpWidget(ScreenUtilInit(...))` needs a warm-up pump first.**
  `SplashScreen.initState` calls `NotificationScheduler.instance.start()`, which
  arms a real `Timer.periodic(Duration(hours: 1))`; `pumpAndSettle` then waits on
  it forever. `await tester.pumpWidget(const SizedBox.shrink()); await tester.pump();`
  before the ScreenUtil tree avoids it.
- ⚠️ **`find.text('دوره')` does not match a `'دوره:'` `Text` in RTL.** A label
  built as `'$label:'` lays out as **two text runs** in a Persian/RTL app, so a
  finder that measures one run matches nothing even though the word is on screen.
  Assert the colon form. (Same class of trap as the `.sp`-scales-with-width rule:
  never assume a `Text`'s `data` equals one finder string.)
- `flutter test` needs:
  `env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy NO_PROXY=localhost,127.0.0.1 flutter test`
  and it routinely outlives the tool timeout → run it with `run_in_background`.
