/// 时光集合（相册/游记聚合）。
class MemoryCollection {
  const MemoryCollection({
    required this.id,
    required this.name,
    required this.tagId,
    this.coverPhotoPath,
    this.isPinned = false,
    required this.createdAt,
    this.lastModifiedByName,
    this.lastModifiedAt,
  });

  final String id;
  final String name;
  final String tagId;
  final String? coverPhotoPath;
  final bool isPinned;
  final DateTime createdAt;
  /// 伴侣共享场景下最后修改者称呼。
  final String? lastModifiedByName;
  /// 伴侣共享场景下最后修改时间。
  final DateTime? lastModifiedAt;

  MemoryCollection copyWith({
    String? id,
    String? name,
    String? tagId,
    String? coverPhotoPath,
    bool? isPinned,
    DateTime? createdAt,
    String? lastModifiedByName,
    DateTime? lastModifiedAt,
    bool clearLastModifiedByName = false,
    bool clearLastModifiedAt = false,
  }) {
    return MemoryCollection(
      id: id ?? this.id,
      name: name ?? this.name,
      tagId: tagId ?? this.tagId,
      coverPhotoPath: coverPhotoPath ?? this.coverPhotoPath,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      lastModifiedByName: clearLastModifiedByName
          ? null
          : (lastModifiedByName ?? this.lastModifiedByName),
      lastModifiedAt:
          clearLastModifiedAt ? null : (lastModifiedAt ?? this.lastModifiedAt),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tagId': tagId,
    'coverPhotoPath': coverPhotoPath,
    'isPinned': isPinned,
    'createdAt': createdAt.toIso8601String(),
    if (lastModifiedByName != null && lastModifiedByName!.isNotEmpty)
      'lastModifiedByName': lastModifiedByName,
    if (lastModifiedAt != null)
      'lastModifiedAt': lastModifiedAt!.toIso8601String(),
  };

  factory MemoryCollection.fromJson(Map<String, dynamic> json) {
    return MemoryCollection(
      id: json['id'] as String,
      name: json['name'] as String,
      tagId: json['tagId'] as String,
      coverPhotoPath: json['coverPhotoPath'] as String?,
      isPinned: json['isPinned'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastModifiedByName: json['lastModifiedByName'] as String?,
      lastModifiedAt: json['lastModifiedAt'] != null
          ? DateTime.tryParse(json['lastModifiedAt'] as String)
          : null,
    );
  }
}
