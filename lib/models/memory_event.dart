/// 时光集内的一条纪念事件。
class MemoryEvent {
  const MemoryEvent({
    required this.id,
    required this.collectionId,
    required this.title,
    this.location,
    required this.date,
    this.photoPaths = const [],
  });

  final String id;
  final String collectionId;
  final String title;
  final String? location;
  final DateTime date;
  final List<String> photoPaths;

  MemoryEvent copyWith({
    String? id,
    String? collectionId,
    String? title,
    String? location,
    DateTime? date,
    List<String>? photoPaths,
  }) {
    return MemoryEvent(
      id: id ?? this.id,
      collectionId: collectionId ?? this.collectionId,
      title: title ?? this.title,
      location: location ?? this.location,
      date: date ?? this.date,
      photoPaths: photoPaths ?? this.photoPaths,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'collectionId': collectionId,
    'title': title,
    'location': location,
    'date': date.toIso8601String(),
    'photoPaths': photoPaths,
  };

  factory MemoryEvent.fromJson(Map<String, dynamic> json) {
    final pathsRaw = json['photoPaths'];
    List<String> paths = const [];
    if (pathsRaw is List) {
      paths = pathsRaw.map((e) => e.toString()).toList();
    }
    return MemoryEvent(
      id: json['id'] as String,
      collectionId: json['collectionId'] as String,
      title: json['title'] as String,
      location: json['location'] as String?,
      date: DateTime.parse(json['date'] as String),
      photoPaths: paths,
    );
  }
}
