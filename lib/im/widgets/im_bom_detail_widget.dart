import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../models/im_bom.dart';
import '../models/im_item.dart';
import '../models/im_uom.dart';
import '../widgets/im_item_list_widget.dart';
import '../widgets/im_uom_list_widget.dart';

// ---------------------------------------------------------------------------
// Collapsible section — same look used across the other IM detail widgets
// ---------------------------------------------------------------------------
class _Section extends StatefulWidget {
  final String title;
  final bool initiallyExpanded;
  final List<Widget> children;
  final Widget? trailing;

  const _Section({required this.title, this.initiallyExpanded = true, required this.children, this.trailing});

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            color: Colors.blueGrey.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.blueGrey.shade600),
              const SizedBox(width: 6),
              Expanded(child: Text(widget.title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800))),
              if (widget.trailing != null) widget.trailing!,
            ]),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: widget.children),
          ),
        const Divider(height: 1),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Add/Edit component dialog
// ---------------------------------------------------------------------------
Future<ImBomDetail?> _showComponentDialog(BuildContext context, ImBomDetail? existing) async {
  final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
  int? componentItemId = existing?.componentItemId;
  String? componentItemCode = existing?.componentItemCode;
  String? componentItemName = isEnglish && (existing?.componentItemNameEn ?? '').isNotEmpty
      ? existing?.componentItemNameEn
      : existing?.componentItemNameTh;
  int? uomId = existing?.uomId;
  String? uomCode = existing?.uomCode;
  String? uomName = isEnglish && (existing?.uomNameEn ?? '').isNotEmpty ? existing?.uomNameEn : existing?.uomNameTh;
  final qtyCtrl = TextEditingController(text: existing != null ? '${existing.quantityPer}' : '1');
  final scrapCtrl = TextEditingController(text: existing != null ? '${existing.scrapPercent}' : '0');

  return showDialog<ImBomDetail>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
      Widget buildFkField({required String label, required String? displayText, required bool hasValue, required VoidCallback onSearch}) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InputDecorator(
              decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              child: Row(children: [
                Expanded(
                  child: hasValue
                      ? Text(displayText ?? '', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)
                      : Text(isEnglish ? '— Not specified —' : '— ไม่ระบุ —', style: TextStyle(color: Colors.grey.shade600)),
                ),
                IconButton(icon: const Icon(Icons.search, color: Colors.teal), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onSearch),
              ]),
            ),
          );

      return AlertDialog(
        title: Text(existing == null ? (isEnglish ? 'Add Component' : 'เพิ่มส่วนประกอบ') : (isEnglish ? 'Edit Component' : 'แก้ไขส่วนประกอบ')),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildFkField(
                label: isEnglish ? 'Component Item *' : 'สินค้าส่วนประกอบ *',
                hasValue: componentItemId != null,
                displayText: '$componentItemCode — $componentItemName',
                onSearch: () => ImItemListWidget.search(ctx, onSelected: (ImItem i) {
                  setDlg(() {
                    componentItemId = i.id; componentItemCode = i.itemCode;
                    componentItemName = isEnglish && (i.itemNameEn ?? '').isNotEmpty ? i.itemNameEn : i.itemNameTh;
                    if (uomId == null && i.baseUomId != null) {
                      uomId = i.baseUomId; uomCode = i.baseUomCode;
                      uomName = isEnglish && (i.baseUomNameEn ?? '').isNotEmpty ? i.baseUomNameEn : i.baseUomNameTh;
                    }
                  });
                }),
              ),
              Row(children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      decoration: InputDecoration(labelText: isEnglish ? 'Qty per unit *' : 'จำนวนต่อหน่วย *', border: const OutlineInputBorder()),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: buildFkField(
                    label: isEnglish ? 'UOM' : 'หน่วยนับ',
                    hasValue: uomId != null,
                    displayText: '$uomCode — $uomName',
                    onSearch: () => ImUomListWidget.search(ctx, onSelected: (ImUom u) {
                      setDlg(() {
                        uomId = u.id; uomCode = u.uomCode;
                        uomName = isEnglish && (u.uomNameEn ?? '').isNotEmpty ? u.uomNameEn : u.uomNameTh;
                      });
                    }),
                  ),
                ),
              ]),
              TextField(
                controller: scrapCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                decoration: InputDecoration(labelText: isEnglish ? 'Scrap %' : 'เปอร์เซ็นต์ของเสีย (%)', border: const OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(
            onPressed: () {
              if (componentItemId == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please select a component item' : 'กรุณาเลือกสินค้าส่วนประกอบ')));
                return;
              }
              Navigator.of(ctx).pop(ImBomDetail(
                id: existing?.id,
                bomHeaderId: existing?.bomHeaderId,
                lineNo: existing?.lineNo ?? 1,
                componentItemId: componentItemId!,
                componentItemCode: componentItemCode,
                componentItemNameTh: isEnglish ? null : componentItemName,
                componentItemNameEn: isEnglish ? componentItemName : null,
                quantityPer: double.tryParse(qtyCtrl.text) ?? 0,
                uomId: uomId,
                uomCode: uomCode,
                uomNameTh: isEnglish ? null : uomName,
                uomNameEn: isEnglish ? uomName : null,
                scrapPercent: double.tryParse(scrapCtrl.text) ?? 0,
              ));
            },
            child: Text(isEnglish ? 'OK' : 'ตกลง'),
          ),
        ],
      );
    }),
  );
}

class ImBomDetailWidget extends StatefulWidget {
  final Mode mode;
  final ImBomHeader? selected;
  final Future<void> Function(ImBomHeader) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;

  const ImBomDetailWidget({
    super.key,
    required this.mode,
    required this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
  });

  @override
  State<ImBomDetailWidget> createState() => ImBomDetailWidgetState();
}

class ImBomDetailWidgetState extends State<ImBomDetailWidget> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isEnglish = false;

  late TextEditingController _versionCtrl;
  late TextEditingController _bomQtyCtrl;

  bool _isActive = true;
  DateTime? _effectiveDate;

  int? _parentItemId; String? _parentItemCode; String? _parentItemName;
  int? _outputUomId; String? _outputUomCode; String? _outputUomName;

  List<ImBomDetail> _details = [];

  bool get _isReadOnly => widget.mode == Mode.view || widget.mode == Mode.none;

  @override
  void initState() {
    super.initState();
    _versionCtrl = TextEditingController(text: '1');
    _bomQtyCtrl = TextEditingController(text: '1');
    if (widget.selected != null) _populate(widget.selected!);
  }

  @override
  void didUpdateWidget(covariant ImBomDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected || widget.mode != oldWidget.mode) {
      if (widget.selected != null) {
        _populate(widget.selected!);
      } else {
        _clear();
      }
    }
  }

  @override
  void dispose() {
    _versionCtrl.dispose();
    _bomQtyCtrl.dispose();
    super.dispose();
  }

  void _populate(ImBomHeader h) {
    _versionCtrl.text = h.bomVersion;
    _bomQtyCtrl.text = '${h.bomQty}';
    _isActive = h.isActive;
    _effectiveDate = h.effectiveDate;
    _parentItemId = h.parentItemId; _parentItemCode = h.parentItemCode;
    _parentItemName = _isEnglish && (h.parentItemNameEn ?? '').isNotEmpty ? h.parentItemNameEn : h.parentItemNameTh;
    _outputUomId = h.outputUomId; _outputUomCode = h.outputUomCode;
    _outputUomName = _isEnglish && (h.outputUomNameEn ?? '').isNotEmpty ? h.outputUomNameEn : h.outputUomNameTh;
    _details = List.from(h.details);
  }

  void _clear() {
    _versionCtrl.text = '1';
    _bomQtyCtrl.text = '1';
    _isActive = true;
    _effectiveDate = null;
    _parentItemId = null; _parentItemCode = null; _parentItemName = null;
    _outputUomId = null; _outputUomCode = null; _outputUomName = null;
    _details = [];
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final isEnglish = _isEnglish;
    if (_parentItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please select the item to produce' : 'กรุณาเลือกสินค้าที่ผลิต')));
      return;
    }
    if (_details.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please add at least one component' : 'กรุณาเพิ่มส่วนประกอบอย่างน้อย 1 รายการ')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final header = ImBomHeader(
        id: widget.selected?.id,
        parentItemId: _parentItemId!,
        bomVersion: _versionCtrl.text.trim().isEmpty ? '1' : _versionCtrl.text.trim(),
        bomQty: double.tryParse(_bomQtyCtrl.text) ?? 1,
        outputUomId: _outputUomId,
        isActive: _isActive,
        effectiveDate: _effectiveDate,
        details: _details,
      );
      await widget.onSubmit(header);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickParentItem() async {
    final isEnglish = _isEnglish;
    await ImItemListWidget.search(context, itemTypeFilter: 'STOCK', onSelected: (ImItem i) {
      setState(() {
        _parentItemId = i.id; _parentItemCode = i.itemCode;
        _parentItemName = isEnglish && (i.itemNameEn ?? '').isNotEmpty ? i.itemNameEn : i.itemNameTh;
        if (_outputUomId == null && i.baseUomId != null) {
          _outputUomId = i.baseUomId; _outputUomCode = i.baseUomCode;
          _outputUomName = isEnglish && (i.baseUomNameEn ?? '').isNotEmpty ? i.baseUomNameEn : i.baseUomNameTh;
        }
      });
    });
  }

  Future<void> _pickOutputUom() async {
    final isEnglish = _isEnglish;
    await ImUomListWidget.search(context, onSelected: (ImUom u) {
      setState(() {
        _outputUomId = u.id; _outputUomCode = u.uomCode;
        _outputUomName = isEnglish && (u.uomNameEn ?? '').isNotEmpty ? u.uomNameEn : u.uomNameTh;
      });
    });
  }

  Future<void> _addComponent() async {
    final result = await _showComponentDialog(context, null);
    if (result != null) setState(() => _details.add(result));
  }

  Future<void> _editComponent(int index) async {
    final result = await _showComponentDialog(context, _details[index]);
    if (result != null) setState(() => _details[index] = result);
  }

  void _removeComponent(int index) => setState(() => _details.removeAt(index));

  Widget _buildFkField({required String label, required String? displayText, required bool hasValue, required VoidCallback onSearch, VoidCallback? onClear, bool locked = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          child: Row(children: [
            Expanded(
              child: hasValue
                  ? Row(children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text(displayText ?? '', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                    ])
                  : Text(_isEnglish ? '— Not specified —' : '— ไม่ระบุ —', style: TextStyle(color: Colors.grey.shade600)),
            ),
            if (!_isReadOnly && !locked) ...[
              IconButton(icon: const Icon(Icons.search, color: Colors.teal), tooltip: _isEnglish ? 'Search $label' : 'ค้นหา$label', padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onSearch),
              if (hasValue && onClear != null)
                IconButton(icon: const Icon(Icons.clear, color: Colors.red, size: 18), tooltip: _isEnglish ? 'Clear' : 'ล้าง', padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onClear),
            ],
          ]),
        ),
      );

  Widget _buildBasicSection() {
    final isEnglish = _isEnglish;
    final isLocked = _isReadOnly || widget.mode == Mode.edit;
    return _Section(title: isEnglish ? 'Basic Information' : 'ข้อมูลพื้นฐาน', children: [
      _buildFkField(
        label: isEnglish ? 'Item to Produce *' : 'สินค้าที่ผลิต *',
        hasValue: _parentItemId != null,
        displayText: '$_parentItemCode — $_parentItemName',
        onSearch: _pickParentItem,
        onClear: () => setState(() { _parentItemId = null; _parentItemCode = null; _parentItemName = null; }),
        locked: isLocked,
      ),
      Row(children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextFormField(
              readOnly: _isReadOnly,
              controller: _versionCtrl,
              decoration: InputDecoration(labelText: isEnglish ? 'Version' : 'เวอร์ชัน', border: const OutlineInputBorder()),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextFormField(
              readOnly: _isReadOnly,
              controller: _bomQtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              decoration: InputDecoration(labelText: isEnglish ? 'Output Qty (batch size)' : 'จำนวนผลผลิตต่อรอบ', border: const OutlineInputBorder()),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _buildFkField(
          label: isEnglish ? 'Output UOM' : 'หน่วยนับผลผลิต',
          hasValue: _outputUomId != null,
          displayText: '$_outputUomCode — $_outputUomName',
          onSearch: _pickOutputUom,
          onClear: () => setState(() { _outputUomId = null; _outputUomCode = null; _outputUomName = null; }),
        )),
      ]),
      InkWell(
        onTap: _isReadOnly ? null : () async {
          final picked = await showDatePicker(
            context: context, initialDate: _effectiveDate ?? DateTime.now(),
            firstDate: DateTime(2000), lastDate: DateTime(2100),
          );
          if (picked != null) setState(() => _effectiveDate = picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(labelText: isEnglish ? 'Effective Date' : 'วันที่มีผล', border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
          child: Text(_effectiveDate != null ? '${_effectiveDate!.day}/${_effectiveDate!.month}/${_effectiveDate!.year}' : (isEnglish ? '— Not specified —' : '— ไม่ระบุ —')),
        ),
      ),
      const SizedBox(height: 10),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(isEnglish ? 'Active (only one active version per item)' : 'ใช้งาน (แต่ละสินค้ามีสูตรที่ active ได้ทีละเวอร์ชัน)'),
        value: _isActive,
        activeColor: Colors.teal,
        onChanged: _isReadOnly ? null : (v) => setState(() => _isActive = v),
      ),
    ]);
  }

  Widget _buildComponentsSection() {
    final isEnglish = _isEnglish;
    return _Section(
      title: isEnglish ? 'Components (${_details.length})' : 'ส่วนประกอบ (${_details.length})',
      trailing: _isReadOnly ? null : IconButton(icon: const Icon(Icons.add_circle, color: Colors.teal), tooltip: isEnglish ? 'Add component' : 'เพิ่มส่วนประกอบ', onPressed: _addComponent),
      children: [
        if (_details.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(isEnglish ? 'No components yet' : 'ยังไม่มีส่วนประกอบ', style: TextStyle(color: Colors.grey.shade600)),
          )
        else
          ..._details.asMap().entries.map((entry) {
            final i = entry.key;
            final d = entry.value;
            final name = isEnglish && (d.componentItemNameEn ?? '').isNotEmpty ? d.componentItemNameEn : d.componentItemNameTh;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 3),
              child: ListTile(
                dense: true,
                leading: CircleAvatar(radius: 14, backgroundColor: Colors.teal.shade50, child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Colors.teal))),
                title: Text('${d.componentItemCode}  $name'),
                subtitle: Text(
                  isEnglish
                      ? 'Qty per unit: ${d.quantityPer} ${d.uomCode ?? ''}${d.scrapPercent > 0 ? '  ·  Scrap ${d.scrapPercent}%' : ''}'
                      : 'จำนวนต่อหน่วย: ${d.quantityPer} ${d.uomCode ?? ''}${d.scrapPercent > 0 ? '  ·  ของเสีย ${d.scrapPercent}%' : ''}',
                ),
                trailing: _isReadOnly
                    ? null
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _editComponent(i)),
                        IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _removeComponent(i)),
                      ]),
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = Provider.of<LanguageProvider>(context).isEnglish;
    _isEnglish = isEnglish;
    if (widget.isPlaceholder) {
      return Center(child: Text(isEnglish ? 'Select a BOM to view its data' : 'เลือกสูตรการผลิตเพื่อดูข้อมูล', style: const TextStyle(color: Colors.grey)));
    }

    return Form(
      key: _formKey,
      child: Column(children: [
        Container(
          color: Colors.teal[300],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Icon(Icons.precision_manufacturing, color: Colors.teal[900], size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.mode == Mode.add
                    ? (isEnglish ? 'Add BOM' : 'เพิ่มสูตรการผลิต')
                    : widget.mode == Mode.edit
                        ? (isEnglish ? 'Edit BOM' : 'แก้ไขสูตรการผลิต')
                        : (isEnglish ? 'BOM Information' : 'ข้อมูลสูตรการผลิต'),
                style: TextStyle(color: Colors.teal[900], fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            if (!_isReadOnly) ...[
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save, size: 16),
                label: Text(_isSaving ? (isEnglish ? 'Saving...' : 'กำลังบันทึก...') : (isEnglish ? 'Save' : 'บันทึก')),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[800], foregroundColor: Colors.white),
              ),
              const SizedBox(width: 8),
            ],
            TextButton(onPressed: widget.onCancel, child: Text(isEnglish ? 'Close' : 'ปิด', style: TextStyle(color: Colors.teal[900]))),
          ]),
        ),
        Expanded(
          child: ListView(children: [
            _buildBasicSection(),
            _buildComponentsSection(),
          ]),
        ),
      ]),
    );
  }
}
