class ShareContact {
  ShareContact({required this.name, required this.phone});

  final String name;
  final String phone;

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone};

  factory ShareContact.fromJson(Map<String, dynamic> m) {
    final phoneRaw = m['phone'];
    final phoneStr = phoneRaw is int
        ? '$phoneRaw'
        : (phoneRaw as String? ?? '');
    return ShareContact(
      name: m['name']?.toString() ?? '',
      phone: phoneStr,
    );
  }
}
