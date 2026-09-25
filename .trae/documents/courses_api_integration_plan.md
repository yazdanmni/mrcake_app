# اتصال بخش دوره‌ها به API — Implementation Plan

## 1. تحقیق و بررسی پروژه

### 1.1 معماری فعلی پروژه
پروژه از معماری زیر استفاده می‌کند:
- **Network Layer**: `ApiClient` (Singleton با Dio) + `ApiConfig` + `ApiEndpoints` در `lib/core/network/`
- **Repository Pattern**: `CatalogRepository` در `lib/repositories/catalog_repository.dart`
- **State Management**: `setState` ساده + Singleton (بدون BLoC / Riverpod برای لایه UI)
- **Bridge Layer**: `RemoteLoader` + `RemoteCache` در `lib/core/network/remote_data.dart`
- **Seed Fallback**: تنظیم `AppConfig.useSeedFallback = true` در `lib/core/app_config.dart`
- **Mock Data**: در `lib/data/courses_data.dart` و `lib/data/categories_data.dart`

### 1.2 وضعیت فعلی اتصال به API (پیش از پیاده‌سازی)

#### ✅ آماده و پیاده‌سازی شده در Repository
در `CatalogRepository` متدهای زیر **از قبل وجود دارند و به API وصل هستند**:
- `fetchCourses({teacherId, categoryId, search, ordering, page, pageSize})` → `GET v1/courses/`
- `fetchFeaturedCourses()` → `GET v1/courses/featured/`
- `fetchBestSellingCourses()` → `GET v1/courses/best_selling/`
- `fetchFreeCourses()` → `GET v1/courses/free/`
- `fetchPaidCourses()` → `GET v1/courses/paid/`
- `fetchLatestCourses()` → `GET v1/courses/latest/`
- `fetchCategories()` → `GET v1/courses/categories/`
- `fetchFeaturedCategories()` → `GET v1/courses/categories/featured/`
- `fetchCategoryTree()` → `GET v1/courses/categories/tree/`

Model های `Course.fromJson()` و `CategoryModel.fromJson()` هم از قبل هم mock keys و هم backend keys رو parse می‌کنند.

#### ❌ دو مشکل اساسی که باعث می‌شن API به ظاهر کار نکنه:

**مشکل ۱ — `RemoteLoader` اصلاً seed fallback رو پیاده نکرده**
در `lib/core/network/remote_data.dart`:
- کامنت‌ها می‌گن «وقتی API خطا می‌ده یا خالی برمی‌گرده و `useSeedFallback=true`، seed برگردون»
- ولی در عمل: وقتی خطا رخ می‌ده همیشه `data: const []` برمی‌گرده و **seed نادیده گرفته می‌شه**
- همچنین `AppConfig.useSeedFallback` اصلاً **چک نمی‌شه**

**مشکل ۲ — اکثر صفحه‌ها هیچ seed به `RemoteLoader.list` پاس نمی‌دهن**
حتی اگر fallback درست پیاده شده بود، چون seed پاس داده نمی‌شد، خالی می‌موند. صفحات زیر seed ندارند:
- `CoursesScreen` (courses و categories)
- `HomeScreen` (courses و categories)
- `HomeCourses` (best_selling)
- `CourseCategoriesScreen` (courses + categories)
- `TeacherCoursesScreen` (teacher courses)
- `SearchScreen` (courses + search)
- `ProfileMyCoursesSection` (courses)

### 1.3 تست زنده API (live_api_smoke.dart نتیجه)
- `GET v1/courses/` الان **HTTP 500** برمی‌گردونه (پایگاه داده خالیه) → باید fallback به mock
- `GET v1/courses/categories/` درسته و کار می‌کنه
- `GET v1/courses/categories/featured/` هم درسته
- `GET v1/courses/categories/tree/` هم درسته
- `PagedResult` و `Course.fromJson` و `CategoryModel.fromJson` همگی درست کار می‌کنن

## 2. فایل‌ها و ماژول‌هایی که تغییر می‌کنن

| فایل | نوع تغییر | توضیح |
|-------|-----------|--------|
| `lib/core/network/remote_data.dart` | اصلاح منطق | پیاده‌سازی واقعی seed fallback + چک کردن `useSeedFallback` + مدیریت خالی بودن پاسخ |
| `lib/pages/courses/courses_screen.dart` | اضافه کردن seed | پاس دادن `CoursesData.courses` + `CategoriesData.categories` به RemoteLoader |
| `lib/pages/home/home_screen.dart` | اضافه کردن seed | پاس دادن seed به courses و categories |
| `lib/pages/home/home_courses.dart` | اضافه کردن seed | پاس دادن `CoursesData.courses` به best_selling |
| `lib/pages/courses/course_categories_screen.dart` | اضافه کردن seed | پاس دادن seed به courses + categories |
| `lib/pages/teacher/teacher_courses_screen.dart` | اضافه کردن seed | پاس دادن seed فیلتر شده بر اساس teacherId |
| `lib/pages/search/screen/search_screen.dart` | اضافه کردن seed | پاس دادن seed به courses اولیه |
| `lib/pages/profile/widgets/profile_my_courses_section.dart` | اضافه کردن seed | پاس دادن seed به courses |

**هیچ تغییری در UI/UX انجام نمی‌شود.** تنها منطق داده‌ی لایه‌ها اصلاح می‌شود تا در صورت موفقیت API، داده واقعی و در غیر این صورت (500/خالی) mock بدون تغییر ظاهر نمایش داده شود.

## 3. مراحل پیاده‌سازی (مرتب بر اساس وابستگی)

### مرحله ۱ — اصلاح هسته: RemoteLoader (اولویت: بالا)
**فایل**: `lib/core/network/remote_data.dart`

در متد `RemoteLoader.list`:
1. بلوک `try`: وقتی `fetch()` موفق شد ولی `items.isEmpty` بود:
   - اگر `AppConfig.useSeedFallback == true` و `seed.isNotEmpty` → `data: seed, isRemote: false, error: null` (خطا نداریم فقط خالیه)
   - در غیر این صورت → `data: items, isRemote: true`
2. بلوک `on ApiException`:
   - اگر `AppConfig.useSeedFallback == true` و `seed.isNotEmpty` → `data: seed, isRemote: false, error: error`
   - در غیر این صورت → `data: const [], isRemote: false, error: error`
3. بلوک `catch` (unexpected):
   - مشابه بالا رفتار کن

در متد `RemoteLoader.value`:
- همین منطق را برای `value` هم اعمال کن (اگر seed هست و fallback روشنه برگردون)

### مرحله ۲ — CoursesScreen
**فایل**: `lib/pages/courses/courses_screen.dart`
- `_load()`: categoriesRequest → `seed: CategoriesData.categories`
- `_load()`: coursesRequest → `seed: CoursesData.courses`
- `_applyFilters()`: هم درخواست API می‌زنیم؛ در صورت خطا seed به صورت محلی فیلتر می‌شود (خط 89-92)

### مرحله ۳ — HomeScreen
**فایل**: `lib/pages/home/home_screen.dart`
- `_load()`: categoriesRequest → `seed: CategoriesData.categories`
- `_load()`: coursesRequest → `seed: CoursesData.courses`
- banners هم فعلاً seed خودش رو داره (نیازی به تغییر نیست)

### مرحله ۴ — HomeCourses (کارousel محبوب‌ها)
**فایل**: `lib/pages/home/home_courses.dart`
- `_load()`: `seed: CoursesData.courses`
- `CourseUtils.getPopularCourses` به صورت خودکار ۲ تا از هر دسته رو برمی‌داره

### مرحله ۵ — CourseCategoriesScreen
**فایل**: `lib/pages/courses/course_categories_screen.dart`
- `_load()`: categoriesRequest → `seed: CategoriesData.categories`
- `_load()`: coursesRequest → `seed: CoursesData.courses`
- `_applyFilter()`: هم API هم fallback محلی

### مرحله ۶ — TeacherCoursesScreen (اولویت: متوسط)
**فایل**: `lib/pages/teacher/teacher_courses_screen.dart`
- `_load()`: seed رو بر اساس `widget.teacherId` به صورت محلی فیلتر می‌کنیم:
  ```dart
  seed: CoursesData.courses.where((c) {
    // چون در mock data teacher id نداریم، اسم استادها منطبق نیست.
    // برای این صفحه بهتر است seed کامل یا خالی بگذاریم
    // یا از طریق instructorLastName یک تطابق سخت بزنیم.
    // راه ساده: seed خالی یا همان لیست کامل (چون بعداً معیار teacher واقعی است).
  }).toList()
  ```
  چون mock data فیلد teacherId ندارد، برای این صفحه seed=[] گذاشته می‌شود یا همان CoursesData.courses (چون در عمل تعداد اساتید mock محدود است).

### مرحله ۷ — SearchScreen (اولویت: متوسط)
**فایل**: `lib/pages/search/screen/search_screen.dart`
- `_loadCourses()`: `seed: CoursesData.courses`
- `_performSearch()`: اگر API خطا داد، seed به صورت محلی فیلتر می‌شود (جستجو روی عنوان + نام استاد)

### مرحله ۸ — ProfileMyCoursesSection (اولویت: متوسط)
**فایل**: `lib/pages/profile/widgets/profile_my_courses_section.dart`
- `_load()`: coursesRequest → `seed: CoursesData.courses`
- Enrollmentها seed ندارند (چون ثبت‌نام کاربری مختص هر نفره و mock معنایی نداره)

## 4. وابستگی‌ها و نکات مهم

- **عدم تغییر UI**: هیچ تغییر ویژوال، رنگ، فونت، اندازه، چیدمان، متن یا اسکرین ساخته نمی‌شود. فقط منطق لودینگ داده تغییر می‌کند.
- **مخاطب بودن با mock data**: چون الان API دوره‌ها 500 می‌ده، بعد از اصلاح باید صفحه‌ها دقیقاً همان UI قبلی رو با mock نمایش بدن (یعنی چیزی از نظر کاربر تغییر نکرده).
- **Local filtering + search**: وقتی seed fallback فعال می‌شود، فیلتر دسته‌بندی و جستجو باید روی seed هم به صورت محلی اعمال بشه (نه فقط API).
- `TeacherCoursesScreen`: چون در mock داده‌ها فیلد `teacherId` وجود ندارد، برای این صفحه seed می‌تواند خالی یا لیست کامل باشد. فعلاً seed خالی بهتر است تا UI empty state رو نشان بده (که منطقی‌تر از نمایش تصادفی دوره‌هاست).
- **ProfileMyCoursesSection**: برای enrollments seed نمی‌گذاریم (چون user-specific است). فقط courses لیست کامل seed می‌گیرد (برای تطبیق با enrollment.courseId).
- **Invalidation**: `RemoteLoader.list` با `refresh: true` قبل از همه چی `RemoteCache.clear()` رو صدا می‌زنه — این منطق درست است و تغییر نمی‌کنه.

## 5. اعتبارسنجی پس از پیاده‌سازی

### ۵.۱ تحلیل استاتیک
```bash
flutter analyze
```
باید ۰ خطا/هشدار جدید داشته باشه.

### ۵.۲ تست‌های واحد
```bash
flutter test
```
همه‌ی تست‌های offline باید پاس بشن.

### ۵.۳ تست زنده API
```bash
NO_PROXY="localhost,127.0.0.1,::1" flutter test test/live_api_smoke.dart
```
تست `RemoteLoader keeps the seed when that 500 happens` و تست `RemoteLoader survives an empty page from teachers/` باید بعد از اصلاح واقعاً `result.data.isNotEmpty` داشته باشن.

### ۵.۴ تست دستی در اپ
1. HomeScreen باز بشه → دوره‌های Mock نمایش داده بشن (چون courses API 500 می‌ده)
2. CoursesScreen باز بشه → سکشن‌های «از اینجا شروع کن»، «حرفه‌ای شو»، «تک‌آموزشی» نمایش داده بشن
3. CourseCategoriesScreen باز بشه → categories chips + course sections نمایش داده بشن
4. TeacherCoursesScreen باز بشه → loading → (خالی چون API 500 و seed نداریم teacherId منطبق)
5. SearchScreen باز بشه → پس از وارد کردن متن «کیک» نتایج mock نمایش داده بشه (در صورت خطای API)
6. Pull-to-refresh در همه‌ی صفحات → دوباره لود کنه (نه از cache)

## 6. ریسک‌ها و راهکارها

| ریسک | احتمال | شدت | راهکار |
|------|--------|------|--------|
| وقتی API در آینده 500 نداشته باشه و واقعاً دوره‌ای نداشته باشه، seed باعث می‌شه کاربر فکر کنه دوره وجود داره | بالا | متوسط | `result.isRemote = false` دقیقاً این تفاوت رو نگه می‌داره؛ فعلاً چون `useSeedFallback=true` تنظیم شده، این رفتار مورد انتظار هست. بعداً با فعال شدن API می‌تونیم فلگ رو خاموش کنیم. |
| Local filtering/search دقیقاً مثل backend کار نکنه | متوسط | پایین | بهتر از نمایش خالی هست؛ برای این مرحله قابل قبول است. وقتی API درست کار کنه دیگه به fallback مسیر نمیره. |
| Mock data فیلدهای جدید API (slug, rating, reviews, etc.) رو نداره | پایین | پایین | constructor Course مقادیر پیش‌فرض داره؛ UI از این فیلدها فعلاً استفاده نمی‌کنه. |
