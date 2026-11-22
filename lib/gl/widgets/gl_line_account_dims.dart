import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../sa/services/sa_language_provider.dart';
import '../models/gl_account.dart';
import '../models/gl_dimension.dart';
import '../services/gl_dimension_service.dart';
import 'gl_dimension_picker_field.dart';

// บัญชีที่ใช้ลงบัญชีและมิติของบรรทัดรายการเอกสาร (AR/AP/IM) — user-approved 2026-11-02
//   - บัญชีของบรรทัดเลือกได้ทุกบัญชีที่ลงรายการได้ (ไม่ใช่บัญชีคุม) ค่าเริ่มต้นจากการตั้งค่าของประเภทเอกสาร
//   - มิติของบรรทัด: ช่องที่ว่างใช้มิติหัวเอกสาร (backend utils/glDims.js lineDims)
//   - บัญชีที่ตั้งให้บังคับมิติ (gl_account_dim_rule) แต่บรรทัดและหัวเอกสารไม่มีค่า = แสดงเตือนสีแดง (backend ไม่ให้ Post)

/// ประเภทมิติที่เปิดใช้ + ค่าของแต่ละประเภท (type_code → values)
Future<(List<GlDimensionType>, Map<String, List<GlDimensionValue>>)> loadActiveDimensions() async {
  final svc = GlDimensionService();
  final types = await svc.fetchActiveTypes();
  final vals = await Future.wait(types.map((t) => svc.fetchValuesByType(t.typeCode)));
  return (types, {for (var i = 0; i < types.length; i++) types[i].typeCode: vals[i]});
}

/// แถวช่องมิติหัวเอกสาร (แสดงเฉพาะประเภทมิติที่เปิดใช้ — ไม่มีเลย = ไม่แสดง)
class GlHeaderDimsRow extends StatelessWidget {
  final List<GlDimensionType> dimTypes;
  final Map<String, List<GlDimensionValue>> dimValues;
  final Map<int, int?> selections;
  final bool readOnly;
  final void Function(int slot, int? valueId) onChanged;
  final Widget? trailing;

  const GlHeaderDimsRow({
    super.key,
    required this.dimTypes,
    required this.dimValues,
    required this.selections,
    required this.onChanged,
    this.readOnly = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    if (dimTypes.isEmpty) return const SizedBox.shrink();
    GlDimensionValue? sel(GlDimensionType t) {
      final id = selections[t.slotNo];
      for (final v in dimValues[t.typeCode] ?? const <GlDimensionValue>[]) {
        if (v.id == id) return v;
      }
      return null;
    }
    return Row(children: [
      for (final t in dimTypes) ...[
        Expanded(child: GlDimensionPickerField(
          dimType: t,
          values: dimValues[t.typeCode] ?? const [],
          selected: sel(t),
          readOnly: readOnly,
          onSelected: (v) => onChanged(t.slotNo, v?.id),
        )),
        const SizedBox(width: 8),
      ],
      if (trailing != null) Expanded(child: trailing!),
    ]);
  }
}

String _accName(Account a, bool isEnglish) =>
    isEnglish && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai;

Account? findAccount(List<Account> accounts, int? id) {
  if (id == null) return null;
  for (final a in accounts) {
    if (a.id == id) return a;
  }
  return null;
}

/// slot ของมิติที่บัญชีบังคับ (เฉพาะประเภทมิติที่เปิดใช้)
Set<int> requiredDimSlots(Account? account, List<GlDimensionType> dimTypes) {
  if (account == null) return {};
  final codes = account.dimRules.where((r) => r.isRequired).map((r) => r.typeCode).toSet();
  return dimTypes.where((t) => codes.contains(t.typeCode)).map((t) => t.slotNo).toSet();
}

/// มิติที่ใช้จริงของบรรทัด: ช่องที่ว่างใช้ของหัวเอกสาร
Map<int, int?> effectiveLineDims(Map<int, int?> lineDims, Map<int, int?> headerDims) =>
    {for (var i = 1; i <= 5; i++) i: lineDims[i] ?? headerDims[i]};

/// มิติที่บัญชีบังคับแต่ยังไม่มีค่า (ทั้งบรรทัดและหัวเอกสาร)
List<GlDimensionType> missingLineDims(Account? account, List<GlDimensionType> dimTypes,
    Map<int, int?> lineDims, Map<int, int?> headerDims) {
  final req = requiredDimSlots(account, dimTypes);
  final eff = effectiveLineDims(lineDims, headerDims);
  return dimTypes.where((t) => req.contains(t.slotNo) && eff[t.slotNo] == null).toList();
}

/// dialog เลือกบัญชีที่ใช้ลงบัญชีของบรรทัด — เฉพาะบัญชีลงรายการได้ ไม่ใช่บัญชีคุม
Future<Account?> showGlLineAccountPicker(BuildContext context, List<Account> accounts) {
  final isEnglish = context.read<LanguageProvider>().isEnglish;
  final searchCtrl = TextEditingController();
  final available = accounts.where((a) => a.isNormalAccount && !a.isControlAccount && a.isActive).toList()
    ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
  var filtered = List<Account>.from(available);
  return showDialog<Account>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      void doFilter() {
        final q = searchCtrl.text.toUpperCase();
        setS(() => filtered = q.isEmpty
            ? available
            : available.where((a) =>
                a.accountCode.toUpperCase().contains(q) ||
                a.accountNameThai.toUpperCase().contains(q) ||
                a.accountNameEng.toUpperCase().contains(q)).toList());
      }
      return Dialog(
        child: SizedBox(
          width: 520, height: 500,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: searchCtrl,
                decoration: InputDecoration(
                    labelText: isEnglish ? 'Search Account' : 'ค้นหาบัญชี',
                    prefixIcon: const Icon(Icons.search), border: const OutlineInputBorder()),
                onChanged: (_) => doFilter(),
                autofocus: true,
              ),
            ),
            Expanded(child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final a = filtered[i];
                return ListTile(
                  dense: true,
                  title: Text('${a.accountCode} - ${_accName(a, isEnglish)}', style: const TextStyle(fontSize: 13)),
                  trailing: a.dimRules.any((r) => r.isRequired)
                      ? Tooltip(
                          message: isEnglish ? 'Requires dimensions' : 'บัญชีนี้บังคับระบุมิติ',
                          child: const Icon(Icons.tune, size: 16, color: Colors.teal))
                      : null,
                  onTap: () => Navigator.pop(ctx, a),
                );
              },
            )),
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ]),
        ),
      );
    }),
  );
}

// แบบกล่อง (boxed): กรอบสูง 36 บรรทัดเดียว ตัวอักษร 13 — เท่ากับช่องอื่นในตารางรายการของ IM
const double _boxH = 36;
BoxDecoration _boxDeco({required bool readOnly, bool err = false}) => BoxDecoration(
      color: err ? const Color(0xFFFDECEA) : (readOnly ? const Color(0xFFEEF0F2) : Colors.white),
      border: Border.all(
          color: err ? const Color(0xFFC62828) : (readOnly ? const Color(0xFFC3C9D0) : Colors.grey.shade500), width: err ? 1.4 : 1),
      borderRadius: BorderRadius.circular(4),
    );

/// ช่องบัญชีที่ใช้ลงบัญชีของบรรทัด (กดเพื่อเลือก)
class GlLineAccountCell extends StatelessWidget {
  final List<Account> accounts;
  final int? accountId;
  final bool readOnly;
  final ValueChanged<Account> onChanged;
  final double width;
  final String? placeholder; // ข้อความเมื่อยังไม่เลือก (null = แจ้งให้เลือกบัญชี)
  final VoidCallback? onClear; // ล้างบัญชีที่เลือก (กลับไปใช้ค่าตั้งต้น)
  /// true = กรอบสูง 36 บรรทัดเดียว "รหัส ชื่อ" (ชื่อเต็มใน tooltip) / false = แบบเดิม 2 บรรทัดมีเส้นใต้
  final bool boxed;

  const GlLineAccountCell({
    super.key,
    required this.accounts,
    required this.accountId,
    required this.onChanged,
    this.readOnly = false,
    this.width = 150,
    this.placeholder,
    this.onClear,
    this.boxed = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final acc = findAccount(accounts, accountId);
    if (boxed) return _buildBoxed(context, isEnglish, acc);
    final content = acc == null
        ? Text(placeholder ?? (isEnglish ? '— Select —' : '— เลือกบัญชี —'),
            style: TextStyle(fontSize: 12, color: readOnly || placeholder != null ? Colors.grey : Colors.red[400],
                fontStyle: placeholder != null ? FontStyle.italic : FontStyle.normal))
        : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(acc.accountCode, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal[700])),
            Text(_accName(acc, isEnglish), style: const TextStyle(fontSize: 10, color: Colors.grey),
                overflow: TextOverflow.ellipsis),
          ]);
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: readOnly ? null : () async {
          final a = await showGlLineAccountPicker(context, accounts);
          if (a != null) onChanged(a);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 2),
          decoration: readOnly
              ? null
              : const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.teal, width: 1))),
          child: Row(children: [
            Expanded(child: content),
            if (!readOnly && acc != null && onClear != null)
              InkWell(onTap: onClear, child: const Icon(Icons.clear, size: 14, color: Colors.grey)),
            if (!readOnly) const Icon(Icons.search, size: 14, color: Colors.teal),
          ]),
        ),
      ),
    );
  }

  Widget _buildBoxed(BuildContext context, bool isEnglish, Account? acc) {
    final missing = acc == null && placeholder == null && !readOnly;
    final text = acc == null
        ? Text(placeholder ?? (isEnglish ? '— Select —' : '— เลือกบัญชี —'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: missing ? Colors.red[400] : Colors.grey.shade600,
                fontStyle: placeholder != null ? FontStyle.italic : FontStyle.normal))
        : Text.rich(
            TextSpan(children: [
              TextSpan(text: acc.accountCode, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal[700])),
              TextSpan(text: '  ${_accName(acc, isEnglish)}', style: const TextStyle(color: Color(0xFF4A5562))),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13));
    final box = SizedBox(
      width: width,
      child: InkWell(
        onTap: readOnly ? null : () async {
          final a = await showGlLineAccountPicker(context, accounts);
          if (a != null) onChanged(a);
        },
        child: Container(
          height: _boxH,
          padding: const EdgeInsets.only(left: 7, right: 4),
          decoration: _boxDeco(readOnly: readOnly, err: missing),
          child: Row(children: [
            Expanded(child: text),
            if (!readOnly && acc != null && onClear != null)
              InkWell(onTap: onClear, child: const Icon(Icons.clear, size: 14, color: Colors.grey)),
            if (!readOnly) const Icon(Icons.search, size: 16, color: Color(0xFF0F6E6E)),
          ]),
        ),
      ),
    );
    return acc == null ? box : Tooltip(message: '${acc.accountCode} — ${_accName(acc, isEnglish)}', child: box);
  }
}

/// ช่องมิติของบรรทัด: แสดงมิติที่ใช้จริง (ค่าจากหัวเอกสารเป็นตัวเอียงสีเทา) กดเพื่อแก้ในหน้าต่าง
class GlLineDimsCell extends StatelessWidget {
  final List<GlDimensionType> dimTypes;
  final Map<String, List<GlDimensionValue>> dimValues;
  final Map<int, int?> lineDims;
  final Map<int, int?> headerDims;
  final Account? account;
  final bool readOnly;
  final ValueChanged<Map<int, int?>> onChanged;
  final double width;
  /// true = กรอบสูง 36 บรรทัดเดียว "ค่า · ค่า" (ชื่อมิติ/ชื่อค่าเต็มใน tooltip) / false = แบบเดิมเรียงลงมีเส้นใต้
  final bool boxed;

  const GlLineDimsCell({
    super.key,
    required this.dimTypes,
    required this.dimValues,
    required this.lineDims,
    required this.headerDims,
    required this.account,
    required this.onChanged,
    this.readOnly = false,
    this.width = 140,
    this.boxed = false,
  });

  GlDimensionValue? _value(GlDimensionType t, int? id) {
    if (id == null) return null;
    for (final v in dimValues[t.typeCode] ?? const <GlDimensionValue>[]) {
      if (v.id == id) return v;
    }
    return null;
  }

  Future<void> _openDialog(BuildContext context) async {
    final isEnglish = context.read<LanguageProvider>().isEnglish;
    final req = requiredDimSlots(account, dimTypes);
    final work = Map<int, int?>.from(lineDims);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        title: Text(isEnglish ? 'Line Dimensions' : 'มิติของบรรทัด'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isEnglish
                    ? 'Leave blank to use the header dimension.'
                    : 'ช่องที่ว่างใช้มิติตามหัวเอกสาร',
                style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade600, fontStyle: FontStyle.italic)),
            const SizedBox(height: 12),
            for (final t in dimTypes) ...[
              Row(children: [
                Expanded(child: GlDimensionPickerField(
                  dimType: t,
                  values: dimValues[t.typeCode] ?? const [],
                  selected: _value(t, work[t.slotNo]),
                  onSelected: (v) => setS(() => work[t.slotNo] = v?.id),
                )),
                if (req.contains(t.slotNo))
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Tooltip(
                      message: isEnglish ? 'Required by the account' : 'บัญชีนี้บังคับระบุ',
                      child: Text('*', style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
              ]),
              if (work[t.slotNo] == null && _value(t, headerDims[t.slotNo]) != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 4),
                  child: Text(
                      '${isEnglish ? 'Header' : 'หัวเอกสาร'}: ${_value(t, headerDims[t.slotNo])!.valueCode} ${_dimValName(_value(t, headerDims[t.slotNo])!, isEnglish)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              const SizedBox(height: 10),
            ],
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEnglish ? 'OK' : 'ตกลง')),
        ],
      )),
    );
    if (ok == true) onChanged(work);
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final missing = missingLineDims(account, dimTypes, lineDims, headerDims);
    if (boxed) return _buildBoxed(context, isEnglish, missing);
    final parts = <Widget>[];
    for (final t in dimTypes) {
      final own = _value(t, lineDims[t.slotNo]);
      final inherited = own == null ? _value(t, headerDims[t.slotNo]) : null;
      final v = own ?? inherited;
      if (v == null) continue;
      parts.add(Text(v.valueCode,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 12,
              color: own != null ? Colors.teal[700] : Colors.grey,
              fontStyle: own != null ? FontStyle.normal : FontStyle.italic,
              fontWeight: own != null ? FontWeight.bold : FontWeight.normal)));
    }
    final body = Row(children: [
      Expanded(child: parts.isEmpty
          ? Text('—', style: TextStyle(fontSize: 12, color: Colors.grey[500]))
          : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: parts)),
      if (missing.isNotEmpty)
        Tooltip(
          message: '${isEnglish ? 'Required' : 'ต้องระบุ'}: ${missing.map((t) => isEnglish ? (t.nameEng ?? t.nameThai) : t.nameThai).join(', ')}',
          child: Icon(Icons.error_outline, size: 16, color: Colors.red[700]),
        )
      else if (!readOnly)
        const Icon(Icons.tune, size: 14, color: Colors.teal),
    ]);
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: readOnly ? null : () => _openDialog(context),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 2),
          decoration: readOnly
              ? null
              : BoxDecoration(border: Border(bottom: BorderSide(
                  color: missing.isNotEmpty ? Colors.red : Colors.teal, width: 1))),
          child: body,
        ),
      ),
    );
  }

  Widget _buildBoxed(BuildContext context, bool isEnglish, List<GlDimensionType> missing) {
    final spans = <InlineSpan>[];
    final tips = <String>[];
    for (final t in dimTypes) {
      final own = _value(t, lineDims[t.slotNo]);
      final inherited = own == null ? _value(t, headerDims[t.slotNo]) : null;
      final v = own ?? inherited;
      if (v == null) continue;
      if (spans.isNotEmpty) spans.add(const TextSpan(text: ' · ', style: TextStyle(color: Colors.grey)));
      spans.add(TextSpan(
          text: v.valueCode,
          style: TextStyle(
              color: own != null ? Colors.teal[700] : Colors.grey.shade600,
              fontStyle: own != null ? FontStyle.normal : FontStyle.italic,
              fontWeight: own != null ? FontWeight.bold : FontWeight.normal)));
      final typeName = isEnglish && (t.nameEng ?? '').isNotEmpty ? t.nameEng! : t.nameThai;
      tips.add('$typeName: ${v.valueCode} ${_dimValName(v, isEnglish)}'
          '${own == null ? (isEnglish ? ' (header)' : ' (ตามหัวเอกสาร)') : ''}');
    }
    if (missing.isNotEmpty) {
      tips.add('${isEnglish ? 'Required' : 'ต้องระบุ'}: ${missing.map((t) => isEnglish ? (t.nameEng ?? t.nameThai) : t.nameThai).join(', ')}');
    }
    final box = SizedBox(
      width: width,
      child: InkWell(
        onTap: readOnly ? null : () => _openDialog(context),
        child: Container(
          height: _boxH,
          padding: const EdgeInsets.only(left: 7, right: 4),
          decoration: _boxDeco(readOnly: readOnly, err: missing.isNotEmpty),
          child: Row(children: [
            Expanded(
              child: spans.isEmpty
                  ? Text('—', style: TextStyle(fontSize: 13, color: Colors.grey[500]))
                  : Text.rich(TextSpan(children: spans), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
            ),
            if (missing.isNotEmpty)
              Icon(Icons.error_outline, size: 16, color: Colors.red[700])
            else if (!readOnly)
              const Icon(Icons.tune, size: 16, color: Color(0xFF0F6E6E)),
          ]),
        ),
      ),
    );
    return tips.isEmpty ? box : Tooltip(message: tips.join('\n'), child: box);
  }
}

// ชื่อค่ามิติตามภาษา — ไม่มีชื่ออังกฤษ = ชื่อไทย
String _dimValName(GlDimensionValue v, bool isEnglish) =>
    isEnglish && (v.valueNameEng ?? '').isNotEmpty ? v.valueNameEng! : v.valueNameThai;
