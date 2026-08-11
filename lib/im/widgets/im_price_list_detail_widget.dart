import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../cd/models/cd_currency.dart';
import '../../cd/widgets/cd_currency_list_widget.dart';
import '../models/im_price_list.dart';
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
// Add/Edit price line dialog
// ---------------------------------------------------------------------------
Future<ImPriceListDetail?> _showPriceLineDialog(BuildContext context, ImPriceListDetail? existing) async {
  final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
  int? itemId = existing?.itemId;
  String? itemCode = existing?.itemCode;
  String? itemName = isEnglish && (existing?.itemNameEn ?? '').isNotEmpty ? existing?.itemNameEn : existing?.itemNameTh;
  int? uomId = existing?.uomId;
  String? uomCode = existing?.uomCode;
  String? uomName = isEnglish && (existing?.uomNameEn ?? '').isNotEmpty ? existing?.uomNameEn : existing?.uomNameTh;
  DateTime? effectiveFrom = existing?.effectiveFrom;
  DateTime? effectiveTo = existing?.effectiveTo;
  final minQtyCtrl = TextEditingController(text: existing != null ? '${existing.minQty}' : '0');
  final priceCtrl = TextEditingController(text: existing != null ? '${existing.unitPriceFc}' : '0');

  String fmtDate(DateTime? d) => d == null ? (isEnglish ? '— Not specified —' : '— ไม่ระบุ —') : '${d.day}/${d.month}/${d.year}';

  return showDialog<ImPriceListDetail>(
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
        title: Text(existing == null ? (isEnglish ? 'Add Price Line' : 'เพิ่มรายการราคา') : (isEnglish ? 'Edit Price Line' : 'แก้ไขรายการราคา')),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildFkField(
                  label: isEnglish ? 'Item *' : 'สินค้า *',
                  hasValue: itemId != null,
                  displayText: '$itemCode — $itemName',
                  onSearch: () => ImItemListWidget.search(ctx, onSelected: (ImItem i) {
                    setDlg(() {
                      itemId = i.id; itemCode = i.itemCode;
                      itemName = isEnglish && (i.itemNameEn ?? '').isNotEmpty ? i.itemNameEn : i.itemNameTh;
                      if (uomId == null && i.baseUomId != null) {
                        uomId = i.baseUomId; uomCode = i.baseUomCode;
                        uomName = isEnglish && (i.baseUomNameEn ?? '').isNotEmpty ? i.baseUomNameEn : i.baseUomNameTh;
                      }
                    });
                  }),
                ),
                Row(children: [
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
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: minQtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                        decoration: InputDecoration(labelText: isEnglish ? 'Min Qty' : 'จำนวนขั้นต่ำ', border: const OutlineInputBorder()),
                      ),
                    ),
                  ),
                ]),
                TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  decoration: InputDecoration(labelText: isEnglish ? 'Unit Price *' : 'ราคาต่อหน่วย *', border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(context: ctx, initialDate: effectiveFrom ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                        if (picked != null) setDlg(() => effectiveFrom = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(labelText: isEnglish ? 'Effective From' : 'มีผลตั้งแต่', border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                        child: Text(fmtDate(effectiveFrom)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(context: ctx, initialDate: effectiveTo ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                        if (picked != null) setDlg(() => effectiveTo = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(labelText: isEnglish ? 'Effective To' : 'มีผลถึง', border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                        child: Text(fmtDate(effectiveTo)),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(
            onPressed: () {
              if (itemId == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please select an item' : 'กรุณาเลือกสินค้า')));
                return;
              }
              Navigator.of(ctx).pop(ImPriceListDetail(
                id: existing?.id,
                priceListId: existing?.priceListId,
                itemId: itemId!,
                itemCode: itemCode,
                itemNameTh: isEnglish ? null : itemName,
                itemNameEn: isEnglish ? itemName : null,
                uomId: uomId,
                uomCode: uomCode,
                uomNameTh: isEnglish ? null : uomName,
                uomNameEn: isEnglish ? uomName : null,
                minQty: double.tryParse(minQtyCtrl.text) ?? 0,
                unitPriceFc: double.tryParse(priceCtrl.text) ?? 0,
                effectiveFrom: effectiveFrom,
                effectiveTo: effectiveTo,
              ));
            },
            child: Text(isEnglish ? 'OK' : 'ตกลง'),
          ),
        ],
      );
    }),
  );
}

class ImPriceListDetailWidget extends StatefulWidget {
  final Mode mode;
  final ImPriceListHeader? selected;
  final Future<void> Function(ImPriceListHeader) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;

  const ImPriceListDetailWidget({
    super.key,
    required this.mode,
    required this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
  });

  @override
  State<ImPriceListDetailWidget> createState() => ImPriceListDetailWidgetState();
}

class ImPriceListDetailWidgetState extends State<ImPriceListDetailWidget> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isEnglish = false;

  late TextEditingController _codeCtrl;
  late TextEditingController _nameCtrl;

  bool _isActive = true;
  String _listType = 'SALES';

  int? _currencyId; String? _currencyCode; String? _currencyName;

  List<ImPriceListDetail> _details = [];

  bool get _isReadOnly => widget.mode == Mode.view || widget.mode == Mode.none;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController();
    _nameCtrl = TextEditingController();
    if (widget.selected != null) _populate(widget.selected!);
  }

  @override
  void didUpdateWidget(covariant ImPriceListDetailWidget oldWidget) {
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
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _populate(ImPriceListHeader h) {
    _codeCtrl.text = h.priceListCode;
    _nameCtrl.text = h.priceListName;
    _isActive = h.isActive;
    _listType = h.listType;
    _currencyId = h.currencyId; _currencyCode = h.currencyCode;
    _currencyName = _isEnglish && (h.currencyNameEn ?? '').isNotEmpty ? h.currencyNameEn : h.currencyNameTh;
    _details = List.from(h.details);
  }

  void _clear() {
    _codeCtrl.clear();
    _nameCtrl.clear();
    _isActive = true;
    _listType = 'SALES';
    _currencyId = null; _currencyCode = null; _currencyName = null;
    _details = [];
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final isEnglish = _isEnglish;
    if (_details.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please add at least one price line' : 'กรุณาเพิ่มรายการราคาอย่างน้อย 1 รายการ')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final header = ImPriceListHeader(
        id: widget.selected?.id,
        priceListCode: _codeCtrl.text.trim().toUpperCase(),
        priceListName: _nameCtrl.text.trim(),
        listType: _listType,
        currencyId: _currencyId,
        isActive: _isActive,
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

  Future<void> _pickCurrency() async {
    final isEnglish = _isEnglish;
    await CurrencyListWidget.search(context, onSelected: (Currency c) {
      setState(() {
        _currencyId = c.id; _currencyCode = c.currencyCode;
        _currencyName = isEnglish && c.currencyNameEng.isNotEmpty ? c.currencyNameEng : c.currencyNameThai;
      });
    });
  }

  Future<void> _addLine() async {
    final result = await _showPriceLineDialog(context, null);
    if (result != null) setState(() => _details.add(result));
  }

  Future<void> _editLine(int index) async {
    final result = await _showPriceLineDialog(context, _details[index]);
    if (result != null) setState(() => _details[index] = result);
  }

  void _removeLine(int index) => setState(() => _details.removeAt(index));

  Widget _buildFkField({required String label, required String? displayText, required bool hasValue, required VoidCallback onSearch, VoidCallback? onClear}) =>
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
            if (!_isReadOnly) ...[
              IconButton(icon: const Icon(Icons.search, color: Colors.teal), tooltip: _isEnglish ? 'Search $label' : 'ค้นหา$label', padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onSearch),
              if (hasValue && onClear != null)
                IconButton(icon: const Icon(Icons.clear, color: Colors.red, size: 18), tooltip: _isEnglish ? 'Clear' : 'ล้าง', padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onClear),
            ],
          ]),
        ),
      );

  Widget _buildBasicSection() {
    final isEnglish = _isEnglish;
    return _Section(title: isEnglish ? 'Basic Information' : 'ข้อมูลพื้นฐาน', children: [
      Row(children: [
        Expanded(
          child: TextFormField(
            readOnly: _isReadOnly || widget.mode == Mode.edit,
            controller: _codeCtrl,
            style: const TextStyle(fontWeight: FontWeight.bold),
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(labelText: isEnglish ? 'Price List Code *' : 'รหัสตารางราคา *', border: const OutlineInputBorder()),
            validator: (v) => (v == null || v.trim().isEmpty) ? (isEnglish ? 'Please enter the price list code' : 'กรุณาป้อนรหัสตารางราคา') : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: TextFormField(
            readOnly: _isReadOnly,
            controller: _nameCtrl,
            decoration: InputDecoration(labelText: isEnglish ? 'Price List Name *' : 'ชื่อตารางราคา *', border: const OutlineInputBorder()),
            validator: (v) => (v == null || v.trim().isEmpty) ? (isEnglish ? 'Please enter the price list name' : 'กรุณาป้อนชื่อตารางราคา') : null,
          ),
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _listType,
            isExpanded: true,
            decoration: InputDecoration(labelText: isEnglish ? 'List Type' : 'ประเภทตารางราคา', border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            items: imPriceListTypes.map((t) => DropdownMenuItem(value: t, child: Text(imPriceListTypeLabel(t, isEnglish)))).toList(),
            onChanged: _isReadOnly ? null : (v) => setState(() => _listType = v ?? 'SALES'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _buildFkField(
          label: isEnglish ? 'Currency' : 'สกุลเงิน',
          hasValue: _currencyId != null,
          displayText: '$_currencyCode — $_currencyName',
          onSearch: _pickCurrency,
          onClear: () => setState(() { _currencyId = null; _currencyCode = null; _currencyName = null; }),
        )),
      ]),
      const SizedBox(height: 10),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(isEnglish ? 'Active' : 'ใช้งาน'),
        value: _isActive,
        activeColor: Colors.teal,
        onChanged: _isReadOnly ? null : (v) => setState(() => _isActive = v),
      ),
    ]);
  }

  Widget _buildLinesSection() {
    final isEnglish = _isEnglish;
    return _Section(
      title: isEnglish ? 'Price Lines (${_details.length})' : 'รายการราคา (${_details.length})',
      trailing: _isReadOnly ? null : IconButton(icon: const Icon(Icons.add_circle, color: Colors.teal), tooltip: isEnglish ? 'Add price line' : 'เพิ่มรายการราคา', onPressed: _addLine),
      children: [
        if (_details.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(isEnglish ? 'No price lines yet' : 'ยังไม่มีรายการราคา', style: TextStyle(color: Colors.grey.shade600)),
          )
        else
          ..._details.asMap().entries.map((entry) {
            final i = entry.key;
            final d = entry.value;
            final name = isEnglish && (d.itemNameEn ?? '').isNotEmpty ? d.itemNameEn : d.itemNameTh;
            final rangeText = (d.effectiveFrom != null || d.effectiveTo != null)
                ? '  ·  ${d.effectiveFrom != null ? '${d.effectiveFrom!.day}/${d.effectiveFrom!.month}/${d.effectiveFrom!.year}' : '…'} - ${d.effectiveTo != null ? '${d.effectiveTo!.day}/${d.effectiveTo!.month}/${d.effectiveTo!.year}' : '…'}'
                : '';
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 3),
              child: ListTile(
                dense: true,
                leading: CircleAvatar(radius: 14, backgroundColor: Colors.teal.shade50, child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Colors.teal))),
                title: Text('${d.itemCode}  $name'),
                subtitle: Text(
                  isEnglish
                      ? 'Price: ${d.unitPriceFc} / ${d.uomCode ?? ''}${d.minQty > 0 ? '  ·  Min qty ${d.minQty}' : ''}$rangeText'
                      : 'ราคา: ${d.unitPriceFc} / ${d.uomCode ?? ''}${d.minQty > 0 ? '  ·  ขั้นต่ำ ${d.minQty}' : ''}$rangeText',
                ),
                trailing: _isReadOnly
                    ? null
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _editLine(i)),
                        IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _removeLine(i)),
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
      return Center(child: Text(isEnglish ? 'Select a price list to view its data' : 'เลือกตารางราคาเพื่อดูข้อมูล', style: const TextStyle(color: Colors.grey)));
    }

    return Form(
      key: _formKey,
      child: Column(children: [
        Container(
          color: Colors.teal[300],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Icon(Icons.price_change_outlined, color: Colors.teal[900], size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.mode == Mode.add
                    ? (isEnglish ? 'Add Price List' : 'เพิ่มตารางราคา')
                    : widget.mode == Mode.edit
                        ? (isEnglish ? 'Edit Price List' : 'แก้ไขตารางราคา')
                        : (isEnglish ? 'Price List Information' : 'ข้อมูลตารางราคา'),
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
            _buildLinesSection(),
          ]),
        ),
      ]),
    );
  }
}
