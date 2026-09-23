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
        final filteredNewRecipes = recipesResult.data
            .where((recipe) => recipe.featured == true && recipe.courseId == null)
            .toList();
        _recipes.addAll(filteredNewRecipes);
        _filteredRecipes = List.from(_recipes); // Update filtered list too
        _currentPage++;
        _hasMoreRecipes = filteredNewRecipes.isNotEmpty; // Check if there are any *filtered* new recipes
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

  SliverGrid _buildRecipesGrid() {
    if (_filteredRecipes.isEmpty) {
      return SliverGrid(
        delegate: SliverChildListDelegate([
          Center(
            child: Text(
              'رسپی‌ای پیدا نشد',
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'PinarB',
                fontSize: 17.sp,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ]),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 20.h,
          crossAxisSpacing: 14.w,
          childAspectRatio: .72,
        ),
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
