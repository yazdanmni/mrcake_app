/// Input validation shared by every form of the app.
///
/// All messages are Persian so they can be handed straight to the UI.
class Validators {
  Validators._();

  static final RegExp _iranMobile = RegExp(r'^09\d{9}$');
  static final RegExp _email = RegExp(
    r"^[\w.!#$%&'*+/=?^`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?"
    r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$',
  );

  /// Keeps only the digits of a phone number, caps it at 11 characters and
  /// converts the Persian/Arabic digits users sometimes type.
  static String normalizePhone(String raw) {
    final buffer = StringBuffer();
    for (final rune in raw.runes) {
      final char = String.fromCharCode(rune);
      final persian = '۰۱۲۳۴۵۶۷۸۹'.indexOf(char);
      final arabic = '٠١٢٣٤٥٦٧٨٩'.indexOf(char);
      if (persian >= 0) {
        buffer.write(persian);
      } else if (arabic >= 0) {
        buffer.write(arabic);
      } else if (char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57) {
        buffer.write(char);
      }
    }
    final digits = buffer.toString();
    return digits.length > 11 ? digits.substring(0, 11) : digits;
  }

  /// Returns null when valid, otherwise the message to show under the field.
  static String? phone(String? value) {
    final phone = normalizePhone(value ?? '');
    if (phone.isEmpty) return 'شماره موبایل را وارد کنید.';
    if (phone.length < 11) return 'شماره موبایل باید ۱۱ رقم باشد.';
    if (!_iranMobile.hasMatch(phone)) {
      return 'شماره موبایل معتبر نیست. (مثال: ۰۹۱۲۳۴۵۶۷۸۹)';
    }
    return null;
  }

  static bool isPhoneValid(String? value) => phone(value) == null;

  /// The backend enforces `minLength: 6` on passwords.
  static String? password(String? value, {int minLength = 6}) {
    final password = value ?? '';
    if (password.isEmpty) return 'رمز عبور را وارد کنید.';
    if (password.length < minLength) {
      return 'رمز عبور باید حداقل $minLength کاراکتر باشد.';
    }
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    final confirm = value ?? '';
    if (confirm.isEmpty) return 'تکرار رمز عبور را وارد کنید.';
    if (confirm != original) return 'رمزهای عبور با یکدیگر مطابقت ندارند.';
    return null;
  }

  static String? otp(String? value, {int length = 4}) {
    final code = (value ?? '').trim();
    if (code.isEmpty) return 'کد تایید را وارد کنید.';
    if (code.length < length) return 'کد تایید باید $length رقم باشد.';
    return null;
  }

  static String? required(String? value, {required String label}) {
    if (value == null || value.trim().isEmpty) return '$label را وارد کنید.';
    return null;
  }

  static String? optionalEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return null;
    if (!_email.hasMatch(email)) return 'ایمیل وارد شده معتبر نیست.';
    return null;
  }

  /// A username has no spaces and is at least 3 characters long.
  static String? username(String? value) {
    final username = value?.trim() ?? '';
    if (username.isEmpty) return 'نام کاربری را وارد کنید.';
    if (username.length < 3) return 'نام کاربری باید حداقل ۳ کاراکتر باشد.';
    if (username.contains(' ')) return 'نام کاربری نباید فاصله داشته باشد.';
    return null;
  }
}
