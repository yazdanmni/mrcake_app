import '../models/recipe.dart';

class RecipesData {
  RecipesData._();

  static const List<Recipe> recipes = [
    Recipe(
      id: 1,
      teacherId: 1,
      title: 'کیک شکلاتی حرفه‌ای',
      image:
          'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=900',
      description:
          'یک کیک شکلاتی نرم و خوشمزه که برای مهمانی‌ها و مناسبت‌های مختلف انتخاب بسیار خوبی است.',
      difficulty: 'medium',
      ingredients: [
        RecipeIngredient(
          name: 'آرد',
          amount: '۲ پیمانه',
        ),
        RecipeIngredient(
          name: 'شکر',
          amount: '۱ پیمانه',
        ),
        RecipeIngredient(
          name: 'تخم مرغ',
          amount: '۳ عدد',
        ),
        RecipeIngredient(
          name: 'پودر کاکائو',
          amount: '۳ قاشق غذاخوری',
        ),
      ],
      steps: [
        'فر را روی دمای ۱۸۰ درجه روشن کنید.',
        'تخم مرغ و شکر را با همزن به خوبی مخلوط کنید.',
        'آرد و پودر کاکائو را الک کرده و به مواد اضافه کنید.',
        'مواد را داخل قالب بریزید.',
        'قالب را داخل فر قرار دهید و اجازه دهید کیک کاملاً بپزد.',
      ],
    ),
    Recipe(
      id: 2,
      teacherId: 2,
      title: 'چیزکیک توت‌فرنگی',
      image:
          'https://images.unsplash.com/photo-1565958011703-44f9829ba187?w=900',
      description:
          'چیزکیک توت‌فرنگی یکی از دسرهای محبوب و خوش‌طعم است که بافتی لطیف و ظاهری زیبا دارد.',
      difficulty: 'easy',
      ingredients: [
        RecipeIngredient(
          name: 'بیسکویت',
          amount: '۲۰۰ گرم',
        ),
        RecipeIngredient(
          name: 'پنیر خامه‌ای',
          amount: '۴۰۰ گرم',
        ),
        RecipeIngredient(
          name: 'خامه',
          amount: '۲۰۰ گرم',
        ),
        RecipeIngredient(
          name: 'توت‌فرنگی',
          amount: '۳۰۰ گرم',
        ),
      ],
      steps: [
        'بیسکویت‌ها را کاملاً خرد کنید.',
        'کره آب شده را به بیسکویت اضافه کنید.',
        'مواد را کف قالب به صورت یکدست پخش کنید.',
        'پنیر خامه‌ای و خامه را مخلوط کنید.',
        'مواد را روی پایه بیسکویتی بریزید.',
        'چیزکیک را برای چند ساعت داخل یخچال قرار دهید.',
      ],
    ),
    Recipe(
      id: 3,
      teacherId: 3,
      title: 'کوکی شکلات چیپسی',
      image:
          'https://images.unsplash.com/photo-1499636136210-6f4ee915583e?w=900',
      description:
          'کوکی شکلات چیپسی ترد و خوشمزه با مغز نرم، گزینه‌ای عالی برای عصرانه و پذیرایی است.',
      difficulty: 'easy',
      ingredients: [
        RecipeIngredient(
          name: 'آرد',
          amount: '۲ پیمانه',
        ),
        RecipeIngredient(
          name: 'کره',
          amount: '۱۵۰ گرم',
        ),
        RecipeIngredient(
          name: 'شکر',
          amount: '۱ پیمانه',
        ),
        RecipeIngredient(
          name: 'شکلات چیپسی',
          amount: '۱۵۰ گرم',
        ),
      ],
      steps: [
        'کره و شکر را با همزن مخلوط کنید.',
        'تخم مرغ را اضافه کنید.',
        'آرد را کم‌کم به مواد اضافه کنید.',
        'شکلات چیپسی را داخل خمیر بریزید.',
        'خمیر را به شکل گلوله‌های کوچک درآورید.',
        'کوکی‌ها را داخل فر از قبل گرم شده قرار دهید.',
      ],
    ),
    Recipe(
      id: 4,
      teacherId: 1,
      title: 'براونی شکلاتی',
      image:
          'https://images.unsplash.com/photo-1564355808539-22fda35bed7e?w=900',
      description:
          'براونی شکلاتی با بافتی مرطوب و شکلاتی که برای دوستداران طعم شکلات انتخاب مناسبی است.',
      difficulty: 'hard',
      ingredients: [
        RecipeIngredient(
          name: 'شکلات تلخ',
          amount: '۲۰۰ گرم',
        ),
        RecipeIngredient(
          name: 'کره',
          amount: '۱۰۰ گرم',
        ),
        RecipeIngredient(
          name: 'شکر',
          amount: '۱ پیمانه',
        ),
        RecipeIngredient(
          name: 'آرد',
          amount: '۱ پیمانه',
        ),
      ],
      steps: [
        'شکلات و کره را به روش بن‌ماری ذوب کنید.',
        'شکر را اضافه کرده و مخلوط کنید.',
        'تخم مرغ‌ها را یکی یکی اضافه کنید.',
        'آرد را الک کرده و به مواد اضافه کنید.',
        'مواد را داخل قالب بریزید.',
        'براونی را در فر قرار دهید و پس از پخت اجازه دهید خنک شود.',
      ],
    ),
  ];
}