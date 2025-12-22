enum FileType {
  image,
  video,
  pdf,
  document,
  audio,
  other,
}

class FileModel {
  final String id;
  final String name;
  final String url;
  final String? localPath;
  final FileType type;
  final int size; // in bytes
  final String? thumbnailUrl;
  final DateTime? timestamp;

  FileModel({
    required this.id,
    required this.name,
    required this.url,
    this.localPath,
    required this.type,
    required this.size,
    this.thumbnailUrl,
    this.timestamp,
  });

  String get sizeFormatted {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  String get fileExtension {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toUpperCase() : '';
  }
}
