import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';


class CoursesSearch extends StatefulWidget {
  const CoursesSearch({
    super.key,
    this.onChanged,
  });

  final ValueChanged<String>? onChanged;

  @override
  State<CoursesSearch> createState() => _CoursesSearchState();
}

class _CoursesSearchState extends State<CoursesSearch> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        onChanged: widget.onChanged,
        style: TextStyle(
          fontFamily: 'shabnam',
          fontSize: 16.sp,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'جستجوی دوره...',
          hintTextDirection: TextDirection.rtl,
          hintStyle: TextStyle(
            fontFamily: 'shabnam',
            fontSize: 16.sp,
            color: AppColors.textSecondary,
          ),

          prefixIcon: Icon(
            Icons.search_rounded,
            size: 23.sp,
            color: AppColors.textPrimary,
          ),

          filled: true,
          fillColor: AppColors.field,

          contentPadding: EdgeInsets.symmetric(
            horizontal: 18.w,
            vertical: 14.h,
          ),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18.r),
            borderSide: BorderSide.none,
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18.r),
            borderSide: BorderSide(
              color: AppColors.border,
              width: 2,
            ),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15.r),
            borderSide: BorderSide(
              color: AppColors.premium,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}