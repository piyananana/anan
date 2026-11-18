import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:anan/gl/utils/gl_ledger_split.dart';

// บัญชีแยกประเภท: แยกก้อนตามสาขา/มิติเฉพาะบัญชีที่ผังบัญชีบังคับ (glSplitLedger)
// ชุดที่ 2 ใช้ข้อมูลจริงจาก API ของ backend: สร้างด้วย anan_backend + สคริปต์ t_tb_ledger_split.js <db> <fixture.json>
// แล้วรัน: GL_SPLIT_FIXTURE=<fixture.json> flutter test test/gl_ledger_split_test.dart (ไม่มีไฟล์ = ข้าม)

double _n(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;

// ก้อนของรายงาน (เหมือนหน้าจอ): key → (ยอดยกมาสุทธิ, รายการ)
Map<String, ({double beg, List<Map<String, dynamic>> tx})> _groups(
    ({List<Map<String, dynamic>> beginning, List<Map<String, dynamic>> transactions}) r) {
  final g = <String, ({double beg, List<Map<String, dynamic>> tx})>{};
  for (final b in r.beginning) {
    final k = glSplitKey(b);
    g[k] = (beg: (g[k]?.beg ?? 0) + _n(b['amount_dr']) - _n(b['amount_cr']), tx: g[k]?.tx ?? []);
  }
  for (final t in r.transactions) {
    final k = glSplitKey(t);
    g[k] = (beg: g[k]?.beg ?? 0, tx: [...?g[k]?.tx, t]);
  }
  return g;
}

double _end(({double beg, List<Map<String, dynamic>> tx}) x) =>
    x.beg + x.tx.fold(0.0, (s, t) => s + _n(t['debit_lc']) - _n(t['credit_lc']));

void main() {
  // บัญชี 1 = เงินสด (ไม่บังคับ), 2 = รายได้ (บังคับมิติช่อง 1), 3 = บังคับสาขา
  GlSplitRule rule(int? id) => switch (id) {
        2 => (branch: false, slots: {1}),
        3 => (branch: true, slots: <int>{}),
        _ => glNoSplit,
      };
  Map<String, dynamic> tx(int acc, String code, String date, double dr, double cr, {int? br, int? d1, int? d2, int line = 1}) => {
        'account_id': acc, 'account_code': code, 'doc_date': date, 'doc_no': 'D$date', 'line_no': line,
        'branch_id': br, 'dim1_id': d1, 'dim2_id': d2, 'dim3_id': null, 'dim4_id': null, 'dim5_id': null,
        'debit_lc': dr, 'credit_lc': cr,
      };
  Map<String, dynamic> beg(int acc, double dr, double cr, {int? br, int? d1, int? d2}) => {
        'account_id': acc, 'branch_id': br, 'dim1_id': d1, 'dim2_id': d2, 'dim3_id': null, 'dim4_id': null, 'dim5_id': null,
        'amount_dr': '$dr', 'amount_cr': '$cr',
      };

  final rawBeg = [beg(1, 300, 0, d1: 10, br: 1), beg(1, 100, 0), beg(2, 0, 400, d1: 10, d2: 7), beg(3, 50, 0, br: 1, d1: 10)];
  final rawTx = [
    // API เรียงตามสาขา/มิติก่อนวันที่
    tx(1, '111200', '2026-01-20', 1000, 0, d1: 10),
    tx(1, '111200', '2026-01-10', 700, 0),
    tx(2, '411200', '2026-01-20', 0, 1000, d1: 10, d2: 7),
    tx(2, '411200', '2026-01-25', 0, 300, d1: 10, d2: 8),
    tx(2, '411200', '2026-01-10', 0, 200),
    tx(3, '115000', '2026-01-05', 20, 0, br: 1, d1: 11),
    tx(3, '115000', '2026-01-06', 30, 0, br: 2),
  ];

  test('account not requiring dims: one combined ledger in date order, branch/dims cleared', () {
    final g = _groups(glSplitLedger(rawBeg, rawTx, rule));
    final cash = g.entries.where((e) => e.key.startsWith('1_')).toList();
    expect(cash.length, 1);
    expect(cash.first.value.beg, 400); // 300 (มีมิติ/สาขา) + 100
    expect(cash.first.value.tx.map((t) => t['doc_date']), ['2026-01-10', '2026-01-20']);
    expect(_end(cash.first.value), 2100);
    expect(cash.first.value.tx.every((t) => t['dim1_id'] == null && t['branch_id'] == null), isTrue);
  });

  test('account requiring dim slot 1: split by slot 1 only (slot 2 merged), unspecified kept separately', () {
    final g = _groups(glSplitLedger(rawBeg, rawTx, rule));
    final rev = {for (final e in g.entries.where((e) => e.key.startsWith('2_'))) e.key: e.value};
    expect(rev.keys.toSet(), {'2_0_10_0_0_0_0', '2_0_0_0_0_0_0'});
    expect(_end(rev['2_0_10_0_0_0_0']!), -1700); // ยกมา 400 + 1000 + 300 (มิติ 2 ต่างกันรวมกัน)
    expect(_end(rev['2_0_0_0_0_0_0']!), -200);
  });

  test('account requiring branch: split by branch only, dims cleared', () {
    final g = _groups(glSplitLedger(rawBeg, rawTx, rule));
    final keys = g.keys.where((k) => k.startsWith('3_')).toSet();
    expect(keys, {'3_1_0_0_0_0_0', '3_2_0_0_0_0_0'});
    expect(_end(g['3_1_0_0_0_0_0']!), 70);
    expect(_end(g['3_2_0_0_0_0_0']!), 30);
  });

  test('split off: every account is one ledger; totals never change', () {
    final on = _groups(glSplitLedger(rawBeg, rawTx, rule));
    final off = _groups(glSplitLedger(rawBeg, rawTx, (_) => glNoSplit));
    expect(off.keys.toSet(), {'1_0_0_0_0_0_0', '2_0_0_0_0_0_0', '3_0_0_0_0_0_0'});
    for (final acc in [1, 2, 3]) {
      double sum(Map<String, ({double beg, List<Map<String, dynamic>> tx})> m) =>
          m.entries.where((e) => e.key.startsWith('${acc}_')).fold(0.0, (s, e) => s + _end(e.value));
      expect(sum(on), closeTo(sum(off), 1e-9), reason: 'account $acc');
    }
  });

  final fixturePath = Platform.environment['GL_SPLIT_FIXTURE'];
  test('backend data (fixture): ledger matches the trial balance per account and splits like it', () {
    final fx = jsonDecode(File(fixturePath!).readAsStringSync()) as Map<String, dynamic>;
    final rules = (fx['rules'] as Map).map((k, v) => MapEntry(int.parse(k as String),
        (branch: v['branch'] as bool, slots: {for (final s in v['slots'] as List) s as int})));
    GlSplitRule ruleOf(int? id) => rules[id] ?? glNoSplit;
    List<Map<String, dynamic>> rows(dynamic l) => [for (final x in l as List) Map<String, dynamic>.from(x as Map)];
    final acc = (fx['accounts'] as Map).map((k, v) => MapEntry(k as String, v as int));
    final a = fx['dimA'] as int, b = fx['dimB'] as int;

    // งวด 2: ยอดยกไปต่อบัญชีต้องเท่ากับงบทดลองถึงงวด 2
    final p2 = fx['period2'] as Map;
    final g = _groups(glSplitLedger(rows(p2['beginning']), rows(p2['transactions']), ruleOf));
    final tbEnd = (fx['tbEndP2'] as Map).map((k, v) => MapEntry(int.parse(k as String), (v as num).toDouble()));
    for (final e in tbEnd.entries) {
      final sum = g.entries.where((x) => x.key.startsWith('${e.key}_')).fold(0.0, (s, x) => s + _end(x.value));
      expect(sum, closeTo(e.value, 0.005), reason: 'account ${e.key}');
    }
    final cash = g.keys.where((k) => k.startsWith('${acc['111200']}_')).toList();
    expect(cash.length, 1, reason: 'cash 111200 is one ledger');
    expect(g[cash.first]!.beg, closeTo(2000, 0.005));
    expect(_end(g[cash.first]!), closeTo(2050, 0.005));
    final rev = {for (final k in g.keys.where((k) => k.startsWith('${acc['411200']}_'))) k: g[k]!};
    expect(rev.keys.toSet(), {'${acc['411200']}_0_${a}_0_0_0_0', '${acc['411200']}_0_${b}_0_0_0_0', '${acc['411200']}_0_0_0_0_0_0'});
    expect(_end(rev['${acc['411200']}_0_${a}_0_0_0_0']!), closeTo(-1000, 0.005));
    expect(_end(rev['${acc['411200']}_0_${b}_0_0_0_0']!), closeTo(-550, 0.005));
    expect(_end(rev['${acc['411200']}_0_0_0_0_0_0']!), closeTo(-200, 0.005));

    // งวด 1: เงินสดที่มี/ไม่มีมิติรวมเป็นก้อนเดียว เรียงตามวันที่ (API ส่งมาเรียงตามมิติก่อน)
    final p1 = fx['period1'] as Map;
    final g1 = _groups(glSplitLedger(rows(p1['beginning']), rows(p1['transactions']), ruleOf));
    final cash1 = g1.entries.where((e) => e.key.startsWith('${acc['111200']}_')).toList();
    expect(cash1.length, 1);
    expect(cash1.first.value.tx.map((t) => (t['doc_date'] as String).substring(0, 10)).toList()..sort(),
        cash1.first.value.tx.map((t) => (t['doc_date'] as String).substring(0, 10)).toList());
    expect(_end(cash1.first.value), closeTo(2000, 0.005));
  }, skip: fixturePath == null || !File(fixturePath).existsSync() ? 'GL_SPLIT_FIXTURE not set' : false);
}
