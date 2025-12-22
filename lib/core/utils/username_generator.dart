import 'dart:math';

class UsernameGenerator {
  UsernameGenerator._();

  static final List<String> _adjectives = [
    'Cool', 'Swift', 'Bright', 'Bold', 'Sharp', 'Fast', 'Quick', 'Smart',
    'Wild', 'Calm', 'Brave', 'Wise', 'Neat', 'Fresh', 'Crisp', 'Smooth',
  ];

  static final List<String> _nouns = [
    'Tiger', 'Eagle', 'Wolf', 'Lion', 'Falcon', 'Hawk', 'Bear', 'Fox',
    'Storm', 'Thunder', 'Lightning', 'Blaze', 'Flame', 'Wave', 'River', 'Ocean',
  ];

  static final List<String> _numbers = ['123', '456', '789', '007', '42', '99', '88', '77'];

  static String generate() {
    final random = Random();
    final adjective = _adjectives[random.nextInt(_adjectives.length)];
    final noun = _nouns[random.nextInt(_nouns.length)];
    final number = _numbers[random.nextInt(_numbers.length)];

    final patterns = [
      '${adjective}_$noun',
      '${adjective}$noun',
      '$noun$number',
      '${adjective}_$number',
      '${adjective.toLowerCase()}_${noun.toLowerCase()}',
    ];

    return patterns[random.nextInt(patterns.length)];
  }
}
