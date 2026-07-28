// lib/cm/screens/cm_bank_file_format_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../models/cm_bank_file_format.dart';
import '../services/cm_bank_file_format_service.dart';

// ── Available field definitions ───────────────────────────────────────────────

class _FieldDef {
  final String code;
  final String label;
  final String type; // 'text' | 'date' | 'decimal' | 'integer' | 'constant'
  const _FieldDef(this.code, this.label, this.type);
}

const _availableFields = [
  _FieldDef('payment_date',     'วันที่ชำระ',                    'date'),
  _FieldDef('amount',           'จำนวนเงิน',                      'decimal'),
  _FieldDef('currency',         'สกุลเงิน',                       'text'),
  _FieldDef('vendor_code',      'รหัสเจ้าหนี้',                   'text'),
  _FieldDef('vendor_name',      'ชื่อเจ้าหนี้',                   'text'),
  _FieldDef('vendor_tax_id',    'เลขประจำตัวผู้เสียภาษี',         'text'),
  _FieldDef('bank_code',        'รหัสธนาคาร',                     'text'),
  _FieldDef('bank_branch_code', 'รหัสสาขาธนาคาร',                'text'),
  _FieldDef('account_number',   'เลขที่บัญชี',                    'text'),
  _FieldDef('account_name',     'ชื่อบัญชี',                      'text'),
  _FieldDef('reference',        'อ้างอิง',                        'text'),
  _FieldDef('doc_number',       'เลขที่เอกสาร',                   'text'),
  _FieldDef('sequence',         'ลำดับที่',                        'integer'),
  _FieldDef('company_code',     'รหัสบริษัท',                     'text'),
  _FieldDef('branch_code',      'รหัสสาขา',                       'text'),
  _FieldDef('constant',         'ค่าคงที่',                        'constant'),
];

_FieldDef _fieldDefOf(String code) =>
    _availableFields.firstWhere((f) => f.code == code,
        orElse: () => _FieldDef(code, code, 'text'));

Color _fieldColor(String type) {
  switch (type) {
    case 'date':     return Colors.teal;
    case 'decimal':  return Colors.orange[800]!;
    case 'integer':  return Colors.purple;
    case 'constant': return Colors.grey[700]!;
    default:         return Colors.blue[700]!;
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class CmBankFileFormatScreen extends StatefulWidget {
  const CmBankFileFormatScreen({super.key});

  @override
  State<CmBankFileFormatScreen> createState() => _CmBankFileFormatScreenState();
}

class _CmBankFileFormatScreenState extends State<CmBankFileFormatScreen>
    with AutomaticKeepAliveClientMixin {
  final _svc = CmBankFileFormatService();

  List<CmBankFileFormat> _rows = [];
  bool _loading = true;

  CmBankFileFormat? _selected;
  bool _isAdding = false;
  bool _isLeftExpanded = true;
  double _leftWidth = 300;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _svc.fetchRows();
      if (mounted) setState(() { _rows = rows; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onAdd() => setState(() { _selected = null; _isAdding = true; });

  void _onSelect(CmBankFileFormat row) async {
    setState(() { _selected = row; _isAdding = false; });
    try {
      final full = await _svc.fetchRow(row.id!);
      if (mounted) setState(() => _selected = full);
    } catch (_) {}
  }

  Future<void> _onDelete(CmBankFileFormat row) async {
    if (!(MenuScope.of(context)?.canDelete ?? true)) return;
    final l = AppL10n(Provider.of<LanguageProvider>(context, listen: false).isEnglish);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ลบรูปแบบไฟล์ "${row.formatName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l.delete, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.deleteRow(row.id!);
      if (mounted) {
        setState(() { _selected = null; _isAdding = false; });
        _load();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('ลบสำเร็จ')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _onSave(CmBankFileFormat row) async {
    final perm = MenuScope.of(context);
    if (!(row.id == null ? (perm?.canCreate ?? true) : (perm?.canEdit ?? true))) return;
    try {
      final saved = row.id == null
          ? await _svc.addRow(row)
          : await _svc.updateRow(row);
      if (mounted) {
        setState(() { _selected = saved; _isAdding = false; });
        _load();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('บันทึกสำเร็จ')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    }
  }

  void _onCancel() => setState(() { _selected = null; _isAdding = false; });

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), tooltip: 'รีเฟรช', onPressed: _load),
        ],
      ),
      body: LayoutBuilder(builder: (ctx, constraints) {
        final maxLeft =
            (constraints.maxWidth - 36 - 5 - 300).clamp(200.0, double.infinity);
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ── Collapse strip ─────────────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _isLeftExpanded = !_isLeftExpanded),
            child: Container(
              width: 36,
              color: Colors.teal[700],
              child: Center(
                child: Icon(
                  _isLeftExpanded ? Icons.chevron_left : Icons.chevron_right,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // ── Left panel ─────────────────────────────────────────────────
          if (_isLeftExpanded) ...[
            SizedBox(
              width: _leftWidth,
              child: Column(children: [
                Container(
                  color: Colors.teal.shade50,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(children: [
                    Expanded(
                      child: Text('รูปแบบไฟล์ (${_rows.length})',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal[800])),
                    ),
                    IconButton(
                      icon: Icon(Icons.add_circle, color: Colors.teal[700]),
                      tooltip: 'เพิ่มรูปแบบใหม่',
                      onPressed: (MenuScope.of(context)?.canCreate ?? true) ? _onAdd : null,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ]),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _rows.isEmpty
                          ? const Center(
                              child: Text('ยังไม่มีรูปแบบไฟล์',
                                  style: TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              itemCount: _rows.length,
                              itemBuilder: (_, i) {
                                final r = _rows[i];
                                final isSelected = _selected?.id == r.id;
                                return ListTile(
                                  dense: true,
                                  selected: isSelected,
                                  selectedTileColor: Colors.teal.shade50,
                                  title: Text(r.formatCode,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  subtitle: Text(r.formatName,
                                      overflow: TextOverflow.ellipsis),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 18, color: Colors.red),
                                    onPressed: () => _onDelete(r),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  onTap: () => _onSelect(r),
                                );
                              },
                            ),
                ),
              ]),
            ),
            // Resizable divider
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                onHorizontalDragUpdate: (d) => setState(() =>
                    _leftWidth = (_leftWidth + d.delta.dx).clamp(200.0, maxLeft)),
                child: Container(width: 5, color: Colors.grey[300]),
              ),
            ),
          ],
          // ── Right panel ────────────────────────────────────────────────
          Expanded(
            child: (_isAdding || _selected != null)
                ? _FormatDetailPanel(
                    key: ValueKey(_selected?.id ?? 'new'),
                    initial: _selected,
                    onSave: _onSave,
                    onCancel: _onCancel,
                  )
                : Center(
                    child: Text(
                      'เลือกรูปแบบหรือกด + เพื่อเพิ่มใหม่',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ),
          ),
        ]);
      }),
    );
  }
}

// ── Format detail panel ───────────────────────────────────────────────────────

class _FormatDetailPanel extends StatefulWidget {
  final CmBankFileFormat? initial;
  final Future<void> Function(CmBankFileFormat) onSave;
  final VoidCallback onCancel;

  const _FormatDetailPanel({
    super.key,
    required this.initial,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<_FormatDetailPanel> createState() => _FormatDetailPanelState();
}

class _FormatDetailPanelState extends State<_FormatDetailPanel> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _bankCodeCtrl;
  late TextEditingController _extCtrl;
  late TextEditingController _delimiterCtrl;
  bool _hasHeader = false;
  bool _hasFooter = false;
  bool _isActive = true;

  late List<_ColRow> _cols;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final f = widget.initial;
    _codeCtrl      = TextEditingController(text: f?.formatCode ?? '');
    _nameCtrl      = TextEditingController(text: f?.formatName ?? '');
    _bankCodeCtrl  = TextEditingController(text: f?.bankCode ?? '');
    _extCtrl       = TextEditingController(text: f?.fileExtension ?? 'txt');
    _delimiterCtrl = TextEditingController(text: f?.delimiter ?? '');
    _hasHeader = f?.hasHeader ?? false;
    _hasFooter = f?.hasFooter ?? false;
    _isActive  = f?.isActive  ?? true;
    _cols = (f?.columns ?? []).map((c) => _ColRow.fromModel(c)).toList();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _bankCodeCtrl.dispose();
    _extCtrl.dispose();
    _delimiterCtrl.dispose();
    for (final c in _cols) { c.dispose(); }
    super.dispose();
  }

  void _addField(_FieldDef def) {
    setState(() {
      _cols.add(_ColRow(
        fieldCode: def.code,
        labelCtrl: TextEditingController(text: def.label),
        lengthCtrl: TextEditingController(
            text: def.type == 'date'
                ? '8'
                : def.type == 'decimal'
                    ? '15'
                    : '20'),
        align: (def.type == 'decimal' || def.type == 'integer') ? 'R' : 'L',
        padChar: (def.type == 'decimal' || def.type == 'integer') ? '0' : ' ',
        dateFormat: 'YYYYMMDD',
        decimalPlaces: 2,
        constantValue: '',
      ));
    });
  }

  void _removeCol(int i) {
    setState(() {
      _cols[i].dispose();
      _cols.removeAt(i);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final format = CmBankFileFormat(
        id: widget.initial?.id,
        formatCode: _codeCtrl.text.trim(),
        formatName: _nameCtrl.text.trim(),
        bankCode:
            _bankCodeCtrl.text.trim().isEmpty ? null : _bankCodeCtrl.text.trim(),
        fileExtension:
            _extCtrl.text.trim().isEmpty ? 'txt' : _extCtrl.text.trim(),
        delimiter: _delimiterCtrl.text,
        hasHeader: _hasHeader,
        hasFooter: _hasFooter,
        isActive: _isActive,
        columns: _cols
            .map((c) => CmBankFileFormatColumn(
                  fieldCode: c.fieldCode,
                  columnLabel: c.labelCtrl.text,
                  length: int.tryParse(c.lengthCtrl.text) ?? 20,
                  align: c.align,
                  padChar: c.padChar.isEmpty ? ' ' : c.padChar,
                  dateFormat: c.dateFormat,
                  decimalPlaces: c.decimalPlaces,
                  constantValue:
                      c.constantValue.isEmpty ? null : c.constantValue,
                ))
            .toList(),
      );
      await widget.onSave(format);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isNew = widget.initial?.id == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header bar ────────────────────────────────────────────────
        Container(
          color: Colors.teal[300],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Row(children: [
            Expanded(
              child: Text(
                isNew
                    ? 'เพิ่มรูปแบบไฟล์ใหม่'
                    : 'แก้ไข: ${widget.initial?.formatCode}',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.teal))
                  : const Icon(Icons.save, size: 16),
              label: Text(
                  _isSaving ? 'กำลังบันทึก...' : isNew ? 'เพิ่ม' : 'บันทึก',
                  style: const TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.teal[900],
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: widget.onCancel,
              icon: const Icon(Icons.cancel, size: 16),
              label: const Text('ยกเลิก', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white54,
                foregroundColor: Colors.teal[900],
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ]),
        ),

        // ── Body ──────────────────────────────────────────────────────
        Expanded(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Basic info fields
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(children: [
                    Row(children: [
                      Flexible(
                        flex: 2,
                        child: TextFormField(
                          controller: _codeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'รหัสรูปแบบ *',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[A-Za-z0-9_\-]'))
                          ],
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'กรุณาป้อนรหัส' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        flex: 4,
                        child: TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'ชื่อรูปแบบ *',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'กรุณาป้อนชื่อ' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        flex: 2,
                        child: TextFormField(
                          controller: _bankCodeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'รหัสธนาคาร',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Flexible(
                        flex: 2,
                        child: TextFormField(
                          controller: _extCtrl,
                          decoration: const InputDecoration(
                            labelText: 'นามสกุลไฟล์',
                            hintText: 'txt',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        flex: 3,
                        child: TextFormField(
                          controller: _delimiterCtrl,
                          decoration: const InputDecoration(
                            labelText: 'ตัวคั่น (เว้นว่าง = Fixed-Width)',
                            hintText: ', หรือ | หรือ \\t',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        flex: 2,
                        child: _miniSwitch('Header', _hasHeader,
                            (v) => setState(() => _hasHeader = v)),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        flex: 2,
                        child: _miniSwitch('Footer', _hasFooter,
                            (v) => setState(() => _hasFooter = v)),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        flex: 2,
                        child: _miniSwitch('ใช้งาน', _isActive,
                            (v) => setState(() => _isActive = v)),
                      ),
                    ]),
                  ]),
                ),
                Divider(height: 1, color: Colors.grey.shade300),

                // ── Column drag-and-drop section ──────────────────────
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Available fields palette
                      Container(
                        width: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          border: Border(
                              right: BorderSide(color: Colors.grey.shade300)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              color: Colors.grey.shade200,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              child: const Text('ฟีลด์ที่มีอยู่',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(6),
                                child: Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: _availableFields.map((f) {
                                    return ActionChip(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 0),
                                      label: Text(f.label,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.white)),
                                      backgroundColor: _fieldColor(f.type),
                                      avatar: Icon(Icons.add,
                                          size: 14,
                                          color: Colors.white.withOpacity(0.8)),
                                      onPressed: () => _addField(f),
                                      visualDensity: VisualDensity.compact,
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Columns list (reorderable)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // List header row
                            Container(
                              color: Colors.teal.shade50,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              child: Row(children: [
                                const SizedBox(width: 28),
                                const SizedBox(width: 6),
                                SizedBox(
                                    width: 100,
                                    child: Text('ฟีลด์', style: _headerStyle())),
                                const SizedBox(width: 6),
                                Expanded(
                                    child: Text('ชื่อคอลัมน์',
                                        style: _headerStyle())),
                                const SizedBox(width: 6),
                                SizedBox(
                                    width: 60,
                                    child: Text('ความยาว',
                                        style: _headerStyle())),
                                const SizedBox(width: 6),
                                SizedBox(
                                    width: 60,
                                    child:
                                        Text('จัดชิด', style: _headerStyle())),
                                SizedBox(
                                    width: 60,
                                    child: Text('', style: _headerStyle())),
                                SizedBox(
                                    width: 32,
                                    child: Text('', style: _headerStyle())),
                              ]),
                            ),
                            // Reorderable list
                            Expanded(
                              child: _cols.isEmpty
                                  ? Center(
                                      child: Text(
                                        'คลิกฟีลด์ทางซ้ายเพื่อเพิ่มคอลัมน์',
                                        style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 13),
                                      ),
                                    )
                                  : ReorderableListView.builder(
                                      buildDefaultDragHandles: false,
                                      itemCount: _cols.length,
                                      onReorder: (oldIdx, newIdx) {
                                        setState(() {
                                          if (newIdx > oldIdx) newIdx--;
                                          final item = _cols.removeAt(oldIdx);
                                          _cols.insert(newIdx, item);
                                        });
                                      },
                                      itemBuilder: (ctx, i) =>
                                          _buildColRow(_cols[i], i),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  TextStyle _headerStyle() => TextStyle(
      fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal[800]);

  Widget _miniSwitch(
      String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildColRow(_ColRow col, int i) {
    final def = _fieldDefOf(col.fieldCode);
    final chipColor = _fieldColor(def.type);
    return Container(
      key: ValueKey('col_$i'),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        color: i.isEven ? Colors.white : Colors.grey.shade50,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle
          ReorderableDragStartListener(
            index: i,
            child: const Icon(Icons.drag_handle, size: 20, color: Colors.grey),
          ),
          const SizedBox(width: 6),
          // Field code chip
          Container(
            width: 100,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: chipColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: chipColor.withOpacity(0.4)),
            ),
            child: Text(
              def.label,
              style: TextStyle(
                  fontSize: 11,
                  color: chipColor,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          // Label
          Expanded(
            child: SizedBox(
              height: 32,
              child: TextFormField(
                controller: col.labelCtrl,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Length
          SizedBox(
            width: 60,
            height: 32,
            child: TextFormField(
              controller: col.lengthCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) => (v == null || v.isEmpty) ? '?' : null,
            ),
          ),
          const SizedBox(width: 6),
          // Align toggle
          SizedBox(
            width: 60,
            height: 32,
            child: ToggleButtons(
              isSelected: [col.align == 'L', col.align == 'R'],
              onPressed: (idx) =>
                  setState(() => col.align = idx == 0 ? 'L' : 'R'),
              constraints:
                  const BoxConstraints(minWidth: 28, minHeight: 32),
              textStyle: const TextStyle(fontSize: 11),
              children: const [Text('ซ้าย'), Text('ขวา')],
            ),
          ),
          // Settings icon
          SizedBox(
            width: 60,
            child: IconButton(
              icon: const Icon(Icons.tune, size: 18, color: Colors.blueGrey),
              tooltip: 'ตั้งค่าเพิ่มเติม',
              onPressed: () => _openColSettings(col),
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),
          // Delete
          SizedBox(
            width: 32,
            child: IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: Colors.red),
              onPressed: () => _removeCol(i),
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openColSettings(_ColRow col) async {
    final def = _fieldDefOf(col.fieldCode);
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ColSettingsDialog(col: col, fieldDef: def),
    );
    setState(() {});
  }
}

// ── Column settings dialog ────────────────────────────────────────────────────

class _ColSettingsDialog extends StatefulWidget {
  final _ColRow col;
  final _FieldDef fieldDef;
  const _ColSettingsDialog({required this.col, required this.fieldDef});

  @override
  State<_ColSettingsDialog> createState() => _ColSettingsDialogState();
}

class _ColSettingsDialogState extends State<_ColSettingsDialog> {
  late TextEditingController _padCtrl;
  late TextEditingController _constCtrl;

  @override
  void initState() {
    super.initState();
    _padCtrl   = TextEditingController(text: widget.col.padChar);
    _constCtrl = TextEditingController(text: widget.col.constantValue);
  }

  @override
  void dispose() {
    _padCtrl.dispose();
    _constCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n(Provider.of<LanguageProvider>(context, listen: false).isEnglish);
    final col = widget.col;
    final def = widget.fieldDef;
    return AlertDialog(
      title: Text('ตั้งค่า: ${def.label}'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _padCtrl,
              maxLength: 1,
              decoration: const InputDecoration(
                labelText: 'อักษรเติม (Pad)',
                hintText: 'เว้นว่าง = space, 0 = ศูนย์',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              onChanged: (v) => col.padChar = v,
            ),
            const SizedBox(height: 12),
            if (def.type == 'date') ...[
              DropdownButtonFormField<String>(
                value: col.dateFormat,
                decoration: const InputDecoration(
                    labelText: 'รูปแบบวันที่', border: OutlineInputBorder()),
                items: [
                  'YYYYMMDD',
                  'DDMMYYYY',
                  'MMDDYYYY',
                  'DD/MM/YYYY',
                  'YYYY-MM-DD',
                  'YYYYMM'
                ].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => col.dateFormat = v);
                },
              ),
              const SizedBox(height: 12),
            ],
            if (def.type == 'decimal') ...[
              DropdownButtonFormField<int>(
                value: col.decimalPlaces,
                decoration: const InputDecoration(
                    labelText: 'ทศนิยม', border: OutlineInputBorder()),
                items: [0, 1, 2, 3, 4]
                    .map((d) =>
                        DropdownMenuItem(value: d, child: Text('$d ตำแหน่ง')))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => col.decimalPlaces = v);
                },
              ),
              const SizedBox(height: 12),
            ],
            if (def.type == 'constant') ...[
              TextField(
                controller: _constCtrl,
                decoration: const InputDecoration(
                    labelText: 'ค่าคงที่', border: OutlineInputBorder()),
                onChanged: (v) => col.constantValue = v,
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.close),
        ),
      ],
    );
  }
}

// ── Mutable column row state ──────────────────────────────────────────────────

class _ColRow {
  String fieldCode;
  TextEditingController labelCtrl;
  TextEditingController lengthCtrl;
  String align;
  String padChar;
  String dateFormat;
  int decimalPlaces;
  String constantValue;

  _ColRow({
    required this.fieldCode,
    required this.labelCtrl,
    required this.lengthCtrl,
    required this.align,
    required this.padChar,
    required this.dateFormat,
    required this.decimalPlaces,
    required this.constantValue,
  });

  factory _ColRow.fromModel(CmBankFileFormatColumn c) => _ColRow(
        fieldCode:     c.fieldCode,
        labelCtrl:     TextEditingController(text: c.columnLabel),
        lengthCtrl:    TextEditingController(text: c.length.toString()),
        align:         c.align,
        padChar:       c.padChar,
        dateFormat:    c.dateFormat,
        decimalPlaces: c.decimalPlaces,
        constantValue: c.constantValue ?? '',
      );

  void dispose() {
    labelCtrl.dispose();
    lengthCtrl.dispose();
  }
}
