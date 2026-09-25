# Mr. Cake — project memory

Flutter app for an Iranian cake/cooking course platform.
Backend `https://api.mceiran.website/api/`, schema `…/api/schema/` (**YAML by
default — append `?format=json`**). Repo `github.com/yazdanmni/mrcake_app`.

## Architecture conventions (do not fight these)

- **No state management package.** `flutter_riverpod` is a leftover dependency;
  screens are `StatefulWidget` + `setState`. Keep it that way.
- **Layering:** `pages/ → repositories/ → ApiClient` (one Dio singleton).
  Repositories are singletons: `XRepository.instance`.
- **Response envelope** `{success, message, data}` is unwrapped by
  `ApiClient.unwrapEnvelope`; DRF pages `{count, next, previous, results}` are
  passed through untouched. Read values with `Json.asMap / asInt / asString /
  asBool` — never raw casts.
- **Reads** go through `RemoteLoader.list|value|action` + `RemoteCache` (TTL).
  Only *public* reads may be cached; anything account-specific must always hit
  the network. User-initiated refresh must pass `refresh: true` to bypass the TTL.
- **UI scale:** `ScreenUtilInit` designSize `390×844`. Use `.w/.h/.sp/.r`.
  ⚠️ **`.sp` is `value * scaleWidth` in this project** — `ScreenUtilInit`'s
  `fontSizeResolver` defaults to `FontSizeResolvers.width`, which bypasses
  `minTextAdapt`, so **text grows with the screen WIDTH while `.h` boxes grow with
  the height**. Verified: on 1024×768, `scaleText` = 0.910 but `16.sp` = 42.01.
  Consequences: (a) never give a fixed `width` to a child of `Expanded`;
  (b) cap any text inside a height-sized box against that box
  (`min(16.sp, boxHeight * share)`); (c) **`Ink` applies its decoration's border
  as padding to its child** — the content box is `height - 2*(padding + border)`;
  (d) a font paints a line box a bit taller than `fontSize * height` and the
  engine rounds it to whole pixels, so reserve ~1.25×; (e) wrap text in
  `Flexible` so a short reservation clips instead of overflowing.
  **Test at 360×640, 768×1024, 844×390 and 1024×768** — a 390-wide phone hides
  this whole class (a 360-wide one overflowed by 6.7px).
- **Widget tests: load the real fonts** (`test/support/app_fonts.dart`,
  `await loadAppFonts()`) before asserting on layout. `flutter test` does not load
  the pubspec fonts, so Persian glyphs render as squares — wider/taller than
  reality, which both *creates* false `RenderFlex overflowed` and *hides* real
  ones. **Never swallow `overflowed by` in `FlutterError.onError`**: it also
  swallows the genuine overflow and makes `expect(tester.takeException(), isNull)`
  vacuous. Use `ignoreNetworkImageErrors()` for the unavoidable image failures.
  To assert "text was not clipped", compare against a `TextPainter` built from the
  widget's own style, not against `fontSize * height`.
- Palette: `lib/core/theme/app_colors.dart` (the `lib/core/common/app_colors.dart`
  one is dead). Fonts `bshabnam` / `pinarb` / `BShabnam`.
- **Back buttons:** `Navigator.canPop(context)` is the "was this screen pushed?"
  discriminator, because `MainBottomNavigation` is installed with
  `pushAndRemoveUntil(_, (_) => false)` → as a tab it is the only route
  (`canPop == false`). `CoursesScreen` is the one screen that is *both* a tab and
  a push target; `CoursesHeader` renders the arrow only when `canPop` is true.
  Screens that are only ever pushed (`StudentsScreen`, `RecipesScreen`) always
  show one.

## Domain rules

- **A paid course registration is a REQUEST, not a payment.** No gateway works
  (`mock_gateway` → `404 شناسه پرداخت یافت نشد` for every body). Paid → the app
  files a support ticket on the user's behalf (name, family name, phone filled in
  automatically) and parks the course in the **cart** until an admin approves.
  Only a free course or a **100 % coupon** enrolls immediately.
- ⚠️ **`v1/courses/enrollments/` does not exist on the live server**, even though
  it *is* declared in the OpenAPI schema (`PaginatedEnrollmentList`). Probed:
  `GET v1/courses/enrollments/` → `404 {"message":"یافت نشد."}`, while
  `GET v1/courses/my_courses/` → `401` unauthenticated (i.e. it *is* mounted).
  **Use `my_courses/`** — it answers `CourseList` objects directly, so nothing
  needs a second lookup. Pointing «دوره‌های من» / the cart at `enrollments/` is
  what produced «دوره یافت نشد». `enrollments/` is kept **only** as a best-effort
  source of `progress_percent`, inside a `try/catch`.
- Free/100 % enrollment happens via `POST v1/payments/orders/` with `course_ids`
  (+ optional `coupon_code`); `enrollments/` is `GET`-only, there is no POST on it.
- **Course ranking:** `GET v1/courses/?ordering=-students_count` — the live
  backend honours DRF `ordering` (verified `۳، ۲، ۰` vs the default `۲، ۰، ۳`), and
  unlike `best_selling/` it is **public** (`best_selling/` → `401` for a guest, so
  it can never be a guest-facing source). The home «دوره های محبوب» carousel uses
  it; `CourseUtils.getPopularCourses` re-sorts locally (students desc, ties by
  rating then id — Dart's `List.sort` is not stable) so an older deployment still
  renders in the right order.
- **«هنرجوها» is the نمونه کارها gallery, NOT a roster.** `StudentsScreen`
  (`lib/pages/students/students_screen.dart`) reads
  `GET v1/content/teacher-portfolio/` with **no** `teacher` filter, renders it
  with the teacher profile's own `TeacherPortfolioGrid`, and opens a work in the
  **Explore** player (`ReelsViewer`). **Both media types** (`image` and `video`)
  are supported there, with the same structure as the teacher profile's works
  block — that parity is a standing requirement, so a change to the teacher
  profile's portfolio must be mirrored on this page. The account roster was built
  and then removed on request — **do not re-add it**.
  `CatalogRepository.fetchStudents` (`GET v1/accounts/users/?role=user`,
  `role` enum `admin|super_admin|teacher|user`, **auth-required** — a guest gets
  `401`) is kept but has **no UI caller**.
- ⚠️ **A null query value becomes a bare key in Dio.** `{'teacher': null}`
  serialises as `?teacher` with no `=`, and DRF answers an empty integer filter
  with a **400**. Drop the entry instead: `'teacher': ?teacherId`.
- **Teacher portfolio:** `GET v1/content/teacher-portfolio/` (filters
  `is_published`, `ordering`, `page`, `page_size`, `search`, `teacher`, `type`) —
  **public** (`security: [{jwtAuth: []}, {}]`). `TeacherPortfolioItem` has
  `teacher` (the owner's profile id, readOnly) + `media` (an id resolved through
  `v1/media/{id}/`) and **no student field**, so works cannot be grouped per
  student. Its `type` is `image` | `video`, so any gallery of these is **mixed** —
  a renderer must cope with an item that has no video url.
  ⚠️ **A `video` work has no cover image.** The payload is
  `{id, type, description, position, is_published, teacher, media}` — no cover
  field. `image` comes from `json['image'] ?? json['thumbnail'] ?? json['media_url']`,
  none of which exist on a video row, so `image` stays empty and
  `TeacherPortfolioItemCard` paints its `play_arrow_rounded` badge (gated on
  `item.isVideo`) over the `Icons.image_outlined` **placeholder**. Image and video
  are **not symmetric**; the teacher profile behaves identically (same widget, same
  payload) — a poster frame needs a backend field, not a client fix. Do not
  "fix" it on one screen only.
- **`ReelsViewer` (Explore's vertical player) is shared** with «هنرجوها». It
  speaks `ExploreVideo` and has an **image mode**: an empty `videoUrl` *with* a
  thumbnail renders a full-bleed still and skips the player, the play/pause toggle
  and the progress bar, instead of reporting `آدرس ویدیو خالی است.`
- **Recipes:** `v1/courses/recipes/` filters are `category`, `course`,
  `difficulty`, `featured`, `is_active`, `ordering`, `page_size`, `search` — there
  is **no `course__isnull`**, so "recipes that belong to no course" is filtered in
  the app (`Recipe.courseId == null`). `RecipeList.course` is a plain nullable
  integer. When filtering a paginated list, advance on what the **backend**
  returned, never on what survived the filter, or a fully-filtered page ends the
  list and hides everything after it.
- `v1/payments/cart/` and `v1/discounts/apply/validate/` are declared in the
  schema with **no request/response body**. `GET cart` is public and returns a
  single object `{items, total_items, unique_courses, subtotal, total}` — parse
  it with `CartSummary`, **not** `PagedResult`.- **Nothing is activated on the device.** `EnrollmentStore` and `CartStore` were
  **deleted** (2026-09-24) — do not reintroduce them. «دوره‌های من» reads
  `GET v1/courses/my_courses/` only; the cart reads `GET v1/payments/cart/`
  only. A course appears in the profile only once the backend creates the
  enrollment (order settled).
- **The created order has the last word on free vs paid.** Read
  `OrderDetail.total_amount`; never branch on `CouponValidation.isFree`, because
  the validator can decode to an empty map. `total <= 0` → enroll, send **no**
  ticket and **no** cart row.
- Orders: `GET v1/payments/orders/` (list) / `/{id}/` (detail, only payload with
  `items[]`). `status` = `pending|paid|failed|canceled|refunded`. Not cached.
- **Navigation:** profile course tap → `CourseLearningScreen` **directly**;
  course-details student button + the free-registration CTA → same screen.
  `CourseLearningScreen.open(context, {course, details})` takes an optional
  `details` (`CourseDetails.seedFrom(course)` when the caller has none).

## Landmines

- ⚠️ **Never run `git stash` or `git gc` in this repo.** A `git stash push`
  triggered `gc --auto` which was killed mid-repack and destroyed
  `.git/objects/pack/*` + `.git/refs/`. Use `git worktree add --detach <path> HEAD`
  when a clean-HEAD comparison is needed.
- ⚠️ **`flutter test` has no Persian font** — every glyph renders as a square of
  `fontSize`, so production screens report `RenderFlex overflowed` and the failure
  reads *"Multiple exceptions (N) were detected"*, not a failed `expect()`.
  **Fix it at the source: `await loadAppFonts()`** (see the conventions above) —
  never filter the error. Enlarging `tester.view.physicalSize` does not help —
  ScreenUtil scales the text by the same factor. Note `testWidgets` installs its
  own `FlutterError.onError` when the body starts, overwriting anything set in
  `setUp`, which is why `ignoreNetworkImageErrors()` is called *inside* each test
  body rather than in `setUp`.
- Widget tests fake only the socket: `FakeApiAdapter implements HttpClientAdapter`
  and route by path. Everything above it stays production code.
- ⚠️ **`flutter test` fails with `WebSocketException: Invalid WebSocket upgrade
  request` when a proxy is set.** The runner talks to `flutter_tester` over a
  localhost WebSocket and `HTTP_PROXY`/`HTTPS_PROXY` hijack it. Not a code bug —
  it fails on tests that always passed. Run:
  `env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy NO_PROXY=localhost,127.0.0.1 flutter test`
