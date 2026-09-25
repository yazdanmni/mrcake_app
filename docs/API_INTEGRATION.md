# Mr. Cake — API Integration

Backend connection for the Flutter app. **Dio only**, no state‑management package
(no BLoC / Provider / Riverpod). State is plain `setState`, `ChangeNotifier` and
singletons.

| | |
|---|---|
| Base URL | `https://api.mceiran.website/api/` |
| Swagger | `https://api.mceiran.website/api/schema/swagger/` |
| OpenAPI JSON | `https://api.mceiran.website/api/schema/?format=json` |
| Media CDN | `https://media.dl.mceiran.website/` ⚠️ **broken certificate — see §7** |
| Auth | `Authorization: Bearer <JWT>` (`jwtAuth`) |

---

## 0. ⚠️ Server media does not load — broken TLS certificate

**Every image in the app is invisible, and the cause is server-side.**

`media.dl.mceiran.website` serves a certificate that does not cover its own
hostname:

```bash
$ openssl s_client -connect media.dl.mceiran.website:443 \
      -servername media.dl.mceiran.website | openssl x509 -noout -subject -ext subjectAltName
  subject=CN=alvand.irandns.com
  X509v3 Subject Alternative Name:
      DNS:alvand.irandns.com            ← only this; media.dl.mceiran.website is absent
```

Compare the API host, which is configured correctly:

```
  subject=CN=*.mceiran.website
  SAN: DNS:*.mceiran.website, DNS:mceiran.website, DNS:www.api.mceiran.website
```

Because the hostname is not in the SAN list, **every HTTPS client rejects the
host** — `Image.network`, a browser, `curl` — with a hostname mismatch:

```
HandshakeException: Handshake error in client
```

The files themselves are perfectly fine. Fetching with verification skipped
returns `200 image/png` and a complete 24 223-byte PNG. Only the certificate is
wrong.

This affects **all** server content, because every URL the backend returns is on
that host:

| Content | URL |
|---|---|
| category icons | `https://media.dl.mceiran.website/categories/icons/2026/09/22/cake.png` |
| hero | `https://media.dl.mceiran.website/hero/2026/09/21/home_hero.png` |
| home banner | `https://media.dl.mceiran.website/banners/images/2026/09/22/234564765__1.webp` |

### The fix (server-side, not in the app)

Issue a certificate whose SAN list includes `media.dl.mceiran.website` — or serve
media from a host the existing `*.mceiran.website` wildcard already covers.

No app-side change can substitute for that. The media is not reachable on any
other host (`api.mceiran.website/media/…` → `404`, `media.mceiran.website` does
not resolve), so rewriting the URL is not an option either.

### Temporary workaround — currently ENABLED

`lib/core/network/media_host_overrides.dart` + `AppConfig.allowInsecureMediaHost`.

`allowInsecureMediaHost` is currently **`true`**, which is what makes server
images display. It changes **no UI** — it only lets the existing `Image.network`
calls succeed.

It is deliberately narrow: `badCertificateCallback` returns `true` **only** for
`media.dl.mceiran.website`. The API host, the payment gateway and the VPN probe
keep full certificate validation, so the JWT is never exposed.

While it is `true`, someone able to intercept traffic to that one host could
serve arbitrary images. **Set it back to `false` once the certificate covers
`media.dl.mceiran.website`.** Debug builds log every accepted certificate so it
cannot be forgotten silently:

```
[MEDIA-TLS] accepting a mismatched certificate for media.dl.mceiran.website
(cert CN="/CN=alvand.irandns.com", issuer="/C=US/O=Let's Encrypt/CN=YE2").
This is the temporary workaround in MediaHostHttpOverrides — fix the server
certificate and set AppConfig.allowInsecureMediaHost = false.
```

### Verified: the real image pipeline decodes server media

`test/live_media_image.dart` drives `NetworkImage` — the exact class behind
`Image.network` — with a url produced by the API model:

```
category image url -> https://media.dl.mceiran.website/categories/icons/2026/09/21/cake.png
[MEDIA-TLS] accepting a mismatched certificate for media.dl.mceiran.website …
decoded -> 512 x 512
```

That is the whole chain proven end to end: API → model → image loader → decoded
bitmap.

> Note: this test lives in its own file because `testWidgets` initialises the
> widget binding, which installs an `HttpOverrides` that blocks real HTTP for the
> **entire file**. Mixing it with the plain `test()`s in `live_api_smoke.dart`
> silently broke nine of them.

### The app already degrades gracefully

All 26 `Image.network` calls in `lib/pages` have a matching `errorBuilder`, so if
an image ever does fail it shows a placeholder (an icon or a themed box) instead
of a broken image or a red error widget.

---

## 1. Screen → Endpoint → Model → Repository

### Auth flow (fully implemented)

| Screen | Method + Endpoint | Model | Repository |
|---|---|---|---|
| `SplashScreen` | `GET v1/banners/hero/active/` (warm‑up probe) | `HeroSection` | `NetworkProbe` / `CatalogRepository` |
| `SplashScreen` | – (local) | `VpnStatus` | `VpnDetector` |
| `LoginScreen` | `POST v1/accounts/auth/send-otp/` (existence probe, `purpose=forgot_password`) | `AccountProbeResult` | `AuthRepository.checkAccountExists` |
| `LoginScreen` | `POST v1/accounts/auth/send-otp/` (`purpose=registration`) | `bool` | `AuthRepository.sendOtp` |
| `LoginOtpScreen` | `POST v1/accounts/auth/verify-otp/` | `AuthSession` + `UserModel` | `AuthRepository.verifyOtp` |
| `LoginOtpScreen` | `POST v1/accounts/auth/send-otp/` (resend) | `bool` | `AuthRepository.sendOtp` |
| `LoginPasswordScreen` | `POST v1/accounts/auth/login-password/` | `AuthSession` + `UserModel` | `AuthRepository.loginWithPassword` |
| `CompleteProfileScreen` | `POST v1/accounts/profile/complete/` | `UserModel` | `ProfileRepository.completeProfile` |
| `CompleteProfileScreen` | `POST v1/media/` (avatar, multipart) | `MediaModel` | `MediaRepository.upload` |
| `ChangePasswordScreen` | `POST v1/accounts/auth/change-password/` (auth) | `AuthSession` | `AuthRepository.changePassword` |
| `ChangePasswordScreen` | `POST v1/accounts/auth/reset-password/` (phone + otp) | `AuthSession` | `AuthRepository.resetPassword` |
| `MainBottomNavigation` | `POST v1/accounts/auth/logout/` | – | `AuthRepository.logout` |

### Catalogue (fully wired — every screen loads from the API)

| Screen | Method + Endpoint | Model | Repository |
|---|---|---|---|
| `HomeScreen` | `GET v1/banners/by_type/?type=home_top` → `banners/` | `BannerModel` | `CatalogRepository.fetchHomeBanners` |
| `HomeScreen` | `GET v1/courses/categories/featured/` → `categories/` | `CategoryModel` | `CatalogRepository.fetchFeaturedCategories` |
| `HomeScreen` | `GET v1/courses/featured/` → `best_selling/` | `Course` | `CatalogRepository.fetchFeaturedCourses` |
| `HomeScreen` (popular carousel) | `GET v1/courses/?ordering=-students_count` → `courses/` | `Course` | `CatalogRepository.fetchCoursesByStudents` |
| `HomeScreen` (intro videos) | derived from the course list | `CourseIntroVideo` | `CourseIntroVideo.fromCourse` |
| `CoursesScreen` | `GET v1/courses/?category=&search=` | `Course` | `CatalogRepository.fetchCourses` |
| `CoursesScreen` | `GET v1/courses/categories/` | `CategoryModel` | `CatalogRepository.fetchCategories` |
| `CourseCategoriesScreen` | `GET v1/courses/categories/tree/` | `CategoryModel` | `CatalogRepository.fetchCategoryTree` |
| `CourseCategoriesScreen` | `GET v1/courses/?category={id}` | `Course` | `CatalogRepository.fetchCourses` |
| `CourseDetailsScreen` | `GET v1/courses/{id}/` | `CourseDetails` | `CatalogRepository.fetchCourseDetails` |
| `CourseLearningScreen` | `GET v1/courses/{id}/` + `chapters/?course=` | `CourseChapter` | `CatalogRepository.fetchCourseDetails` / `fetchChapters` |
| `LessonScreen` | `GET v1/courses/lessons/{id}/` | `CourseLesson` | `CatalogRepository.fetchLesson` |
| `LessonScreen` | `POST v1/courses/{id}/mark_lesson/` (on video end) | – | `CatalogRepository.markLesson` |
| `ExploreScreen` | `GET v1/content/explore-videos/` | `ExploreVideo` | `CatalogRepository.fetchExploreVideos` |
| `ExploreScreen` | `GET v1/media/{id}/` (resolves media ids) | `MediaModel` | `MediaRepository.resolveUrl` |
| `RecipesScreen` | `GET v1/courses/recipes/?search=` | `Recipe` | `CatalogRepository.fetchRecipes` |
| `RecipesScreen` | `GET v1/accounts/teachers/` (author names) | `Teacher` | `CatalogRepository.fetchTeachers` |
| `StudentsScreen` | `GET v1/accounts/teacher-portfolios/` (**no** `teacher` filter) | `TeacherPortfolioItem` | `CatalogRepository.fetchTeacherPortfolio` |
| `StudentsScreen` | `GET v1/accounts/teachers/` (resolves the work's owner) | `Teacher` | `CatalogRepository.fetchTeachers` |
| `RecipeDetailScreen` | `GET v1/courses/recipes/{id}/` | `Recipe` | `CatalogRepository.fetchRecipe` |
| `RecipeDetailScreen` | `GET v1/accounts/teachers/{id}/` → `users/{id}/` | `Teacher` | `CatalogRepository.fetchTeacher` / `fetchTeacherByUserId` |
| `TeacherScreen` | `GET v1/accounts/teachers/{id}/` | `Teacher` | `CatalogRepository.fetchTeacher` |
| `TeacherScreen` | `GET v1/accounts/teacher-portfolios/?teacher={id}` | `TeacherPortfolioItem` | `CatalogRepository.fetchTeacherPortfolio` |
| `SearchScreen` | `GET v1/courses/?search=` | `Course` | `CatalogRepository.fetchCourses` |
| `ProfileScreen` | `GET v1/accounts/profile/` | `UserModel` | `ProfileRepository.fetchProfile` |
| `ProfileScreen` | `PATCH v1/accounts/profile/` | `UserModel` | `ProfileRepository.updateProfile` |
| `ProfileMyCoursesSection` | `GET v1/courses/my_courses/` | `Course` | `CatalogRepository.fetchMyCourses` |
| `ProfileMyCoursesSection` (progress only) | `GET v1/courses/enrollments/` — ⚠️ **404 on the live server** | `Enrollment` | `CatalogRepository.fetchEnrollments` |
| `TicketsScreen` | `GET v1/support/my_tickets/` | `TicketModel` | `SupportRepository.fetchMyTickets` |
| `TicketsScreen` | `GET v1/support/subjects/` | `TicketSubject` | `SupportRepository.fetchSubjects` |
| `TicketDetailsScreen` | `GET v1/support/{id}/` | `TicketMessage[]` | `SupportRepository.fetchTicket` |
| `CreateTicketScreen` | `POST v1/support/` | `TicketDetail` | `SupportRepository.createTicket` |
| `CreateTicketScreen` | `POST v1/media/` (attachment) | `MediaModel` | `MediaRepository.uploadUrl` |
| `CartScreen` | `GET v1/payments/cart/` | `CartSummary` | `ShopRepository.fetchCart` |
| `CartScreen` | `POST v1/payments/cart/` | — | `ShopRepository.addToCart` |
| `CartScreen` | `DELETE v1/payments/cart/{id}/` | — | `ShopRepository.removeCartItem` |
| `OrdersScreen` | `GET v1/payments/orders/` | `CourseOrder` | `ShopRepository.fetchOrderSummaries` |
| `OrderDetailsScreen` | `GET v1/payments/orders/{id}/` | `CourseOrder` + `CourseOrderLine` | `ShopRepository.fetchOrderDetails` |
| `CourseDetailsScreen` | `POST v1/payments/orders/` (registration) | `OrderDetail` | `ShopRepository.createOrder` |

#### Repository methods that exist but have no screen yet

| Endpoint | Repository method | Why it is unused |
|---|---|---|
| `POST v1/accounts/auth/logout/` | `AuthRepository.logout` | the design has **no logout button** anywhere; the call is ready to be attached to one |
| `POST v1/courses/{id}/toggle_favorite/` | `CatalogRepository.toggleFavorite` | no favourite button in the course detail design |
| `GET v1/courses/reviews/` · `POST v1/courses/reviews/` | `fetchReviews` / `submitReview` | no review UI yet |
| `GET v1/courses/my_favorites/` | `fetchMyFavorites` | no favourites screen |
| `POST v1/payments/cart/sync/` · `DELETE v1/payments/cart/clear/` | `ShopRepository.syncCart` / `clearCart` | the cart is a list of *pending requests*, not a basket to sync or empty |
| `GET v1/notifications/` | `NotificationRepository` | no notifications screen |

#### Three backend gaps worth knowing

1. **There is no `POST courses/enrollments/`.** `v1/courses/enrollments/` is
   `GET`‑only, so the backend creates an enrollment as a side effect of an
   **order**. The only write path the app has is:

   ```
   POST v1/payments/orders/   {course_ids: [12], gateway: 'mock', coupon_code?}
        → GET  v1/courses/my_courses/  now contains the course
   ```

2. **`v1/courses/enrollments/` does not exist on the live server.** It *is*
   declared in the OpenAPI schema (`PaginatedEnrollmentList`, `jwtAuth`), but
   `GET /api/v1/courses/enrollments/` answers

   ```
   404 {"success": false, "message": "یافت نشد.", "status_code": 404}
   ```

   (probed unauthenticated; `my_courses/` answers `401` instead, which is how
   you can tell it is the one that is actually mounted). **Use
   `GET v1/courses/my_courses/`** — it answers `CourseList` objects directly, so
   nothing has to be looked up a second time. Pointing «دوره‌های من» and the cart
   at `enrollments/` is what produced «دوره یافت نشد» on a profile that owned
   courses. `enrollments/` survives only as a **best-effort** source of
   `progress_percent`, wrapped in a `try/catch`.

3. **`v1/courses/best_selling/` is auth-only.** A guest gets
   `401 اطلاعات برای اعتبارسنجی ارسال نشده است.`, so the home carousel used to
   fall back to the bundled seed data for anyone not signed in. The student
   ranking is read from the **public** `v1/courses/` instead.

   `OrderCreate` accepts **`course_ids`** directly (`{coupon_code, gateway,
   description, course_ids}`). `gateway` defaults to `mock`; the enum is
   `mock | zarinpal | idpay | other` and only `mock` can complete without a real
   bank redirect.

   **`ShopRepository.createOrder` used to be wrong** — it sent
   `{gateway, address_id, note}`. Neither `address_id` nor `note` exists on
   `OrderCreate`, and `course_ids` (the field that actually puts a course in the
   order) was missing, so it could only ever have produced an empty order. It is
   fixed, and it is now the **first step of every registration** — free, 100 %
   coupon or paid. A paid order additionally files a ticket and waits in the cart
   until an admin marks it paid; a zero-total order enrolls immediately. See
   [§7](#7-course-registration-coupons--enrollment).

   **Still open:** the body of `mock_gateway` is unknown. Every candidate
   (`{}`, `{payment}`, `{payment_id}`, `{id}`, `{authority}`, `{order_id}`,
   `{order, amount}`) returns the identical
   `404 شناسه پرداخت یافت نشد` — for `POST` *and* for `GET` — because the
   database holds no payments to look up, and the schema types the request body
   as `Payment`, which is a *response* schema. Rather than guess (a guessed body
   is exactly the bug that `createOrder` had), the method is deliberately **not**
   written; see the comment block in `ShopRepository` for how to finish it. The
   app is designed to work without it: the order itself is the registration
   record, and it is read back through `GET v1/payments/orders/` (§7.5).

2. **`is_enrolled` / `is_favorite` / `user_review` / `teacher_profile`** are
   declared as `string` in the OpenAPI document although the backend sends a
   boolean / object. `Json.asBool` / `Json.asInt` / `Json.asMap` accept every
   shape, so the models are unaffected.

3. **`OrderItem` exposes no course id** — only `course_title`, `unit_price`,
   `quantity`, `discount_per_item`, `line_total`. Matching an order line back to
   a course therefore has to go through the title, or the backend has to add the
   field.

---

## 2. Architecture

```
lib/
├─ core/
│  ├─ app_config.dart              feature switches (auto-login, VPN warning)
│  ├─ network/
│  │  ├─ api_config.dart           base url, media url, timeouts, ALL endpoints
│  │  ├─ api_exception.dart        ApiErrorType + Persian messages + field errors
│  │  ├─ api_client.dart           the single Dio instance + envelope unwrapping
│  │  ├─ network_probe.dart        splash warm-up / connection quality
│  │  └─ vpn_detector.dart         VPN / proxy detection (no native plugin)
│  ├─ router/app_router.dart       every navigation decision of the auth flow
│  ├─ session/session_manager.dart JWT + profile cache (SharedPreferences)
│  └─ utils/                       validators, currency + Jalali date formatting
├─ models/                         UserModel, AuthSession, BannerModel, ...
└─ repositories/                   AuthRepository, ProfileRepository, ...
```

### Request pipeline

```
Screen ──▶ Repository ──▶ ApiClient (Dio)
                             ├─ onRequest  : Authorization: Bearer <token>
                             ├─ onResponse : 2xx OK, 401 → SessionManager.clear()
                             └─ unwrap     : {success, message, data} → data
                                          (errors → ApiException)
```

### The response envelope

The backend answers with:

```json
{ "success": true,  "message": "کد تایید ارسال شد", "data": { ... } }
{ "success": false, "message": "...", "errors": { "field": ["..."] }, "status_code": 400 }
```

`ApiClient.unwrapEnvelope` returns `data` on success and throws an
`ApiException` (with the backend's own Persian sentence) on failure. List
endpoints that return a raw DRF page (`{count, next, previous, results}`) are
passed through untouched and normalised by `PagedResult`.

---

## 3. Auth flow

```
Splash
  │  session restore + VPN check + network probe (duration = network speed)
  ├─ VPN detected ──▶ warning card on the splash (auto-continue)
  ├─ no network   ──▶ error card + «تلاش مجدد»
  ├─ valid JWT    ──▶ MainBottomNavigation            (AppConfig.autoLoginWithSavedToken)
  └─ no JWT       ──▶ Login

Login  (phone + «ادامه» / «رد شدن»)
  ├─ «رد شدن» ─────────────────────────────────────▶ MainBottomNavigation (guest)
  ├─ phone NOT registered ─▶ send-otp(registration) ─▶ OTP ─▶ CompleteProfile ─▶ Main
  └─ phone registered     ──────────────────────────▶ Password
        ├─ correct password ───────────────────────▶ Main
        ├─ «ورود با کد تایید» ─▶ send-otp(login) ──▶ OTP ─▶ Main
        └─ «رمز عبورتان را گم کردید؟»
              └─ send-otp(forgot_password) ─▶ OTP ─▶ ChangePassword ─▶ Main
                                                     («رد شدن» also allowed)
```

### How "does this phone number have an account?" is answered

The whole auth surface is six endpoints — `send-otp`, `verify-otp`,
`login-password`, `reset-password` (public) and `change-password`, `logout`
(auth). **There is no "does this phone exist" endpoint**, so the app uses the one
signal the backend does expose:

* `POST v1/accounts/auth/send-otp/` with `purpose=forgot_password`
  → **HTTP 400** `حساب کاربری با این شماره یافت نشد` when the number is unknown,
  → **HTTP 200** when the account exists.

`login-password` answers `حساب کاربری با این شماره وجود ندارد` for unknown
numbers too, but it was deliberately **not** used: probing it would mean sending
a fake password on every login attempt and could trip account lock-outs.

#### ⚠️ The probe costs an SMS — a product decision, not a bug

`SendOTP` is `{phone_number (required), purpose}` with **no check-only flag**, so
the 200 branch means an OTP SMS was actually sent. Consequence: **a user who
already has an account receives an SMS the moment they tap «ادامه» on the login
screen**, before they have chosen anything — they only wanted the password screen.

This is unavoidable through the documented API. Two mitigations are already in
place:

* the probe result is cached per phone number for 12 hours
  (`_AccountProbeCache`), so the SMS is sent at most once per device per number;
* `AuthRepository.hasFreshOtp` reuses an OTP sent less than 3 minutes ago instead
  of paying for a second SMS, so the «ورود با کد تایید» button is free if the
  probe just ran.

If the SMS cost or the surprise matters, the alternatives are (a) ask the backend
for a dedicated `accounts/auth/check-phone/` endpoint, or (b) probe
`login-password` with a dummy password and accept the lock-out risk. The change
is confined to `AuthRepository.checkAccountExists`.

#### 400 is not always "unknown number"

`checkAccountExists` only treats a 400 as "no account" when
`ApiException.isUnknownPhone` matches the phrasing, and **rethrows anything
else**. That matters: a malformed number also answers 400, but with
`یک شماره تماس معتبر وارد نمایید.` Reading that as "no account" would send a typo
to the OTP screen instead of showing the validation error on the login form.

Four tests lock this down in `test/widget_test.dart`: the `یافت نشد` phrasing, the
`login-password` `وجود ندارد` phrasing, the invalid-format sentence (must be
`false`), and a 404 `شناسه پرداخت یافت نشد` (must be `false` — the status guard).

> If the backend later adds an explicit "phone exists" endpoint, only
> `AuthRepository.checkAccountExists` needs to change.

### Session

`SessionManager` (a `ChangeNotifier` singleton) stores the JWT and the profile
in `SharedPreferences`:

* `mr_cake.auth.access_token`, `mr_cake.auth.refresh_token`
* `mr_cake.auth.user`, `mr_cake.auth.last_phone`

`ApiClient` reads the token through a callback, so there is no circular
dependency. On `401` the interceptor calls `SessionManager.clear()` and the next
screen falls back to the login form.

---

## 4. Splash screen

* The default Flutter launch screen was removed on both platforms:
  * Android — `drawable/launch_background.xml`, `drawable-v21/…`,
    `values/styles.xml`, `values-night/styles.xml` and
    `values-v31/styles.xml` (Android 12 splash) now all use
    `@color/splash_background` (`#FFF8F0`) with a transparent system icon.
  * iOS — `LaunchScreen.storyboard` uses the same brand colour and the default
    `LaunchImage` was removed.
* Duration follows the network: the splash waits for
  `GET v1/banners/hero/active/` (which also warms up DNS + TLS), with
  `splashMinDuration = 1.5 s` and `splashMaxDuration = 12 s` plus a safety timer.
* VPN detection combines the network interface list (`tun0`, `ppp0`, `utun4`, …)
  with a best-effort public-IP country lookup on a **separate** Dio client so the
  user's JWT is never sent to a third party. A `utun` interface alone is not
  treated as a VPN on iOS (system interfaces).
* If a VPN is detected the error card is rendered on the splash; the app then
  continues automatically (`AppConfig.blockOnVpn = false`).

---

## 5. Configuration switches

`lib/core/app_config.dart`

| Switch | Default | Effect |
|---|---|---|
| `autoLoginWithSavedToken` | `true` | splash → main when a JWT is stored |
| `showVpnWarning` | `true` | render the VPN card on the splash |
| `blockOnVpn` | `false` | require a tap instead of auto-continuing |
| `enableVpnIpLookup` | `true` | public-IP country signal for VPN detection |
| `useSeedFallback` | `true` | keep the bundled seed content when the API errors or returns an empty page |
| `catalogueCacheTtl` | `5 min` | in-memory TTL for resolved catalogue responses (`Duration.zero` disables) |
| `allowInsecureMediaHost` | **`true`** | ⚠️ accepts the mismatched certificate for the media host only — this is what makes server images display. Revert to `false` once the cert is fixed. See §0 |

### Why `useSeedFallback` exists

The production database is still being filled, so most catalogue endpoints
answer with an **empty page** and `GET v1/courses/` currently answers **HTTP
500**. Without a fallback every wired screen would render blank.

`lib/core/network/remote_data.dart` centralises the rule:

```dart
final result = await RemoteLoader.list(
  label: 'courses.best_selling',
  seed: CoursesData.courses,            // bundled mock data
  fetch: () => CatalogRepository.instance.fetchBestSellingCourses(),
);
// result.data     → API rows, or the seed when the call failed / came back empty
// result.isRemote → true only when the rows really came from the backend
```

* `RemoteLoader.list` — list screens (courses, recipes, explore, tickets, enrollments)
* `RemoteLoader.value` — detail screens (course, lesson, recipe, teacher, profile)
* `RemoteLoader.action` — fire‑and‑forget writes (favourite, mark‑lesson, logout)
* `RemoteCache` — the TTL cache behind `catalogueCacheTtl`

Every screen therefore renders instantly from the seed and swaps in the real
rows as soon as they arrive; a `RefreshIndicator` re-runs the same loader.
Set `useSeedFallback = false` to see the true backend state.

### What `catalogueCacheTtl` actually caches

The cache lives inside `CatalogRepository._cached(key, fetch)` and is **opt‑in
per endpoint**, because caching the wrong thing shows a user data that belongs to
someone else — or to their past self.

| Cached (public) | Key | Why |
|---|---|---|
| course lists (`featured`, `latest`, `free`, `paid`, `best_selling`) | `courses:{path}:p{n}` | identical for every visitor |
| categories (`categories`, `featured`, `tree`) | `categories:{path}:p{n}` | change rarely |
| course detail | `course-detail:{id}` | `CourseDetailsScreen` loads it and `CourseLearningScreen` loads it again immediately — the cache removes one full round trip per course opened |
| lesson / chapter | `lesson:{id}` · `chapter:{id}` | static content |
| recipe list / detail | `recipe:{id}` | static content |
| explore reels, teacher portfolio | `explore:…` · `portfolio:…` | cached **after** media hydration, so the `v1/media/{id}/` lookups are not repeated |
| teachers | `teachers:…` · `teacher:{id}` · `teacher-user:{id}` | public profiles |

| **Never** cached | Why |
|---|---|
| `fetchEnrollments` | changes the moment the user enrols |
| `fetchMyCourses` · `fetchMyFavorites` | change on enrolment / favourite |
| `fetchCourseProgress` · `fetchReviews` | per‑account, changes constantly |
| `fetchCoursePage` (search) | one cache entry per query string is not worth the memory |
| profile | always must be fresh |

**Invalidation.** A write that changes what a cached read would return drops the
cache itself, so a mutation can never be hidden behind a stale response:

| Write | Invalidates |
|---|---|
| `markLesson` | everything (`invalidateCatalogueCache`) |
| `toggleFavorite` | everything |
| `submitReview` | `course-detail:` |
| `registerRecipeView` | `recipe:` |
| `SessionManager.save` / `.clear` | everything — a new account must not inherit the previous one's `is_enrolled` / `is_favorite` |

`RemoteCache` is covered by 8 unit tests (round‑trip, type mismatch, null,
prefix invalidation, clear, remove) in `test/widget_test.dart`.

### Pull‑to‑refresh must bypass the cache

A cached read would answer the pull with the same rows it already had, so the
gesture would look broken. `RemoteLoader` therefore takes a `refresh` flag:

```dart
Future<void> _load({bool refresh = false}) async {
  final result = await RemoteLoader.list<Course>(
    label: 'courses.list',
    seed: CoursesData.courses,
    refresh: refresh,               // true → RemoteCache.clear() first
    fetch: () => _repository.fetchCourses(),
  );
  …
}

RefreshIndicator(onRefresh: () => _load(refresh: true), child: …)
```

| Screen | `_load` | `onRefresh` |
|---|---|---|
| `CoursesScreen` | `_load({bool refresh = false})` | `() => _load(refresh: true)` |
| `HomeScreen` | `_load({bool refresh = false})` | `() => _load(refresh: true)` |
| `ProfileScreen` | `_load()` — profile is not cached, so it already re‑fetches | `_load` |

`RemoteLoader` itself is covered by 8 more tests (success, failure → seed, empty
page → seed, empty seed stays empty, refresh clears, no‑refresh keeps, `value`
fallback, `action` never throws).

---

## 6. Verified against the live API

### Automated: `test/live_api_smoke.dart`

A smoke test that exercises the **real** backend through the real stack (Dio →
`ApiClient` → envelope → `PagedResult` → `fromJson` mappers). It is deliberately
**not** named `*_test.dart`, so `flutter test` does not pick it up and the normal
suite stays offline and deterministic. Run it explicitly:

```bash
NO_PROXY="localhost,127.0.0.1,::1" flutter test test/live_api_smoke.dart
```

Last run: **10/10 pass.** What it proved that static analysis cannot:

| Check | Result |
|---|---|
| `fetchCategories()` mapping | 2 categories; `name`→`title`, `icon`→`image`, `slug`, `isRoot` all correct |
| `fetchCategoryTree()` | 1 root with `children=1` — nesting works |
| `fetchFeaturedCategories()` | envelope unwrapped, 1 item |
| `fetchActiveHero()` | `id=2`, real `media.dl.mceiran.website` url |
| `fetchHomeBanners()` | returns `[]` — **no 401 for a guest** |
| `fetchActiveBanners()` | `401` — confirms the auth requirement is real |
| `fetchCourses()` | `500` → `ApiException(type: server, message: خطای سرور داخلی)`, no crash |
| `RemoteLoader` on that 500 | keeps the seed, `isRemote: false`, `hasError: true` |
| `RemoteLoader` on an empty page | keeps the seed |
| caching | two calls → **one** network request, 1 cache entry |

### Manual probes

| Check | Result |
|---|---|
| `GET v1/banners/hero/active/` | `200 {"success":true,"data":{"id":2,"image":"https://media.dl.mceiran.website/hero/2026/09/21/home_hero.png"}}` |
| `GET v1/banners/by_type/?type=home_top` | `200 {"success":true,"data":[]}` (public) |
| `GET v1/banners/all_active/` | `401 اطلاعات برای اعتبارسنجی ارسال نشده است` (**auth required**) |
| `POST v1/accounts/auth/send-otp/` (valid phone) | `200 {"success":true,"message":"کد تایید ارسال شد","data":{"phone_number":"+98912…","purpose":"auth"}}` |
| `POST v1/accounts/auth/send-otp/` (bad phone) | `400 {"success":false,"errors":{"phone_number":["یک شماره تماس معتبر وارد نمایید."]},"status_code":400}` |
| `POST v1/accounts/auth/send-otp/` `purpose=forgot_password` (unknown phone) | `400 … "حساب کاربری با این شماره یافت نشد"` |
| `POST v1/accounts/auth/login-password/` (unknown phone) | `400 … "حساب کاربری با این شماره وجود ندارد"` |
| `POST v1/accounts/auth/verify-otp/` (wrong code) | `400 … "کد تایید اشتباه یا منقضی شده است"` |
| `GET v1/accounts/profile/` (no token) | `401 … "اطلاعات برای اعتبارسنجی ارسال نشده است."` |
| `POST v1/payments/payments/mock_gateway/` (any body) | `404 شناسه پرداخت یافت نشد` — see the payment note in §1 |
| `GET v1/payments/payments/mock_gateway/` (public, no token) | `404 شناسه پرداخت یافت نشد` — the endpoint keys off a **payment identifier**, so it is the gateway redirect handler, not a "create payment" call |
| `POST v1/discounts/apply/validate/` (unknown code, no token) | `404 کد تخفیف یافت نشد` — the coupon is looked up before auth is enforced |
| `POST v1/payments/orders/` (no token) | `401 ابتدا باید وارد حساب کاربری خود شوید` |

### The 401 that used to log guests out

`banners/all_active/` is `security: [{jwtAuth: []}]` — auth-required — while
`by_type`, `banners/` and `hero/active/` are `[{jwtAuth: []}, {}]` — public. The
home carousel originally fell back to `all_active/`, so a **guest** opening the
home screen took a 401.

Two fixes:

1. `fetchHomeBanners` now falls back to the public `banners/` endpoint.
2. `ApiClient`'s interceptor only treats a 401 as a dead session **when a token
   was actually sent**:

   ```dart
   final sentToken = response.requestOptions.headers['Authorization'];
   if (sentToken is String && sentToken.isNotEmpty) {
     unawaited(onUnauthorized?.call());
   }
   ```

   Without this, any screen that happens to call an auth-only endpoint while
   signed out would clear the session and wipe the response cache.

The database currently has **no user accounts**, so the "account exists" branch
of `send-otp` could not be executed end-to-end. `AuthSession.fromResponse`
therefore walks the payload and picks the first plausible token / user
(`data.access`, `data.tokens.access`, `data.token`, `data.user`, …) instead of
assuming one exact shape — it keeps working whichever serializer the backend
returns.

---

## 7. Course registration, coupons & enrollment

Everything below lives in
`lib/pages/course_details/course_details_screen.dart` (`_RegisterButton`),
`lib/models/coupon_model.dart`, `lib/models/cart_item.dart`,
`lib/models/course_order.dart`, `lib/repositories/support_repository.dart`
(`ShopRepository` + `SupportRepository`), `lib/pages/cart/cart_screen.dart` and
`lib/pages/orders/`.

**A paid registration is a request, not a payment.** Nothing is charged in the
app: the user is asked for a coupon code, the amount is settled, and if anything
is still owed the app files a support ticket on the user's behalf and parks the
course in the cart until an admin approves the order.

**Nothing is activated on the device.** There is no local mirror of enrollments
or of the cart any more — `EnrollmentStore` and `CartStore` were deleted. A
course appears in «دوره‌های من» only when the backend has actually created the
enrollment, and the profile reads `GET v1/courses/my_courses/` and nothing else
(`enrollments/` is only consulted best-effort for the progress bar — see gap 2
above).

### 7.1 The decision table

Every row below creates an order first. The order's `total_amount` is what
decides free vs paid — never the client-side coupon maths.

| Course / coupon | CTA on the dialog | Result |
|---|---|---|
| `access == free` | «ثبت نام دوره» | «ثبت نام در دوره» → checkbox → order → «ثبت نام با موفقیت انجام شد» → «شروع یادگیری» → course content |
| paid, **100 % coupon** | «ثبت نام رایگان فوری» | **identical to a free course** — same dialog, same checkbox, same success wording, `coupon_code` still sent to the order |
| paid, partial coupon | «ارسال درخواست ثبت نام» | price breakdown settles the amount → order (`pending`) + **ticket + cart**, nothing charged |
| paid, no coupon | «ارسال درخواست ثبت نام» | same — the coupon field is simply left empty |
| paid, invalid coupon | «ارسال درخواست ثبت نام» | inline error, then the request is filed **without** the bad code (an invalid code must never block it) |

Two things the wording is careful about: the free confirmation says *why* nothing
is owed («کد تخفیف شما کل هزینه این دوره را پوشش داد…» when a coupon did it,
«این دوره رایگان است…» when the course really is free), and the paid result is
**not** the green "payment succeeded" dialog — nothing was paid, so it says
«درخواست ثبت نام ارسال شد» and explains that the course is waiting in «سفارش‌ها»
and the cart.

### 7.2 The order has the last word

`_showFreeCourseConfirmDialog(context, {couponCode})` is the **only** "nothing to
pay" registration flow. A free course calls it with no coupon; a 100 % coupon
calls it with the code. That is what makes the two paths indistinguishable to the
user — the requirement was that a 100 % code behaves exactly like a free course.

Both dialogs funnel into `_submitRegistration`, which returns
`({bool ok, bool wasFree, int? ticketId})`:

```dart
final order = await _createOrder(context: context, couponCode: couponCode);
if (!order.ok) return (ok: false, wasFree: false, ticketId: null);

_invalidateEnrolmentCaches();

if (order.total <= 0) {
  return (ok: true, wasFree: true, ticketId: null);   // nothing else is sent
}

final ticketId = await _fileEnrollmentTicket(/* … */);
return (ok: true, wasFree: false, ticketId: ticketId);
```

`wasFree` is read **from the created order** (`OrderDetail.total_amount`), not
from the client-side coupon maths. That matters because
`POST v1/discounts/apply/validate/` is documented with **no response body**: a
successful validation can decode to an empty map, in which case the client cannot
size the discount and only the order knows the truth.
`CouponValidation.fromJson(..., fallbackCode: code)` keeps the typed code so the
UI still names the coupon, and `hasDiscountData` says whether the numbers are
usable.

> **The bug this fixes.** A coupon that zeroed the amount used to still file a
> registration request. The free-vs-paid branch was taken from
> `CouponValidation.isFree`, i.e. from client-side arithmetic over a payload that
> may be empty. The decision now happens *after* the order exists, and the
> `total <= 0` branch returns **before** any ticket or cart call, so a zero total
> provably cannot send a request. `test/coupon_flow_test.dart` pins this down with
> a validator that answers `{}` (so the client cannot tell) and an order that
> answers `total_amount: 0` — no ticket, no cart row.

`course_ids` is the mandatory field and the only supported way to register a
course — `v1/courses/enrollments/` is read-only, there is no POST on it.

### 7.3 The ticket the app writes by itself

`_fileEnrollmentTicket` builds and posts a `TicketCreate`:

```
title      ثبت نام دوره «<course>» — <first name> <last name>   (≤ 250 chars)
message    نام و نام خانوادگی / شماره تماس / دوره / قیمت دوره /
           کد تخفیف / مبلغ تخفیف / مبلغ قابل پرداخت
subject_id resolved by name — see below
priority   high
```

* The **name rides in the title as well as the body**, because `TicketList` —
  the only payload the tickets screen reads — carries `title` / `subject` /
  `status` and nothing else. The body is what the detail screen shows.
* `مبلغ قابل پرداخت` is the **order's** total, so the ticket and the order can
  never disagree.
* `subject_id` is resolved by **name**, never by id: ids are database-assigned
  and would silently point at the wrong subject on another deployment. The live
  backend ships four subjects and the right one for a new purchase is
  `خرید دوره های جدید`. Matching folds the Arabic/Persian letter variants and the
  zero-width non-joiner, so «دوره‌های» and «دوره های» compare equal. If nothing
  matches, `subject_id` is left `null` (the field is nullable) — guessing
  `results.first` would be actively wrong, because the live endpoint returns
  subjects newest-first and the first row is «درخواست دوره های قبلی خودتان».
* `resolveNewPurchaseSubjectId()` never throws: a ticket with no subject beats no
  ticket.
* The whole method is **best-effort**: the order already exists by the time it
  runs, so a failure is logged and surfaces as `ticketId == null` in the result
  dialog rather than turning a registered request into an error screen.

`TicketDetailsScreen` used to render `TicketModel.description`, which the API
never provides, so the body was invisible for **every** ticket. It now fetches
`GET v1/support/{id}/` and renders the real `messages[]` (through the same
`_DetailBox` the rest of the screen uses), falling back to the old box when the
call returns nothing.

### 7.4 The cart means "waiting for approval"

A cart row here is not a basket waiting for a checkout button — it is an
enrollment request waiting for an admin, and `CartScreen` says so. There is
deliberately no "pay" action on it.

`GET v1/payments/cart/` is **public** and answers a single object, not a DRF page:

```json
{"success": true, "data": {
  "items": [], "total_items": 0, "unique_courses": 0,
  "subtotal": 0, "total": 0
}}
```

Reading that with `PagedResult.from` would wrap the whole object as one "item"
and produce a cart with a single meaningless row, so it is parsed by
`CartSummary`. The item fields themselves are **undocumented** — the endpoint is
declared in the schema with no request body *and* no response body — so
`CartItem.fromJson` reads the plausible names and degrades safely.

`CartScreen` renders exactly what the server returns, minus the rows that are no
longer pending: a course that has become an **enrollment** was approved, so it
belongs to «دوره‌های من», not here. That rule is what implements "پس از تأیید
دانشجو می‌شود و در پروفایل نمایش داده می‌شود": the backend creates the enrollment,
`ProfileMyCoursesSection` picks it up from `v1/courses/my_courses/`, and the cart
row disappears on its own.

Because there is no local copy to fall back on, a **failed** `DELETE` leaves the
row on screen and shows an error. Pretending it worked would make the row
reappear on the next load.

### 7.5 «سفارش های من» — the record of the request

`lib/pages/orders/orders_screen.dart` reads `GET v1/payments/orders/` and lists
**every** order the backend holds for the user. `OrderList` carries
`order_number`, `status`, `subtotal`, `discount_amount`, `total_amount`,
`paid_amount`, `payment_gateway`, `payment_time`, `items_count`, `created_at` and
`updated_at`.

Tapping an order opens `OrderDetailsScreen`, which fetches
`GET v1/payments/orders/{id}/`. That is the **only** payload carrying `items[]` —
`OrderItem.course_title` is a snapshot taken when the order was created
("عنوان دوره در زمان سفارش"), so an order stays readable even if the course is
later renamed or removed. The detail screen also shows `tax_amount`,
`description` and `coupon_code`, and is where the course an order was placed for
is actually named.

`status` is `Status628Enum`: `pending | paid | failed | canceled | refunded`, and
the Persian labels come from the schema itself (`OrderStatus.label`), never from
the raw enum.

The list is **not cached**: an order's status changes the moment an admin approves
it, and a stale «در انتظار پرداخت» would hide a course the user already owns.

The whole lifecycle, end to end:

```
register ─▶ POST payments/orders/  ─▶ order (pending) ─▶ «سفارش های من»
                    │
                    ├─ total == 0 ─▶ backend enrolls ─▶ «دوره‌های من»   (no ticket, no cart)
                    │
                    └─ total  > 0 ─▶ ticket + cart row
                                          │
                            admin marks the order paid
                                          │
                                          ▼
                              backend creates the enrollment
                                          │
                    ┌─────────────────────┴─────────────────────┐
                    ▼                                           ▼
          «دوره‌های من» gains the course            cart row disappears
```

### 7.6 Navigation: profile → course content

A course in «دوره‌های من» is already an enrollment — the backend created it — so
there is nothing to decide. Tapping it goes **straight** to
`course_learning_screen.dart`; there is no details screen in between and no
register button:

```dart
void _openCourse(Course course) {
  CourseLearningScreen.open(context, course: course);
}
```

On the course details screen the flow continues the same way: the button reads
«شما دانشجوی این دوره هستید» once `is_enrolled` is true, and tapping it — or the
«شروع یادگیری» CTA right after a free / 100 % coupon registration — opens the
same `CourseLearningScreen`.

`CourseLearningScreen` needs both a `Course` and a `CourseDetails` for its first
frame, but the profile only holds a `Course` from the enrollments endpoint.
`CourseLearningScreen.open(context, {course, details})` therefore accepts an
optional `details`: the course details screen hands over the payload it already
loaded, and the profile falls back to `CourseDetails.seedFrom(course)`, which the
screen immediately replaces with the server payload via `RemoteLoader.value`.

A **paid** request deliberately does not navigate anywhere: the course is not the
user's yet, so its dialog ends on «متوجه شدم» and nothing is activated on the
device.

### 7.7 What is verified, and what is not

Verified:

* `flutter analyze` → **0 errors** (23 pre-existing infos/warnings).
* `flutter test` → **244 / 244 pass, 0 failures.**
* `test/home_quick_actions_test.dart` (21 tests) — the four home shortcuts: no
  `RenderFlex` overflow on **eight** device sizes (320×568 up to 1024×768,
  portrait **and** landscape, including the 360×640 phone the report came from),
  the four cards fill the row without overlapping, a narrow phone really gets
  narrower cards, the label is never clipped (compared against a `TextPainter`,
  not against the widget's own constants), a 1.5× system font shrinks the icon
  rather than the label, and the design size is pixel-identical (85-tall cards
  spanning 25→365, a 37 icon circle, a 22 icon). See §7.11.
* `test/home_shortcuts_navigation_test.dart` (3 tests) — the **real**
  `HomeScreen` is pumped and each shortcut is tapped: «هنرجوها» lands on
  `StudentsScreen`, «رسپی‌ها» on `RecipesScreen`, «استاد» still on the teachers
  screen. The two roster shortcuts used to be `// TODO` stubs that did nothing.
* `test/students_portfolio_test.dart` (26 tests) — «هنرجوها», which is **only** the
  **نمونه کارها** gallery: it asks `accounts/teacher-portfolios/` **without** a
  `teacher` filter (so every teacher's works show), renders one card per work,
  **never reads the accounts endpoint**, paginates, still renders for a
  signed-out visitor, opens the Explore-style vertical player on tap at the
  tapped index, captions it with the owner when the teacher resolves and **drops**
  the caption when it does not, and on seven device sizes keeps every three-column
  cell inside the screen. It also pins the retained `fetchStudents` binding
  (`role=user`). Four tests pin `TeacherPortfolioItem.fromJson` on **both** payload
  shapes — the `accounts/` one has no `type` field, so a video row must be
  recognised from its `video` url, and a row with neither url must stay a picture
  rather than be handed to a player. Four more cover the gallery side of both
  media types (see §7.12).
  (This file replaced `students_screen_test.dart` — 12 tests for the account
  roster, which the screen no longer renders.)
* `test/teacher_portfolio_test.dart` (8 tests) — the teacher profile's own works
  block, driven through a **fake `VideoPlayerPlatform`** because a test process
  has no decoder. A video work is handed its `video` url and told to **play**; it
  is never reported as a playback failure; an image work renders its picture and
  never creates a player; a work with **neither** url creates nothing and shows
  the neutral panel; only the work on screen is playing; swiping pauses the one
  left behind; and the grid card badges a video while asking for **no** picture
  when its `image` is empty. See §7.12.
* `test/recipes_standalone_test.dart` (20 tests) — «رسپی‌ها» lists **only**
  recipes with no course (a course-linked recipe never appears, and a
  non-featured standalone recipe does), a page made entirely of course recipes
  does **not** end the pagination (verified to fail with the old guard — see
  §7.11), the app-wide empty state on an empty library, a *different* sentence
  when a search matched nothing, and no overflow on seven device sizes — for the
  populated grid **and** for the empty state.
* `test/back_button_policy_test.dart` (4 tests) — the conditional back button:
  `CoursesScreen` has none as the navigation tab and one when pushed (and it
  pops), the title stays pinned to the right either way, and `StudentsScreen`
  always has one.
* `test/banner_links_test.dart` (22 tests) — `ExternalLink` parsing, the banner
  link fields, the tap behaviour, the **3s autoplay** (see §7.10) and the hero.
* `test/popular_courses_test.dart` (9 tests) — the home carousel: the ranking
  itself (most students first, no per-type balancing, zero-student courses last,
  deterministic tie-breaks, `limit`) plus two widget tests driving the real
  `HomeCourses` against a fake server, asserting it asks for
  `ordering=-students_count` and fills the row from the top of the ranking.
* `test/profile_my_courses_test.dart` (6 tests) — «دوره‌های من» reads
  `my_courses/`, progress is enriched from `enrollments/` **when it answers**,
  a `404` on `enrollments/` does not hide the courses, the empty state, the
  failure state plus a successful retry, and tapping a course reports it back.
* `test/coupon_enrollment_test.dart` (11 tests) — the coupon arithmetic
  (100 % → free, partial → reduced, `max_discount_amount` cap, fixed coupon never
  over-discounts, invalid coupon, empty validator body) and `Enrollment.fromJson`
  against the `GET v1/courses/enrollments/` payload shape, including that a 100 %
  coupon enrollment is `is_paid == false` yet still an enrollment.
* `test/course_order_test.dart` (21 tests) — `CourseOrder` / `OrderStatus` /
  `OrderGateway`, the Jalali conversion (`PersianDate`) and the currency
  formatting.
* `test/cart_screen_test.dart` (5 tests) — the cart screen against a fake server:
  a pending row renders with its price, an empty cart explains what it is for,
  removing a row deletes it server-side, a **failed** delete keeps the row and
  says so, and a course that became an enrollment leaves the cart on its own.
* `test/orders_screen_test.dart` (6 tests) — «سفارش های من» reads
  `GET v1/payments/orders/`, a `pending` order is visibly pending and explains
  what happens next, a settled order shows as paid, every row the server returns
  is listed, the empty state, and opening an order fetches
  `GET v1/payments/orders/{id}/` and names the course from `items[]`.
* `test/coupon_flow_test.dart` (6 tests) — the flow driven through the **real**
  `CourseDetailsScreen` dialogs, with only the socket faked
  (`FakeApiAdapter implements HttpClientAdapter`). It proves:
  1. a paid course opens the coupon dialog first («ارسال درخواست ثبت نام», never
     «ادامه و پرداخت» and never the free CTA) and posts nothing on open,
  2. a 100 % coupon flips the CTA to «ثبت نام رایگان فوری», and tapping it enters
     the *same* «ثبت نام در دوره» confirmation dialog a genuinely free course
     uses — nothing is posted before the user confirms,
  3. the free path posts `{course_ids: [7], coupon_code: 'FREE100', gateway: 'mock'}`,
     files **no ticket and no cart row**, and ends with
     «ثبت نام با موفقیت انجام شد»,
  4. the free confirmation's «شروع یادگیری» lands on `CourseLearningScreen`,
  5. **the regression**: a validator that answers `{}` (so the client cannot tell
     whether the coupon is 100 %) plus an order that answers `total_amount: 0`
     still sends no ticket and no cart row — the order decides,
  6. a partial coupon settles `- 500,000 تومان` → `2,000,000 تومان`, then files a
     ticket whose body contains the user's name, family name and phone number and
     whose `subject_id` is `1` (matched by name against the live subject list),
     adds the course to the cart, and creates the order — nothing was charged,
  7. an invalid coupon shows the error but still files the request, with the bad
     code **omitted** from the body.

**Not** verified: the real `POST v1/payments/orders/` round trip, the real
`POST v1/payments/cart/` body, and the admin-side approval that flips an order to
`paid`. The first two need a logged-in test account and the backend has none; the
cart endpoint is declared with no request body in the schema, so
`{course, quantity}` is the app's existing convention and not a confirmed
contract. The third is a backend behaviour the app only observes.

**⚠️ Three live checks are stale, not broken.** `test/live_api_smoke.dart` is run
by hand and asserts against *server* behaviour, so it rots when the backend moves.
As of this round it reports **12 pass / 3 fail**, and all three failures are
expectations the server has outgrown — `courses/` no longer answers `500` (so "the
500 becomes an ApiException" and "RemoteLoader keeps the seed when that 500
happens" have nothing to trigger on), and the media host's certificate is no longer
rejected by a strict client. None of them touch the portfolio path, and the two
portfolio checks pass.

### 7.8 Test-harness notes

**Load the real fonts when a test asserts on layout.** `flutter test` does not
load the fonts declared in `pubspec.yaml`, so every Persian glyph is drawn as a
square of `fontSize`. That makes text measurably wider and taller than on a
device, and it turns real widgets into false `RenderFlex overflowed` reports —
which is exactly the failure a responsive-layout test exists to detect.
`test/support/app_fonts.dart` registers the bundled TTFs with a `FontLoader`:

```dart
await loadAppFonts();   // call inside the test body, before pumpWidget
```

**Do not "fix" it by swallowing the error.** The usual workaround is a
`FlutterError.onError` that returns early on `overflowed by`. That also swallows
the *genuine* overflow, and since `tester.takeException()` only sees what
`FlutterError.onError` forwarded, `expect(tester.takeException(), isNull)` then
passes no matter what the layout does — a vacuous assertion. With the fonts
loaded, the assertion means what it says. `ignoreNetworkImageErrors()` in the same
helper filters only the unavoidable image-load failures, never an overflow.

This matters in both directions: it was the real fonts that revealed the original
`HomeQuickActions` bug on a **360×640** phone (6.7px of overflow) that the
square-glyph font had been hiding. Family names must match `TextStyle.fontFamily`
exactly — the app spells them inconsistently (`Shabnam` / `shabnam`,
`BShabnam` / `bshabnam`), and an unregistered name silently falls back to squares.

**A rendered line box is not `fontSize * height`.** The engine rounds it to whole
pixels, so `16 * 1.1 = 17.6` paints as `18.0` and `10.37 * 1.1 = 11.4` paints as
`11.0`. To assert "this text was not clipped", measure the natural height with a
`TextPainter` using the widget's own style rather than multiplying the font size:

```dart
final TextPainter painter = TextPainter(
  text: TextSpan(text: label, style: style),
  textDirection: TextDirection.rtl,
  maxLines: 1,
)..layout();
expect(tester.getSize(finder).height, greaterThanOrEqualTo(painter.height - 0.01));
```

**`tester.tap` on an off-screen widget silently does nothing** when
`warnIfMissed: false` — in a scroll view, `await tester.ensureVisible(finder)`
first. A shortcut below the hero and the promo banner is otherwise untappable, and
the test fails as "the screen never opened" rather than "the tap missed".

**`flutter test` cannot reach `flutter_tester` when a proxy is configured.**
This shell exports `HTTP_PROXY` / `HTTPS_PROXY` (and the lowercase variants), and
the test runner talks to `flutter_tester` over a **localhost WebSocket**. With a
proxy set, that connection is routed through the proxy and dies immediately:
```
Failed to load "...": Unable to connect to flutter_tester process:
WebSocketException: Invalid WebSocket upgrade request
```

It is not a code failure — the same thing happens on a test that has always
passed. Unset the proxy variables for the run:

```bash
env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy \
    NO_PROXY=localhost,127.0.0.1 flutter test
```

**A widget test has no video decoder.** `VideoPlayerController.initialize()`
throws in a test process, so without help every work in the portfolio viewer looks
like a playback failure. `test/teacher_portfolio_test.dart` installs a fake
`VideoPlayerPlatform` and asserts on what it was asked to do:

```dart
VideoPlayerPlatform.instance = FakeVideoPlatform();   // in setUp
VideoPlayerPlatform.instance = originalPlatform;      // in tearDown
```

Three details make it work, and each is a trap on its own:

* **`videoEventsFor` must emit on listen.** `initialize()` subscribes and then
  waits for an `initialized` event; a `StreamController.broadcast()` drops the
  event if it fires before the subscription. Return
  `Stream.fromIterable([VideoEvent(eventType: initialized, duration: …, size: …)])`
  so it is emitted when listened to. The event's `duration` must be **non-null**,
  or the controller never considers itself initialized.
* **`buildViewWithOptions` must be overridden.** `VideoPlayer`'s own `build`
  calls it, so leaving it out makes the widget throw while mounting. A
  `ColoredBox` stands in for the texture.
* **Never `pumpAndSettle` once a video is playing.** `play()` starts a 500 ms
  periodic position timer, so settling never finishes. Pump a fixed number of
  frames instead, and dispose the tree at the end so the timer is cancelled
  before the test completes.

`video_player_platform_interface` is a **dev dependency** for this, exactly like
`url_launcher_platform_interface` before it, with the version pinned to match
`video_player`'s own constraint.

**Reading the live schema.** `GET https://api.mceiran.website/api/schema/`
returns **YAML** by default, which silently breaks `json.load`. Ask for JSON
explicitly:

```bash
curl -s -k "https://api.mceiran.website/api/schema/?format=json" -o schema.json
```

**`test/banner_links_test.dart`** used to fail with *"A Timer is still pending
even after the widget tree was disposed"*. The CTA calls `AppRouter.toCourses`,
which mounts `CoursesScreen`; its `initState` starts a real Dio request and its
list overflows the 800×600 test surface. Fixed by dropping the `pump()` after the
tap, so `CoursesScreen` is never built. **17 / 17 pass.**

**⚠️ Legacy: the overflow filter is superseded, do not copy it.** Some older
files (`cart_screen_test.dart`, `coupon_flow_test.dart`) still carry this helper:

```dart
void ignoreTestFontOverflow() {
  final void Function(FlutterErrorDetails)? original = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if ('${details.exception}'.contains('overflowed by')) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}
```

It was written when the only known cause of an overflow in `flutter test` was the
missing font. It is **not** the right fix, for the reason given above: it swallows
the genuine overflow too, so the assertion it protects can never fail. New tests
must call `loadAppFonts()` instead. The helper survives only in files that predate
`test/support/app_fonts.dart` and have not been migrated; do not add it to a new
one. (`testWidgets` installs the binding's own `FlutterError.onError` when the body
starts, so even the handler above has to be set inside the body — a `setUp` one is
overwritten before the first pump.)

### 7.9 «دوره های محبوب» — ranked by student count

The home carousel shows the courses with the **most students**, the best-seller
leading the row. The widget is untouched; only the data behind it changed.

**Source.** `GET v1/courses/?ordering=-students_count`.

```bash
# verified against the live backend
curl -s 'https://api.mceiran.website/api/v1/courses/'                     # ۲، ۰، ۳ هنرجو
curl -s 'https://api.mceiran.website/api/v1/courses/?ordering=-students_count'  # ۳، ۲، ۰
```

DRF `ordering` is honoured, and unlike `best_selling/` the endpoint is public,
so a guest sees the real ranking instead of the bundled seed. The list is also
sorted locally (`CourseUtils.getPopularCourses`) so an older deployment that
ignores `ordering` still renders in the right order.

**What was wrong before.** `CourseUtils.getPopularCourses` took `perType: 2`
courses out of every `CourseType` bucket and emitted them free → professional →
single. That is a *balanced mix*, not a ranking: the free bucket always led, so
the actual best-seller could sit behind a course with fewer students — and the
carousel only makes the card at its centre tappable, which is what made it look
like "the wrong course is the one displayed there".

**«مشاهده همه».** Both section headers on the home screen used a bare
`Container` with no gesture attached, so the button did nothing. They now go
through `_ViewAllButton` → `AppRouter.toCourses`. The geometry, colours and
typography are byte-for-byte what they were; only the tap handler is new.

**What was deliberately not touched.** The carousel mechanics
(`viewportFraction: 0.72`, `initialPage: 1`, the card offsets/scales/rotation in
`_CardsLayer`) are unchanged — the request was explicit about not changing the
UI/UX. Note that `initialPage: 1` means the **second** card is the one centred
at launch, with the first peeking to its side; the ranked order is what puts the
best-seller at the head of the row. Changing that is a one-line change to
`initialPage`, but it visibly alters how the section opens.

### 7.10 The promo banner carousel auto-advances every 3s

`HomeBanner` (`lib/pages/home/widgets/home_banner.dart`) flips to the next slide
on its own every **3 seconds**, wrapping around at the end. Nothing about the
slide design, the 94px height or the frosted-glass indicator changed.

**The bug it had to fix first.** The autoplay existed but could never run in the
real app. It was armed once, in `initState`:

```dart
void initState() {
  _startAutoPlay();          // widget.banners is still empty here
}

void _startAutoPlay() {
  if (widget.banners.length < 2) return;   // ← bails out, and never comes back
  ...
}
```

`HomeScreen` mounts the banner with `_banners = const []` and only replaces it
when `banners/by_type/?type=home_top` answers (the live server returns **2**
banners), so the guard always tripped and the timer was never re-armed. It only
ever worked in tests, where the banners are passed up front — which is why
nothing caught it. `didUpdateWidget` now re-arms the countdown whenever the list
changes (and clamps the page index if the list shrinks).

**Single-shot, not `Timer.periodic`.** The countdown is re-armed by
`onPageChanged`, so a slide the user swiped to by hand also gets its full 3s on
screen instead of being yanked away mid-read.

```
t+0.00  timer fires      → animateToPage(next)        → re-arm
t+0.45  animation settles → onPageChanged → re-arm    → fires at t+3.45
```

so each slide is on screen for exactly 3s, whether it arrived by timer or by
finger.

**Tests:** `test/banner_links_test.dart` → `HomeBanner autoplay` (5 tests):
advances every 3s, keeps cycling and wraps, a single slide never moves, **starts
once the API banners arrive** (the regression — verified to fail with
`didUpdateWidget` disabled), and a manual swipe is not yanked away. The waits use
3.1s rather than exactly 3s, because the countdown restarts on *settle* and an
exact 3s sits on the boundary.


### 7.11 The home shortcuts: responsive, wired, and when they show a back button

#### The overflow: `.sp` follows the width, `.h` follows the height

`HomeQuickActions` lays four `Expanded` cards in a row. Each card's `Ink` had a
**fixed** `width: 85.w` next to `height: 85.h`, and inside it an icon circle at
`37.w` and a label at `16.sp`.

The trap is that **`.sp` is `value * scaleWidth` in this project.** It looks like
it should be `min(scaleWidth, scaleHeight)` (`minTextAdapt` is `true` in
`main.dart`), but `ScreenUtil.setSp` is:

```dart
double setSp(num fontSize) =>
    fontSizeResolver?.call(fontSize, _instance) ?? fontSize * scaleText;
```

and `ScreenUtilInit.fontSizeResolver` **defaults to `FontSizeResolvers.width`**,
which returns `fontSize * scaleWidth` and bypasses `scaleText` entirely. Verified
on a 1024×768 surface: `ScreenUtil().scaleText` reports `0.910` while `16.sp`
evaluates to `42.01` — i.e. `16 * (1024 / 390)`. **Every `.sp` in the app grows
with the screen width.**

So the card's height came from the screen height while the icon *and* the text
came from the screen width. Measured with the bundled fonts, the original code:

| device | overflow |
|---|---|
| Galaxy **360×640** | `RenderFlex overflowed by 6.7 pixels` |
| iPad mini 768×1024 | `… by 38 pixels` |
| tablet landscape 1024×768 | `… by 52 pixels` |
| iPhone 13 390×844 (design) | none |

**The phone in the report is a 360-wide one.** A 390-wide test device hides it:
on 360 the label is `16 * 0.923 = 14.8px` while the card is `85 * 0.829 = 70.5px`
tall, and the two scales disagree by just enough. Two consequences worth keeping:
test at 360 (and in landscape), and remember that a phone-only matrix misses the
whole class.

The fix, in `_QuickActionItem`:

```dart
// `.sp` follows the width; the card follows the height. Cap the label.
final double labelSize = math.min(_designLabelSize.sp, contentHeight * 0.20);

// `Ink` applies the decoration's BORDER AS PADDING to its child — a
// `Padding(EdgeInsets.all(2.w))` that is easy to miss and leaves the
// reservation a pixel short.
final double contentHeight = height - (paddingV + border) * 2;

// Reserve the label's real line box, including the platform text scale, so a
// large accessibility font shrinks the icon instead of clipping the label.
final double labelHeight =
    MediaQuery.textScalerOf(context).scale(labelSize) * 1.25;

final double iconBox = math.max(
  0,
  math.min(_designIconBox.w, contentHeight - gap - labelHeight),
);
```

Three details that were each worth a debugging round:

1. **`Ink` insets its child by the border.** `Ink(decoration: … border …)` adds
   the border width as padding, so the column gets `height - 2*(padding + border)`.
   Leaving it out makes the reservation short by exactly that much.
2. **A font's line box is not `fontSize * height`.** With `height: 1.1` and
   `fontSize: 16` the bundled Shabnam paints **18.0**, not 17.6, and the engine
   rounds line heights to whole pixels (`16 * 1.1 = 17.6` → `18.0`, `10.37 * 1.1
   = 11.4` → `11.0`). Hence the 1.25 reservation margin.
3. **`Flexible` on the label is the last line of defence.** Without it a short
   reservation *clips the glyphs silently* instead of raising anything.

At the design size `37.w` is still the smaller term, so the card is
**byte-for-byte unchanged** on a normal phone — pinned by
`test/home_quick_actions_test.dart` (a 37 circle, a 22 icon, an 85-tall card
spanning 25→365). The row gap became `8.w : 10.w` for the same reason; it is
still `8` at the design size.

#### The two dead shortcuts

«هنرجوها» and «رسپی‌ها» were `// TODO` comments — tapping them did nothing.
Both now go through `AppRouter`:

| shortcut | route | screen |
|---|---|---|
| «هنرجوها» | `/students` | `StudentsScreen` — `GET v1/accounts/teacher-portfolios/` |
| «رسپی‌ها» | `/recipes` | `RecipesScreen` |

**The «هنرجوها» screen first shipped as a roster, then was reduced to the
gallery.** There is no students endpoint: the API models a student as an account
whose `role` is `user`, and `role` is the filter `accounts/users/` exposes for
exactly that (`enum: admin, super_admin, teacher, user`). It is **auth-required**
(`security: [{jwtAuth: []}]`; a guest gets
`401 اطلاعات برای اعتبارسنجی ارسال نشده است.`) — so the roster was invisible to a
signed-out visitor, which is part of why it was dropped. The card geometry used to
mirror `TeachersListScreen`, with the avatar and both text sizes clamped against
the **cell** rather than the screen (a cell is `mainAxisExtent: 220.h` tall but as
wide as the screen allows, so the `.sp`-follows-the-width trap applied: on a
1024-wide tablet the name was 42px tall in a 200px cell and the `Flexible`s
silently clipped it — 44.3 rendered against 57.0 natural). Both the card and the
roster are gone; see §7.12 for what the screen is now.

#### «رسپی‌ها» must list only standalone recipes

A recipe with `course` set is part of what that course teaches, so listing it
publicly would hand out the course material for free. The screen filtered on
`featured == true && courseId == null`, which excluded every standalone recipe
that was not marked featured — the opposite of the requirement. It is now
`courseId == null` only.

The API cannot express it: the filters on `v1/courses/recipes/` are `category`,
`course`, `difficulty`, `featured`, `is_active`, `ordering`, `page_size`,
`search` — there is no `course__isnull`. `RecipeList.course` is a plain nullable
integer (checked against the OpenAPI document, not assumed), which is what
`Recipe.courseId` parses.

**Pagination advanced on the wrong list.** It read
`_hasMoreRecipes = filteredNewRecipes.isNotEmpty`, so a page whose every row
belonged to a course looked like the end of the list and the pages *after* it
were never fetched — standalone recipes silently missing. It now advances on
what the backend returned:

```
page 1  8 standalone              → rendered
page 2  5 course-linked           → filtered to nothing, but pagination continues
page 3  2 standalone              → reached (this is what the old guard lost)
```

`test/recipes_standalone_test.dart` asserts pages `[1, 2, 3]` are all requested;
with the old guard it fails with `Actual: [1, 2]`.

#### Back button: only when the screen was pushed

`CoursesScreen` is the one screen that is **both** a bottom-navigation tab *and*
a push target («مشاهده همه», the «دوره‌ها» shortcut, a category). A tab must not
offer a way "back" — there is nothing behind it — while a pushed screen must.
`Navigator.canPop` is exactly that distinction, because
`MainBottomNavigation` is installed with `pushAndRemoveUntil(_, (_) => false)`:

```
tab    : [ MainBottomNavigation ]              canPop = false → no back button
pushed : [ MainBottomNavigation, CoursesScreen ] canPop = true  → back button
```

`CoursesHeader` reads it in `build` — the same check `AppBar` makes to decide
whether to imply a leading back button — and renders the arrow only when true.
The title stays pinned to the right in both cases, so opening courses from the
tab looks exactly as it always did. `StudentsScreen` and `RecipesScreen` are
never tabs, so they are always pushed and always show one.

### 7.12 «هنرجوها» is a gallery, and «رسپی‌ها» has an empty state

#### ⚠️ Two endpoints, and only one of them holds the works

There are **two** portfolio resources, and they are easy to confuse. The app reads
the first:

| endpoint | shape | live `count` |
|---|---|---|
| `GET v1/accounts/teacher-portfolios/` | `TeacherPortfolio` — `image` **or** `video` as **direct urls**, plus `student`, `student_name`, `title` | **2** |
| `GET v1/content/teacher-portfolio/` | `TeacherPortfolioItem` — a `type` enum and a `media` **id** to resolve through `v1/media/{id}/` | **0** |

The teacher profile had been reading the **second** one, which is why its
«نمونه کارهای هنرجو های استاد» block rendered nothing at all on the live server:
the request succeeded, the page was simply empty. It now reads
`accounts/teacher-portfolios/`, and so does «هنرجوها» — the two screens must show
the same works, so they must read the same resource.

`ApiEndpoints.contentTeacherPortfolio` is **kept** as a faithful binding with a
warning comment; nothing calls it.

#### The gallery

«هنرجوها» shows **only نمونه کارها** — the works a teacher published for their
students. The account roster it used to render alongside them is gone, by
explicit decision: the page is the gallery, not a people list.

| what | source |
|---|---|
| the gallery | `GET v1/accounts/teacher-portfolios/` |
| the owner's name + avatar | `GET v1/accounts/teachers/` |

The works are rendered with the **same** `TeacherPortfolioGrid` the teacher
profile uses, so the two galleries are pixel-identical — the teacher profile's
heading for that block is literally «نمونه کارهای هنرجو های استاد», which is what
these rows are.

**The `teacher` filter has to be absent, not empty.** `fetchTeacherPortfolio`
sent `query: {'page': page, 'teacher': teacherId}`, and with `teacherId == null`
Dio serialises that as a **bare** `?teacher`:

```
https://api.mceiran.website/api/v1/accounts/teacher-portfolios/?page=1&teacher
```

DRF answers an empty integer filter with a 400, so the across-every-teacher
gallery would have been empty on the device while the teacher profile (which
passes a real id) looked perfectly fine. The entry is now dropped entirely when
there is no teacher:

```dart
query: {
  'page': page,
  'teacher': ?teacherId,   // the `?` omits the entry when the value is null
},
```

`test/students_portfolio_test.dart` asserts the key is absent; on the old line it
fails with `Expected: false / Actual: <true>`.

**The `teacher` filter is real** — an unknown id is a validation error
(`teacher: یک گزینهٔ معتبر انتخاب کنید`), not a silent no-op, so the teacher
profile is genuinely scoped to its own works. The live database has a single
teacher (`id: 1`), so the filter and the unscoped gallery return the same two rows
today; a live test asserts both.

**The gallery is public** (`security: [{jwtAuth: []}, {}]`), which is why it is
the one thing on the page a signed-out visitor gets — the roster it used to sit
next to answered `401` for a guest.

**The owner cannot be read off a row.** ⚠️ The `accounts/teacher-portfolios/`
payload has **no `teacher` field** — only the `student` the work belongs to — so
`TeacherPortfolioItem.teacherId` is always `0` on this resource. The player still
wants a name and an avatar for its instructor chip, so `StudentsScreen` falls back
to the **single verified teacher** (the backend holds exactly one). If several
teachers exist and a row cannot be attributed, the chip is **dropped** rather than
guessed, because it prints «استاد {lastName}» and would otherwise read «استاد »
on its own. `GET v1/accounts/teachers/` is read best-effort, swallowing a failure —
a missing caption is not worth an error state.

`fetchStudents` (`GET v1/accounts/users/?role=user`) is **kept** in
`CatalogRepository` — it is a faithful binding to a real endpoint — but nothing in
the UI calls it any more. One test still pins the `role=user` contract so the
binding cannot rot silently.

#### The Explore-style vertical player

Tapping a work opens `ReelsViewer` — the same full-screen vertical player the
Explore tab uses — over the whole gallery, starting at the tapped index. The
teacher profile still opens its own `TeacherPortfolioViewer`; this page follows
Explore.

`ReelsViewer` speaks `ExploreVideo`, so each work is mapped onto it: thumbnail ←
`item.image`, video url ← `item.videoUrl`, title ← `item.description`, instructor
← the resolved teacher.

**That model assumes every item is a video, and a portfolio is not.** A work with
`type: image` has no video url, and `_ReelItem` treated an empty url as
`آدرس ویدیو خالی است.` — so half the gallery would have opened on an error
screen. `_ReelItem` now has an **image mode**: an empty video url *with a
thumbnail* renders the picture full-bleed and skips the player, the play/pause
toggle and the progress bar entirely. The branch is additive — Explore's own items
always carry a url, so that tab is unchanged, and an Explore item with a genuinely
missing url now shows its cover instead of an error.

The instructor chip is hidden when both names are empty, and the `12.h` gap that
followed it sits inside the same conditional, so the title does not float with a
stray gap above it.

#### Both media types, exactly as on the teacher profile

The request was for the students page's works block to be *«دقیقا مثل همون بخش
نمونه کار هنرجوهای استاد / هم عکس و هم ویدیو با همون ساختار / بدون تغییر uiux»*,
and for the teacher profile's own block to *«اگر عکس بود عکس نمایش داده بشه و اگر
ویدیو بود ویدیو»* with the player actually activating. Structurally nothing had to
move: the grid **is** the teacher profile's `TeacherPortfolioGrid` →
`TeacherPortfolioItemCard`, so both screens render the same rows with the same
widget. The defect was in what fed it.

**⚠️ `isVideo` used to be read from `type`, which this payload does not have.**
`TeacherPortfolioItem.fromJson` computed `isVideo = json['type'] == 'video'`. The
`accounts/teacher-portfolios/` shape has **no `type` field at all** — it signals
the media by filling in `image` **or** `video`. So every row parsed as a picture:
a video work was sent to the image branch with an empty url, the card lost its
play badge, and the viewer showed a placeholder instead of a player. `isVideo` is
now derived from either signal:

```dart
final isVideo = type == 'video' || (video != null && video.isNotEmpty);
```

which is true of both resources — `content/` still keys off `type`, and
`accounts/` keys off the url. Three model tests pin it, including a row with
neither url, which must stay a picture rather than be handed to a player.

**A video work has no cover, on either resource.** `image` is null for a video
row, so `TeacherPortfolioItem.image` is empty and the grid card paints its
`play_arrow_rounded` badge over the `Icons.image_outlined` **placeholder**. Image
and video are therefore *not* symmetric — the picture is the picture, the video
is a video with a placeholder thumbnail. This is the same on both screens because
it is the same widget reading the same payload; "fixing" it on one screen would
diverge them, which is what the request asked not to happen. A real poster frame
needs the backend to send one, not a client change.

**The player takes both.** `TeacherPortfolioViewer` builds a
`VideoPlayerController.networkUrl` from `item.videoUrl` for a video and an
`Image.network` for a picture. `ReelsViewer`'s image mode (§ above) covers the
students page, keyed off an empty `videoUrl` plus a non-empty thumbnail, so a
picture renders as a still and a video builds a player in the same swipe session.

**Only the work on screen plays.** `_PortfolioItem` now takes an `isActive` flag
from the `PageView`'s current index. A `PageView` only *builds* the page on
screen, so a video starts buffering only when its page is reached — but once the
next page is built the previous one is still in the tree, and without the flag it
carried on playing underneath: two soundtracks at once. Verified by disabling the
flag and watching `test/teacher_portfolio_test.dart` fail with
`Expected: Set:[2] / Actual: Set:[1, 2]`.

**Empty urls never reach a loader.** `Image.network('')` resolves against the
app's base uri, so it fires a pointless request for the app itself and only then
falls back to its `errorBuilder`; both the card and the viewer now short-circuit
to the same neutral panel instead. No visual change — the fallback was already
that panel.

The eight tests in `test/teacher_portfolio_test.dart` drive the real viewer
through a fake `VideoPlayerPlatform` (a test process has no decoder, so without it
`initialize()` throws and every work would look like a playback failure). They
assert a video work is handed its url and told to **play**, that an image work
never creates a player, that a work with no url creates nothing, that only the
visible work is playing, and that swiping pauses the one left behind. The
`students_portfolio_test.dart` group covers the gallery side: an image work yields
no badge, a video work yields one, a mixed gallery badges **only** the video, and
the player is handed a non-empty `videoUrl` for the video and an empty one for the
image — the last one puts the **image first** on purpose, because tapping into a
video page would build a real controller.

**Live-checked.** `test/live_api_smoke.dart` (run explicitly; it hits the real
backend) reads both live rows and asserts `isVideo` follows the url that is set —
one video and one image today, each with its `student_name` and `title`.

#### The empty states

`_buildRecipesGrid` used to return a two-column `SliverGrid` holding a single
`Center(child: Text('رسپی‌ای پیدا نشد'))` — the sentence was laid out inside one
grid cell at `childAspectRatio: .72`, which is not an empty state, it is a
sentence in a box. It now returns a `SliverToBoxAdapter` carrying the same
block the courses screens use (icon at `52.sp` in `AppColors.premium`, a `15.h`
gap, centred `bshabnam` at `16.sp` with `height: 1.8`):

* empty **library** → «هنوز رسپی مستقلی اضافه نشده. 🍰 …»
* a **search** that matched nothing → «رسپی‌ای پیدا نشد»

Two different sentences, because the library may be full while the search is
empty. While `_isLoadingMore` is true the sliver is empty, so the first load
cannot flash the empty state before the rows arrive.

Both screens' new blocks are covered on seven device sizes (320×568 up to
1024×768, portrait and landscape, including 360×640), asserting no overflow
**and** — for the three-column gallery — that every cell stays inside the
viewport, since a cell wider than a third of the screen would run off the edge
without reporting anything.
