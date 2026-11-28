// สรุปของบัญชีบนหน้าจอผังบัญชี (GET /gl_account/:id/summary, user 2026-11-28)
// หัวบัญชี = รวมทั้งกิ่ง; จำนวนเงินเป็นสกุลเงินหลัก; งวดแรกของปี (period_number ต่ำสุด) = งวดยอดยกมา

double _d(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
int _i(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);

class GlFiscalYearRef {
  final int id;
  final String fyCode;
  const GlFiscalYearRef(this.id, this.fyCode);
  factory GlFiscalYearRef.fromJson(Map<String, dynamic> j) => GlFiscalYearRef(_i(j['id']), j['fy_code']?.toString() ?? '');
}

class GlAccountPeriodRow {
  final int id;
  final int periodNumber;
  final String periodName;
  final String startDate; // yyyy-MM-dd
  final String endDate;
  final String glStatus;
  final double debit;
  final double credit;
  const GlAccountPeriodRow({required this.id, required this.periodNumber, required this.periodName, required this.startDate,
      required this.endDate, required this.glStatus, required this.debit, required this.credit});
  double get net => debit - credit;
  factory GlAccountPeriodRow.fromJson(Map<String, dynamic> j) => GlAccountPeriodRow(
        id: _i(j['id']),
        periodNumber: _i(j['period_number']),
        periodName: j['period_name']?.toString() ?? '',
        startDate: j['start_date']?.toString() ?? '',
        endDate: j['end_date']?.toString() ?? '',
        glStatus: j['gl_status']?.toString() ?? 'OPEN',
        debit: _d(j['debit']),
        credit: _d(j['credit']),
      );
}

/// ที่หนึ่งที่ตั้งค่าใช้บัญชีนี้ (ตั้งค่าบัญชี GL ตามประเภทเอกสาร, ลูกค้า, สินค้า ฯลฯ)
class GlAccountUsage {
  final String module;
  final String table;
  final String screenTh;
  final String screenEn;
  final String? targetPath;
  final String? refCode;
  final String? refNameTh;
  final String? refNameEn;
  final String fieldTh;
  final String fieldEn;
  final int total; // จำนวนแถวทั้งหมดของหน้าจอตั้งค่านี้ (แสดงไม่เกิน 20)
  const GlAccountUsage({required this.module, required this.table, required this.screenTh, required this.screenEn, this.targetPath,
      this.refCode, this.refNameTh, this.refNameEn, required this.fieldTh, required this.fieldEn, required this.total});
  factory GlAccountUsage.fromJson(Map<String, dynamic> j) => GlAccountUsage(
        module: j['module']?.toString() ?? '',
        table: j['table']?.toString() ?? '',
        screenTh: j['screen_th']?.toString() ?? '',
        screenEn: j['screen_en']?.toString() ?? '',
        targetPath: j['target_path']?.toString(),
        refCode: j['ref_code']?.toString(),
        refNameTh: j['ref_name_th']?.toString(),
        refNameEn: j['ref_name_en']?.toString(),
        fieldTh: j['field_th']?.toString() ?? '',
        fieldEn: j['field_en']?.toString() ?? '',
        total: _i(j['total']),
      );
  String screen(bool e) => e && screenEn.isNotEmpty ? screenEn : screenTh;
  String field(bool e) => e && fieldEn.isNotEmpty ? fieldEn : fieldTh;
  String ref(bool e) {
    final name = e && (refNameEn ?? '').isNotEmpty ? refNameEn! : (refNameTh ?? '');
    return [refCode ?? '', name].where((s) => s.isNotEmpty).join('  ');
  }
}

class GlAccountSummary {
  final List<GlFiscalYearRef> fiscalYears;
  final GlFiscalYearRef? fiscalYear;
  final List<GlAccountPeriodRow> periods;
  final double balanceToday; // เดบิต - เครดิต
  final int linesPosted;
  final int linesDraft;
  final String? lastDocNo;
  final String? lastDate;
  final List<GlAccountUsage> usage;
  const GlAccountSummary({required this.fiscalYears, this.fiscalYear, required this.periods, required this.balanceToday,
      required this.linesPosted, required this.linesDraft, this.lastDocNo, this.lastDate, required this.usage});

  factory GlAccountSummary.fromJson(Map<String, dynamic> j) {
    final last = j['last_movement'] as Map<String, dynamic>?;
    final fy = j['fiscal_year'] as Map<String, dynamic>?;
    return GlAccountSummary(
      fiscalYears: [for (final x in (j['fiscal_years'] as List? ?? const [])) GlFiscalYearRef.fromJson(x as Map<String, dynamic>)],
      fiscalYear: fy == null ? null : GlFiscalYearRef.fromJson(fy),
      periods: [for (final x in (j['periods'] as List? ?? const [])) GlAccountPeriodRow.fromJson(x as Map<String, dynamic>)],
      balanceToday: _d(j['balance_today']),
      linesPosted: _i(j['lines_posted']),
      linesDraft: _i(j['lines_draft']),
      lastDocNo: last?['doc_no']?.toString(),
      lastDate: last?['posting_date']?.toString(),
      usage: [for (final x in (j['usage'] as List? ?? const [])) GlAccountUsage.fromJson(x as Map<String, dynamic>)],
    );
  }

  /// จำนวนที่ตั้งค่าใช้บัญชีนี้ทั้งหมด (นับแถวจริง ไม่ใช่แถวที่แสดง) ต่อโมดูล
  Map<String, int> get usageByModule {
    final seen = <String>{};
    final out = <String, int>{};
    for (final u in usage) {
      if (!seen.add(u.table)) continue;
      out[u.module] = (out[u.module] ?? 0) + u.total;
    }
    return out;
  }

  int get usageTotal => usageByModule.values.fold(0, (s, n) => s + n);
}
