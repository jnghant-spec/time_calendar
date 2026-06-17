enum PartnerStatus {
  none,
  pending,
  accepted,
}

/// 伴侣关系（持久化于 [TagService]）。
class PartnerRelation {
  const PartnerRelation({
    this.partnerContactId,
    this.status = PartnerStatus.none,
    this.partnerName,
  });

  final String? partnerContactId;
  final PartnerStatus status;
  /// 伴侣称呼。
  final String? partnerName;

  Map<String, dynamic> toJson() => {
        if (partnerContactId != null && partnerContactId!.isNotEmpty)
          'partnerContactId': partnerContactId,
        'status': status.name,
        if (partnerName != null && partnerName!.isNotEmpty)
          'partnerName': partnerName,
      };

  factory PartnerRelation.fromJson(Map<String, dynamic> m) {
    final statusRaw = m['status'] as String? ?? PartnerStatus.none.name;
    return PartnerRelation(
      partnerContactId: m['partnerContactId'] as String?,
      status: PartnerStatus.values.firstWhere(
        (e) => e.name == statusRaw,
        orElse: () => PartnerStatus.none,
      ),
      partnerName: m['partnerName'] as String?,
    );
  }

  PartnerRelation copyWith({
    String? partnerContactId,
    PartnerStatus? status,
    String? partnerName,
    bool clearPartnerContactId = false,
    bool clearPartnerName = false,
  }) {
    return PartnerRelation(
      partnerContactId: clearPartnerContactId
          ? null
          : (partnerContactId ?? this.partnerContactId),
      status: status ?? this.status,
      partnerName:
          clearPartnerName ? null : (partnerName ?? this.partnerName),
    );
  }
}
