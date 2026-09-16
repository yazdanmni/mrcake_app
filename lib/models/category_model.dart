/// Category tile shown in the home grid.
class CategoryModel {
  final int id;
  final String title;
  final String? image;

  const CategoryModel({
    required this.id,
    required this.title,
    this.image,
  });
}