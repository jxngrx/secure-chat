class PhoneFormatter {
  PhoneFormatter._();

  static String formatUSPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.length <= 3) {
      return digitsOnly;
    } else if (digitsOnly.length <= 6) {
      return '${digitsOnly.substring(0, 3)} ${digitsOnly.substring(3)}';
    } else {
      return '${digitsOnly.substring(0, 3)} ${digitsOnly.substring(3, 6)} ${digitsOnly.substring(6, digitsOnly.length > 10 ? 10 : digitsOnly.length)}';
    }
  }

  static String getUnformattedPhone(String formattedPhone) {
    return formattedPhone.replaceAll(RegExp(r'\D'), '');
  }

  static bool isValidPhoneNumber(String phoneNumber, String dialCode) {
    final digitsOnly = getUnformattedPhone(phoneNumber);
    // Basic validation - at least 7 digits, max 15 digits
    return digitsOnly.length >= 7 && digitsOnly.length <= 15;
  }
}
