import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ProfileBanner extends StatelessWidget {
  final File? bannerImage;
  final String? bannerImageUrl;

  const ProfileBanner({
    super.key,
    this.bannerImage,
    this.bannerImageUrl,
  });

  static const double bannerHeight = 245;

  @override
  Widget build(BuildContext context) {
    // No edit affordance: the banner is a **fixed** image. The user asked for
    // the button to go, and with it the whole pick → crop → upload path, which
    // could never succeed anyway — `POST v1/media/` drops the connection for any
    // multipart request that actually carries a file part (see the note in
    // [_buildBannerContent]). Offering a control that always ends in
    // «آپلود تصویر ناموفق» is worse than not offering it.
    return SizedBox(
      width: double.infinity,
      height: bannerHeight.h,
      child: Stack(
        fit: StackFit.expand,
        children: [ClipRRect(child: _buildBannerContent(context))],
      ),
    );
  }

  Widget _buildBannerContent(BuildContext context) {
    // 1. A locally-picked image, if a caller ever passes one.
    final File? local = bannerImage;
    if (local != null) {
      return Image.file(
        local,
        width: double.infinity,
        height: bannerHeight.h,
        fit: BoxFit.cover,
      );
    }

    // 2. The url the backend sent (or `SessionManager` cached).
    final String? url = bannerImageUrl;
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

    // 3. Fallback — the bundled asset, so the banner is never blank.
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
