import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/pages/courses/widgets/courses_search.dart';

import '../../../core/theme/app_colors.dart';

class ExploreHeader extends StatelessWidget {
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchSubmitted;

  const ExploreHeader({
    super.key,
    this.onSearchChanged,
    this.onSearchSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: 25.w),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'اکسپلور',
            style: TextStyle(
              fontFamily: 'PinarB',
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              height: 1.1,
            ),
          ),


          Expanded(
            child: CoursesSearch(
              onChanged: (value) {
                // بعداً اتصال به API
              },
            ),
          ),
        ],
      ),
    );
  }
}
