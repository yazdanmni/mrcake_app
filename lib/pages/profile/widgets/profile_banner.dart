import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mr_cake_project/core/theme/app_colors.dart';

class ProfileBanner extends StatefulWidget {
  final File? bannerImage;
  final String? bannerImageUrl;
  final ValueChanged<File?>? onImageChanged;

  const ProfileBanner({
    super.key,
    this.bannerImage,
    this.bannerImageUrl,
    this.onImageChanged,
  });

  @override
  State<ProfileBanner> createState() => _ProfileBannerState();
}

class _ProfileBannerState extends State<ProfileBanner> {
  static const double bannerHeight = 245;
  static const int recommendedWidth = 1080;
  static const int recommendedHeight = 735;

  File? _bannerImage;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _bannerImage = widget.bannerImage;
  }

  @override
  void didUpdateWidget(covariant ProfileBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bannerImage?.path != widget.bannerImage?.path) {
      _bannerImage = widget.bannerImage;
    }
  }

  Future<void> _pickBannerImage() async {
    try {
      final bool shouldContinue = await _showImageGuide();
      if (!shouldContinue || !mounted) return;

      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (pickedFile == null) return;
      if (!mounted) return;

      final double screenWidth = MediaQuery.sizeOf(context).width;
      final double cropHeight = bannerHeight.h;
      final double cropRatio = screenWidth / cropHeight;

      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 92,
        aspectRatio: CropAspectRatio(
          ratioX: cropRatio,
          ratioY: 1,
        ),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'برش تصویر بنر',
            toolbarColor: AppColors.sectionBackground,
            toolbarWidgetColor: AppColors.textPrimary,
            backgroundColor: AppColors.sectionBackground,
            lockAspectRatio: true,
            hideBottomControls: false,
            showCropGrid: true,
          ),
          IOSUiSettings(
            title: 'برش تصویر بنر',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            rotateButtonsHidden: false,
            rotateClockwiseButtonHidden: false,
            aspectRatioPickerButtonHidden: true,
          ),
        ],
      );

      if (croppedFile == null) return;

      final File resultFile = File(croppedFile.path);
      if (!mounted) return;

      setState(() {
        _bannerImage = resultFile;
      });

      widget.onImageChanged?.call(resultFile);
    } catch (e, stackTrace) {
      debugPrint('ProfileBanner image error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.textPrimary,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16.w),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
          content: Text(
            'خطایی در انتخاب تصویر رخ داد',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'shabnam',
              fontSize: 13.sp,
            ),
          ),
        ),
      );
    }
  }

  Future<bool> _showImageGuide() async {
    final bool? result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (BuildContext context) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(25.w, 12.h, 25.w, 25.h),
          decoration: BoxDecoration(
            color: AppColors.sectionBackground,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28.r),
              topRight: Radius.circular(28.r),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .12),
                blurRadius: 25.r,
                offset: Offset(0, -5.h),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              SizedBox(height: 22.h),
              Container(
                width: 58.w,
                height: 58.w,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: .10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.photo_size_select_large_outlined,
                  color: AppColors.primary,
                  size: 28.sp,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'افزودن تصویر بنر',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 19.sp,
                  fontFamily: 'pinarb',
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'یک تصویر با کیفیت انتخاب کنید. '
                'در مرحله بعد می‌توانید قسمت موردنظر تصویر را برش دهید.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.5.sp,
                  height: 1.8,
                  fontFamily: 'shabnam',
                ),
              ),
              SizedBox(height: 18.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 14.h,
                ),
                decoration: BoxDecoration(
                  color: AppColors.field,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: AppColors.border,
                    width: 1,
                  ),
                ),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Container(
                      width: 40.w,
                      height: 40.w,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        Icons.aspect_ratio_outlined,
                        color: AppColors.primary,
                        size: 21.sp,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'اندازه پیشنهادی',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12.sp,
                              fontFamily: 'shabnam',
                            ),
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            '$recommendedWidth × $recommendedHeight پیکسل',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14.sp,
                              fontFamily: 'bshabnam',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              SizedBox(
                width: double.infinity,
                height: 54.h,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  child: Text(
                    'انتخاب تصویر',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontFamily: 'bshabnam',
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: bannerHeight.h,
      margin: EdgeInsets.only(top: 15.h),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            child: _buildBannerContent(),
          ),
          Positioned(
            top: 15.h,
            right: 25.w,
            child: _GlassEditButton(
              onTap: _pickBannerImage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerContent() {
    // 1. Newly picked local image takes precedence (after edit dialog)
    if (_bannerImage != null) {
      return Image.file(
        _bannerImage!,
        width: double.infinity,
        height: bannerHeight.h,
        fit: BoxFit.cover,
      );
    }

    // 2. Persisted URL from the API (or user model / SessionManager)
    final url = widget.bannerImageUrl;
    if (url != null && url.trim().isNotEmpty) {
      return Image.network(
        url,
        width: double.infinity,
        height: bannerHeight.h,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const _DefaultBanner();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: SizedBox(
              width: 28.w,
              height: 28.w,
              child: CircularProgressIndicator(
                strokeWidth: 2.w,
                color: Colors.white,
              ),
            ),
          );
        },
      );
    }

    // 3. Fallback — asset banner pro_banner.jpg
    return const _DefaultBanner();
  }
}

class _DefaultBanner extends StatelessWidget {
  const _DefaultBanner();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/pro_banner.jpg',
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return CustomPaint(
          painter: _PremiumNoisePainter(),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _PremiumNoisePainter extends CustomPainter {
  final math.Random _random = math.Random(21);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint gradientPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          Color(0xFFFFE7EC),
          Color(0xFFF6C5CF),
          Color(0xFFE8A1B1),
          Color(0xFFD98298),
        ],
        stops: [0.0, 0.38, 0.72, 1.0],
      ).createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );

    canvas.drawRect(Offset.zero & size, gradientPaint);

    final Paint glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.65, -0.7),
        radius: 1.1,
        colors: [
          Colors.white.withValues(alpha: .42),
          Colors.white.withValues(alpha: .12),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );

    canvas.drawRect(Offset.zero & size, glowPaint);

    final Paint noisePaint = Paint()..style = PaintingStyle.fill;
    const int density = 1700;
    for (int i = 0; i < density; i++) {
      final double x = _random.nextDouble() * size.width;
      final double y = _random.nextDouble() * size.height;
      final bool isLight = _random.nextBool();
      noisePaint.color = isLight
          ? Colors.white.withValues(alpha: .025 + (_random.nextDouble() * .025))
          : Colors.black.withValues(alpha: .012 + (_random.nextDouble() * .018));
      final double radius = .25 + (_random.nextDouble() * .65);
      canvas.drawCircle(Offset(x, y), radius, noisePaint);
    }

    final Paint linePaint = Paint()
      ..color = Colors.white.withValues(alpha: .035)
      ..strokeWidth = 1;

    for (double x = -size.height; x < size.width; x += 55) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GlassEditButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _GlassEditButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.only(top: 170.h),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .22),
              border: Border.all(
                color: Colors.white.withValues(alpha: .75),
                width: 1.2,
              ),
              borderRadius: BorderRadius.circular(14.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .12),
                  blurRadius: 14.r,
                  offset: Offset(0, 5.h),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: .18),
                  blurRadius: 5.r,
                  offset: Offset(0, -1.h),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.edit_outlined,
                size: 24.sp,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
