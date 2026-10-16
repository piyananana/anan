import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../sa/utils/sa_app_l10n.dart';

/// แตกยอดของช่องในงบการเงิน: รายบัญชี → คลิกบัญชี → รายการบัญชีแยกประเภท
/// [fetch] เรียก engine พร้อม drill = {row_id, col_seq_no, account_code?} (ตัวกรองสาขา/มิติ/งวดเดียวกับงบ)
Future<void> showFinReportDrillDialog(
  BuildContext context, {
  required Future<Map<String, dynamic>> Function(Map<String, dynamic> drill) fetch,
  required int rowId,
  required int colSeqNo,
  required bool isEnglish,
  String? columnTitle,
}) {
  return showDialog(
    context: context,
    builder: (_) => _FinReportDrillDialog(
      fetch: fetch, rowId: rowId, colSeqNo: colSeqNo, isEnglish: isEnglish, columnTitle: columnTitle),
  );
}

class _FinReportDrillDialog extends StatefulWidget {
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> drill) fetch;
  final int rowId;
  final int colSeqNo;
  final bool isEnglish;
  final String? columnTitle;

  const _FinReportDrillDialog({
    required this.fetch,
    required this.rowId,
    required this.colSeqNo,
    required this.isEnglish,
    this.columnTitle,
  });

  @override
  State<_FinReportDrillDialog> createState() => _FinReportDrillDialogState();
}

class _FinReportDrillDialogState extends State<_FinReportDrillDialog> {
  final NumberFormat _fmt = NumberFormat('#,##0.00', 'en_US');
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _accounts; // ผลระดับรายบัญชี
  Map<String, dynamic>? _lines; // ผลระดับรายการบัญชี (null = แสดงรายบัญชี)

  bool get _en => widget.isEnglish;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({Map<String, dynamic>? account}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await widget.fetch({
        'row_id': account?['row_id'] ?? widget.rowId,
        'col_seq_no': widget.colSeqNo,
        if (account != null) 'account_code': account['account_code'],
      });
      if (!mounted) return;
      setState(() {
        if (account == null) {
          _accounts = res;
        } else {
          _lines = res;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _amt(dynamic v) {
    final d = (v as num?)?.toDouble() ?? 0;
    if (d.abs() < 0.005) return '-';
    return d < 0 ? '(${_fmt.format(d.abs())})' : _fmt.format(d);
  }

  String _date(String? ymd) {
    if (ymd == null) return '';
    final p = ymd.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : ymd;
  }

  String _periodText(Map<String, dynamic>? data) {
    final p = data?['period'];
    if (p == null) return '';
    final range = p['from_name'] == p['to_name'] ? '${p['from_name']}' : '${p['from_name']} – ${p['to_name']}';
    return '$range  (${_date(p['from'])} – ${_date(p['to'])})';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n(_en);
    final showingLines = _lines != null;
    final head = showingLines ? _lines : _accounts;
    final title = showingLines
        ? '${_lines!['account_code']}  ${_lines!['account_name'] ?? ''}'
        : (_accounts?['row_label'] ?? (_en ? 'Breakdown' : 'รายละเอียดยอด'));

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      title: Row(children: [
        if (showingLines)
          IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: _en ? 'Back to accounts' : 'กลับไปรายบัญชี',
            onPressed: _loading ? null : () => setState(() { _lines = null; _error = null; }),
          ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.toString(), style: const TextStyle(fontSize: 17), overflow: TextOverflow.ellipsis),
            Text(
              [
                if (showingLines) _lines!['row_label'],
                if (widget.columnTitle != null && widget.columnTitle!.isNotEmpty) widget.columnTitle,
                _periodText(head),
              ].where((s) => s != null && s.toString().isNotEmpty).join('  ·  '),
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ]),
        ),
      ]),
      content: SizedBox(
        width: showingLines ? 900 : 640,
        height: 480,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : showingLines
                    ? _buildLines()
                    : _buildAccounts(),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l.close))],
    );
  }

  Widget _buildAccounts() {
    final List accounts = _accounts?['accounts'] ?? const [];
    final List skipped = _accounts?['skipped_rows'] ?? const [];
    final multiRow = accounts.map((a) => a['row_id']).toSet().length > 1;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
        _en ? 'Amounts in Baht — click an account to see its ledger entries'
            : 'จำนวนเงินเป็นบาท — คลิกบัญชีเพื่อดูรายการบัญชีแยกประเภท',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      const Divider(),
      Expanded(
        child: accounts.isEmpty
            ? Center(child: Text(_en ? 'No account balances' : 'ไม่มียอดบัญชี', style: const TextStyle(color: Colors.grey)))
            : ListView.separated(
                itemCount: accounts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final a = accounts[i];
                  final newGroup = multiRow && (i == 0 || accounts[i - 1]['row_id'] != a['row_id']);
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (newGroup)
                      Container(
                        color: Colors.blueGrey.shade50,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text('${a['row_label']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    InkWell(
                      onTap: () => _load(account: Map<String, dynamic>.from(a)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: Row(children: [
                          SizedBox(width: 90, child: Text('${a['account_code']}', style: const TextStyle(fontSize: 13))),
                          Expanded(child: Text('${a['account_name'] ?? ''}', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                          SizedBox(width: 140, child: Text(_amt(a['amount']), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
                          const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                        ]),
                      ),
                    ),
                  ]);
                },
              ),
      ),
      const Divider(),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          Expanded(child: Text(_en ? 'Total' : 'รวม', style: const TextStyle(fontWeight: FontWeight.bold))),
          SizedBox(width: 140, child: Text(_amt(_accounts?['total']), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
          const SizedBox(width: 18),
        ]),
      ),
      if (skipped.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            (_en ? 'Not included above (formula rows/cells): ' : 'ไม่รวมในรายการข้างบน (บรรทัด/ช่องที่เป็นสูตร): ') +
                skipped.map((r) => r['row_label']).join(', '),
            style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
          ),
        ),
    ]);
  }

  Widget _buildLines() {
    final List lines = _lines?['lines'] ?? const [];
    final double totalDr = (_lines?['total_debit'] as num?)?.toDouble() ?? 0;
    final double totalCr = (_lines?['total_credit'] as num?)?.toDouble() ?? 0;
    final double balance = (_lines?['amount'] as num?)?.toDouble() ?? 0;
    final double sign = _lines?['normal_sign'] == 'CREDIT' ? -1 : 1;
    final double net = sign * (totalDr - totalCr);
    final bool mismatch = _lines?['truncated'] != true && (net - balance).abs() >= 0.005;
    const hs = TextStyle(fontWeight: FontWeight.bold, fontSize: 12);
    const cs = TextStyle(fontSize: 12);

    Widget line(List<Widget> cells) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: cells),
        );
    List<Widget> cols(String date, String doc, String desc, String dr, String cr, TextStyle st) => [
          SizedBox(width: 80, child: Text(date, style: st)),
          SizedBox(width: 150, child: Text(doc, style: st, overflow: TextOverflow.ellipsis)),
          Expanded(child: Text(desc, style: st, overflow: TextOverflow.ellipsis, maxLines: 2)),
          SizedBox(width: 120, child: Text(dr, style: st, textAlign: TextAlign.right)),
          SizedBox(width: 120, child: Text(cr, style: st, textAlign: TextAlign.right)),
        ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        color: Colors.grey.shade200,
        child: line(cols(_en ? 'Date' : 'วันที่', _en ? 'Document' : 'เลขที่เอกสาร', _en ? 'Description' : 'คำอธิบาย',
            _en ? 'Debit' : 'เดบิต', _en ? 'Credit' : 'เครดิต', hs)),
      ),
      Expanded(
        child: lines.isEmpty
            ? Center(child: Text(_en ? 'No entries' : 'ไม่มีรายการ', style: const TextStyle(color: Colors.grey)))
            : ListView.separated(
                itemCount: lines.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final ln = lines[i];
                  final doc = [ln['doc_code'], ln['doc_no']].where((s) => s != null && '$s'.isNotEmpty).join(' ');
                  final dr = (ln['debit'] as num?)?.toDouble() ?? 0;
                  final cr = (ln['credit'] as num?)?.toDouble() ?? 0;
                  return line(cols(_date(ln['doc_date']), doc, '${ln['description'] ?? ''}',
                      dr == 0 ? '' : _fmt.format(dr), cr == 0 ? '' : _fmt.format(cr), cs));
                },
              ),
      ),
      const Divider(height: 1),
      line(cols('', '', _en ? 'Total' : 'รวม', _fmt.format(totalDr), _fmt.format(totalCr), hs)),
      line(cols('', '', _en ? 'Net (as shown in the report)' : 'สุทธิ (ตามเครื่องหมายในงบ)', '', _amt(net), hs)),
      if (_lines?['truncated'] == true)
        Text(_en ? 'Showing the first ${lines.length} entries only' : 'แสดงเฉพาะ ${lines.length} รายการแรก',
            style: TextStyle(fontSize: 12, color: Colors.orange.shade900)),
      if (mismatch)
        Text(
          _en
              ? 'Entries do not match the account balance used by the report (${_amt(balance)}) — the balance table may need to be rebuilt'
              : 'ผลรวมรายการไม่ตรงกับยอดสะสมที่งบใช้ (${_amt(balance)}) — ยอดสะสมของบัญชีอาจต้องคำนวณใหม่',
          style: TextStyle(fontSize: 12, color: Colors.red.shade700),
        ),
    ]);
  }
}
