import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/data/explore_videos_data.dart';
import 'package:mr_cake_project/pages/explore/widgets/explore_grid.dart';
import 'package:mr_cake_project/pages/explore/widgets/explore_header.dart';
import 'package:mr_cake_project/pages/explore/widgets/reels_viewer.dart';

class ExploreScreen extends StatefulWidget {
  const new({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const ExploreHeader(),
              SizedBox(height: 44.h),
              ExploreGrid(
                videos: ExploreVideosData.videos,
                onVideoTap: (video) {
                  final int index = ExploreVideosData.videos.indexWhere(
                    (item) => item.id == video.id,
                  );
          
                  if (index == -1) {
                    return;
                  }
          
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReelsViewer(
                        videos: ExploreVideosData.videos,
                        initialIndex: index,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
