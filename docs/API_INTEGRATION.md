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
| `HomeScreen` (popular carousel) | `GET v1/courses/best_selling/` | `Course` | `CatalogRepository.fetchBestSellingCourses` |
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
| `RecipeDetailScreen` | `GET v1/courses/recipes/{id}/` | `Recipe` | `CatalogRepository.fetchRecipe` |
| `RecipeDetailScreen` | `GET v1/accounts/teachers/{id}/` → `users/{id}/` | `Teacher` | `CatalogRepository.fetchTeacher` / `fetchTeacherByUserId` |
| `TeacherScreen` | `GET v1/accounts/teachers/{id}/` | `Teacher` | `CatalogRepository.fetchTeacher` |
| `TeacherScreen` | `GET v1/content/teacher-portfolio/?teacher={id}` | `TeacherPortfolioItem` | `CatalogRepository.fetchTeacherPortfolio` |
| `SearchScreen` | `GET v1/courses/?search=` | `Course` | `CatalogRepository.fetchCourses` |
| `ProfileScreen` | `GET v1/accounts/profile/` | `UserModel` | `ProfileRepository.fetchProfile` |
| `ProfileScreen` | `PATCH v1/accounts/profile/` | `UserModel` | `ProfileRepository.updateProfile` |
| `ProfileMyCoursesSection` | `GET v1/courses/enrollments/` | `Enrollment` | `CatalogRepository.fetchEnrollments` |
| `TicketsScreen` | `GET v1/support/my_tickets/` | `TicketModel` | `SupportRepository.fetchMyTickets` |
| `TicketsScreen` | `GET v1/support/subjects/` | `TicketSubject` | `SupportRepository.fetchSubjects` |
| `CreateTicketScreen` | `POST v1/support/` | `TicketDetail` | `SupportRepository.createTicket` |
| `CreateTicketScreen` | `POST v1/media/` (attachment) | `MediaModel` | `MediaRepository.uploadUrl` |

#### Repository methods that exist but have no screen yet

| Endpoint | Repository method | Why it is unused |
|---|---|---|
| `POST v1/accounts/auth/logout/` | `AuthRepository.logout` | the design has **no logout button** anywhere; the call is ready to be attached to one |
| `POST v1/courses/{id}/toggle_favorite/` | `CatalogRepository.toggleFavorite` | no favourite button in the course detail design |
| `GET v1/courses/reviews/` · `POST v1/courses/reviews/` | `fetchReviews` / `submitReview` | no review UI yet |
| `GET v1/courses/my_favorites/` | `fetchMyFavorites` | no favourites screen |
| `GET/POST v1/payments/*`, `v1/discounts/*`, `v1/notifications/` | `ShopRepository`, `NotificationRepository` | no cart / checkout / notifications screen |

#### Two backend gaps worth knowing

1. **There is no `POST courses/enrollments/`.** `v1/courses/enrollments/` is
   `GET`‑only, so the backend creates an enrollment as a side effect of a **paid
   order**. The path is:

   ```
   POST v1/payments/orders/   {course_ids: [12], gateway: 'mock'}
        → POST v1/payments/payments/mock_gateway/   (completes the payment)
        → POST v1/payments/payments/verify_mock/
        → GET  v1/courses/enrollments/  now contains the course
   ```

   `OrderCreate` accepts **`course_ids`** directly (`{coupon_code, gateway,
   description, course_ids}`), so no cart step is needed. `gateway` defaults to
   `mock`; the enum is `mock | zarinpal | idpay | other` and only `mock` can
   complete without a real bank redirect.

   **`ShopRepository.createOrder` used to be wrong** — it sent
   `{gateway, address_id, note}`. Neither `address_id` nor `note` exists on
   `OrderCreate`, and `course_ids` (the field that actually puts a course in the
   order) was missing, so it could only ever have produced an empty order. It is
   fixed. It has no callers yet, so nothing regressed.

   **Still open:** the body of `mock_gateway` is unknown. Every candidate
   (`{}`, `{payment}`, `{payment_id}`, `{id}`, `{authority}`, `{order_id}`,
   `{order, amount}`) returns the identical
   `404 شناسه پرداخت یافت نشد`, because the database holds no payments to look
   up — and the schema types the request body as `Payment`, which is a *response*
   schema. Rather than guess, the method is deliberately **not** written; see the
   comment block in `ShopRepository` for how to finish it. Until then
   «ثبت نام دوره» flips `isStudent` locally.

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
│  └─ utils/                       validators, themed snack bars
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
