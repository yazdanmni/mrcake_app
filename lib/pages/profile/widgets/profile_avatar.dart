import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';

class ProfileAvatar extends StatefulWidget {
  const ProfileAvatar({
    super.key,
    this.imageUrl,
    this.onImageChanged,
    this.size = 135,
  });

  final String? imageUrl;

  final ValueChanged<File?>? onImageChanged;

  final double size;

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  final ImagePicker _picker = ImagePicker();

  File? _localImage;

  bool _isPicking = false;

  bool get _hasNetworkImage {
    return widget.imageUrl != null &&
        widget.imageUrl!.trim().isNotEmpty;
  }

  // =========================================================
  // انتخاب تصویر
  // =========================================================

  Future<void> _pickProfileImage() async {
    if (_isPicking) return;

    try {
      setState(() {
        _isPicking = true;
      });

      debugPrint('PROFILE AVATAR: opening gallery...');

      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      debugPrint(
        'PROFILE AVATAR: picked = ${pickedFile?.path}',
      );

      if (pickedFile == null) {
        return;
      }

      // =====================================================
      // Crop
      // =====================================================

      debugPrint('PROFILE AVATAR: opening cropper...');

      final CroppedFile? croppedFile =
          await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        compressQuality: 90,
        aspectRatio: const CropAspectRatio(
          ratioX: 1,
          ratioY: 1,
        ),
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

      debugPrint(
        'PROFILE AVATAR: cropped = ${croppedFile?.path}',
      );

      if (croppedFile == null) {
        return;
      }

      final File image = File(croppedFile.path);

      if (!mounted) return;

      setState(() {
        _localImage = image;
      });

      widget.onImageChanged?.call(image);
    } catch (e, stackTrace) {
      debugPrint('PROFILE AVATAR ERROR: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'انتخاب تصویر انجام نشد',
            style: TextStyle(
              fontFamily: 'BShabnam',
              fontSize: 13.sp,
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isPicking = false;
      });
    }
  }

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final double avatarSize = widget.size.w;

    return SizedBox(
      width: avatarSize + 32.w,
      height: avatarSize + 32.w,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ===================================================
          // Avatar
          // ===================================================

          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: avatarSize,
              height: avatarSize,
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.sectionBackground,
                border: Border.all(
                  color: AppColors.border,
                  width: 2.w,
                ),
              ),
              child: ClipOval(
                child: _buildAvatarImage(),
              ),
            ),
          ),

          // ===================================================
          // Edit Button
          // ===================================================

          Positioned(
            right: 10.w,
            bottom: 20.h,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _pickProfileImage,
                borderRadius: BorderRadius.circular(16.r),
                child: Container(
                  width: 55.w,
                  height: 55.w,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16.r),
                    color: AppColors.sectionBackground.withValues(alpha: 
                      0.88,
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.65),
                      width: 1.2.w,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 14.r,
                        offset: Offset(0, 6.h),
                      ),
                    ],
                  ),
                  child: _isPicking
                      ? Center(
                          child: SizedBox(
                            width: 23.w,
                            height: 23.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.w,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.edit_rounded,
                            size: 28.sp,
                            color: AppColors.primary,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // Avatar Image
  // =========================================================

  Widget _buildAvatarImage() {
    // عکس انتخاب‌شده جدید
    if (_localImage != null) {
      return Image.file(
        _localImage!,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
      );
    }

    // عکس API
    if (_hasNetworkImage) {
      return Image.network(
        widget.imageUrl!,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (
          context,
          error,
          stackTrace,
        ) {
          return _buildPlaceholder();
        },
        loadingBuilder: (
          context,
          child,
          loadingProgress,
        ) {
          if (loadingProgress == null) {
            return child;
          }

          return _buildPlaceholder(
            loading: true,
          );
        },
      );
    }

    // بدون عکس
    return _buildPlaceholder();
  }

  // =========================================================
  // Placeholder
  // =========================================================

  Widget _buildPlaceholder({
    bool loading = false,
  }) {
    if (loading) {
      return Center(
        child: SizedBox(
          width: 25.w,
          height: 25.w,
          child: CircularProgressIndicator(
            strokeWidth: 2.w,
            color: AppColors.primary,
          ),
        ),
      );
    }

    return Container(
      color: AppColors.field,
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: 52.sp,
        color: AppColors.textSecondary,
      ),
    );
  }
}