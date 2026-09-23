import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/remote_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/course.dart';
import '../../../repositories/catalog_repository.dart';
import '../../home/widgets/course_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
  });

  @override
  State<SearchScreen> createState() =>
      _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const String _recentSearchesKey =
      'master_cake_recent_searches';

  final TextEditingController _searchController =
      TextEditingController();

  final FocusNode _searchFocusNode =
      FocusNode();

  List<String> _recentSearches = [];
  List<Course> _searchResults = [];

  bool _isSearching = false;

  /// منبع اصلی دوره‌ها — ابتدا داده‌های آفلاین، سپس پاسخ بک‌اند.
  List<Course> _courses = const [];

  Timer? _searchDebounce;

  /// شناسه آخرین درخواست تا پاسخ‌های قدیمی نتیجه جدید را خراب نکنند.
  int _searchRequestId = 0;

  @override
  void initState() {
    super.initState();

    _loadRecentSearches();
    _loadCourses();

    _searchController.addListener(
      _onSearchChanged,
    );
  }

  Future<void> _loadCourses() async {
    final result = await RemoteLoader.list<Course>(
      label: 'search.courses',
      fetch: CatalogRepository.instance.fetchCourses,
    );

    if (!mounted) return;
    setState(() => _courses = result.data);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();

    _searchController.removeListener(
      _onSearchChanged,
    );

    _searchController.dispose();
    _searchFocusNode.dispose();

    super.dispose();
  }

  // =========================================================
  // Recent Searches
  // =========================================================

  Future<void> _loadRecentSearches() async {
    final prefs =
        await SharedPreferences.getInstance();

    final saved =
        prefs.getStringList(
              _recentSearchesKey,
            ) ??
            [];

    if (!mounted) return;

    setState(() {
      _recentSearches = saved;
    });
  }

  Future<void> _saveRecentSearches() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setStringList(
      _recentSearchesKey,
      _recentSearches,
    );
  }

  Future<void> _addToRecentSearches(
    String value,
  ) async {
    final query = value.trim();

    if (query.isEmpty) return;

    final updated =
        List<String>.from(_recentSearches);

    updated.removeWhere(
      (item) =>
          _normalize(item) ==
          _normalize(query),
    );

    updated.insert(0, query);

    if (updated.length > 10) {
      updated.removeRange(
        10,
        updated.length,
      );
    }

    setState(() {
      _recentSearches = updated;
    });

    await _saveRecentSearches();
  }

  Future<void> _removeRecentSearch(
    String search,
  ) async {
    final updated =
        List<String>.from(_recentSearches);

    updated.remove(search);

    setState(() {
      _recentSearches = updated;
    });

    await _saveRecentSearches();
  }

  Future<void> _clearRecentSearches() async {
    setState(() {
      _recentSearches = [];
    });

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove(
      _recentSearchesKey,
    );
  }

  // =========================================================
  // Search
  // =========================================================

  void _onSearchChanged() {
    final query =
        _searchController.text.trim();

    _searchDebounce?.cancel();

    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });

      return;
    }

    _searchDebounce = Timer(
      const Duration(milliseconds: 400),
      () {
        _performSearch(query);
      },
    );
  }

  /// نتیجه محلی فوراً نمایش داده می‌شود و سپس با پاسخ بک‌اند جایگزین می‌شود.
  Future<void> _performSearch(
    String query,
  ) async {
    final requestId = ++_searchRequestId;

    setState(() {
      _isSearching = true;
      _searchResults = []; // Clear local results as we fetch from API
    });

    final result = await RemoteLoader.list<Course>(
      label: 'search.query',
      fetch: () => CatalogRepository.instance.fetchCourses(
        search: query,
      ),
    );

    // درخواست قدیمی نباید نتیجه جدیدتر را بازنویسی کند.
    if (!mounted || requestId != _searchRequestId) return;

    setState(() => _searchResults = result.data);
  }

  String _normalize(
    String value,
  ) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ي', 'ی')
        .replaceAll('ى', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll('ة', 'ه')
        .replaceAll('ۀ', 'ه')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ی');
  }

  Future<void> _submitSearch(
    String value,
  ) async {
    final query = value.trim();

    if (query.isEmpty) return;

    await _addToRecentSearches(
      query,
    );

    _searchFocusNode.unfocus();

    _performSearch(query);
  }

  void _selectRecentSearch(
    String search,
  ) {
    _searchController.text = search;

    _searchController.selection =
        TextSelection.fromPosition(
      TextPosition(
        offset:
            _searchController.text.length,
      ),
    );

    _performSearch(search);

    _searchFocusNode.unfocus();
  }

  void _clearSearch() {
    _searchController.clear();

    setState(() {
      _isSearching = false;
      _searchResults = [];
    });

    _searchFocusNode.requestFocus();
  }

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior
                  .onDrag,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.only(
                top: 20.h,
                left: 25.w,
                right: 25.w,
              ),
              sliver:
                  SliverToBoxAdapter(
                child: _buildHeader(),
              ),
            ),

            SliverPadding(
              padding: EdgeInsets.only(
                top: 18.h,
                left: 25.w,
                right: 25.w,
              ),
              sliver:
                  SliverToBoxAdapter(
                child:
                    _buildSearchField(),
              ),
            ),

            if (_isSearching) ...[
              SliverPadding(
                padding: EdgeInsets.only(
                  top: 28.h,
                  left: 25.w,
                  right: 25.w,
                ),
                sliver:
                    SliverToBoxAdapter(
                  child:
                      _buildResultsHeader(),
                ),
              ),

              _buildSearchResults(),
            ],

            if (!_isSearching &&
                _recentSearches.isNotEmpty)
              SliverPadding(
                padding:
                    EdgeInsets.symmetric(
                  horizontal: 25.w,
                ),
                sliver:
                    SliverToBoxAdapter(
                  child:
                      _buildRecentSearches(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Align(
      alignment:
          Alignment.centerRight,
      child: Text(
        'جستجو',
        textDirection:
            TextDirection.rtl,
        style: TextStyle(
          fontFamily: 'PinarB',
          fontSize: 24.sp,
          fontWeight:
              FontWeight.w700,
          color:
              AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    final hasText =
        _searchController.text
            .trim()
            .isNotEmpty;

    return Container(
      height: 56.h,
      decoration:
          BoxDecoration(
        color: AppColors.field,
        borderRadius:
            BorderRadius.circular(
          17.r,
        ),
        border: Border.all(
          color:
              AppColors.border,
          width: 1,
        ),
      ),
      child: TextField(
        controller:
            _searchController,
        focusNode:
            _searchFocusNode,
        textDirection:
            TextDirection.rtl,
        textInputAction:
            TextInputAction.search,
        onSubmitted:
            _submitSearch,
        style: TextStyle(
          fontFamily:
              'bshabnam',
          fontSize: 14.sp,
          color:
              AppColors.textPrimary,
        ),
        decoration:
            InputDecoration(
          border:
              InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 16.h,
          ),
          hintText:
              'چی دوست داری یاد بگیری؟',
          hintTextDirection:
              TextDirection.rtl,
          hintStyle:
              TextStyle(
            fontFamily:
                'bshabnam',
            fontSize: 14.sp,
            color:
                AppColors
                    .textSecondary,
          ),
          prefixIcon:
              Icon(
            Icons.search_rounded,
            size: 24.sp,
            color:
                AppColors
                    .textSecondary,
          ),
          suffixIcon:
              hasText
                  ? IconButton(
                      onPressed:
                          _clearSearch,
                      icon:
                          Icon(
                        Icons
                            .close_rounded,
                        size: 21.sp,
                        color:
                            AppColors
                                .textSecondary,
                      ),
                    )
                  : null,
        ),
      ),
    );
  }

  Widget _buildRecentSearches() {
    return Padding(
      padding:
          EdgeInsets.only(
        top: 28.h,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .stretch,
        children: [
          Row(
            textDirection:
                TextDirection.rtl,
            children: [
              Expanded(
                child: Text(
                  'جستجوهای اخیر',
                  textDirection:
                      TextDirection
                          .rtl,
                  style:
                      TextStyle(
                    fontFamily:
                        'PinarB',
                    fontSize: 17.sp,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        AppColors
                            .textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap:
                    _clearRecentSearches,
                child:
                    Text(
                  'پاک کردن همه',
                  textDirection:
                      TextDirection
                          .rtl,
                  style:
                      TextStyle(
                    fontFamily:
                        'bshabnam',
                    fontSize: 12.sp,
                    color:
                        AppColors
                            .primary,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(
            height: 14.h,
          ),

          Wrap(
            spacing: 8.w,
            runSpacing: 10.h,
            alignment:
                WrapAlignment.start,
            children:
                _recentSearches
                    .map(
              (search) {
                return _buildRecentChip(
                  search,
                );
              },
            ).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentChip(
    String search,
  ) {
    return Material(
      color:
          Colors.transparent,
      child: InkWell(
        borderRadius:
            BorderRadius.circular(
          30.r,
        ),
        onTap: () =>
            _selectRecentSearch(
          search,
        ),
        child: Container(
          padding:
              EdgeInsets.symmetric(
            horizontal: 13.w,
            vertical: 9.h,
          ),
          decoration:
              BoxDecoration(
            color:
                AppColors.field,
            borderRadius:
                BorderRadius.circular(
              30.r,
            ),
            border:
                Border.all(
              color:
                  AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize:
                MainAxisSize.min,
            textDirection:
                TextDirection.rtl,
            children: [
              GestureDetector(
                onTap: () =>
                    _removeRecentSearch(
                  search,
                ),
                child:
                    Icon(
                  Icons
                      .close_rounded,
                  size: 16.sp,
                  color: AppColors
                      .textSecondary,
                ),
              ),

              SizedBox(
                width: 7.w,
              ),

              Icon(
                Icons
                    .history_rounded,
                size: 17.sp,
                color: AppColors
                    .textSecondary,
              ),

              SizedBox(
                width: 6.w,
              ),

              Text(
                search,
                textDirection:
                    TextDirection
                        .rtl,
                style:
                    TextStyle(
                  fontFamily:
                      'bshabnam',
                  fontSize: 12.sp,
                  color:
                      AppColors
                          .textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsHeader() {
    return Row(
      textDirection:
          TextDirection.rtl,
      children: [
        Text(
          'نتایج جستجو',
          textDirection:
              TextDirection.rtl,
          style: TextStyle(
            fontFamily:
                'PinarB',
            fontSize: 18.sp,
            fontWeight:
                FontWeight.w700,
            color:
                AppColors
                    .textPrimary,
          ),
        ),

        SizedBox(
          width: 8.w,
        ),

        Container(
          padding:
              EdgeInsets.symmetric(
            horizontal: 8.w,
            vertical: 3.h,
          ),
          decoration:
              BoxDecoration(
            color: AppColors
                .primary
                .withValues(alpha: .10),
            borderRadius:
                BorderRadius.circular(
              8.r,
            ),
          ),
          child: Text(
            '${_searchResults.length}',
            style:
                TextStyle(
              fontFamily:
                  'bshabnam',
              fontSize: 11.sp,
              fontWeight:
                  FontWeight.w700,
              color:
                  AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding:
                EdgeInsets.symmetric(
              horizontal: 30.w,
            ),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Container(
                  width: 72.w,
                  height: 72.w,
                  decoration:
                      BoxDecoration(
                    color:
                        AppColors.field,
                    shape:
                        BoxShape.circle,
                  ),
                  child:
                      Icon(
                    Icons
                        .search_off_rounded,
                    size: 34.sp,
                    color: AppColors
                        .textSecondary,
                  ),
                ),

                SizedBox(
                  height: 18.h,
                ),

                Text(
                  'دوره‌ای پیدا نشد',
                  textDirection:
                      TextDirection.rtl,
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    fontFamily:
                        'PinarB',
                    fontSize: 18.sp,
                    fontWeight:
                        FontWeight.w700,
                    color: AppColors
                        .textPrimary,
                  ),
                ),

                SizedBox(
                  height: 8.h,
                ),

                Text(
                  'عبارت دیگری را جستجو کن.',
                  textDirection:
                      TextDirection.rtl,
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    fontFamily:
                        'bshabnam',
                    fontSize: 13.sp,
                    color: AppColors
                        .textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding:
          EdgeInsets.only(
        top: 18.h,
        left: 25.w,
        right: 25.w,
        bottom: 30.h,
      ),
      sliver: SliverList(
        delegate:
            SliverChildBuilderDelegate(
          (
            context,
            index,
          ) {
            final Course course =
                _searchResults[index];

            final double cardWidth =
                _getCardWidth(context);

            final double cardHeight =
                cardWidth * 267 / 180;

            return Padding(
              padding:
                  EdgeInsets.only(
                bottom: 16.h,
              ),
              child: CourseCard(
                course: course,
                width: cardWidth,
                height: cardHeight,
                onTap: () {
                  // بعداً صفحه جزئیات دوره
                  // اینجا متصل می‌شود.
                },
              ),
            );
          },
          childCount:
              _searchResults.length,
        ),
      ),
    );
  }

  double _getCardWidth(
    BuildContext context,
  ) {
    final width =
        MediaQuery.sizeOf(context).width;

    if (width <= 320) return 145;
    if (width <= 360) return 155;
    if (width <= 390) return 165;
    if (width <= 430) return 175;

    return 185;
  }
}