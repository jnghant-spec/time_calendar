/// 事件集与子事件的多对多关联。
class CollectionSubEvent {
  const CollectionSubEvent({
    required this.id,
    required this.collectionId,
    required this.subEventId,
    required this.sortOrder,
    required this.addedAt,
  });

  final String id;
  final String collectionId;
  final String subEventId;
  final int sortOrder;
  final DateTime addedAt;

  CollectionSubEvent copyWith({
    String? id,
    String? collectionId,
    String? subEventId,
    int? sortOrder,
    DateTime? addedAt,
  }) {
    return CollectionSubEvent(
      id: id ?? this.id,
      collectionId: collectionId ?? this.collectionId,
      subEventId: subEventId ?? this.subEventId,
      sortOrder: sortOrder ?? this.sortOrder,
      addedAt: addedAt ??
          DateTime.fromMillisecondsSinceEpoch(
            this.addedAt.millisecondsSinceEpoch,
          ),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'collectionId': collectionId,
        'subEventId': subEventId,
        'sortOrder': sortOrder,
        'addedAt': addedAt.millisecondsSinceEpoch,
      };

  factory CollectionSubEvent.fromJson(Map<String, dynamic> json) {
    return CollectionSubEvent(
      id: json['id'] as String,
      collectionId: json['collectionId'] as String,
      subEventId: json['subEventId'] as String,
      sortOrder: json['sortOrder'] as int? ?? 0,
      addedAt: DateTime.fromMillisecondsSinceEpoch(
        json['addedAt'] as int? ??
            DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
