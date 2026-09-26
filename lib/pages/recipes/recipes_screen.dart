import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mr_cake_project/models/teacher_model.dart';
import 'package:mr_cake_project/pages/recipes/recipe_detail_screen.dart';
import 'package:mr_cake_project/repositories/catalog_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/remote_data.dart';
import '../../core/theme/app_colors.dart';
import '../../models/recipe.dart';

/// «رسپی‌ها» — the standalone recipe library.
///
/// Two rules define this screen:
///
///  1. **Only recipes that belong to no course.** A recipe with a `course` is
///     part of what that course teaches, so it is filtered out (see
///     [_RecipesScreenState._loadRecipes]);
///  2. it is never a bottom-navigation tab — it is opened from the home
///     «رسپی‌ها» shortcut — so it always shows a back button.
///
/// Every dimension goes through ScreenUtil, so the two-column grid and the
/// cards scale with the device instead of overflowing.
class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  static const String _recentSearchesKey = 'master_cake_recipe_recent_searches';

  final TextEditingController _searchController = TextEditingController();

  final FocusNode _searchFocusNode = FocusNode();

  Timer? _searchDebounce;

  List<String> _recentSearches = [];

  List<Recipe> _filteredRecipes = [];

  bool _isSearching = false;

  List<Recipe> _recipes = []; // Changed to empty list

  List<Teacher> _teachers = []; // Changed to empty list

  /// Pagination for recipes
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMoreRecipes = true;

  /// How many pages have come back from the backend so far.
  ///
  /// [_hasMoreRecipes] starts `true` and is only corrected after a response, so
  /// on its own it cannot tell "nothing loaded yet" from "the backend has more
  /// pages but every row so far belonged to a course". This counter is what
  /// separates the two.
  int _loadedPages = 0;

  /// شناسه آخرین درخواست تا پاسخ‌های قدیمی نتیجه جدید را خراب نکنند.
  int _searchRequestId = 0;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _loadRecentSearches();
    _loadRecipes(refresh: true); // Initial load with refresh

    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadRecipes({bool refresh = false, String? searchQuery}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMoreRecipes = true;
      _loadedPages = 0;
      _recipes.clear();
      _filteredRecipes.clear();
    }

    if (!_hasMoreRecipes || _isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      // Fetch recipes
      final recipesResult = await RemoteLoader.list<Recipe>(
        label: 'recipes.list.page$_currentPage',
        seed: const [], // Added missing seed parameter
        fetch: () => CatalogRepository.instance.fetchRecipes(page: _currentPage, search: searchQuery),
      );

      // Fetch teachers (only once or on refresh, as they are not paginated per recipe fetch)
      if (refresh) {
        final teachersResult = await RemoteLoader.list<Teacher>(
          label: 'recipes.teachers',
          seed: const [], // Added missing seed parameter
          fetch: CatalogRepository.instance.fetchTeachers,
        );
        if (mounted) {
          setState(() {
            _teachers = teachersResult.data;
          });
        }
      }

      if (!mounted) return;

      setState(() {
        // Only **standalone** recipes belong on this screen. A recipe whose
        // `course` is set is part of a course — it is taught inside that
        // course, so listing it here would hand out what the course sells.
        //
        // The API cannot express "course is empty" (its filters are `course`,
        // `category`, `featured`, `difficulty`, `is_active` — no `course__isnull`),
        // so the exclusion is done here. `RecipeList.course` is a plain
        // nullable id, which is what `Recipe.courseId` parses.
        //
        // The filter is applied on **every** page, not just on refresh, and it
        // is applied to `_recipes` (the accumulated set) so a refresh cannot
        // leave course recipes behind.
        _recipes.addAll(
          recipesResult.data.where((Recipe recipe) => recipe.courseId == null),
        );
        _filteredRecipes = List<Recipe>.from(_recipes);

        // Advance on what the *backend* returned, not on what survived the
        // filter: a page whose every row belongs to a course would otherwise
        // look like the end of the list and silently hide the pages after it.
        _loadedPages++;
        _currentPage++;
        _hasMoreRecipes = recipesResult.data.isNotEmpty;
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
        _hasMoreRecipes) {
      _loadRecipes(searchQuery: _searchController.text.trim());
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();

    _searchController.removeListener(_onSearchChanged);
    _scrollController.removeListener(_onScroll);

    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();

    final saved = prefs.getStringList(_recentSearchesKey) ?? [];

    if (!mounted) return;

    setState(() {
      _recentSearches = saved;
    });
  }

  Future<void> _saveRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(_recentSearchesKey, _recentSearches);
  }

  Future<void> _addToRecentSearches(String value) async {
    final query = value.trim();

    if (query.isEmpty) return;

    final updated = List<String>.from(_recentSearches);

    updated.removeWhere((item) => _normalize(item) == _normalize(query));

    updated.insert(0, query);

    if (updated.length > 10) {
      updated.removeRange(10, updated.length);
    }

    setState(() {
      _recentSearches = updated;
    });

    await _saveRecentSearches();
  }

  Future<void> _removeRecentSearch(String value) async {
    final updated = List<String>.from(_recentSearches);

    updated.remove(value);

    setState(() {
      _recentSearches = updated;
    });

    await _saveRecentSearches();
  }

  Future<void> _clearRecentSearches() async {
    setState(() {
      _recentSearches = [];
    });

    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_recentSearchesKey);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      _searchDebounce?.cancel();

      setState(() {
        _isSearching = false;
        _filteredRecipes = List<Recipe>.from(_recipes);
      });

      return;
    }

    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _performSearch(query);
    });
  }

  /// نتیجه محلی فوراً نمایش داده می‌شود و سپس با پاسخ بک‌اند جایگزین می‌شود.
  Future<void> _performSearch(String query) async {
    final normalizedQuery = _normalize(query);

    // Local filtering (optional, can be removed if API handles all filtering)
    final localResults = _recipes.where((recipe) {
      final title = _normalize(recipe.title);

      final description = _normalize(recipe.description);

      final teacher = _getTeacher(recipe.teacherId);

      final teacherName = teacher == null ? '' : _normalize(teacher.fullName);

      return title.contains(normalizedQuery) ||
          description.contains(normalizedQuery) ||
          teacherName.contains(normalizedQuery);
    }).toList();

    final requestId = ++_searchRequestId;

    if (!mounted) return;

    setState(() {
      _isSearching = true;
      _filteredRecipes = localResults;
    });

    // Fetch from API with search query, refresh to get first page of search results
    await _loadRecipes(refresh: true, searchQuery: query);

    // Old request should not overwrite newer results (still relevant if API response is slow)
    if (!mounted || requestId != _searchRequestId) return;

    // _filteredRecipes is already updated by _loadRecipes
  }

  String _normalize(String value) {
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

  Future<void> _submitSearch(String value) async {
    final query = value.trim();

    if (query.isEmpty) return;

    await _addToRecentSearches(query);

    _searchFocusNode.unfocus();

    _performSearch(query);
  }

  void _selectRecentSearch(String value) {
    _searchController.text = value;

    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: value.length),
    );

    _performSearch(value);

    _searchFocusNode.unfocus();
  }

  void _clearSearch() {
    _searchController.clear();

    setState(() {
      _isSearching = false;
      _filteredRecipes = List<Recipe>.from(_recipes);
    });

    _searchFocusNode.requestFocus();
  }

  Teacher? _getTeacher(int teacherId) {
    for (final teacher in _teachers) {
      if (teacher.id == teacherId) {
        return teacher;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),

            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 25.w),
              sliver: SliverToBoxAdapter(child: _buildSearchField()),
            ),

            if (!_isSearching && _recentSearches.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 25.w),
                sliver: SliverToBoxAdapter(child: _buildRecentSearches()),
              ),

            SliverPadding(
              padding: EdgeInsets.only(
                top: 40.h,
                left: 25.w,
                right: 25.w,
                bottom: 30.h,
              ),
              sliver: _buildRecipesGrid(),
            ),
            if (_isLoadingMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16.h),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.only(
        left: 25.w,
        right: 25.w,
        top: 18.h,
        bottom: 18.h,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        textDirection: TextDirection.rtl,
        children: [
          Text(
            'رسپی ها',
            style: TextStyle(
              fontFamily: 'pinarb',
              fontSize: 20.sp,
              color: AppColors.textPrimary,
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.of(context).pop();
            },
            child: Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: AppColors.premium.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: AppColors.premium, width: 1.5.w),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_back_ios_rounded,
                size: 19.sp,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    final hasText = _searchController.text.trim().isNotEmpty;

    return Container(
      height: 56.h,
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(17.r),
        border: Border.all(color: AppColors.border, width: 2.w),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        textDirection: TextDirection.rtl,
        textInputAction: TextInputAction.search,
        onSubmitted: _submitSearch,
        style: TextStyle(
          fontFamily: 'bShabnam',
          fontSize: 14.sp,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 17.h,
          ),
          hintText: 'جستجو در رسپی ها',
          hintTextDirection: TextDirection.rtl,
          hintStyle: TextStyle(
            fontFamily: 'bShabnam',
            fontSize: 13.sp,
            color: AppColors.textSecondary,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.only(right: 14.w, left: 4.w),
            child: Icon(
              Icons.search_rounded,
              size: 23.sp,
              color: AppColors.textSecondary,
            ),
          ),
          suffixIcon: hasText
              ? IconButton(
                  onPressed: _clearSearch,
                  splashRadius: 20.r,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20.sp,
                    color: AppColors.textSecondary,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildRecentSearches() {
    return Padding(
      padding: EdgeInsets.only(top: 28.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: Text(
                  'جستجوهای اخیر',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'PinarB',
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _clearRecentSearches,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 5.h, horizontal: 3.w),
                  child: Text(
                    'پاک کردن',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontFamily: 'bShabnam',
                      fontSize: 11.sp,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 9.h,
            children: _recentSearches.map((search) {
              return _buildRecentChip(search);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentChip(String search) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectRecentSearch(search),
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
          decoration: BoxDecoration(
            color: AppColors.field,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _removeRecentSearch(search),
                child: Icon(
                  Icons.close_rounded,
                  size: 15.sp,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(width: 6.w),
              Icon(
                Icons.history_rounded,
                size: 16.sp,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 6.w),
              Text(
                search,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'bShabnam',
                  fontSize: 12.sp,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecipesGrid() {
    if (_filteredRecipes.isEmpty) {
      // Still fetching: the spinner further down the sliver list is the whole
      // story, so show nothing rather than flashing an empty state.
      //
      // The same holds while the backend still has pages left: with the
      // course-recipes filter applied client-side, page 1 can be *entirely*
      // course recipes while page 2 holds the standalone ones. Declaring the
      // library empty here would be a lie — keep loading instead.
      if (_isLoadingMore || (_hasMoreRecipes && _recipes.isEmpty && _loadedPages == 0)) {
        return const SliverToBoxAdapter();
      }

      // A search that matched nothing deserves a different sentence from a
      // library that is genuinely empty.
      return SliverToBoxAdapter(
        child: _searchController.text.trim().isEmpty
            ? _buildEmptyState()
            : _buildNoResults(),
      );
    }

    return SliverGrid(
      delegate: SliverChildBuilderDelegate((context, index) {
        final recipe = _filteredRecipes[index];

        final teacher = _getTeacher(recipe.teacherId);

        return _RecipeCard(
          recipe: recipe,
          teacher: teacher,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RecipeDetailScreen(recipeId: recipe.id),
              ),
            );
          },
        );
      }, childCount: _filteredRecipes.length),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 24.h,
        crossAxisSpacing: 14.w,
        childAspectRatio: .67,
      ),
    );
  }

  /// Shown when the standalone library itself is empty.
  ///
  /// Same shape as the empty state the courses screens use — an icon over a
  /// centred line — so «رسپی‌ها» reads like the rest of the app instead of a
  /// bare sentence floating inside a grid cell.
  Widget _buildEmptyState() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w, vertical: 50.h),
      child: Column(
        children: [
          Icon(
            Icons.restaurant_menu_outlined,
            size: 52.sp,
            color: AppColors.premium,
          ),
          SizedBox(height: 15.h),
          Text(
            'هنوز رسپی مستقلی اضافه نشده. 🍰\n\nرسپی‌هایی که به هیچ دوره‌ای وصل نیستن اینجا نمایش داده می‌شن.\n\nبه‌زودی رسپی‌های خوشمزه‌ی جدید اینجا منتظرت می‌مونن!',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'bshabnam',
              fontSize: 16.sp,
              color: AppColors.textPrimary,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }

  /// Shown when a search matched nothing — the library may well have recipes.
  Widget _buildNoResults() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 25.w, vertical: 50.h),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 52.sp,
            color: AppColors.premium,
          ),
          SizedBox(height: 15.h),
          Text(
            'رسپی‌ای پیدا نشد',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontFamily: 'bshabnam',
              fontSize: 16.sp,
              color: AppColors.textPrimary,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final Teacher? teacher;
  final VoidCallback onTap;

  const _RecipeCard({
    required this.recipe,
    required this.teacher,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: TextDirection.rtl,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18.r),
            child: AspectRatio(
              aspectRatio: 172 / 79,
              child: Image.network(
                recipe.image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Container(
                    color: AppColors.field,
                    child: Icon(
                      Icons.image_outlined,
                      color: AppColors.textSecondary,
                    ),
                  );
                },
              ),
            ),
          ),

          SizedBox(height: 10.h),

          Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipOval(
                child: Image.network(
                  teacher?.profileImage ?? '',
                  width: 31.w,
                  height: 31.w,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Container(
                      width: 31.w,
                      height: 31.w,
                      color: AppColors.field,
                      child: Icon(
                        Icons.person_rounded,
                        size: 18.sp,
                        color: AppColors.textSecondary,
                      ),
                    );
                  },
                ),
              ),

              SizedBox(width: 8.w),

              Expanded(
                child: Text(
                  recipe.title,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'bShabnam',
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 10.h),

          Text(
            teacher == null ? 'استاد' : 'استاد ${teacher!.lastName}',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Shabnam',
              fontSize: 16.sp,
              color: AppColors.textSecondary,
            ),
          ),

          SizedBox(height: 10.h),

          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            textDirection: TextDirection.rtl,
            children: [
              Text(
                '${recipe.readingTime} دقیقه',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Shabnam',
                  fontSize: 16.sp,
                  color: AppColors.textSecondary,
                ),
              ),

              SizedBox(width: 8.w),

              Container(
                width: 4.w,
                height: 4.w,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary,
                  shape: BoxShape.circle,
                ),
              ),

              SizedBox(width: 8.w),

              Text(
                recipe.difficultyTitle,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: 'Shabnam',
                  fontSize: 16.sp,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
