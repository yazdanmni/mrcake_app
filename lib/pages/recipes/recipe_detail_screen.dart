import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/app_colors.dart';
import '../../models/recipe.dart';
import '../../models/teacher_model.dart';
import '../../data/recipes_data.dart';
import '../../data/teacher_data.dart';

class RecipeDetailScreen extends StatelessWidget {
  final int recipeId;

  const RecipeDetailScreen({super.key, required this.recipeId});

  @override
  Widget build(BuildContext context) {
    final Recipe? recipe = _findRecipe(recipeId);

    if (recipe == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text(
            'رسپی پیدا نشد',
            style: TextStyle(
              fontFamily: 'bShabnam',
              fontSize: 18.sp,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      );
    }

    final Teacher? teacher = TeacherData.getTeacherById(recipe.teacherId);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _RecipeSliverHeader(recipe: recipe, teacher: teacher),

            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(25.w, 17.h, 25.w, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // =====================================================
                    // TITLE
                    // =====================================================

                    Text(
                      recipe.title,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'bShabnam',
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),

                    SizedBox(height: 14.h),

                    // =====================================================
                    // DESCRIPTION
                    // =====================================================
                    Text(
                      recipe.description,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'Shabnam',
                        fontSize: 18.sp,
                        color: AppColors.textSecondary,
                        height: 1.65,
                      ),
                    ),

                    SizedBox(height: 30.h),

                    // =====================================================
                    // INGREDIENTS
                    // =====================================================
                    _IngredientsSection(ingredients: recipe.ingredients),

                    SizedBox(height: 22.h),

                    // =====================================================
                    // STEPS TITLE
                    // =====================================================
                    Text(
                      'مراحل تهیه',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'bShabnam',
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),

                    SizedBox(height: 14.h),

                    // =====================================================
                    // STEPS
                    // =====================================================
                    _StepsList(steps: recipe.steps),

                    SizedBox(height: 30.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Recipe? _findRecipe(int id) {
    for (final Recipe recipe in RecipesData.recipes) {
      if (recipe.id == id) {
        return recipe;
      }
    }

    return null;
  }
}

// ============================================================================
// SLIVER HEADER
// ============================================================================

class _RecipeSliverHeader extends StatelessWidget {
  final Recipe recipe;
  final Teacher? teacher;

  const _RecipeSliverHeader({required this.recipe, required this.teacher});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      expandedHeight: 310.h,
      collapsedHeight: 0,
      toolbarHeight: 0,
      floating: false,
      pinned: false,
      snap: false,
      stretch: true,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: _RecipeHeaderImage(recipe: recipe, teacher: teacher),
      ),
    );
  }
}

// ============================================================================
// HEADER IMAGE
// ============================================================================

class _RecipeHeaderImage extends StatelessWidget {
  final Recipe recipe;
  final Teacher? teacher;

  const _RecipeHeaderImage({required this.recipe, required this.teacher});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(18.r),
          bottomRight: Radius.circular(18.r),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.24),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(18.r),
          bottomRight: Radius.circular(18.r),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // =============================================================
            // RECIPE IMAGE
            // =============================================================

            Image.network(
              recipe.image,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) {
                    return Container(
                      color: AppColors.field,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 42.sp,
                        color: AppColors.textSecondary,
                      ),
                    );
                  },
            ),

            // =============================================================
            // SOFT IMAGE OVERLAY
            // =============================================================
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.08),
                    Colors.transparent,
                    Colors.black.withOpacity(0.18),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),

            // =============================================================
            // HEADER CONTROLS
            // BACK LEFT — TEACHER RIGHT
            // =============================================================
            Positioned(
              left: 25.w,
              right: 25.w,
              top: MediaQuery.of(context).padding.top + 15.h,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                textDirection: TextDirection.ltr,
                children: [
                  // -------------------------------------------------------
                  // BACK BUTTON — LEFT
                  // -------------------------------------------------------

                  _BackButton(),

                  // -------------------------------------------------------
                  // TEACHER CARD — RIGHT
                  // -------------------------------------------------------
                  if (teacher != null)
                    _TeacherCard(teacher: teacher!)
                  else
                    SizedBox(width: 119.w, height: 37.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ============================================================================
// BACK BUTTON
// ============================================================================

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).pop();
      },
      child: Container(
        width: 44.w,
        height: 44.w,
        decoration: BoxDecoration(
          color: AppColors.premium.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: AppColors.premium, width: 1.5.w),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 19.sp,
          color: AppColors.white,
        ),
      ),
    );
  }
}

// ============================================================================
// TEACHER CARD
// ============================================================================

class _TeacherCard extends StatelessWidget {
  final Teacher teacher;

  const _TeacherCard({required this.teacher});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 119.w,
      height: 37.h,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.5.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 1.w),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.30),
              borderRadius: BorderRadius.circular(18.5.r),
              border: Border.all(
                color: Colors.white.withOpacity(0.45),
                width: 0.7.w,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.16),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                // =========================================================
                // PROFILE
                // =========================================================

                SizedBox(
                  width: 31.w,
                  height: 31.w,
                  child: ClipOval(
                    child: Image.network(
                      teacher.profileImage,
                      width: 31.w,
                      height: 31.w,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (
                            BuildContext context,
                            Object error,
                            StackTrace? stackTrace,
                          ) {
                            return Container(
                              width: 31.w,
                              height: 31.w,
                              color: AppColors.field,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.person_outline,
                                size: 18.sp,
                                color: AppColors.textSecondary,
                              ),
                            );
                          },
                    ),
                  ),
                ),

                SizedBox(width: 5.w),

                // =========================================================
                // TEACHER NAME
                // =========================================================
                Expanded(
                  child: Text(
                    'استاد ${teacher.lastName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'bShabnam',
                      fontSize: 14.sp,
                      color: AppColors.textPrimary,
                      height: 1.1,
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
// ============================================================================
// INGREDIENTS SECTION
// ============================================================================

class _IngredientsSection extends StatelessWidget {
  final List<RecipeIngredient> ingredients;

  const _IngredientsSection({required this.ingredients});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ================================================================
        // HEADERS
        // مقدار ← چپ
        // مواد لازم → راست
        // ================================================================

        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // =========================================================
              // مقدار — سمت چپ
              // =========================================================

              Expanded(
                child: _IngredientHeader(
                  title: 'مقدار',
                  color: AppColors.primary,
                ),
              ),

              SizedBox(width: 10.w),

              // =========================================================
              // مواد لازم — سمت راست
              // =========================================================
              Expanded(
                child: _IngredientHeader(
                  title: 'مواد لازم',
                  color: AppColors.premium,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 11.h),

        // ================================================================
        // INGREDIENT ITEMS
        // مقدار ← چپ
        // مواد لازم → راست
        // ================================================================
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // =========================================================
              // مقدار — سمت چپ
              // =========================================================

              Expanded(
                child: _IngredientColumn(
                  ingredients: ingredients,
                  showAmount: true,
                ),
              ),

              SizedBox(width: 10.w),

              // =========================================================
              // مواد لازم — سمت راست
              // =========================================================
              Expanded(
                child: _IngredientColumn(
                  ingredients: ingredients,
                  showAmount: false,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
// ============================================================================
// INGREDIENT HEADER
// ============================================================================

class _IngredientHeader extends StatelessWidget {
  final String title;
  final Color color;

  const _IngredientHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 33.h,
      constraints: BoxConstraints(maxWidth: 166.w),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8.r),
      ),
      alignment: Alignment.center,
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'bShabnam',
          fontSize: 15.sp,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}

// ============================================================================
// INGREDIENT COLUMN
// ============================================================================

class _IngredientColumn extends StatelessWidget {
  final List<RecipeIngredient> ingredients;
  final bool showAmount;

  const _IngredientColumn({
    required this.ingredients,
    required this.showAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      textDirection: TextDirection.rtl,
      children: List.generate(ingredients.length, (index) {
        final RecipeIngredient ingredient = ingredients[index];

        return Padding(
          padding: EdgeInsets.only(
            bottom: index == ingredients.length - 1 ? 0 : 6.h,
          ),
          child: _IngredientItem(
            text: showAmount ? ingredient.amount : ingredient.name,
            borderColor: showAmount ? AppColors.primary : AppColors.premium,
          ),
        );
      }),
    );
  }
}

// ============================================================================
// INGREDIENT ITEM
// ============================================================================

class _IngredientItem extends StatelessWidget {
  final String text;
  final Color borderColor;

  const _IngredientItem({required this.text, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: 36.h),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: borderColor, width: 2.w),
      ),
      alignment: Alignment.center,
      child: Text(
        textDirection: TextDirection.rtl,
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'bShabnam',
          fontSize: 15.sp,
          color: AppColors.textPrimary,
          height: 1.25,
        ),
      ),
    );
  }
}

// ============================================================================
// STEPS LIST
// ============================================================================

class _StepsList extends StatelessWidget {
  final List<String> steps;

  const _StepsList({required this.steps});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(steps.length, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index == steps.length - 1 ? 0 : 5.h),
          child: _StepItem(number: index + 1, text: steps[index]),
        );
      }),
    );
  }
}

// ============================================================================
// SINGLE STEP
// ============================================================================

class _StepItem extends StatelessWidget {
  final int number;
  final String text;

  const _StepItem({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    final String formattedNumber = number.toString().padLeft(2, '0');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===============================================================
          // NUMBER BOX
          // ===============================================================

          Container(
            width: 30.w,
            height: 30.w,
            decoration: BoxDecoration(
              color: AppColors.field,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: AppColors.premium, width: 1.w),
            ),
            alignment: Alignment.center,
            child: Text(
              formattedNumber,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'bShabnam',
                fontSize: 20.sp,
                color: AppColors.textPrimary,
                height: 1,
              ),
            ),
          ),

          SizedBox(width: 8.w),

          // ===============================================================
          // STEP DESCRIPTION
          // ===============================================================
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
              decoration: BoxDecoration(
                color: AppColors.field,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: AppColors.primary, width: 1.w),
              ),
              child: Text(
                text,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'Shabnam',
                  fontSize: 18.sp,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
