import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/core/network/remote_data.dart';
import 'package:mr_cake_project/core/theme/app_colors.dart';
import 'package:mr_cake_project/models/explore_video.dart';
import 'dart:async';
import 'package:mr_cake_project/pages/explore/widgets/explore_grid.dart';
import 'package:mr_cake_project/pages/explore/widgets/explore_header.dart';
import 'package:mr_cake_project/pages/explore/widgets/reels_viewer.dart';
import 'package:mr_cake_project/repositories/catalog_repository.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final CatalogRepository _repository = CatalogRepository.instance;
  final ScrollController _scrollController = ScrollController();

  List<ExploreVideo> _videos = [];
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMoreVideos = true;

  @override
  void initState() {
    super.initState();
    _load(refresh: true); // Initial load
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMoreVideos = true;
      _videos.clear(); // Clear videos on refresh
    }

    if (!_hasMoreVideos || _isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final newVideos = await RemoteLoader.list<ExploreVideo>(
        label: 'explore.videos.page$_currentPage',
        seed: const [], // Added missing seed parameter
        fetch: () => _repository.fetchExploreVideos(page: _currentPage),
      );

      if (!mounted) return;

      setState(() {
        _videos.addAll(newVideos.data);
        _currentPage++;
        // Assuming the API returns an empty list if no more videos are available
        _hasMoreVideos = newVideos.data.isNotEmpty;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent &&
        !_isLoadingMore &&
        _hasMoreVideos) {
      _load();
    }
  }

  void _openVideo(ExploreVideo video) {
    final int index = _videos.indexWhere(
      (item) => item.id == video.id,
    );

    if (index == -1) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReelsViewer(
          videos: _videos,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            children: [
              const ExploreHeader(),
              SizedBox(height: 44.h),
              ExploreGrid(
                videos: _videos,
                onVideoTap: _openVideo,
              ),
              if (_isLoadingMore)
                Padding(
                  padding: EdgeInsets.all(16.h),
                  child: const CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
