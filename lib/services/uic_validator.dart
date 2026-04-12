class UicValidator {
  static bool validateUicNumber(String uicNumber) {
    final cleanedNumber = uicNumber.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanedNumber.length != 12) {
      return false;
    }

    final baseNumber = cleanedNumber.substring(0, 11);
    final checkDigit = int.parse(cleanedNumber.substring(11, 12));

    int sum = 0;
    for (int i = 0; i < baseNumber.length; i++) {
      int digit = int.parse(baseNumber[i]);
      int multiplier = (i % 2 == 0) ? 2 : 1;
      int product = digit * multiplier;
      sum += (product > 9)
          ? (product
              .toString()
              .split('')
              .map(int.parse)
              .reduce((a, b) => a + b))
          : product;
    }

    int calculatedCheckDigit = (10 - (sum % 10)) % 10;

    return calculatedCheckDigit == checkDigit;
  }

  static String formatUicNumber(String number) {
    final cleaned = number.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length != 12) return number;

    // Formát: XX XX XXXX XXX-X
    return '${cleaned.substring(0, 2)} ${cleaned.substring(2, 4)} ${cleaned.substring(4, 8)} ${cleaned.substring(8, 11)}-${cleaned.substring(11)}';
  }
}
