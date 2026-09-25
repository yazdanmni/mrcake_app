# بازبینی ساختار پروژه — Mr. Cake (Flutter)

تاریخ بازبینی: ۲ مهر ۱۴۰۵ / 24 Sep 2026
نسخه‌ها: Flutter 3.47.1 · Dart 3.13.1 · commit `1766e73`

---

## ۱. خلاصه مدیریتی

| مورد | وضعیت |
|---|---|
| کامپایل / لینت | ✅ `flutter analyze` → **۰ error**، ۴ warning، ۲۵ info |
| تست | ⚠️ `flutter test` → **۱۰۳ pass / ۱ fail** (خطای قدیمی، بی‌ربط — بخش ۵) |
| ساخت APK | ✅ آخرین `flutter build apk --debug` موفق |
| اتصال به API | 🟡 کاتالوگ حالا زنده است (۳ دوره، ۴ دسته، ۱ استاد)؛ ولی پرداخت تست‌پذیر نیست |
| معماری | ✅ لایه‌بندی تمیز: `pages → repositories → ApiClient(Dio)` |
| بدهی فنی | 🟡 ۷ فایل مرده، ۴ صفحه غیرقابل‌دسترس، ۳ فایل بسیار بزرگ |

حجم کد: **۹۶ فایل Dart** در `lib/` (≈ ۲۹٫۸۰۰ خط) + **۵ فایل تست**.

---

## ۲. درخت پروژه

```
lib/
├─ main.dart                     نقطه ورود (HttpOverrides برای مدیا + SplashScreen)
├─ core/
│  ├─ app_config.dart            کلیدهای فیچر (auto-login، VPN، seed-fallback، TLS مدیا)
│  ├─ common/app_colors.dart     ⚠️ فایل مرده (پالت placeholder، هیچ import‌کننده‌ای ندارد)
│  ├─ theme/app_colors.dart      ✅ پالت واقعی (۵۱ فایل از آن استفاده می‌کنند)
│  ├─ network/
│  │  ├─ api_config.dart         baseUrl، mediaUrl، تایم‌اوت‌ها و **همه** endpointها
│  │  ├─ api_client.dart         تک‌نمونه‌ی Dio + بازکردن envelope + کلاس Json
│  │  ├─ api_exception.dart      ApiErrorType + پیام‌های فارسی + خطاهای فیلدی
│  │  ├─ remote_data.dart        RemoteResult / RemoteLoader / RemoteCache
│  │  ├─ network_probe.dart      گرم‌کردن اتصال در اسپلش
│  │  ├─ vpn_detector.dart       تشخیص VPN بدون پلاگین نیتیو
│  │  └─ media_host_overrides.dart  دورزدن موقت TLS فقط برای هاست مدیا
│  ├─ router/app_router.dart     همه‌ی تصمیم‌های ناوبری
│  ├─ session/
│  │  ├─ session_manager.dart    JWT + کش پروفایل (SharedPreferences)
│  │  └─ enrollment_store.dart   🆕 آینه‌ی لوکال ثبت‌نام‌ها (کار همین تسک)
│  └─ utils/                     validators، app_feedback، external_link
├─ models/                       ۱۲ مدل (Course، CourseDetails، Enrollment، Coupon، …)
├─ data/                         ۷ فایل seed (فقط برای fallback وقتی API خطا/خالی می‌دهد)
├─ repositories/                 auth · profile(+media) · catalog · support(+notification+shop)
├─ pages/                        ۲۹ صفحه + ویجت‌های هر صفحه
├─ navigation/main_bottom_navigation.dart   ۵ تب: Explore · Courses · Home · Search · Profile
├─ widgets/course_card.dart      ⚠️ shim منسوخ (@Deprecated، بدون استفاده)
└─ utils/course_utils.dart
```

### جریان یک درخواست

```
Screen ──▶ RemoteLoader.list/value ──▶ Repository ──▶ ApiClient (Dio)
                                                   │
                                    Authorization: Bearer <JWT>
                                                   │
                            unwrap {success, message, data}  ──▶ Model.fromJson
                                                   │
                    خطا/صفحه‌ی خالی ──▶ seed (AppConfig.useSeedFallback)
```

نکته‌ی مهم: پروژه **BLoC ندارد**؛ state با `setState` مدیریت می‌شود و فقط
`flutter_riverpod` برای یک provider تکی (`catalogRepositoryProvider`) استفاده شده
است — یعنی Riverpod عملاً بلااستفاده است (بخش ۵).

---

## ۳. وضعیت اتصال به API (پروب زنده، همین امروز)

| Endpoint | کد | توضیح |
|---|---|---|
| `courses/` | **200** | ✅ قبلاً 500 بود؛ حالا **۳ دوره** برمی‌گرداند |
| `courses/categories/` | 200 | ۴ دسته |
| `courses/categories/tree/` | 200 | درخت دسته‌ها |
| `banners/hero/active/` | 200 | — |
| `banners/by_type/?type=home_top` | 200 | — |
| `content/explore-videos/` | 200 | ۱ ریلز |
| `accounts/teachers/` | 200 | ۱ استاد |
| `courses/tags/` | 200 | — |
| `courses/featured/` | **401** | نیاز به توکن → سکشن‌های خانه فعلاً از seed پر می‌شوند |
| `courses/recipes/` | **404** | این endpoint در بک‌اند وجود ندارد |
| `payments/orders/` | 401 | بدون توکن؛ مسیر خرید |
| `payments/payments/mock_gateway/` | **404** | برای هر بدنه‌ای — بخش ۵ |
| `discounts/apply/validate/` | 404 | برای کد نامعتبر؛ کد نامعتبر = «کد تخفیف یافت نشد» |

---

## ۴. مشکلات ساختاری (به ترتیب اولویت)

### ۴.۱ صفحه‌های ساخته‌شده ولی غیرقابل‌دسترس — مهم‌ترین یافته
هیچ‌جای `lib/` به این صفحه‌ها navigate نمی‌کند:

| فایل | حجم | چرا مهم است |
|---|---|---|
| `pages/course_learning/course_learning_screen.dart` | ۱۵ KB | **بعد از خرید دوره، هیچ راهی برای ورود به محتوای دوره وجود ندارد.** کلیک روی کارت «دوره‌های من» به `CourseDetailsScreen` می‌رود و آنجا فقط دکمه‌ی غیرفعال «شما دانشجوی این دوره هستید» دیده می‌شود. |
| `pages/course_learning/lesson_screen.dart` | — | فقط از داخل صفحه‌ی بالا صدا زده می‌شود، پس آن هم مرده است |
| `pages/recipes/recipes_screen.dart` | ۲۱ KB | تب «دستور پخت» وجود ندارد |
| `pages/recipes/recipe_detail_screen.dart` | — | همان |
| `pages/search/widgets/{search_field,popular_categories}.dart` | ۴٫۷ KB | ویجت‌های بی‌استفاده |
| `pages/profile/widgets/profile_header.dart` | ۶٫۴ KB | بی‌استفاده |
| `data/explore_videos_data.dart` | ۳ KB | seed بی‌استفاده |
| `core/common/app_colors.dart` | ۰٫۷ KB | پالت اشتباه (آبی/کهربایی) که هیچ‌کس import نمی‌کند — ریسک گمراهی |

> ⚠️ این‌ها را **حذف یا وصل نکردم** چون خارج از محدوده‌ی تسک و به‌معنای تغییر UX است.

### ۴.۲ فایل‌های بسیار بزرگ (قابل نگهداری نیستند)
| فایل | خطوط |
|---|---|
| `pages/course_details/course_details_screen.dart` | **۳٫۱۰۷** |
| `pages/course_learning/lesson_screen.dart` | ۱٫۶۸۳ |
| `pages/support/tickets_screen.dart` | ۱٫۳۵۶ |
| `pages/search/screen/search_screen.dart` | ۸۵۷ |

صفحه‌ی جزئیات دوره شامل UI + دو دیالوگ ثبت‌نام + دیالوگ کد تخفیف + دو دیالوگ موفقیت
+ منطق پرداخت است. پیشنهاد: شکستن به `widgets/` و انتقال منطق پرداخت به یک
`CheckoutController`.

### ۴.۳ کد مرده‌ی داخل فایل‌ها (خروجی analyze)
- `profile_banner.dart:50` → `_pickBannerImage` استفاده نمی‌شود (warning)
- `search_screen.dart:40` → فیلد `_courses` نوشته می‌شود ولی خوانده نمی‌شود
- `profile_edit_info_section.dart:129,130` → پارامترهای `keyboardType` / `inputFormatters` هیچ‌وقت مقدار نمی‌گیرند
- `catalog_repository.dart:529` → `print` در کد پروداکشن

### ۴.۴ تکرار / سردرگمی
- دو `AppColors` (بخش ۴.۱) و دو `CourseCard` (`widgets/course_card.dart` منسوخ و `pages/home/widgets/course_card.dart` فعال).
- `BannerModel` دو بار تعریف شده (مدل API + یک نسخه‌ی ویجت‌محلی در `home_banner.dart`) — مستند شده ولی هنوز منبع خطاست.
- Riverpod نیمه‌وارد شده: یک provider، بدون Consumer. یا کامل حذف شود یا واقعاً استفاده شود.

### ۴.۵ گپ‌های سمت سرور (خارج از کنترل اپ)
1. `mock_gateway` برای هر بدنه‌ای ۴۰۴ می‌دهد → مرحله‌ی نهایی پرداخت قابل تأیید نیست
   (جزئیات در `API_INTEGRATION.md` بخش ۷).
2. `courses/recipes/` وجود ندارد → صفحات دستور پخت داده ندارند.
3. `courses/featured/` و بقیه‌ی لیست‌های ویژه نیاز به توکن دارند → مهمان‌ها seed می‌بینند.
4. گواهی TLS هاست مدیا (`media.dl.mceiran.website`) هنوز نامعتبر است و با
   `AppConfig.allowInsecureMediaHost = true` دور زده می‌شود — **این باید سرور-ساید
   درست شود و بعد فلگ `false` شود.**

---

## ۵. تست‌ها

```
flutter test  →  103 pass / 1 fail   (۱۱ تست جدید در همین تسک)
```

- ✅ پاس: مدل‌ها، `ApiClient.unwrapEnvelope`، `ApiException`، `RemoteCache`،
  `RemoteLoader`، `HomeHeader`، و فایل جدید `coupon_enrollment_test.dart`.
- ❌ **خطای قدیمی:** `test/banner_links_test.dart` → «the CTA button does not open
  the hero link» با پیام *"A Timer is still pending even after the widget tree was
  disposed"*. علت: دکمه‌ی CTA به `CoursesScreen` می‌رود و `initState` آن یک درخواست
  واقعی Dio شروع می‌کند. **این خطا روی `HEAD` تمیز هم رخ می‌دهد** (با worktree
  جداگانه تست شد) و ربطی به کار پرداخت ندارد. رفعش یا stub کردن `HttpOverrides`
  است یا لغو درخواست‌های در جریان هنگام `dispose`.

---

## ۶. پیشنهادهای اولویت‌دار

| # | کار | چرا |
|---|---|---|
| ۱ | وصل‌کردن «دوره‌های من» به `CourseLearningScreen` | بدون آن، خرید دوره عملاً بی‌نتیجه است |
| ۲ | پاک‌کردن فایل‌های مرده (بخش ۴.۱) | کاهش سردرگمی؛ `core/common/app_colors.dart` خطر واقعی است |
| ۳ | شکستن `course_details_screen.dart` | ۳٫۱k خط، هر تغییری را پرریسک می‌کند |
| ۴ | تعیین تکلیف Riverpod | یا حذف یا استفاده‌ی واقعی |
| ۵ | رفع خطای `banner_links_test` | نگه‌داشتن تست‌ها سبز، ارزشش را دارد |
| ۶ | پیگیری سرور: `mock_gateway`, `courses/recipes/`, گواهی TLS | موارد باز بک‌اند |

---

## ۷. چیزی که در همین تسک تغییر کرد

فقط بخش پرداخت دوره — بدون هیچ تغییر UI/UX:

- `lib/core/session/enrollment_store.dart` 🆕 — آینه‌ی لوکال ثبت‌نام‌ها
- `lib/core/session/session_manager.dart` — init/clear آینه + پاک‌سازی هنگام تعویض حساب
- `lib/models/coupon_model.dart` — `fallbackCode` + `hasDiscountData`
- `lib/repositories/support_repository.dart` — پاس‌دادن کد به `fromJson`
- `lib/pages/course_details/course_details_screen.dart` — یکسان‌سازی مسیر «۱۰۰٪ تخفیف» با «دوره‌ی رایگان»
- `lib/pages/profile/widgets/profile_my_courses_section.dart` — ادغام API + آینه‌ی لوکال
- `test/coupon_enrollment_test.dart` 🆕 — ۱۱ تست
- `docs/API_INTEGRATION.md` — بخش ۷ اضافه شد

جزئیات کامل در `docs/API_INTEGRATION.md` بخش ۷.
