import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/models/teacher_model.dart';

import 'teacher_portfolio_item.dart';

class TeacherPortfolioGrid extends StatelessWidget {
  final List<TeacherPortfolioItem> items;
  final ValueChanged<TeacherPortfolioItem>? onItemTap;

  const TeacherPortfolioGrid({
    super.key,
    required this.items,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: 25.w,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 20.w,
        mainAxisSpacing: 20.h,
        mainAxisExtent: 150.h,
      ),
      itemCount: items.length,
      itemBuilder: (
        BuildContext context,
        int index,
      ) {
        final TeacherPortfolioItem item = items[index];

        return TeacherPortfolioItemCard(
          item: item,
          onTap: () {
            onItemTap?.call(item);
          },
        );
      },
    );
  }
}