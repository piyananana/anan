// GL Dimension Framework models

class GlDimensionType {
  final int slotNo;
  final String typeCode;
  final String nameThai;
  final String? nameEng;
  final bool isActive;
  final int sortOrder;

  const GlDimensionType({
    required this.slotNo,
    required this.typeCode,
    required this.nameThai,
    this.nameEng,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory GlDimensionType.fromJson(Map<String, dynamic> j) => GlDimensionType(
        slotNo:    j['slot_no'] as int,
        typeCode:  j['type_code'] as String,
        nameThai:  j['name_thai'] as String,
        nameEng:   j['name_eng'] as String?,
        isActive:  j['is_active'] as bool? ?? true,
        sortOrder: j['sort_order'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'slot_no':    slotNo,
        'type_code':  typeCode,
        'name_thai':  nameThai,
        'name_eng':   nameEng,
        'is_active':  isActive,
        'sort_order': sortOrder,
      };
}

class GlDimensionValue {
  final int id;
  final String typeCode;
  final String valueCode;
  final String valueNameThai;
  final String? valueNameEng;
  final int? parentId;
  final String? parentCode;
  final String? parentName;
  final bool isActive;
  final int sortOrder;

  const GlDimensionValue({
    required this.id,
    required this.typeCode,
    required this.valueCode,
    required this.valueNameThai,
    this.valueNameEng,
    this.parentId,
    this.parentCode,
    this.parentName,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory GlDimensionValue.fromJson(Map<String, dynamic> j) => GlDimensionValue(
        id:            j['id'] as int,
        typeCode:      j['type_code'] as String,
        valueCode:     j['value_code'] as String,
        valueNameThai: j['value_name_thai'] as String,
        valueNameEng:  j['value_name_eng'] as String?,
        parentId:      j['parent_id'] as int?,
        parentCode:    j['parent_code'] as String?,
        parentName:    j['parent_name'] as String?,
        isActive:      j['is_active'] as bool? ?? true,
        sortOrder:     j['sort_order'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id':              id,
        'type_code':       typeCode,
        'value_code':      valueCode,
        'value_name_thai': valueNameThai,
        'value_name_eng':  valueNameEng,
        'parent_id':       parentId,
        'is_active':       isActive,
        'sort_order':      sortOrder,
      };

  String get displayName => '$valueCode — $valueNameThai';
}

// ── สรุปของหน้าจอประเภทมิติ (user 2026-11-28) ──
int _dimInt(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);

/// ตัวเลขต่อช่องบนการ์ดซ้าย (GET /gl_dimension_type/usage)
class GlDimTypeUsage {
  final int slotNo;
  final int valueCount;
  final int requiredAccounts;
  final int optionalAccounts;
  const GlDimTypeUsage(this.slotNo, this.valueCount, this.requiredAccounts, this.optionalAccounts);
  factory GlDimTypeUsage.fromJson(Map<String, dynamic> j) =>
      GlDimTypeUsage(_dimInt(j['slot_no']), _dimInt(j['value_count']), _dimInt(j['required_accounts']), _dimInt(j['optional_accounts']));
}

class GlDimTypeAccountRow {
  final int id;
  final String code;
  final String nameThai;
  final String nameEng;
  final String accountType;
  final bool isRequired;
  final int linesYear;
  final int missingDraft;
  const GlDimTypeAccountRow({required this.id, required this.code, required this.nameThai, required this.nameEng,
      required this.accountType, required this.isRequired, required this.linesYear, required this.missingDraft});
  factory GlDimTypeAccountRow.fromJson(Map<String, dynamic> j) => GlDimTypeAccountRow(
        id: _dimInt(j['id']),
        code: j['account_code']?.toString() ?? '',
        nameThai: j['account_name_thai']?.toString() ?? '',
        nameEng: j['account_name_eng']?.toString() ?? '',
        accountType: j['account_type']?.toString() ?? '',
        isRequired: j['is_required'] == true,
        linesYear: _dimInt(j['lines_year']),
        missingDraft: _dimInt(j['missing_draft']),
      );
  String name(bool e) => e && nameEng.isNotEmpty ? nameEng : nameThai;
}

class GlDimValueUsageRow {
  final int id;
  final String code;
  final String nameThai;
  final String? nameEng;
  final bool isActive;
  final String? parentCode;
  final int linesYear;
  const GlDimValueUsageRow({required this.id, required this.code, required this.nameThai, this.nameEng, required this.isActive,
      this.parentCode, required this.linesYear});
  factory GlDimValueUsageRow.fromJson(Map<String, dynamic> j) => GlDimValueUsageRow(
        id: _dimInt(j['id']),
        code: j['value_code']?.toString() ?? '',
        nameThai: j['value_name_thai']?.toString() ?? '',
        nameEng: j['value_name_eng']?.toString(),
        isActive: j['is_active'] != false,
        parentCode: j['parent_code']?.toString(),
        linesYear: _dimInt(j['lines_year']),
      );
  String name(bool e) => e && (nameEng ?? '').isNotEmpty ? nameEng! : nameThai;
}

/// GET /gl_dimension_type/:slot_no/summary
class GlDimTypeSummary {
  final String? fyCode;
  final int valueCount;
  final int activeValues;
  final int linesYear;
  final int missingDraft;
  final List<GlDimTypeAccountRow> accounts;
  final List<GlDimValueUsageRow> values;
  const GlDimTypeSummary({this.fyCode, required this.valueCount, required this.activeValues, required this.linesYear,
      required this.missingDraft, required this.accounts, required this.values});
  factory GlDimTypeSummary.fromJson(Map<String, dynamic> j) => GlDimTypeSummary(
        fyCode: (j['fiscal_year'] as Map<String, dynamic>?)?['fy_code']?.toString(),
        valueCount: _dimInt(j['value_count']),
        activeValues: _dimInt(j['active_values']),
        linesYear: _dimInt(j['lines_year']),
        missingDraft: _dimInt(j['missing_draft']),
        accounts: [for (final x in (j['accounts'] as List? ?? const [])) GlDimTypeAccountRow.fromJson(x as Map<String, dynamic>)],
        values: [for (final x in (j['values'] as List? ?? const [])) GlDimValueUsageRow.fromJson(x as Map<String, dynamic>)],
      );
  int get requiredAccounts => accounts.where((a) => a.isRequired).length;
  int get optionalAccounts => accounts.where((a) => !a.isRequired).length;
}

// ── สรุปของหน้าจอค่ามิติ (user 2026-11-28) ──
double _dimD(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);

/// GET /gl_dimension_value/usage — บรรทัด Posted ต่อค่า (เฉพาะของตัวเอง)
class GlDimValueLineCount {
  final int linesYear;
  final int linesAll;
  const GlDimValueLineCount(this.linesYear, this.linesAll);
}

class GlDimValueAccountRow {
  final int id;
  final String code;
  final String nameThai;
  final String nameEng;
  final String accountType;
  final double debit;
  final double credit;
  const GlDimValueAccountRow({required this.id, required this.code, required this.nameThai, required this.nameEng,
      required this.accountType, required this.debit, required this.credit});
  factory GlDimValueAccountRow.fromJson(Map<String, dynamic> j) => GlDimValueAccountRow(
        id: _dimInt(j['id']),
        code: j['account_code']?.toString() ?? '',
        nameThai: j['account_name_thai']?.toString() ?? '',
        nameEng: j['account_name_eng']?.toString() ?? '',
        accountType: j['account_type']?.toString() ?? '',
        debit: _dimD(j['debit']),
        credit: _dimD(j['credit']),
      );
  String name(bool e) => e && nameEng.isNotEmpty ? nameEng : nameThai;
}

/// GET /gl_dimension_value/:id/summary — ค่านี้รวมค่าย่อยทุกระดับ
class GlDimValueSummary {
  final String? fyCode;
  final int linesYear;
  final double revenue;
  final double expense;
  final String? lastDocNo;
  final String? lastDate;
  final List<GlDimValueAccountRow> byAccount;
  final List<GlDimValueUsageRow> children;
  const GlDimValueSummary({this.fyCode, required this.linesYear, required this.revenue, required this.expense, this.lastDocNo,
      this.lastDate, required this.byAccount, required this.children});
  factory GlDimValueSummary.fromJson(Map<String, dynamic> j) {
    final last = j['last_used'] as Map<String, dynamic>?;
    return GlDimValueSummary(
      fyCode: (j['fiscal_year'] as Map<String, dynamic>?)?['fy_code']?.toString(),
      linesYear: _dimInt(j['lines_year']),
      revenue: _dimD(j['revenue']),
      expense: _dimD(j['expense']),
      lastDocNo: last?['doc_no']?.toString(),
      lastDate: last?['posting_date']?.toString(),
      byAccount: [for (final x in (j['by_account'] as List? ?? const [])) GlDimValueAccountRow.fromJson(x as Map<String, dynamic>)],
      children: [for (final x in (j['children'] as List? ?? const [])) GlDimValueUsageRow.fromJson(x as Map<String, dynamic>)],
    );
  }
}
