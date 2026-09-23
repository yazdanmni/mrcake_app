import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mr_cake_project/core/session/session_manager.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/models/user_model.dart';
import 'package:mr_cake_project/pages/home/widgets/home_header.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mr_cake_project/core/network/api_client.dart';
import 'package:mr_cake_project/core/network/api_exception.dart';
import 'package:mr_cake_project/core/network/remote_data.dart';
import 'package:mr_cake_project/core/utils/validators.dart';
import 'package:mr_cake_project/models/auth_session.dart';
import 'package:mr_cake_project/models/category_model.dart';
import 'package:mr_cake_project/models/course.dart';
import 'package:mr_cake_project/models/course_details.dart';
import 'package:mr_cake_project/models/course_intro_video.dart';
import 'package:mr_cake_project/models/enrollment.dart';
import 'package:mr_cake_project/models/explore_video.dart';
import 'package:mr_cake_project/models/recipe.dart';
import 'package:mr_cake_project/models/teacher_model.dart';
import 'package:mr_cake_project/repositories/catalog_repository.dart';

void main() {
  group('HomeHeader', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() => SessionManager.instance.clear(keepPhone: false));

    Future<void> pumpHeader(WidgetTester tester, Size screenSize) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = screenSize;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) => const MaterialApp(
            home: Scaffold(
              body: Align(alignment: Alignment.topCenter, child: HomeHeader()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> signIn({String? firstName = ' جواد '}) {
      return SessionManager.instance.save(
        AuthSession.fromResponse({
          'access': 'TEST_TOKEN',
          'user': {
            'id': 7,
            'phone_number': '09123456789',
            'first_name': firstName,
            'last_name': 'یادگاری',
            'full_name': 'جواد یادگاری',
          },
        }),
      );
    }

    for (final size in const [
      Size(320, 568),
      Size(360, 800),
      Size(390, 844),
      Size(430, 932),
      Size(844, 390),
    ]) {
      testWidgets('circular avatar and first-name greeting at $size', (
        tester,
      ) async {
        await signIn();
        await pumpHeader(tester, size);

        final avatar = find.descendant(
          of: find.byType(HomeHeader),
          matching: find.byType(ClipOval),
        );
        expect(avatar, findsOneWidget);
        final avatarSize = tester.getSize(avatar);
        expect(avatarSize.width, greaterThan(0));
        expect(avatarSize.width, closeTo(avatarSize.height, 0.001));

        final container = tester.widget<Container>(
          find.ancestor(of: avatar, matching: find.byType(Container)).first,
        );
        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.shape, BoxShape.circle);
        expect(
          decoration.border,
          Border.all(color: AppColors.border, width: 2.w),
        );
        expect(find.text('سلام'), findsOneWidget);
        expect(find.text('جواد'), findsOneWidget);
        expect(find.text('جواد یادگاری'), findsNothing);
        expect(
          tester.widget<Text>(find.text('جواد')).style!.color,
          AppColors.textSecondary,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('keeps compound first names and reacts to profile changes', (
      tester,
    ) async {
      await signIn();
      await pumpHeader(tester, const Size(390, 844));
      await SessionManager.instance.updateUser(
        const UserModel(
          id: 7,
          phoneNumber: '09123456789',
          firstName: ' محمد رضا ',
          lastName: 'یادگاری',
          fullName: 'محمد رضا یادگاری',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('محمد رضا'), findsOneWidget);
      expect(find.text('محمد رضا یادگاری'), findsNothing);
      expect(find.text('جواد'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('long first name stays inside a narrow header', (tester) async {
      await signIn(firstName: 'محمد رضا محمد رضا محمد رضا');
      await pumpHeader(tester, const Size(320, 568));

      final name = tester.widget<Text>(find.text('محمد رضا محمد رضا محمد رضا'));
      expect(name.maxLines, 1);
      expect(name.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });

    testWidgets('guest keeps the styled login button without an avatar', (
      tester,
    ) async {
      await pumpHeader(tester, const Size(320, 568));
      final button = find.text('ورود / ثبت نام');
      expect(button, findsOneWidget);
      expect(find.byType(ClipOval), findsNothing);
      final container = tester.widget<Container>(
        find.ancestor(of: button, matching: find.byType(Container)).first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, AppColors.field);
      expect(decoration.borderRadius, BorderRadius.circular(16.r));
      expect(
        decoration.border,
        Border.all(color: AppColors.border, width: 2.w),
      );
      expect(tester.takeException(), isNull);
    });

    for (final firstName in [null, '   ']) {
      testWidgets(
        'does not substitute full name when first name is $firstName',
        (tester) async {
          await signIn(firstName: firstName);
          await pumpHeader(tester, const Size(390, 844));

          expect(find.text('سلام'), findsOneWidget);
          expect(find.text('جواد یادگاری'), findsNothing);
          expect(find.text('09123456789'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  group('Validators.normalizePhone', () {
    test('keeps latin digits', () {
      expect(Validators.normalizePhone('09123456789'), '09123456789');
    });

    test('converts persian digits', () {
      expect(Validators.normalizePhone('۰۹۱۲۳۴۵۶۷۸۹'), '09123456789');
    });

    test('converts arabic digits', () {
      expect(Validators.normalizePhone('٠٩١٢٣٤٥٦٧٨٩'), '09123456789');
    });

    test('drops every non digit character and caps at 11 digits', () {
      expect(Validators.normalizePhone('+98 (912) 345-6789'), '98912345678');
    });

    test('caps the result at 11 digits', () {
      expect(Validators.normalizePhone('091234567899999'), '09123456789');
    });
  });

  group('Validators.phone', () {
    test('accepts a valid iran mobile number', () {
      expect(Validators.phone('09123456789'), isNull);
    });

    test('rejects an empty value', () {
      expect(Validators.phone(''), isNotNull);
    });

    test('rejects a short number', () {
      expect(Validators.phone('0912345678'), isNotNull);
    });

    test('rejects a number that does not start with 09', () {
      expect(Validators.phone('08123456789'), isNotNull);
    });
  });

  group('Validators.password', () {
    test('enforces the backend minimum of 6 characters', () {
      expect(Validators.password('12345'), isNotNull);
      expect(Validators.password('123456'), isNull);
    });

    test('confirmPassword detects a mismatch', () {
      expect(Validators.confirmPassword('abcdef', 'abcdef'), isNull);
      expect(Validators.confirmPassword('abcdef', 'abcdeF'), isNotNull);
      expect(Validators.confirmPassword('', 'abcdef'), isNotNull);
    });
  });

  group('ApiClient.unwrapEnvelope', () {
    test('returns data from a success envelope', () {
      final result = ApiClient.unwrapEnvelope({
        'success': true,
        'message': 'کد تایید ارسال شد',
        'data': {'phone_number': '+989123456789'},
      });
      expect(result, {'phone_number': '+989123456789'});
    });

    test('passes a DRF page through untouched', () {
      final result = ApiClient.unwrapEnvelope({
        'count': 0,
        'next': null,
        'previous': null,
        'results': <dynamic>[],
      });
      expect(result, isA<Map<String, dynamic>>());
      expect((result as Map)['count'], 0);
    });

    test('throws on a failure envelope', () {
      expect(
        () => ApiClient.unwrapEnvelope({
          'success': false,
          'message': 'phone_number: یک شماره تماس معتبر وارد نمایید.',
          'errors': {
            'phone_number': ['یک شماره تماس معتبر وارد نمایید.'],
          },
          'status_code': 400,
        }),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('ApiException', () {
    ApiException unknownPhone() => ApiException.fromEnvelope({
      'success': false,
      'message': 'phone_number: حساب کاربری با این شماره یافت نشد',
      'errors': {
        'phone_number': ['حساب کاربری با این شماره یافت نشد'],
      },
      'status_code': 400,
    });

    test('strips the field prefix from the message', () {
      expect(unknownPhone().message, 'حساب کاربری با این شماره یافت نشد');
    });

    test('detects an unknown phone number', () {
      expect(unknownPhone().isUnknownPhone, isTrue);
      expect(unknownPhone().field, 'phone_number');
      expect(unknownPhone().type, ApiErrorType.validation);
    });

    test('reads the login-password phrasing too', () {
      final error = ApiException.fromEnvelope({
        'success': false,
        'message': 'حساب کاربری با این شماره وجود ندارد',
        'status_code': 400,
      });
      expect(error.isUnknownPhone, isTrue);
    });

    test('does NOT treat an invalid phone FORMAT as an unknown phone', () {
      // The crux of the auth flow: `checkAccountExists` probes with
      // `purpose=forgot_password` and routes to the OTP screen when the number
      // is unknown. A malformed number also answers 400, but with a different
      // sentence — reading it as "no account" would send a typo to the OTP
      // screen instead of showing a validation error on the login form.
      final error = ApiException.fromEnvelope({
        'success': false,
        'message': 'phone_number: یک شماره تماس معتبر وارد نمایید.',
        'errors': {
          'phone_number': ['یک شماره تماس معتبر وارد نمایید.'],
        },
        'status_code': 400,
      });

      expect(error.isUnknownPhone, isFalse);
      expect(error.type, ApiErrorType.validation);
      expect(error.message, 'یک شماره تماس معتبر وارد نمایید.');
    });

    test('does NOT read a non-400 "یافت نشد" as an unknown phone', () {
      // `mock_gateway` answers `404 شناسه پرداخت یافت نشد`; the status guard
      // must stop that being mistaken for a missing account.
      final error = ApiException.fromEnvelope({
        'success': false,
        'message': 'شناسه پرداخت یافت نشد',
        'status_code': 404,
      });
      expect(error.isUnknownPhone, isFalse);
    });

    test('an unknown phone is not also reported as a wrong password', () {
      expect(unknownPhone().isWrongPassword, isFalse);
      expect(unknownPhone().isInvalidOtp, isFalse);
    });

    test('detects an invalid OTP', () {
      final error = ApiException.fromEnvelope({
        'success': false,
        'message': 'otp: کد تایید اشتباه یا منقضی شده است',
        'errors': {
          'otp': ['کد تایید اشتباه یا منقضی شده است'],
        },
        'status_code': 400,
      });
      expect(error.isInvalidOtp, isTrue);
      expect(error.isUnknownPhone, isFalse);
    });

    test('detects a wrong password', () {
      final error = ApiException.fromEnvelope({
        'success': false,
        'message': 'رمز عبور اشتباه است',
        'status_code': 400,
      });
      expect(error.isWrongPassword, isTrue);
    });

    test('maps 401 to unauthorized', () {
      final error = ApiException.fromEnvelope({
        'success': false,
        'message': 'اطلاعات برای اعتبارسنجی ارسال نشده است.',
        'errors': null,
        'status_code': 401,
      });
      expect(error.type, ApiErrorType.unauthorized);
      expect(error.isUnauthorized, isTrue);
    });
  });

  group('AuthSession.fromResponse', () {
    test('reads access/refresh/user from a flat payload', () {
      final session = AuthSession.fromResponse({
        'access': 'ACCESS_TOKEN',
        'refresh': 'REFRESH_TOKEN',
        'user': {
          'id': 7,
          'phone_number': '09123456789',
          'role': 'user',
          'first_name': 'جواد',
          'last_name': 'یادگاری',
          'is_profile_complete': true,
        },
      });

      expect(session.accessToken, 'ACCESS_TOKEN');
      expect(session.refreshToken, 'REFRESH_TOKEN');
      expect(session.hasToken, isTrue);
      expect(session.user?.id, 7);
      expect(session.user?.phoneNumber, '09123456789');
      expect(session.user?.displayName, 'جواد یادگاری');
      expect(session.user?.maskedPhone, '0912*******89');
    });

    test('reads a nested tokens object and a profile key', () {
      final session = AuthSession.fromResponse({
        'tokens': {'access': 'NESTED_ACCESS', 'refresh': 'NESTED_REFRESH'},
        'profile': {'id': 12, 'phone_number': '09351234567', 'role': 'teacher'},
      });

      expect(session.accessToken, 'NESTED_ACCESS');
      expect(session.refreshToken, 'NESTED_REFRESH');
      expect(session.user?.id, 12);
    });

    test('handles an envelope that was not unwrapped yet', () {
      final session = AuthSession.fromResponse({
        'success': true,
        'message': 'ok',
        'data': {'token': 'ENVELOPED_TOKEN'},
      });

      expect(session.accessToken, 'ENVELOPED_TOKEN');
    });

    test('does not mistake a send-otp payload for a user', () {
      final session = AuthSession.fromResponse({
        'phone_number': '+989123456789',
        'purpose': 'auth',
      });

      expect(session.hasToken, isFalse);
      expect(session.user, isNull);
    });
  });

  group('PagedResult.from', () {
    test('reads the count/next/previous page shape', () {
      final page = PagedResult.from({
        'count': 3,
        'next': 'https://api.mceiran.website/api/v1/courses/?page=2',
        'previous': null,
        'results': [
          {'id': 1},
          {'id': 2},
        ],
      });

      expect(page.items, hasLength(2));
      expect(page.count, 3);
      expect(page.hasMore, isTrue);
    });

    test('reads the links/total_pages page shape', () {
      final page = PagedResult.from({
        'links': {'next': null, 'previous': null},
        'count': 2,
        'total_pages': 1,
        'current_page': 1,
        'results': [
          {'id': 1},
          {'id': 2},
        ],
      });

      expect(page.items, hasLength(2));
      expect(page.currentPage, 1);
      expect(page.totalPages, 1);
      expect(page.hasMore, isFalse);
    });

    test('wraps a single object so callers always get a list', () {
      final page = PagedResult.from({'id': 7, 'name': 'کیک'});

      expect(page.items, hasLength(1));
      expect(page.count, 1);
    });
  });

  group('CategoryModel.fromJson', () {
    test('maps the backend name/icon onto title/image', () {
      final category = CategoryModel.fromJson({
        'id': 2,
        'name': 'کیک های خامه ای',
        'slug': 'کیک-های-خامه-ای',
        'icon': 'https://media.dl.mceiran.website/categories/icons/cake.png',
        'banner': null,
        'parent': 1,
        'order': 1,
        'featured': true,
      });

      expect(category.id, 2);
      expect(category.title, 'کیک های خامه ای');
      expect(category.image, contains('cake.png'));
      expect(category.parentId, 1);
      expect(category.isRoot, isFalse);
      expect(category.featured, isTrue);
    });

    test('reads the children of the tree endpoint', () {
      final parent = CategoryModel.fromJson({
        'id': 1,
        'name': 'کیک',
        'children': [
          {'id': 2, 'name': 'کیک خامه ای'},
        ],
      });

      expect(parent.children, hasLength(1));
      expect(parent.children.first.title, 'کیک خامه ای');
      expect(parent.hasChildren, isTrue);
    });
  });

  group('Course.fromJson', () {
    test('reads the nested teacher, category, prices and duration', () {
      final course = Course.fromJson({
        'id': 5,
        'title': 'آموزش کیک',
        'slug': 'cake',
        'image': '/media/courses/cover.jpg',
        'teacher': {
          'id': 9,
          'first_name': 'مریم',
          'last_name': 'احمدی',
          'avatar': '/media/avatars/maryam.jpg',
        },
        'category': {'id': 2, 'name': 'کیک'},
        'price': 2490000,
        'discount_price': 1990000,
        'final_price': 1990000,
        'has_discount': true,
        'is_free': false,
        'students_count': 3200,
        'lessons_count': 24,
        'total_duration_seconds': 7200,
        'featured': true,
      });

      expect(course.id, 5);
      expect(course.instructorFirstName, 'مریم');
      expect(course.instructorLastName, 'احمدی');
      expect(course.instructorFullName, 'مریم احمدی');
      expect(course.instructorImage, contains('media.dl.mceiran.website'));
      expect(course.categoryIds, [2]);
      expect(course.price, '1990000');
      expect(course.lessons, '24');
      expect(course.duration, '2');
      expect(course.studentsCount, 3200);
      expect(course.type, CourseType.professional);
      expect(course.access, CourseAccess.paid);
      expect(course.hasDiscount, isTrue);
      expect(course.totalDurationSeconds, 7200);
    });

    test('derives the free and single-lesson types', () {
      final free = Course.fromJson({'id': 1, 'title': 'x', 'is_free': true});

      expect(free.type, CourseType.free);
      expect(free.access, CourseAccess.free);
      expect(free.isFree, isTrue);

      final single = Course.fromJson({
        'id': 2,
        'title': 'y',
        'is_free': false,
        'lessons_count': 1,
      });

      expect(single.type, CourseType.single);
      expect(single.access, CourseAccess.paid);
    });

    test('still reads the legacy mock keys', () {
      final course = Course.fromJson({
        'id': 1,
        'title': 'آموزش مقدماتی کیک‌پزی',
        'image': 'https://example.com/a.jpg',
        'instructor_first_name': 'مریم',
        'instructor_last_name': 'احمدی',
        'price': '0',
        'currency': 'تومان',
        'lessons': '12',
        'students_count': 2450,
        'category_ids': [1],
        'type': 'free',
        'access': 'free',
      });

      expect(course.type, CourseType.free);
      expect(course.lessons, '12');
      expect(course.categoryIds, [1]);
      expect(course.isFreeByPrice, isTrue);
    });
  });

  group('Recipe.fromJson', () {
    test('reads ingredient_items, step_items and the difficulty enum', () {
      final recipe = Recipe.fromJson({
        'id': 4,
        'title': 'کیک شکلاتی',
        'slug': 'chocolate-cake',
        'image': '/media/recipes/cake.jpg',
        'short_description': 'توضیح کوتاه',
        'difficulty': 'beginner',
        'preparation_time': 20,
        'cooking_time': 40,
        'servings': 8,
        'featured': true,
        'views_count': 120,
        'category': {'id': 1, 'name': 'کیک'},
        'created_by': {
          'id': 3,
          'first_name': 'مریم',
          'last_name': 'احمدی',
          'full_name': 'مریم احمدی',
          'avatar': '/media/avatars/m.jpg',
        },
        'ingredient_items': [
          {'id': 1, 'name': 'آرد', 'amount': '۲ پیمانه'},
          {'id': 2, 'name': 'شکر', 'amount': '۱ پیمانه'},
        ],
        'step_items': [
          {'id': 1, 'body': 'آرد را الک کنید.'},
          {'id': 2, 'body': 'مواد را مخلوط کنید.'},
        ],
      });

      expect(recipe.id, 4);
      expect(recipe.teacherId, 3);
      expect(recipe.categoryId, 1);
      expect(recipe.categoryTitle, 'کیک');
      expect(recipe.image, contains('media.dl.mceiran.website'));
      expect(recipe.ingredients, hasLength(2));
      expect(recipe.ingredients.first.name, 'آرد');
      expect(recipe.ingredients.first.amount, '۲ پیمانه');
      expect(recipe.steps, hasLength(2));
      expect(recipe.steps.first, 'آرد را الک کنید.');
      expect(recipe.difficultyTitle, 'آسان');
      expect(recipe.totalTime, 60);
      expect(recipe.hasTimes, isTrue);
      expect(recipe.authorName, 'مریم احمدی');
      expect(recipe.authorAvatar, contains('media.dl.mceiran.website'));
    });

    test('splits the raw ingredients string when there are no items', () {
      final recipe = Recipe.fromJson({
        'id': 1,
        'title': 'x',
        'ingredients': 'آرد: ۲ پیمانه\nشکر: ۱ پیمانه',
      });

      expect(recipe.ingredients, hasLength(2));
      expect(recipe.ingredients.first.name, 'آرد');
      expect(recipe.ingredients.first.amount, '۲ پیمانه');
      expect(recipe.ingredientsText, isNotNull);
    });

    test('maps every difficulty value onto a persian label', () {
      expect(
        Recipe.fromJson({'id': 1, 'difficulty': 'medium'}).difficultyTitle,
        'متوسط',
      );
      expect(
        Recipe.fromJson({'id': 1, 'difficulty': 'advanced'}).difficultyTitle,
        'سخت',
      );
      expect(
        Recipe.fromJson({'id': 1, 'difficulty': 'all'}).difficultyTitle,
        'همه سطوح',
      );
    });
  });

  group('ExploreVideo.fromJson', () {
    test('reads duration_seconds and the media ids', () {
      final video = ExploreVideo.fromJson({
        'id': 1,
        'title': 'ترفند خامه کشی',
        'description': 'توضیح',
        'duration_seconds': 90,
        'status': 'published',
        'teacher': 3,
        'video_media': 12,
        'thumbnail_media': 13,
        'is_active': true,
      });

      expect(video.duration, 90);
      expect(video.durationLabel, '01:30');
      expect(video.instructorId, 3);
      expect(video.videoMediaId, 12);
      expect(video.thumbnailMediaId, 13);
      expect(video.isPublished, isTrue);
    });

    test('withMedia and withInstructor keep the other fields', () {
      final video = ExploreVideo.fromJson({'id': 1, 'title': 't'})
          .withMedia(videoUrl: 'https://cdn.example.com/v.mp4')
          .withInstructor(firstName: 'مریم', lastName: 'احمدی');

      expect(video.videoUrl, 'https://cdn.example.com/v.mp4');
      expect(video.instructorFullName, 'مریم احمدی');
      expect(video.title, 't');
    });
  });

  group('Teacher.fromJson', () {
    test('reads the nested user and the statistics', () {
      final teacher = Teacher.fromJson({
        'id': 1,
        'user': {
          'id': 9,
          'first_name': 'مریم',
          'last_name': 'احمدی',
          'full_name': 'مریم احمدی',
          'avatar': '/media/avatars/m.jpg',
        },
        'expertise': 'کیک و شیرینی',
        'rating': '4.8',
        'about': 'درباره استاد',
        'years_experience': 12,
        'students_count': 2450,
        'courses_count': 8,
        'is_blue_verified': true,
      });

      expect(teacher.fullName, 'مریم احمدی');
      expect(teacher.profileImage, contains('media.dl.mceiran.website'));
      expect(teacher.experienceYears, 12);
      expect(teacher.courseCount, 8);
      expect(teacher.studentsCount, 2450);
      expect(teacher.isVerified, isTrue);
      expect(teacher.about, 'درباره استاد');
    });

    test('withPortfolio replaces the portfolio only', () {
      final teacher = Teacher.fromJson({'id': 1, 'first_name': 'الف'});

      final updated = teacher.withPortfolio(const [
        TeacherPortfolioItem(
          id: 5,
          image: 'https://cdn.example.com/i.jpg',
          isVideo: false,
          description: 'نمونه کار',
        ),
      ]);

      expect(updated.portfolio, hasLength(1));
      expect(updated.portfolio.first.description, 'نمونه کار');
      expect(updated.firstName, 'الف');
    });

    test('falls back to a generic name when the user is empty', () {
      expect(Teacher.fromJson({'id': 1}).fullName, 'استاد مستر کیک');
    });
  });

  group('Enrollment.fromJson', () {
    test('converts progress_percent into a 0..1 ratio', () {
      final enrollment = Enrollment.fromJson({
        'id': 1,
        'course_id': 5,
        'progress_percent': 65,
        'is_paid': true,
        'completed': false,
        'lesson_progress_count': 7,
      });

      expect(enrollment.courseId, 5);
      expect(enrollment.progress, closeTo(0.65, 0.0001));
      expect(enrollment.progressPercent, 65);
      expect(enrollment.isPaid, isTrue);
    });

    test('reads the nested course object', () {
      final enrollment = Enrollment.fromJson({
        'id': 2,
        'course': {'id': 9, 'title': 'دوره کیک', 'lessons_count': 3},
      });

      expect(enrollment.courseId, 9);
      expect(enrollment.course?.title, 'دوره کیک');
    });

    test('clamps an out of range progress', () {
      final enrollment = Enrollment.fromJson({
        'id': 3,
        'course_id': 1,
        'progress_percent': 140,
      });

      expect(enrollment.progress, 1.0);
    });
  });

  group('CourseDetails.fromJson', () {
    test('reads chapters, lessons and formats the lesson duration', () {
      final details = CourseDetails.fromJson({
        'id': 3,
        'description': 'توضیح دوره',
        'video_trailer': '/media/trailer.mp4',
        'image': '/media/cover.jpg',
        'lessons_count': 2,
        'total_duration_seconds': 5400,
        'is_enrolled': true,
        'is_favorite': false,
        'chapters': [
          {
            'id': 1,
            'title': 'شروع',
            'order': 1,
            'lessons': [
              {
                'id': 10,
                'title': 'آرد',
                'duration': 500,
                'video_file': '/media/l1.mp4',
              },
              {'id': 11, 'title': 'خامه', 'duration': 615},
            ],
          },
        ],
      });

      expect(details.courseId, 3);
      expect(details.description, 'توضیح دوره');
      expect(details.introVideo, contains('trailer.mp4'));
      expect(details.introImage, contains('cover.jpg'));
      expect(details.hasIntroVideo, isTrue);
      expect(details.chapters, hasLength(1));
      expect(details.chapters.first.number, 1);
      expect(details.chapters.first.lessons, hasLength(2));

      final first = details.chapters.first.lessons.first;
      expect(first.duration, '08:20');
      expect(first.durationSeconds, 500);
      expect(first.video, contains('l1.mp4'));

      expect(details.chapters.first.lessons[1].duration, '10:15');
      expect(details.resolvedLessonsCount, 2);
      expect(details.totalDurationMinutes, 90);
      expect(details.isEnrolled, isTrue);
    });

    test('copyWithChapters swaps the chapter list', () {
      final details = CourseDetails.fromJson({'id': 1});

      final updated = details.copyWithChapters(const [
        CourseChapter(id: 1, number: 1, title: 'فصل', lessons: []),
      ]);

      expect(updated.chapters, hasLength(1));
      expect(updated.chaptersCount, 1);
      expect(updated.courseId, 1);
    });
  });

  group('CourseIntroVideo', () {
    test('formatSeconds pads short and long durations', () {
      expect(CourseIntroVideo.formatSeconds(0), '00:00');
      expect(CourseIntroVideo.formatSeconds(90), '01:30');
      expect(CourseIntroVideo.formatSeconds(3661), '01:01:01');
    });

    test('fromCourse maps a course onto the promo card', () {
      final course = Course.fromJson({
        'id': 4,
        'title': 'دوره کیک',
        'image': '/media/cover.jpg',
        'lessons_count': 10,
        'total_duration_seconds': 7200,
        'students_count': 500,
        'teacher': {'first_name': 'مریم', 'last_name': 'احمدی'},
      });

      final video = CourseIntroVideo.fromCourse(course);

      expect(video.courseId, 4);
      expect(video.title, 'دوره کیک');
      expect(video.teacherLastName, 'احمدی');
      expect(video.duration, '02:00:00');
      expect(video.studentsCount, '500');
      expect(video.thumbnail, contains('media.dl.mceiran.website'));
    });
  });

  group('RemoteCache', () {
    setUp(RemoteCache.clear);
    tearDown(RemoteCache.clear);

    test('read returns null for a key that was never written', () {
      expect(RemoteCache.read<String>('missing'), isNull);
    });

    test('write then read round-trips the value', () {
      RemoteCache.write('courses:p1', ['a', 'b']);

      expect(RemoteCache.read<List<String>>('courses:p1'), ['a', 'b']);
      expect(RemoteCache.length, 1);
    });

    test('read returns null when the stored type does not match', () {
      RemoteCache.write('courses:p1', 'a string');

      expect(RemoteCache.read<List<String>>('courses:p1'), isNull);
    });

    test('write ignores a null value', () {
      RemoteCache.write('courses:p1', null);

      expect(RemoteCache.length, 0);
    });

    test('invalidate drops only the keys with the given prefix', () {
      RemoteCache.write('course-detail:1', 'one');
      RemoteCache.write('course-detail:2', 'two');
      RemoteCache.write('recipe:1', 'recipe');

      RemoteCache.invalidate('course-detail:');

      expect(RemoteCache.read<String>('course-detail:1'), isNull);
      expect(RemoteCache.read<String>('course-detail:2'), isNull);
      expect(RemoteCache.read<String>('recipe:1'), 'recipe');
      expect(RemoteCache.length, 1);
    });

    test('invalidate with an unknown prefix keeps everything', () {
      RemoteCache.write('recipe:1', 'recipe');

      RemoteCache.invalidate('teacher:');

      expect(RemoteCache.read<String>('recipe:1'), 'recipe');
    });

    test('clear removes every entry', () {
      RemoteCache.write('a', 1);
      RemoteCache.write('b', 2);

      RemoteCache.clear();

      expect(RemoteCache.length, 0);
    });

    test('remove drops a single key', () {
      RemoteCache.write('a', 1);
      RemoteCache.write('b', 2);

      RemoteCache.remove('a');

      expect(RemoteCache.read<int>('a'), isNull);
      expect(RemoteCache.read<int>('b'), 2);
    });
  });

  group('RemoteLoader', () {
    setUp(RemoteCache.clear);
    tearDown(RemoteCache.clear);

    test('returns the real rows and marks them remote on success', () async {
      final result = await RemoteLoader.list<String>(
        label: 'test',
        seed: const ['seed'],
        fetch: () async => ['remote'],
      );

      expect(result.data, ['remote']);
      expect(result.isRemote, isTrue);
      expect(result.hasError, isFalse);
    });

    test('keeps the seed and reports the error when the call fails', () async {
      final result = await RemoteLoader.list<String>(
        label: 'test',
        seed: const ['seed'],
        fetch: () async =>
            throw ApiException(message: 'boom', type: ApiErrorType.unknown),
      );

      expect(result.data, ['seed']);
      expect(result.isRemote, isFalse);
      expect(result.hasError, isTrue);
      expect(result.message, 'boom');
    });

    test(
      'keeps the seed when the backend answers with an empty page',
      () async {
        final result = await RemoteLoader.list<String>(
          label: 'test',
          seed: const ['seed'],
          fetch: () async => const <String>[],
        );

        expect(result.data, ['seed']);
        expect(result.isRemote, isFalse);
      },
    );

    test('does not resurrect an empty seed into a remote flag', () async {
      final result = await RemoteLoader.list<String>(
        label: 'test',
        seed: const [],
        fetch: () async => const <String>[],
      );

      expect(result.data, isEmpty);
      expect(result.isRemote, isTrue);
    });

    test('refresh drops the cache before fetching', () async {
      RemoteCache.write('stale', 'value');
      var calls = 0;

      await RemoteLoader.list<String>(
        label: 'test',
        seed: const [],
        refresh: true,
        fetch: () async {
          calls++;
          return ['a'];
        },
      );

      expect(calls, 1);
      expect(RemoteCache.length, 0);
    });

    test('without refresh the cache is left alone', () async {
      RemoteCache.write('keep', 'value');

      await RemoteLoader.list<String>(
        label: 'test',
        seed: const [],
        fetch: () async => ['a'],
      );

      expect(RemoteCache.read<String>('keep'), 'value');
    });

    test('value returns the seed when the fetch yields nothing', () async {
      final result = await RemoteLoader.value<String>(
        label: 'test',
        seed: 'seed',
        fetch: () async => null,
      );

      expect(result.data, 'seed');
      expect(result.isRemote, isFalse);
    });

    test('action reports failure without throwing', () async {
      final ok = await RemoteLoader.action('test', () async {});
      final failed = await RemoteLoader.action(
        'test',
        () async =>
            throw ApiException(message: 'x', type: ApiErrorType.unknown),
      );

      expect(ok, isTrue);
      expect(failed, isFalse);
    });
  });
}
