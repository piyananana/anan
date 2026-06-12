// lib/cm/models/cm_bank_file_format.dart

class CmBankFileFormatColumn {
  String fieldCode;
  String columnLabel;
  int length;
  String align;      // 'L' | 'R'
  String padChar;    // ' ' | '0' | etc.
  String dateFormat; // 'YYYYMMDD' | 'DDMMYYYY' etc.
  int decimalPlaces; // for decimal/amount fields
  String? constantValue;

  CmBankFileFormatColumn({
    required this.fieldCode,
    String? columnLabel,
    this.length = 20,
    this.align = 'L',
    this.padChar = ' ',
    this.dateFormat = 'YYYYMMDD',
    this.decimalPlaces = 2,
    this.constantValue,
  }) : columnLabel = columnLabel ?? fieldCode;

  factory CmBankFileFormatColumn.fromJson(Map<String, dynamic> json) =>
      CmBankFileFormatColumn(
        fieldCode: json['field_code'] ?? '',
        columnLabel: json['column_label'] ?? '',
        length: json['length'] ?? 20,
        align: json['align'] ?? 'L',
        padChar: json['pad_char'] ?? ' ',
        dateFormat: json['date_format'] ?? 'YYYYMMDD',
        decimalPlaces: json['decimal_places'] ?? 2,
        constantValue: json['constant_value'],
      );

  Map<String, dynamic> toJson() => {
        'field_code': fieldCode,
        'column_label': columnLabel,
        'length': length,
        'align': align,
        'pad_char': padChar,
        'date_format': dateFormat,
        'decimal_places': decimalPlaces,
        'constant_value': constantValue,
      };
}

class CmBankFileFormat {
  final int? id;
  final String formatCode;
  final String formatName;
  final String? bankCode;
  final String fileExtension;
  final String delimiter;
  final bool hasHeader;
  final bool hasFooter;
  final List<CmBankFileFormatColumn> columns;
  final bool isActive;

  CmBankFileFormat({
    this.id,
    required this.formatCode,
    required this.formatName,
    this.bankCode,
    this.fileExtension = 'txt',
    this.delimiter = '',
    this.hasHeader = false,
    this.hasFooter = false,
    List<CmBankFileFormatColumn>? columns,
    this.isActive = true,
  }) : columns = columns ?? [];

  factory CmBankFileFormat.fromJson(Map<String, dynamic> json) {
    final rawCols = json['columns'];
    List<CmBankFileFormatColumn> cols = [];
    if (rawCols is List) {
      cols = rawCols
          .map((c) => CmBankFileFormatColumn.fromJson(c as Map<String, dynamic>))
          .toList();
    }
    return CmBankFileFormat(
      id: json['id'],
      formatCode: json['format_code'] ?? '',
      formatName: json['format_name'] ?? '',
      bankCode: json['bank_code'],
      fileExtension: json['file_extension'] ?? 'txt',
      delimiter: json['delimiter'] ?? '',
      hasHeader: json['has_header'] ?? false,
      hasFooter: json['has_footer'] ?? false,
      columns: cols,
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'format_code': formatCode,
        'format_name': formatName,
        'bank_code': bankCode,
        'file_extension': fileExtension,
        'delimiter': delimiter,
        'has_header': hasHeader,
        'has_footer': hasFooter,
        'columns': columns.map((c) => c.toJson()).toList(),
        'is_active': isActive,
      };
}
