// lib/im/models/im_item_running.dart

class ImItemRunning {
  final int? id;
  final bool isAutoNumbering;
  final String formatPrefix;
  final String formatSeparator;
  final String formatSuffixDate;
  final int runningLength;
  final int nextRunningNumber;

  const ImItemRunning({
    this.id,
    required this.isAutoNumbering,
    required this.formatPrefix,
    required this.formatSeparator,
    required this.formatSuffixDate,
    required this.runningLength,
    required this.nextRunningNumber,
  });

  factory ImItemRunning.fromJson(Map<String, dynamic> json) => ImItemRunning(
        id: json['id'],
        isAutoNumbering: json['is_auto_numbering'] ?? false,
        formatPrefix: json['format_prefix'] ?? 'ITEM',
        formatSeparator: json['format_separator'] ?? '-',
        formatSuffixDate: json['format_suffix_date'] ?? '',
        runningLength: json['running_length'] ?? 4,
        nextRunningNumber: json['next_running_number'] ?? 1,
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
}
