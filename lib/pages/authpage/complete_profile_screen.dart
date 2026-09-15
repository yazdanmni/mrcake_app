import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/pages/authpage/widget/complete_profile_fields.dart';

class CompleteProfileScreen extends StatefulWidget {
  const new({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickProfileImage() async {
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

      setState(() {
        _profileImage = File(croppedFile.path);
      });
    } catch (e) {
      debugPrint('Profile image error: $e');
    }
  }

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
                      ),
            
                      SizedBox(height: 1.h),
            
                      ProfileTextField(
                        label: 'نام',
                        hint: 'مثلا جواد',
                        required: true,
                      ),
            
                      SizedBox(height: 1.h),
            
                      ProfileTextField(
                        label: 'نام خانوادگی',
                        hint: 'مثلا یادگاری',
                        required: true,
                      ),
            
                      SizedBox(height: 1.h),
            
                      ProfileTextField(label: 'ایمیل', hint: 'example@mrcake.ir'),
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
                      onPressed: () {
                        // ثبت اطلاعات
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      child: Text(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
