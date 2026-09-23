import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/core/utils/external_link.dart';
import 'package:mr_cake_project/core/router/app_router.dart';

/// API hero image and the "start learning" CTA.
///
/// The layout is intentionally unchanged: the illustration keeps the top of the
/// 376x344 box and the CTA stays right under it. When the API has no active
/// hero, or its image cannot be loaded, the bundled asset remains the fallback.
///
/// Tapping the illustration opens [linkUrl] in the device browser. When the API
/// sends no usable link the image stays inert, exactly as it was before.
class HomeHero extends StatelessWidget {
  const HomeHero({super.key, this.imageUrl, this.linkUrl});

  final String? imageUrl;
  final String? linkUrl;

  @override
  Widget build(BuildContext context) {
    final hasRemoteImage = imageUrl != null && imageUrl!.isNotEmpty;

    // `Expanded` + `Stack` keeps the illustration inside the space left above
    // the CTA, whatever size the API image happens to have, and avoids the
    // layout jump a bare image would cause while it is still downloading.
    Widget illustration = Stack(
      fit: StackFit.expand,
      children: [
        hasRemoteImage
            ? Image.network(
                imageUrl!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset(
                    'assets/images/home_hero.png',
                    fit: BoxFit.contain,
                  );
                },
              )
            : Image.asset(
                'assets/images/home_hero.png',
                fit: BoxFit.contain,
              ),
      ],
    );

    if (ExternalLink.isOpenable(linkUrl)) {
      illustration = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ExternalLink.open(linkUrl),
        child: illustration,
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w),
      child: AspectRatio(
        aspectRatio: 376 / 344,
        child: Column(
          children: [
            Expanded(child: illustration),

            Padding(
              padding: EdgeInsets.only(top: 16.h),
              child: SizedBox(
                width: 160.w,
                height: 43.h,
                child: GestureDetector(
                  onTap: () {
                    AppRouter.toCourses(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Center(
                      child: Text(
                        'شروع یادگیری',
                        style: TextStyle(
                          color: AppColors.white,
                          fontFamily: 'pinarb',
                          fontSize: 16.sp,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
