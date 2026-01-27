/// Utility functions for avatar display
class AvatarUtils {
  AvatarUtils._();

  /// Get initials from a name or username
  /// 
  /// Examples:
  /// - "John Doe" -> "JD"
  /// - "john_doe" -> "JD"
  /// - "john" -> "J"
  /// - "user_123" -> "U"
  static String getInitials(String? name) {
    if (name == null || name.isEmpty) {
      return '?';
    }

    // Remove underscores and split by spaces or underscores
    final cleaned = name.trim();
    if (cleaned.isEmpty) return '?';

    // Split by spaces or underscores
    final parts = cleaned.split(RegExp(r'[\s_]+')).where((p) => p.isNotEmpty).toList();

    if (parts.isEmpty) return '?';

    if (parts.length == 1) {
      // Single word - take first character
      return parts[0][0].toUpperCase();
    } else {
      // Multiple words - take first character of first two words
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
  }

  /// Get color for avatar based on name (deterministic)
  static int getColorForName(String? name) {
    if (name == null || name.isEmpty) {
      return 0xFF137FEC; // Default primary color
    }

    // Generate a color based on the name hash
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }

    // Generate a color from the hash
    final hue = hash.abs() % 360;
    return _hsvToRgb(hue / 360, 0.7, 0.8);
  }

  /// Convert HSV to RGB (simplified)
  static int _hsvToRgb(double h, double s, double v) {
    final c = v * s;
    final x = c * (1 - ((h * 6) % 2 - 1).abs());
    final m = v - c;

    double r = 0, g = 0, b = 0;

    if (h < 1 / 6) {
      r = c; g = x; b = 0;
    } else if (h < 2 / 6) {
      r = x; g = c; b = 0;
    } else if (h < 3 / 6) {
      r = 0; g = c; b = x;
    } else if (h < 4 / 6) {
      r = 0; g = x; b = c;
    } else if (h < 5 / 6) {
      r = x; g = 0; b = c;
    } else {
      r = c; g = 0; b = x;
    }

    return ((r + m) * 255).toInt() << 16 |
           ((g + m) * 255).toInt() << 8 |
           ((b + m) * 255).toInt();
  }
}
