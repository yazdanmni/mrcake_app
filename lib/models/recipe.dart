class Recipe {
  final int id;
  final int teacherId;

  final String title;
  final String image;
  final String description;

  final List<RecipeIngredient> ingredients;
  final List<String> steps;

  /// easy | medium | hard
  final String difficulty;

  const Recipe({
    required this.id,
    required this.teacherId,
    required this.title,
    required this.image,
    required this.description,
    required this.ingredients,
    required this.steps,
    required this.difficulty,
  });

  int get readingTime {
    final String content = [
      title,
      description,
      ...ingredients.map(
        (item) => '${item.name} ${item.amount}',
      ),
      ...steps,
    ].join(' ');

    final int wordCount = content
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;

    final int minutes = (wordCount / 180).ceil();

    return minutes < 1 ? 1 : minutes;
  }

  String get difficultyTitle {
    switch (difficulty) {
      case 'easy':
        return 'آسان';
      case 'hard':
        return 'سخت';
      case 'medium':
      default:
        return 'متوسط';
    }
  }
}

class RecipeIngredient {
  final String name;
  final String amount;

  const RecipeIngredient({
    required this.name,
    required this.amount,
  });
}