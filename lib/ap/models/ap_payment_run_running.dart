class ApPaymentRunRunning {
  final int? id;
  final bool isAutoNumbering;
  final String formatPrefix;
  final String formatSeparator;
  final String formatSuffixDate;
  final int runningLength;
  final int nextRunningNumber;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const ApPaymentRunRunning({
    this.id,
    required this.isAutoNumbering,
    required this.formatPrefix,
    required this.formatSeparator,
    required this.formatSuffixDate,
    required this.runningLength,
    required this.nextRunningNumber,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory ApPaymentRunRunning.fromJson(Map<String, dynamic> json) => ApPaymentRunRunning(
        id: json['id'],
        isAutoNumbering: json['is_auto_numbering'] ?? true,
        formatPrefix: json['format_prefix'] ?? 'PR',
        formatSeparator: json['format_separator'] ?? '-',
        formatSuffixDate: json['format_suffix_date'] ?? 'YYYYMM',
        runningLength: json['running_length'] ?? 4,
        nextRunningNumber: json['next_running_number'] ?? 1,
        createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
        updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
        createdBy: json['created_by']?.toString(),
        updatedBy: json['updated_by']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'is_auto_numbering': isAutoNumbering,
        'format_prefix': formatPrefix,
        'format_separator': formatSeparator,
        'format_suffix_date': formatSuffixDate,
        'running_length': runningLength,
        'next_running_number': nextRunningNumber,
      };

  String get sampleCode {
    String code = formatPrefix;
    if (formatSuffixDate.isNotEmpty) {
      final now = DateTime.now();
      final year = now.year.toString();
      final month = now.month.toString().padLeft(2, '0');
      final day = now.day.toString().padLeft(2, '0');
      switch (formatSuffixDate) {
        case 'YY':
          code += year.substring(2);
          break;
        case 'YYYY':
          code += year;
          break;
        case 'YYMM':
          code += year.substring(2) + month;
          break;
        case 'YYYYMM':
          code += year + month;
          break;
        case 'YYMMDD':
          code += year.substring(2) + month + day;
          break;
      }
    }
    code += formatSeparator;
    code += nextRunningNumber.toString().padLeft(runningLength, '0');
    return code;
  }

  ApPaymentRunRunning copyWith({
    int? id,
    bool? isAutoNumbering,
    String? formatPrefix,
    String? formatSeparator,
    String? formatSuffixDate,
    int? runningLength,
    int? nextRunningNumber,
  }) =>
      ApPaymentRunRunning(
        id: id ?? this.id,
        isAutoNumbering: isAutoNumbering ?? this.isAutoNumbering,
        formatPrefix: formatPrefix ?? this.formatPrefix,
        formatSeparator: formatSeparator ?? this.formatSeparator,
        formatSuffixDate: formatSuffixDate ?? this.formatSuffixDate,
        runningLength: runningLength ?? this.runningLength,
        nextRunningNumber: nextRunningNumber ?? this.nextRunningNumber,
        createdAt: createdAt,
        updatedAt: updatedAt,
        createdBy: createdBy,
        updatedBy: updatedBy,
      );
}
