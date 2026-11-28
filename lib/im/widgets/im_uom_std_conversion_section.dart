// lib/im/widgets/im_uom_std_conversion_section.dart
// ส่วน "อัตราแปลงมาตรฐาน" ในหน้ารายละเอียดหน่วยนับ — แปลงกับหน่วยประเภทเดียวกัน โดยไม่ขึ้นกับสินค้า
// เช่น 1 กิโลกรัม = 1,000 กรัม, 1 โหล = 12 ชิ้น
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../models/im_uom.dart';
import '../models/im_uom_standard_conversion.dart';
import '../services/im_uom_service.dart';
import 'im_master_kit.dart';

class ImUomStdConversionSection extends StatefulWidget {
  final ImUom uom; // หน่วยที่บันทึกแล้ว (ใช้ประเภทหน่วยที่บันทึกไว้)
  final bool readOnly;

  const ImUomStdConversionSection({super.key, required this.uom, required this.readOnly});

  @override
  State<ImUomStdConversionSection> createState() => _ImUomStdConversionSectionState();
}

class _ImUomStdConversionSectionState extends State<ImUomStdConversionSection> with ImMasterKit {
  bool _isEnglish = false;
  @override
  bool get kitEnglish => _isEnglish;
  @override
  bool get kitReadOnly => widget.readOnly;

  final _service = ImUomService();
  static final _fmt = NumberFormat('#,##0.######');
  List<ImUomStandardConversion> _rows = [];
  List<ImUom> _uoms = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ImUomStdConversionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uom.id != widget.uom.id || oldWidget.uom.uomDimension != widget.uom.uomDimension) _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _service.fetchStdConversions(uomId: widget.uom.id),
        _service.fetchActiveRows(),
      ]);
      if (!mounted) return;
      setState(() {
        _rows = results[0] as List<ImUomStandardConversion>;
        _uoms = results[1] as List<ImUom>;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null));
  }

  // แสดงจากมุมของหน่วยนี้เสมอ: 1 [หน่วยนี้] = x [อีกหน่วย]
  ({String other, double factor}) _view(ImUomStandardConversion r, bool isEnglish) {
    if (r.fromUomId == widget.uom.id) {
      return (other: '${r.toUomCode} ${r.toName(isEnglish)}', factor: r.conversionFactor);
    }
    return (other: '${r.fromUomCode} ${r.fromName(isEnglish)}', factor: 1 / r.conversionFactor);
  }

  Future<void> _edit(ImUomStandardConversion? existing) async {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    final l = AppL10n(isEnglish);
    final usedIds = _rows
        .where((r) => r.id != existing?.id)
        .map((r) => r.fromUomId == widget.uom.id ? r.toUomId : r.fromUomId)
        .toSet();
    final candidates = _uoms
        .where((u) => u.id != widget.uom.id && u.uomDimension == widget.uom.uomDimension && !usedIds.contains(u.id))
        .toList();
    int? otherId = existing == null ? null : (existing.fromUomId == widget.uom.id ? existing.toUomId : existing.fromUomId);
    // ป้อนในรูป "1 หน่วยนี้ = x หน่วยอื่น" เสมอ — ถ้าบันทึกไว้อีกทิศ แปลงกลับให้
    final initFactor = existing == null ? null : _view(existing, isEnglish).factor;
    final factorCtrl = TextEditingController(text: initFactor == null ? '' : _fmt.format(initFactor).replaceAll(',', ''));
    final formKey = GlobalKey<FormState>();

    if (candidates.isEmpty && existing == null) {
      _snack(isEnglish
          ? 'No other active ${uomDimensionLabel(widget.uom.uomDimension, true).toLowerCase()} unit to convert to'
          : 'ไม่มีหน่วยประเภท${uomDimensionLabel(widget.uom.uomDimension, false)}อื่นที่ใช้งานอยู่ให้แปลง');
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(existing == null
              ? (isEnglish ? 'Add Standard Conversion' : 'เพิ่มอัตราแปลงมาตรฐาน')
              : (isEnglish ? 'Edit Standard Conversion' : 'แก้ไขอัตราแปลงมาตรฐาน')),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text('1 ${widget.uom.displayName(isEnglish)} =', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 110,
                  child: TextFormField(
                    controller: factorCtrl,
                    autofocus: true,
                    textAlign: TextAlign.right,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                    decoration: InputDecoration(labelText: isEnglish ? 'Factor' : 'อัตรา', border: const OutlineInputBorder(), isDense: true),
                    validator: (v) {
                      final d = double.tryParse(v ?? '');
                      if (d == null || d <= 0) return isEnglish ? '> 0' : 'ต้อง > 0';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: otherId,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: isEnglish ? 'Unit' : 'หน่วย', border: const OutlineInputBorder(), isDense: true),
                    items: [
                      ...candidates.map((u) => DropdownMenuItem(value: u.id, child: Text('${u.uomCode} ${u.displayName(isEnglish)}', overflow: TextOverflow.ellipsis))),
                      // หน่วยเดิมที่ตอนนี้หยุดใช้ ยังต้องแสดงในรายการเพื่อแก้อัตราได้
                      if (otherId != null && !candidates.any((u) => u.id == otherId))
                        DropdownMenuItem(value: otherId, child: Text(existing == null ? '' : _view(existing, isEnglish).other, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setDlg(() => otherId = v),
                    validator: (v) => v == null ? (isEnglish ? 'Select a unit' : 'เลือกหน่วย') : null,
                  ),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  await _service.saveStdConversion(ImUomStandardConversion(
                    id: existing?.id ?? 0,
                    fromUomId: widget.uom.id,
                    toUomId: otherId!,
                    conversionFactor: double.parse(factorCtrl.text),
                  ));
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: Colors.red));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
    factorCtrl.dispose();
    if (saved == true) _load();
  }

  Future<void> _delete(ImUomStandardConversion r) async {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    final l = AppL10n(isEnglish);
    final v = _view(r, isEnglish);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEnglish ? 'Delete Conversion' : 'ลบอัตราแปลง'),
        content: Text('1 ${widget.uom.displayName(isEnglish)} = ${_fmt.format(v.factor)} ${v.other}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEnglish ? 'Delete' : 'ลบ', style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.deleteStdConversion(r.id);
      _load();
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  // การ์ดแบบหน้าจอข้อมูลหลัก IM (user 2026-11-25) — บันทึกทันทีผ่าน API แยก (ไม่รอปุ่มบันทึกของหน่วยนับ)
  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final name = widget.uom.displayName(isEnglish);
    Widget body;
    if (_loading) {
      body = const Padding(padding: EdgeInsets.all(14), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))));
    } else if (_error != null) {
      body = Padding(padding: const EdgeInsets.all(14), child: Text(_error!, style: const TextStyle(color: Colors.red)));
    } else {
      body = kTable([
        KCol(isEnglish ? 'Unit' : 'หน่วย', 4),
        KCol(isEnglish ? 'Factor' : 'อัตรา', 2, num: true),
        KCol(isEnglish ? 'Meaning' : 'ความหมาย', 5),
        if (!widget.readOnly) const KCol('', 2, num: true),
      ], [
        for (final r in _rows)
          () {
            final v = _view(r, isEnglish);
            return <Widget>[
              kCell(v.other),
              kCell(_fmt.format(v.factor), mono: true),
              kCell('1 $name = ${_fmt.format(v.factor)} ${v.other}'),
              if (!widget.readOnly)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  kIconBtn(Icons.edit, isEnglish ? 'Edit' : 'แก้ไข', () => _edit(r)),
                  kIconBtn(Icons.delete, isEnglish ? 'Delete' : 'ลบ', () => _delete(r), color: Colors.red),
                ]),
            ];
          }(),
      ],
          onTap: widget.readOnly ? null : [for (final r in _rows) () => _edit(r)],
          minWidth: 560,
          empty: isEnglish
              ? 'None. Example: 1 kilogram = 1,000 grams, 1 dozen = 12 pieces. Units of the same type only.'
              : 'ยังไม่มี ตัวอย่าง: 1 กิโลกรัม = 1,000 กรัม, 1 โหล = 12 ชิ้น (แปลงได้เฉพาะหน่วยประเภทเดียวกัน)');
    }
    return kCard(
      title: isEnglish ? 'Standard Conversions' : 'อัตราแปลงมาตรฐาน',
      count: isEnglish ? 'All items · ${_rows.length} row(s)' : 'ใช้กับทุกสินค้า · ${_rows.length} รายการ',
      trailing: widget.readOnly ? null : kGhost(isEnglish ? 'Add conversion' : 'เพิ่มอัตราแปลง', Icons.add, _loading ? null : () => _edit(null)),
      padding: EdgeInsets.zero,
      child: body,
    );
  }
}
