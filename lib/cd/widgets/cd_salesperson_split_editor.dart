import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/cd_doc_salesperson.dart';
import '../models/cd_salesperson.dart';
import '../services/cd_salesperson_service.dart';

// ตารางพนักงานขายหลายคน — ข้อมูลลูกค้า (showShares + showPrimary: กรอก % และจำนวนเงินแยกกันอิสระ) และเอกสารขาย
// (แสดงรายชื่ออย่างเดียว — ผู้ป้อนเอกสารไม่ต้องรู้สัดส่วน backend เก็บสัดส่วนจากข้อมูลลูกค้าลงเอกสารให้เอง)
class SalespersonSplitEditor extends StatefulWidget {
  final List<DocSalesperson> items;
  final ValueChanged<List<DocSalesperson>> onChanged;
  final bool readOnly;
  final bool isEnglish;
  final bool showShares;
  final bool showPrimary;
  final Set<int> preferredIds; // เช่น พนักงานขายในเขตการขายของลูกค้า — แสดงก่อนในหน้าต่างเลือก
  final String? title;

  const SalespersonSplitEditor({
    super.key,
    required this.items,
    required this.onChanged,
    required this.isEnglish,
    this.readOnly = false,
    this.showShares = false,
    this.showPrimary = false,
    this.preferredIds = const {},
    this.title,
  });

  @override
  State<SalespersonSplitEditor> createState() => _SalespersonSplitEditorState();
}

class _SalespersonSplitEditorState extends State<SalespersonSplitEditor> {
  final _pctCtrls = <int, TextEditingController>{};
  final _amtCtrls = <int, TextEditingController>{};
  static final _fmtAmt = NumberFormat('#,##0.00');
  static final _fmtPct = NumberFormat('0.####');

  bool get _hasAmount => widget.showShares;

  String _pctText(double? v) => v == null ? '' : _fmtPct.format(v);
  String _amtText(double? v) => v == null ? '' : v.toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    _syncCtrls();
  }

  @override
  void didUpdateWidget(covariant SalespersonSplitEditor old) {
    super.didUpdateWidget(old);
    _syncCtrls();
  }

  // controller ต่อคน — ตั้งข้อความใหม่เฉพาะเมื่อค่าต่างจากที่พิมพ์อยู่ (ไม่ให้เคอร์เซอร์กระโดด)
  void _syncCtrls() {
    final ids = widget.items.map((e) => e.salespersonId).toSet();
    for (final id in _pctCtrls.keys.toList()) {
      if (!ids.contains(id)) {
        _pctCtrls.remove(id)?.dispose();
        _amtCtrls.remove(id)?.dispose();
      }
    }
    for (final e in widget.items) {
      final p = _pctCtrls.putIfAbsent(e.salespersonId, () => TextEditingController());
      final a = _amtCtrls.putIfAbsent(e.salespersonId, () => TextEditingController());
      if (double.tryParse(p.text) != e.sharePercent) p.text = _pctText(e.sharePercent);
      if (double.tryParse(a.text.replaceAll(',', '')) != e.shareAmount) a.text = _amtText(e.shareAmount);
    }
  }

  @override
  void dispose() {
    for (final c in [..._pctCtrls.values, ..._amtCtrls.values]) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit(List<DocSalesperson> list) => widget.onChanged(list);

  void _replace(int id, DocSalesperson Function(DocSalesperson) f) =>
      _emit(widget.items.map((e) => e.salespersonId == id ? f(e) : e).toList());

  void _onPct(int id, String text) =>
      _replace(id, (e) => e.copyWith(sharePercent: () => double.tryParse(text)));

  void _onAmt(int id, String text) =>
      _replace(id, (e) => e.copyWith(shareAmount: () => double.tryParse(text.replaceAll(',', ''))));

  void _setPrimary(int id) =>
      _emit(widget.items.map((e) => e.copyWith(isPrimary: e.salespersonId == id)).toList());

  void _remove(int id) {
    final next = widget.items.where((e) => e.salespersonId != id).toList();
    if (widget.showPrimary && next.isNotEmpty && !next.any((e) => e.isPrimary)) {
      next[0] = next[0].copyWith(isPrimary: true);
    }
    _emit(next);
  }

  // แบ่ง % เท่ากันทุกคน (คนสุดท้ายรับเศษ)
  void _splitEvenly() {
    final n = widget.items.length;
    if (n == 0) return;
    final each = (100 / n * 10000).floorToDouble() / 10000;
    var restPct = 100.0;
    final next = <DocSalesperson>[];
    for (var i = 0; i < n; i++) {
      final pct = i == n - 1 ? (restPct * 10000).roundToDouble() / 10000 : each;
      restPct -= pct;
      next.add(widget.items[i].copyWith(sharePercent: () => pct));
    }
    _emit(next);
  }

  Future<void> _add() async {
    final isEnglish = widget.isEnglish;
    List<Salesperson> all;
    try {
      all = await Provider.of<SalespersonService>(context, listen: false).fetchRows();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
      return;
    }
    if (!mounted) return;
    final chosen = widget.items.map((e) => e.salespersonId).toSet();
    final candidates = all.where((s) => s.isActive && s.id != null && !chosen.contains(s.id)).toList()
      ..sort((a, b) {
        final pa = widget.preferredIds.contains(a.id) ? 0 : 1;
        final pb = widget.preferredIds.contains(b.id) ? 0 : 1;
        return pa != pb ? pa - pb : a.salespersonCode.compareTo(b.salespersonCode);
      });
    final searchCtrl = TextEditingController();
    final picked = await showDialog<Salesperson>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) {
        final q = searchCtrl.text.trim().toLowerCase();
        final list = q.isEmpty
            ? candidates
            : candidates.where((s) =>
                s.salespersonCode.toLowerCase().contains(q) ||
                s.salespersonNameThai.toLowerCase().contains(q) ||
                (s.salespersonNameEng ?? '').toLowerCase().contains(q)).toList();
        return AlertDialog(
          title: Text(isEnglish ? 'Add Salesperson' : 'เพิ่มพนักงานขาย',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 500,
            height: 420,
            child: Column(children: [
              TextField(
                controller: searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: isEnglish ? 'Search code / name' : 'ค้นหารหัส / ชื่อ',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setD(() {}),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Text(isEnglish ? 'No salespersons' : 'ไม่มีพนักงานขาย',
                            style: const TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final s = list[i];
                          final name = isEnglish && (s.salespersonNameEng ?? '').isNotEmpty
                              ? s.salespersonNameEng!
                              : s.salespersonNameThai;
                          final preferred = widget.preferredIds.contains(s.id);
                          return ListTile(
                            dense: true,
                            leading: Icon(Icons.person_outline,
                                color: preferred ? Colors.teal : Colors.grey, size: 20),
                            title: Text('${s.salespersonCode} — $name'),
                            subtitle: preferred
                                ? Text(isEnglish ? 'In customer territory' : 'อยู่ในเขตการขายของลูกค้า',
                                    style: const TextStyle(fontSize: 11, color: Colors.teal))
                                : null,
                            onTap: () => Navigator.of(ctx).pop(s),
                          );
                        },
                      ),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(isEnglish ? 'Close' : 'ปิด')),
          ],
        );
      }),
    );
    searchCtrl.dispose();
    if (picked == null) return;
    _emit([
      ...widget.items,
      DocSalesperson(
        salespersonId: picked.id!,
        salespersonCode: picked.salespersonCode,
        salespersonNameThai: picked.salespersonNameThai,
        salespersonNameEng: picked.salespersonNameEng,
        isPrimary: widget.showPrimary && widget.items.isEmpty,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = widget.isEnglish;
    final ro = widget.readOnly;
    final items = widget.items;
    final sumPct = items.fold<double>(0, (s, e) => s + (e.sharePercent ?? 0));
    final sumAmt = items.fold<double>(0, (s, e) => s + (e.shareAmount ?? 0));
    final pctOver = sumPct > 100.0001;
    const head = TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54);

    Widget numField(TextEditingController c, ValueChanged<String> onChanged, {String? suffix}) => SizedBox(
          width: suffix == '%' ? 90 : 130,
          child: TextField(
            controller: c,
            readOnly: ro,
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: InputDecoration(
              isDense: true,
              suffixText: suffix,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            onChanged: onChanged,
          ),
        );

    return InputDecorator(
      decoration: InputDecoration(
        labelText: widget.title ?? (isEnglish ? 'Salespersons' : 'พนักงานขาย'),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(isEnglish ? '— Not specified —' : '— ไม่ระบุ —',
                  style: const TextStyle(color: Colors.grey)),
            )
          else ...[
            Row(children: [
              if (widget.showPrimary) SizedBox(width: 36, child: Text(isEnglish ? 'Main' : 'หลัก', style: head)),
              Expanded(child: Text(isEnglish ? 'Salesperson' : 'พนักงานขาย', style: head)),
              if (_hasAmount) ...[
                const SizedBox(width: 90, child: Text('%', style: head, textAlign: TextAlign.right)),
                const SizedBox(width: 8),
                SizedBox(width: 130, child: Text(isEnglish ? 'Amount' : 'จำนวนเงิน', style: head, textAlign: TextAlign.right)),
              ],
              if (!ro) const SizedBox(width: 40),
            ]),
            const SizedBox(height: 4),
            for (final e in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  if (widget.showPrimary)
                    SizedBox(
                      width: 36,
                      child: IconButton(
                        icon: Icon(e.isPrimary ? Icons.star : Icons.star_border,
                            color: e.isPrimary ? Colors.amber : Colors.grey, size: 20),
                        tooltip: isEnglish ? 'Main salesperson' : 'พนักงานขายหลัก',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: ro ? null : () => _setPrimary(e.salespersonId),
                      ),
                    ),
                  Expanded(
                    child: Text('${e.salespersonCode} — ${e.displayName(isEnglish)}',
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (_hasAmount) ...[
                    numField(_pctCtrls[e.salespersonId]!, (t) => _onPct(e.salespersonId, t), suffix: '%'),
                    const SizedBox(width: 8),
                    numField(_amtCtrls[e.salespersonId]!, (t) => _onAmt(e.salespersonId, t)),
                  ],
                  if (!ro)
                    SizedBox(
                      width: 40,
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        tooltip: isEnglish ? 'Remove' : 'ลบ',
                        onPressed: () => _remove(e.salespersonId),
                      ),
                    ),
                ]),
              ),
            if (_hasAmount) ...[
            const Divider(height: 8),
            Row(children: [
              if (widget.showPrimary) const SizedBox(width: 36),
              Expanded(child: Text(isEnglish ? 'Total' : 'รวม', style: head)),
              SizedBox(
                width: 90,
                child: Text('${_fmtPct.format(sumPct)}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold, color: pctOver ? Colors.red : null)),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 130,
                child: Text(_fmtAmt.format(sumAmt),
                    textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              if (!ro) const SizedBox(width: 40),
            ]),
            if (pctOver)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(isEnglish ? 'Total share exceeds 100%' : 'สัดส่วนรวมเกิน 100%',
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            ],
          ],
          if (!ro)
            Row(children: [
              TextButton.icon(
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: Text(isEnglish ? 'Add salesperson' : 'เพิ่มพนักงานขาย'),
                onPressed: _add,
              ),
              if (_hasAmount && items.length > 1)
                TextButton.icon(
                  icon: const Icon(Icons.call_split, size: 18),
                  label: Text(isEnglish ? 'Split evenly' : 'แบ่งเท่ากัน'),
                  onPressed: _splitEvenly,
                ),
            ]),
        ],
      ),
    );
  }
}
