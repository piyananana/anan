// lib/gl/utils/gl_ledger_split.dart
// รายงานบัญชีแยกประเภท: แยกก้อนตามสาขา/มิติ เฉพาะบัญชีที่ผังบัญชีบังคับ (user-approved 2026-11-17)
//   - บังคับสาขา (branch_required) → แยกตามสาขา
//   - บังคับมิติ (gl_account_dim_rule.is_required, ประเภทมิติที่เปิดใช้) → แยกเฉพาะมิติที่บังคับ
//   - บัญชีอื่น → ล้างสาขา/มิติทุกช่อง = รายการที่มี/ไม่มีมิติรวมเป็นก้อนเดียว ยอดยกมาและยอดคงเหลือต่อเนื่อง
// เหมือนกติกาของงบทดลอง (backend glTrialBalanceReportController.js, show_dimensions=true)

typedef GlSplitRule = ({bool branch, Set<int> slots});

const GlSplitRule glNoSplit = (branch: false, slots: <int>{});

Map<String, dynamic> glMaskSplit(Map<String, dynamic> r, GlSplitRule rule) => {
      ...r,
      'branch_id': rule.branch ? r['branch_id'] : null,
      for (var i = 1; i <= 5; i++) 'dim${i}_id': rule.slots.contains(i) ? r['dim${i}_id'] : null,
    };

String glSplitKey(Map<String, dynamic> r) =>
    "${r['account_id']}_${r['branch_id'] ?? 0}_${r['dim1_id'] ?? 0}_${r['dim2_id'] ?? 0}_${r['dim3_id'] ?? 0}_${r['dim4_id'] ?? 0}_${r['dim5_id'] ?? 0}";

/// ยอดยกมา (รวมแถวที่ตกก้อนเดียวกัน) + รายการเคลื่อนไหว (เรียงใหม่: บัญชี → สาขา → มิติ → วันที่ → เลขที่ → ลำดับ)
({List<Map<String, dynamic>> beginning, List<Map<String, dynamic>> transactions}) glSplitLedger(
  List<Map<String, dynamic>> rawBeginning,
  List<Map<String, dynamic>> rawTransactions,
  GlSplitRule Function(int? accountId) ruleOf,
) {
  double n(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
  final beg = <String, Map<String, dynamic>>{};
  for (final raw in rawBeginning) {
    final b = glMaskSplit(raw, ruleOf(raw['account_id'] as int?));
    final k = glSplitKey(b);
    final e = beg[k];
    if (e == null) {
      beg[k] = {...b, 'amount_dr': n(b['amount_dr']), 'amount_cr': n(b['amount_cr'])};
    } else {
      e['amount_dr'] = (e['amount_dr'] as double) + n(b['amount_dr']);
      e['amount_cr'] = (e['amount_cr'] as double) + n(b['amount_cr']);
    }
  }

  final tx = [
    for (var i = 0; i < rawTransactions.length; i++)
      (i, glMaskSplit(rawTransactions[i], ruleOf(rawTransactions[i]['account_id'] as int?)))
  ];
  int c(dynamic a, dynamic b) => (a as int? ?? 0).compareTo(b as int? ?? 0);
  tx.sort((x, y) {
    final a = x.$2, b = y.$2;
    var r = (a['account_code']?.toString() ?? '').compareTo(b['account_code']?.toString() ?? '');
    if (r != 0) return r;
    r = c(a['branch_id'], b['branch_id']);
    for (var i = 1; r == 0 && i <= 5; i++) {
      r = c(a['dim${i}_id'], b['dim${i}_id']);
    }
    if (r != 0) return r;
    r = (a['doc_date']?.toString() ?? '').compareTo(b['doc_date']?.toString() ?? '');
    if (r != 0) return r;
    r = (a['doc_no']?.toString() ?? '').compareTo(b['doc_no']?.toString() ?? '');
    if (r != 0) return r;
    r = c(a['line_no'], b['line_no']);
    return r != 0 ? r : x.$1.compareTo(y.$1);
  });
  return (beginning: beg.values.toList(), transactions: [for (final t in tx) t.$2]);
}
