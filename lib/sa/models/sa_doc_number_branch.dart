class DocNumberBranchConfig {
  final int docId;
  final String docCode;
  final String docNameThai;
  final String sysModule;
  // Global values (from sa_module_document)
  final String globalPrefix;
  final String globalSeparator;
  final String globalSuffixDate;
  final int globalRunningLength;
  final int globalNextRunning;
  // Branch-specific overrides (null = not set / inherit global)
  final int? configId;
  bool hasConfig;
  String? formatPrefix;
  String? formatSeparator;
  String? formatSuffixDate;
  int? runningLength;
  int nextRunningNumber;

  DocNumberBranchConfig({
    required this.docId,
    required this.docCode,
    required this.docNameThai,
    required this.sysModule,
    required this.globalPrefix,
    required this.globalSeparator,
    required this.globalSuffixDate,
    required this.globalRunningLength,
    required this.globalNextRunning,
    this.configId,
    required this.hasConfig,
    this.formatPrefix,
    this.formatSeparator,
    this.formatSuffixDate,
    this.runningLength,
    required this.nextRunningNumber,
  });

  factory DocNumberBranchConfig.fromJson(Map<String, dynamic> j) {
    final hasConfig = j['id'] != null;
    return DocNumberBranchConfig(
      docId:              j['doc_id'] as int,
      docCode:            j['doc_code'] as String,
      docNameThai:        j['doc_name_thai'] as String,
      sysModule:          j['sys_module'] as String? ?? '',
      globalPrefix:       j['global_prefix'] as String? ?? '',
      globalSeparator:    j['global_separator'] as String? ?? '',
      globalSuffixDate:   j['global_suffix_date'] as String? ?? '',
      globalRunningLength: j['global_running_length'] as int? ?? 4,
      globalNextRunning:  j['global_next_running'] as int? ?? 1,
      configId:           j['id'] as int?,
      hasConfig:          hasConfig,
      formatPrefix:       j['format_prefix'] as String?,
      formatSeparator:    j['format_separator'] as String?,
      formatSuffixDate:   j['format_suffix_date'] as String?,
      runningLength:      j['running_length'] as int?,
      nextRunningNumber:  j['next_running_number'] as int? ?? 1,
    );
  }

  // Effective values (branch override or global fallback)
  String get effectivePrefix    => formatPrefix    ?? globalPrefix;
  String get effectiveSeparator => formatSeparator ?? globalSeparator;
  String get effectiveSuffixDate => formatSuffixDate ?? globalSuffixDate;
  int    get effectiveLength    => runningLength   ?? globalRunningLength;

  /// Preview what the next doc number would look like
  String previewDocNo() {
    if (!hasConfig) return '— ใช้ Global —';
    final now = DateTime.now();
    final y4 = now.year.toString();
    final y2 = y4.substring(2);
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    String datePart = '';
    switch (effectiveSuffixDate) {
      case 'YY':       datePart = y2; break;
      case 'YYYY':     datePart = y4; break;
      case 'YYMM':     datePart = '$y2$mm'; break;
      case 'YYYYMM':   datePart = '$y4$mm'; break;
      case 'YYYYMMDD': datePart = '$y4$mm$dd'; break;
    }
    final running = nextRunningNumber.toString().padLeft(effectiveLength, '0');
    return '$effectivePrefix$datePart$effectiveSeparator$running';
  }

  Map<String, dynamic> toSaveJson() => {
    'doc_id':            docId,
    'format_prefix':     formatPrefix?.isEmpty == true ? null : formatPrefix,
    'format_separator':  formatSeparator?.isEmpty == true ? null : formatSeparator,
    'format_suffix_date': formatSuffixDate?.isEmpty == true ? null : formatSuffixDate,
    'running_length':    runningLength,
  };
}
