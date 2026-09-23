import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/core/utils/external_link.dart';

/// Promo banner item shown in the home carousel.
class BannerModel {
  final String imageUrl;
  final String? title;
  final String? subtitle;

  /// `link_value` of the banner. Tapping the image opens it in the browser.
  final String? linkUrl;

  const BannerModel({
    required this.imageUrl,
    this.title,
    this.subtitle,
    this.linkUrl,
  });
}

/// Horizontal banner carousel used on the home page.
class HomeBanner extends StatefulWidget {
  final List<BannerModel> banners;

  const HomeBanner({
    super.key,
    required this.banners,
  });

  @override
  State<HomeBanner> createState() => _HomeBannerState();
}

class _HomeBannerState extends State<HomeBanner> {
  late final PageController _controller;
  int _currentPage = 0;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startAutoPlay();
  }

  // Auto-advance every 4 seconds when there is more than one slide.
  void _startAutoPlay() {
    if (widget.banners.length < 2) return;

    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_currentPage + 1) % widget.banners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) {
      return const SizedBox.shrink();
    }

    // Figma: height 94, full width, 25px side insets. ScreenUtil keeps it responsive.
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w),
      child: SizedBox(
        width: double.infinity,
        height: 94.h,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16.r),
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.banners.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  return _BannerSlide(banner: widget.banners[index]);
                },
              ),
            ),
            // Glass page indicator overlaid at the bottom center.
            Positioned(
              left: 0,
              right: 0,
              bottom: 6.h,
              child: Center(
                child: _GlassIndicator(
                  itemCount: widget.banners.length,
                  currentIndex: _currentPage,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerSlide extends StatelessWidget {
  final BannerModel banner;

  const _BannerSlide({required this.banner});

  @override
  Widget build(BuildContext context) {
    final hasText = banner.title != null || banner.subtitle != null;

    final slide = Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          banner.imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return ColoredBox(
              color: AppColors.sectionBackground,
              child: Center(
                child: SizedBox(
                  width: 22.w,
                  height: 22.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.w,
                    color: AppColors.primary,
                  ),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return ColoredBox(
              color: AppColors.sectionBackground,
              child: Icon(
                Icons.image_not_supported_outlined,
                size: 36.sp,
                color: AppColors.textSecondary,
              ),
            );
          },
        ),
        // Soft gradient so overlay text stays readable on busy photos.
        if (hasText)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  Color(0xE0FCEFE9),
                ],
                stops: [0.32, 0.82],
              ),
            ),
          ),
        if (hasText)
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (banner.title != null)
                  Text(
                    banner.title!,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'pinarb',
                      fontSize: 13.sp,
                      height: 1.15,
                      color: const Color(0xFFD1495B),
                    ),
                  ),
                const Spacer(),
                if (banner.subtitle != null)
                  Text(
                    banner.subtitle!,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'shabnam',
                      fontSize: 9.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );

    // The banner links to an external site: tapping the image hands it to the
    // browser. Without a usable link the slide stays inert, exactly as before.
    if (!ExternalLink.isOpenable(banner.linkUrl)) return slide;

    return GestureDetector(
      // The image fills the slide, so the whole banner is tappable.
      behavior: HitTestBehavior.opaque,
      onTap: () => ExternalLink.open(banner.linkUrl),
      child: slide,
    );
  }
}

/// Frosted-glass pill with circular dots, matching the Figma indicator.
class _GlassIndicator extends StatelessWidget {
  final int itemCount;
  final int currentIndex;

  const _GlassIndicator({
    required this.itemCount,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: AppColors.white.withValues(alpha: 0.45),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(itemCount, (index) {
              final isActive = index == currentIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: EdgeInsets.symmetric(horizontal: 2.w),
                width: isActive ? 6.w : 5.w,
                height: isActive ? 6.w : 5.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? AppColors.textPrimary
                      : AppColors.white.withValues(alpha: 0.55),
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.9),
                    width: 1,
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
