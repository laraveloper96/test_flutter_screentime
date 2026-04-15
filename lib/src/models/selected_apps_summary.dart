class SelectedAppsSummary {
  const SelectedAppsSummary({
    required this.applicationCount,
    required this.categoryCount,
    required this.webDomainCount,
  });

  final int applicationCount;
  final int categoryCount;
  final int webDomainCount;

  bool get hasSelection =>
      applicationCount > 0 || categoryCount > 0 || webDomainCount > 0;

  int get totalCount => applicationCount + categoryCount + webDomainCount;

  factory SelectedAppsSummary.fromMap(Map<Object?, Object?> map) {
    return SelectedAppsSummary(
      applicationCount: (map['applicationCount'] as num?)?.toInt() ?? 0,
      categoryCount: (map['categoryCount'] as num?)?.toInt() ?? 0,
      webDomainCount: (map['webDomainCount'] as num?)?.toInt() ?? 0,
    );
  }
}
