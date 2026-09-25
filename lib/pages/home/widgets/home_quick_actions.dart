import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';

/// The four home shortcuts. Laid out by the parent, so every card is sized from
/// the width it is *given* rather than from a constant — see
/// [_QuickActionItem] for why that matters on non-phone aspect ratios.
class HomeQuickActions extends StatelessWidget {
  final VoidCallback? onCoursesTap;
  final VoidCallback? onTeachersTap;
  final VoidCallback? onStudentsTap;
  final VoidCallback? onRecipesTap;

  const HomeQuickActions({
    super.key,
    this.onCoursesTap,
    this.onTeachersTap,
    this.onStudentsTap,
    this.onRecipesTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        final double width = constraints.maxWidth;

        // Scaled, so a narrow phone keeps a little more room for the cards
        // themselves. At the 390-wide design size this is still 8, which is
        // what the row already used there.
        final double horizontalGap =
            width < 360 ? 8.w : 10.w;

        return Row(
          textDirection: TextDirection.rtl,
          children: [
            Expanded(
              child: _QuickActionItem(
                icon: Icons.auto_stories_rounded,
                title: 'دوره‌ها',
                onTap: onCoursesTap,
              ),
            ),

            SizedBox(width: horizontalGap),

            Expanded(
              child: _QuickActionItem(
                icon: Icons.school_rounded,
                title: 'استاد',
                onTap: onTeachersTap,
              ),
            ),

            SizedBox(width: horizontalGap),

            Expanded(
              child: _QuickActionItem(
                icon: Icons.groups_rounded,
                title: 'هنرجوها',
                onTap: onStudentsTap,
              ),
            ),

            SizedBox(width: horizontalGap),

            Expanded(
              child: _QuickActionItem(
                icon: Icons.menu_book_rounded,
                title: 'رسپی‌ها',
                onTap: onRecipesTap,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ================================================================
// QUICK ACTION ITEM
// ================================================================

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const _QuickActionItem({
    required this.icon,
    required this.title,
    this.onTap,
  });

  /// Card height at the 390×844 design size.
  static const double _designHeight = 85;

  /// Vertical padding inside the card.
  static const double _designPadding = 9;

  /// Border width. `Ink` applies the decoration's border as **padding** to its
  /// child, so this eats into the card's usable height on both sides.
  static const double _designBorder = 2;

  /// Space between the icon circle and the label.
  static const double _designGap = 6;

  /// Icon circle diameter at the design size.
  static const double _designIconBox = 37;

  /// Label size, and the `TextStyle.height` multiplier applied to it.
  static const double _designLabelSize = 16;
  static const double _labelLineHeight = 1.1;

  /// The largest share of the card the label may take, at any size.
  ///
  /// `.sp` is `value * scaleWidth` in this project — `ScreenUtilInit`'s default
  /// `fontSizeResolver` is `FontSizeResolvers.width`, which bypasses
  /// `minTextAdapt` — so the label grows with the screen **width** while the
  /// card grows with its height. On a tablet or in landscape that is 42px of
  /// text inside a 77px card. Capping it against the card keeps the two in step;
  /// on a phone the cap is never reached, so nothing changes there.
  static const double _labelMaxShare = 0.20;

  /// What is actually subtracted from the card to make room for the label.
  ///
  /// A font's real line box can be a little taller than `fontSize * height`:
  /// the bundled Shabnam paints 18.0 where `16 * 1.1` predicts 17.6. Reserving
  /// the theoretical value alone leaves the label a fraction of a pixel short,
  /// and `Flexible` would then clip the glyphs instead of overflowing. The
  /// margin keeps the label intact; at the design size it changes nothing,
  /// because `37.w` is still the smaller term.
  static const double _labelReserve = 1.25;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // The card is laid out by the row's `Expanded`, so its **width** is
        // whatever is left after the gaps — it must never be a constant. Its
        // height does have to be declared, because the row sits in a scroll
        // view and is handed no height by its parent.
        final double width = constraints.maxWidth;
        final double height = _designHeight.h;

        final double paddingV = _designPadding.h;
        final double border = _designBorder.w;
        final double gap = _designGap.h;

        // What is really left for the column: the card, minus the padding on
        // both sides, minus the border — `Ink` insets its child by the border
        // width, which is easy to forget and leaves the label a pixel short.
        final double contentHeight = height - (paddingV + border) * 2;

        // The label the design asks for, but never more than the card can hold.
        // `.sp` follows the screen width (see [_labelMaxShare]); the reservation
        // also takes the system text scale into account, so a user with large
        // accessibility fonts shrinks the icon instead of clipping the label.
        final double labelSize = math.min(
          _designLabelSize.sp,
          contentHeight * _labelMaxShare,
        );
        final double labelHeight =
            MediaQuery.textScalerOf(context).scale(labelSize) *
                _labelReserve;

        // The icon circle used to be a flat `37.w`. Width scales with the
        // screen width while `85.h` scales with the screen height, so on any
        // device where the two disagree — a narrow phone, a tablet, and above
        // all **landscape** — `37.w` outgrew the card and the column overflowed
        // it. That is the pixel-overflow stripe that showed up on device.
        //
        // Sizing the circle against what the card actually has left keeps the
        // room for the label intact, so the column can never ask for more than
        // the card holds. At the design size `37.w` is still the smaller term,
        // so the card looks byte-for-byte the same as before.
        final double iconRoom = contentHeight - gap - labelHeight;
        final double iconBox = math.max(
          0,
          math.min(_designIconBox.w, iconRoom),
        );

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16.r),
            splashColor:
                AppColors.primary.withValues(alpha: 0.10),
            highlightColor:
                AppColors.primary.withValues(alpha: 0.05),
            child: Ink(
              height: height,
              width: width,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: AppColors.border,
                  width: 2.w,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 4.w,
                  vertical: paddingV,
                ),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    // ==================================================
                    // ICON
                    // ==================================================

                    Container(
                      width: iconBox,
                      height: iconBox,
                      decoration: BoxDecoration(
                        color: AppColors.primary
                            .withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        icon,
                        size: math.min(22.sp, iconBox * 0.6),
                        color: AppColors.primary,
                      ),
                    ),

                    SizedBox(height: gap),

                    // ==================================================
                    // TITLE
                    // ==================================================

                    // `Flexible` is the last line of defence: if a font ever
                    // measures taller than the line box we reserved, the label
                    // shrinks instead of painting the overflow stripe.
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Shabnam',
                          fontSize: labelSize,
                          color: AppColors.textPrimary,
                          height: _labelLineHeight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
