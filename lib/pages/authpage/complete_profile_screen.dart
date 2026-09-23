import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mr_cake_project/core/network/api_exception.dart';
import 'package:mr_cake_project/core/router/app_router.dart';
import 'package:mr_cake_project/core/session/session_manager.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/core/utils/app_feedback.dart';
import 'package:mr_cake_project/core/utils/validators.dart';
import 'package:mr_cake_project/pages/authpage/widget/complete_profile_fields.dart';
import 'package:mr_cake_project/repositories/profile_repository.dart';

/// Shown only for a first time user, right after the registration OTP.
///
/// Screen -> Endpoint -> Model -> Repository
///   CompleteProfileScreen -> POST  v1/media/                    -> MediaModel
///                         -> POST  v1/accounts/profile/complete/ -> UserModel
///                         -> PATCH v1/accounts/profile/         -> UserModel
///                         -> ProfileRepository
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Avatar
  // ---------------------------------------------------------------------------

  Future<void> _pickProfileImage() async {
    if (_isSubmitting) return;

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (pickedFile == null) return;

      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,

        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),

        compressQuality: 90,

        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'ویرایش تصویر',
            toolbarColor: AppColors.sectionBackground,
            toolbarWidgetColor: AppColors.textPrimary,

            lockAspectRatio: true,

            initAspectRatio: CropAspectRatioPreset.square,
          ),

          IOSUiSettings(
            title: 'ویرایش تصویر',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile == null) return;
      if (!mounted) return;

      setState(() {
        _profileImage = File(croppedFile.path);
      });
    } catch (e) {
      debugPrint('Profile image error: $e');
      if (!mounted) return;
      AppFeedback.error(context, 'انتخاب تصویر ناموفق بود.');
    }
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final username = _usernameController.text.trim();
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();

    final error = Validators.username(username) ??
        Validators.required(firstName, label: 'نام') ??
        Validators.required(lastName, label: 'نام خانوادگی') ??
        Validators.optionalEmail(email);

    if (error != null) {
      AppFeedback.error(context, error);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      final user = await ProfileRepository.instance.completeProfile(
        username: username,
        firstName: firstName,
        lastName: lastName,
        email: email.isEmpty ? null : email,
        avatar: _profileImage,
      );

      await SessionManager.instance.updateUser(user);

      if (!mounted) return;
      AppFeedback.success(context, 'ثبت‌نام با موفقیت انجام شد.');
      AppRouter.toMain(context);
    } on ApiException catch (error) {
      if (!mounted) return;
      AppFeedback.error(context, error.message);
    } catch (_) {
      if (!mounted) return;
      AppFeedback.error(
        context,
        'خطای غیرمنتظره‌ای رخ داد. لطفاً دوباره تلاش کنید.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.sectionBackground,
            borderRadius: BorderRadius.only(topRight: Radius.circular(34.r)),
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 17.h, bottom: 10.h),
                  child: Text(
                    'ثبت‌نام',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20.sp,
                      fontFamily: 'pinarb',
                    ),
                  ),
                ),
                Text(
                  'اطلاعات پروفایل خود را تکمیل کنید',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16.sp,
                    fontFamily: 'shabnam',
                  ),
                ),
                SizedBox(height: 25.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 25.w),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _pickProfileImage,
                        child: Container(
                          width: 95.w,
                          height: 95.w,

                          decoration: BoxDecoration(
                            shape: BoxShape.circle,

                            color: AppColors.field,

                            border: Border.all(color: AppColors.border, width: 2),
                          ),

                          child: ClipOval(
                            child: _profileImage == null
                                ? Icon(
                                    Icons.camera_alt_outlined,
                                    size: 28.sp,
                                    color: AppColors.textPrimary,
                                  )
                                : Image.file(
                                    _profileImage!,
                                    width: 82.w,
                                    height: 82.w,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.only(top: 35.h),
                  child: Column(
                    children: [
                      ProfileTextField(
                        label: 'نام کاربری',
                        hint: 'example.2027',
                        required: true,
                        controller: _usernameController,
                      ),

                      SizedBox(height: 1.h),

                      ProfileTextField(
                        label: 'نام',
                        hint: 'مثلا جواد',
                        required: true,
                        controller: _firstNameController,
                      ),

                      SizedBox(height: 1.h),

                      ProfileTextField(
                        label: 'نام خانوادگی',
                        hint: 'مثلا یادگاری',
                        required: true,
                        controller: _lastNameController,
                      ),

                      SizedBox(height: 1.h),

                      ProfileTextField(
                        label: 'ایمیل',
                        hint: 'example@mrcake.ir',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 60.h),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 25.w),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56.h,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.primary.withValues(
                          alpha: 0.6,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      child: _isSubmitting
                          ? const InlineLoader()
                          : Text(
                              'ثبت نام',
                              style: TextStyle(
                                fontFamily: 'bshabnam',
                                fontSize: 20.sp,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
                SizedBox(height: 30.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
