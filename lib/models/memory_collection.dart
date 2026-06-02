/// 时光集合（相册/游记聚合）。
class MemoryCollection {
  const MemoryCollection({
    required this.id,
    required this.name,
    required this.tagId,
    this.coverPhotoPath,
    this.isPinned = false,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String tagId;
  final String? coverPhotoPath;
  final bool isPinned;
  final DateTime createdAt;

  MemoryCollection copyWith({
    String? id,
    String? name,
    String? tagId,
    String? coverPhotoPath,
    bool? isPinned,
    DateTime? createdAt,
  }) {
    return MemoryCollection(
      id: id ?? this.id,
      name: name ?? this.name,
      tagId: tagId ?? this.tagId,
      coverPhotoPath: coverPhotoPath ?? this.coverPhotoPath,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tagId': tagId,
    'coverPhotoPath': coverPhotoPath,
    'isPinned': isPinned,
    'createdAt': createdAt.toIso8601String(),
  };

  factory MemoryCollection.fromJson(Map<String, dynamic> json) {
    return MemoryCollection(
      id: json['id'] as String,
      name: json['name'] as String,
      tagId: json['tagId'] as String,
      coverPhotoPath: json['coverPhotoPath'] as String?,
      isPinned: json['isPinned'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
