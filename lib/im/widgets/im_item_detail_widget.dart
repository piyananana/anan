import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../models/im_item.dart';
import '../models/im_item_category.dart';
import '../services/im_item_running_service.dart';
import '../widgets/im_item_category_list_tree_widget.dart';

// ---------------------------------------------------------------------------
// Collapsible section — same look as ap_vendor_detail_widget's _Section
// ---------------------------------------------------------------------------
class _Section extends StatefulWidget {
  final String title;
  final bool initiallyExpanded;
  final List<Widget> children;

  const _Section({required this.title, this.initiallyExpanded = true, required this.children});

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

class ImItemDetailWidget extends StatefulWidget {
  final Mode mode;
  final ImItem? selected;
  final Future<void> Function(ImItem) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;

  const ImItemDetailWidget({
    super.key,
    required this.mode,
    required this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
  });

  @override
  State<ImItemDetailWidget> createState() => ImItemDetailWidgetState();
}

class ImItemDetailWidgetState extends State<ImItemDetailWidget> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isEnglish = false;

  late TextEditingController _codeCtrl;
  late TextEditingController _barcodeCtrl;
  late TextEditingController _nameThCtrl;
  late TextEditingController _nameEnCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _standardCostCtrl;
  late TextEditingController _minStockCtrl;
  late TextEditingController _maxStockCtrl;
  late TextEditingController _reorderCtrl;

  bool _isActive = true;
  String _itemType = 'STOCK';
  String _costingMethod = 'AVG';
  bool _isPurchaseItem = true;
  bool _isSalesItem = true;
  bool _isManufactured = false;
  bool _isLotTracked = false;
  bool _isSerialTracked = false;

  // รหัสอัตโนมัติ
  bool _autoNumberingEnabled = false;
  bool _autoCodeOverridden = false;

  int? _categoryId; String? _categoryCode; String? _categoryName;
  int? _inventoryAccountId; String? _inventoryAccountCode; String? _inventoryAccountName;
  int? _cogsAccountId; String? _cogsAccountCode; String? _cogsAccountName;
  int? _revenueAccountId; String? _revenueAccountCode; String? _revenueAccountName;
  int? _expenseAccountId; String? _expenseAccountCode; String? _expenseAccountName;

  List<Account> _accounts = [];

  bool get _isReadOnly => widget.mode == Mode.view || widget.mode == Mode.none;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadAccounts();
    _loadAutoNumberingConfig();
    if (widget.selected != null) _populate(widget.selected!);
  }

  void _initControllers() {
    _codeCtrl = TextEditingController();
    _barcodeCtrl = TextEditingController();
    _nameThCtrl = TextEditingController();
    _nameEnCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _standardCostCtrl = TextEditingController(text: '0');
    _minStockCtrl = TextEditingController(text: '0');
    _maxStockCtrl = TextEditingController(text: '0');
    _reorderCtrl = TextEditingController(text: '0');
  }

  @override
  void didUpdateWidget(covariant ImItemDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected || widget.mode != oldWidget.mode) {
      if (widget.selected != null) {
        _populate(widget.selected!);
      } else {
        _clear();
      }
      if (widget.mode == Mode.add) _loadAutoNumberingConfig();
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose(); _barcodeCtrl.dispose(); _nameThCtrl.dispose(); _nameEnCtrl.dispose();
    _descCtrl.dispose(); _standardCostCtrl.dispose(); _minStockCtrl.dispose();
    _maxStockCtrl.dispose(); _reorderCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final list = await AccountService().fetchRows();
      if (mounted) setState(() => _accounts = list.where((a) => a.isActive && a.isNormalAccount).toList());
    } catch (_) {}
  }

  Future<void> _loadAutoNumberingConfig() async {
    if (widget.mode != Mode.add) return;
    try {
      final config = await ImItemRunningService().fetchConfig();
      if (mounted) setState(() => _autoNumberingEnabled = config.isAutoNumbering);
    } catch (_) {}
  }

  void _populate(ImItem item) {
    _codeCtrl.text = item.itemCode;
    _barcodeCtrl.text = item.barcode ?? '';
    _nameThCtrl.text = item.itemNameTh;
    _nameEnCtrl.text = item.itemNameEn ?? '';
    _descCtrl.text = item.description ?? '';
    _standardCostCtrl.text = '${item.standardCost}';
    _minStockCtrl.text = '${item.minStockQty}';
    _maxStockCtrl.text = '${item.maxStockQty}';
    _reorderCtrl.text = '${item.reorderPoint}';
    _isActive = item.isActive;
    _itemType = item.itemType;
    _costingMethod = item.costingMethod;
    _isPurchaseItem = item.isPurchaseItem;
    _isSalesItem = item.isSalesItem;
    _isManufactured = item.isManufactured;
    _isLotTracked = item.isLotTracked;
    _isSerialTracked = item.isSerialTracked;
    _categoryId = item.categoryId; _categoryCode = item.categoryCode; _categoryName = item.categoryName;
    _inventoryAccountId = item.inventoryAccountId; _inventoryAccountCode = item.inventoryAccountCode; _inventoryAccountName = item.inventoryAccountName;
    _cogsAccountId = item.cogsAccountId; _cogsAccountCode = item.cogsAccountCode; _cogsAccountName = item.cogsAccountName;
    _revenueAccountId = item.revenueAccountId; _revenueAccountCode = item.revenueAccountCode; _revenueAccountName = item.revenueAccountName;
    _expenseAccountId = item.expenseAccountId; _expenseAccountCode = item.expenseAccountCode; _expenseAccountName = item.expenseAccountName;
  }

  void _clear() {
    _codeCtrl.clear(); _barcodeCtrl.clear(); _nameThCtrl.clear(); _nameEnCtrl.clear(); _descCtrl.clear();
    _standardCostCtrl.text = '0'; _minStockCtrl.text = '0'; _maxStockCtrl.text = '0'; _reorderCtrl.text = '0';
    _isActive = true; _itemType = 'STOCK'; _costingMethod = 'AVG';
    _isPurchaseItem = true; _isSalesItem = true; _isManufactured = false;
    _isLotTracked = false; _isSerialTracked = false; _autoCodeOverridden = false;
    _categoryId = null; _categoryCode = null; _categoryName = null;
    _inventoryAccountId = null; _inventoryAccountCode = null; _inventoryAccountName = null;
    _cogsAccountId = null; _cogsAccountCode = null; _cogsAccountName = null;
    _revenueAccountId = null; _revenueAccountCode = null; _revenueAccountName = null;
    _expenseAccountId = null; _expenseAccountCode = null; _expenseAccountName = null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final item = ImItem(
        id: widget.selected?.id,
        itemCode: (_autoNumberingEnabled && !_autoCodeOverridden) ? '' : _codeCtrl.text.trim().toUpperCase(),
        barcode: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
        itemNameTh: _nameThCtrl.text.trim(),
        itemNameEn: _nameEnCtrl.text.trim().isEmpty ? null : _nameEnCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        categoryId: _categoryId,
        itemType: _itemType,
        costingMethod: _costingMethod,
        standardCost: double.tryParse(_standardCostCtrl.text) ?? 0,
        isPurchaseItem: _isPurchaseItem,
        isSalesItem: _isSalesItem,
        isManufactured: _isManufactured,
        isLotTracked: _isLotTracked,
        isSerialTracked: _isSerialTracked,
        minStockQty: double.tryParse(_minStockCtrl.text) ?? 0,
        maxStockQty: double.tryParse(_maxStockCtrl.text) ?? 0,
        reorderPoint: double.tryParse(_reorderCtrl.text) ?? 0,
        inventoryAccountId: _inventoryAccountId,
        cogsAccountId: _cogsAccountId,
        revenueAccountId: _revenueAccountId,
        expenseAccountId: _expenseAccountId,
        isActive: _isActive,
      );
      await widget.onSubmit(item);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── รหัสสินค้า (รองรับ auto-numbering) ─────────────────────────────────────
  Widget _buildCodeField() {
    final isEnglish = _isEnglish;
    final isAdd = widget.mode == Mode.add;
    final isLocked = _isReadOnly || widget.mode == Mode.edit;

    if (isAdd && _autoNumberingEnabled && !_autoCodeOverridden) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: isEnglish ? 'Item Code' : 'รหัสสินค้า',
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: Row(children: [
            const Icon(Icons.auto_awesome, color: Colors.teal, size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text(isEnglish ? 'Auto-generated on save' : 'ออกรหัสอัตโนมัติเมื่อบันทึก', style: const TextStyle(color: Colors.teal, fontStyle: FontStyle.italic))),
            TextButton.icon(
              icon: const Icon(Icons.edit, size: 14),
              label: Text(isEnglish ? 'Edit manually' : 'แก้ไขเอง', style: const TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700, padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              onPressed: () => setState(() => _autoCodeOverridden = true),
            ),
          ]),
        ),
      );
    }

    if (isAdd && _autoNumberingEnabled && _autoCodeOverridden) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: TextFormField(
              controller: _codeCtrl,
              decoration: InputDecoration(labelText: isEnglish ? 'Item Code *' : 'รหัสสินค้า *', border: const OutlineInputBorder()),
              textCapitalization: TextCapitalization.characters,
              validator: (v) => (v == null || v.trim().isEmpty) ? (isEnglish ? 'Please enter the item code' : 'กรุณาป้อนรหัสสินค้า') : null,
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: isEnglish ? 'Revert to auto-numbering' : 'กลับไปใช้รหัสอัตโนมัติ',
            child: IconButton(
              icon: const Icon(Icons.auto_awesome, color: Colors.teal),
              onPressed: () => setState(() { _autoCodeOverridden = false; _codeCtrl.clear(); }),
            ),
          ),
        ]),
      );
    }

    return _buildField('${isEnglish ? 'Item Code' : 'รหัสสินค้า'}${!isLocked ? ' *' : ''}', _codeCtrl, required: !isLocked);
  }

  Widget _buildField(String label, TextEditingController ctrl, {bool required = false, TextInputType? keyboard, List<TextInputFormatter>? formatters}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: ctrl,
          readOnly: _isReadOnly,
          keyboardType: keyboard,
          inputFormatters: formatters,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          validator: required ? (v) => (v == null || v.trim().isEmpty) ? (_isEnglish ? 'Please enter $label' : 'กรุณาป้อน $label') : null : null,
        ),
      );

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

  Future<void> _pickCategory() async {
    await ImItemCategoryListTreeWidget.search(context, onSelected: (ImItemCategory c) {
      setState(() {
        _categoryId = c.id; _categoryCode = c.categoryCode; _categoryName = c.categoryNameTh;
      });
    });
  }

  Future<void> _pickAccount(String title, void Function(Account) onPicked) async {
    if (_accounts.isEmpty) await _loadAccounts();
    if (!mounted) return;
    final isEnglish = _isEnglish;
    final searchCtrl = TextEditingController();
    List<Account> filtered = List.from(_accounts);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        void doFilter(String q) => setDlg(() {
              filtered = q.isEmpty
                  ? List.from(_accounts)
                  : _accounts
                      .where((a) => a.accountCode.toUpperCase().contains(q.toUpperCase()) || a.accountNameThai.toUpperCase().contains(q.toUpperCase()) || a.accountNameEng.toUpperCase().contains(q.toUpperCase()))
                      .toList();
            });
        String acctName(Account a) => isEnglish && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai;
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 520,
            height: 400,
            child: Column(children: [
              TextField(
                controller: searchCtrl,
                autofocus: true,
                decoration: InputDecoration(hintText: isEnglish ? 'Search account code / name' : 'ค้นหา รหัส / ชื่อบัญชี', prefixIcon: const Icon(Icons.search), border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 10)),
                onChanged: doFilter,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _accounts.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? Center(child: Text(isEnglish ? 'No data found' : 'ไม่พบข้อมูล'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final a = filtered[i];
                              return ListTile(
                                dense: true,
                                title: Row(children: [
                                  SizedBox(width: 110, child: Text(a.accountCode, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
                                  Expanded(child: Text(acctName(a))),
                                ]),
                                onTap: () { onPicked(a); Navigator.of(ctx).pop(); },
                              );
                            },
                          ),
              ),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Close' : 'ปิด'))],
        );
      }),
    );
    searchCtrl.dispose();
  }

  // ── Sections ───────────────────────────────────────────────────────────────
  Widget _buildBasicSection() {
    final isEnglish = _isEnglish;
    return _Section(title: isEnglish ? 'Basic Information' : 'ข้อมูลพื้นฐาน', children: [
      Row(children: [
        Expanded(child: _buildCodeField()),
        const SizedBox(width: 10),
        Expanded(child: _buildField(isEnglish ? 'Barcode' : 'บาร์โค้ด', _barcodeCtrl)),
        const SizedBox(width: 10),
        Expanded(child: _buildFkField(
          label: isEnglish ? 'Category' : 'หมวดหมู่สินค้า',
          hasValue: _categoryId != null,
          displayText: '$_categoryCode — $_categoryName',
          onSearch: _pickCategory,
          onClear: () => setState(() { _categoryId = null; _categoryCode = null; _categoryName = null; }),
        )),
      ]),
      Row(children: [
        Expanded(child: _buildField(isEnglish ? 'Item Name (Thai) *' : 'ชื่อสินค้า (ไทย) *', _nameThCtrl, required: true)),
        const SizedBox(width: 10),
        Expanded(child: _buildField(isEnglish ? 'Item Name (English)' : 'ชื่อสินค้า (อังกฤษ)', _nameEnCtrl)),
      ]),
      _buildField(isEnglish ? 'Description' : 'คำอธิบาย', _descCtrl),
      Row(children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DropdownButtonFormField<String>(
              value: _itemType,
              isExpanded: true,
              decoration: InputDecoration(labelText: isEnglish ? 'Item Type' : 'ประเภทสินค้า', border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              items: imItemTypes.map((t) => DropdownMenuItem(value: t, child: Text(imItemTypeLabel(t, isEnglish)))).toList(),
              onChanged: _isReadOnly ? null : (v) => setState(() => _itemType = v ?? 'STOCK'),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: DropdownButtonFormField<String>(
              value: _costingMethod,
              isExpanded: true,
              decoration: InputDecoration(labelText: isEnglish ? 'Costing Method' : 'วิธีคิดต้นทุน', border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              items: imCostingMethods.map((m) => DropdownMenuItem(value: m, child: Text(imCostingMethodLabel(m, isEnglish)))).toList(),
              onChanged: (_isReadOnly || _itemType != 'STOCK') ? null : (v) => setState(() => _costingMethod = v ?? 'AVG'),
            ),
          ),
        ),
      ]),
      if (_costingMethod == 'STANDARD')
        _buildField(isEnglish ? 'Standard Cost' : 'ต้นทุนมาตรฐาน', _standardCostCtrl,
            keyboard: const TextInputType.numberWithOptions(decimal: true), formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]),
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

  Widget _buildFlagsSection() {
    final isEnglish = _isEnglish;
    return _Section(title: isEnglish ? 'Usage Flags' : 'คุณสมบัติการใช้งาน', initiallyExpanded: false, children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero, dense: true,
        title: Text(isEnglish ? 'Purchase item (can appear on purchase documents)' : 'ใช้ในการซื้อ (แสดงในเอกสารฝั่งซื้อ)'),
        value: _isPurchaseItem, activeColor: Colors.teal,
        onChanged: _isReadOnly ? null : (v) => setState(() => _isPurchaseItem = v),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero, dense: true,
        title: Text(isEnglish ? 'Sales item (can appear on sales documents)' : 'ใช้ในการขาย (แสดงในเอกสารฝั่งขาย)'),
        value: _isSalesItem, activeColor: Colors.teal,
        onChanged: _isReadOnly ? null : (v) => setState(() => _isSalesItem = v),
      ),
      if (_itemType == 'STOCK') ...[
        SwitchListTile(
          contentPadding: EdgeInsets.zero, dense: true,
          title: Text(isEnglish ? 'Manufactured (produced via a Bill of Materials)' : 'ผลิตเอง (จาก Bill of Materials)'),
          value: _isManufactured, activeColor: Colors.teal,
          onChanged: _isReadOnly ? null : (v) => setState(() => _isManufactured = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero, dense: true,
          title: Text(isEnglish ? 'Lot tracked' : 'ติดตามเป็นล็อต'),
          value: _isLotTracked, activeColor: Colors.teal,
          onChanged: _isReadOnly ? null : (v) => setState(() => _isLotTracked = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero, dense: true,
          title: Text(isEnglish ? 'Serial number tracked' : 'ติดตามเป็นเลขซีเรียล'),
          value: _isSerialTracked, activeColor: Colors.teal,
          onChanged: _isReadOnly ? null : (v) => setState(() => _isSerialTracked = v),
        ),
      ],
    ]);
  }

  Widget _buildStockSection() {
    if (_itemType != 'STOCK') return const SizedBox.shrink();
    final isEnglish = _isEnglish;
    return _Section(title: isEnglish ? 'Replenishment' : 'การเติมสินค้า', initiallyExpanded: false, children: [
      Row(children: [
        Expanded(child: _buildField(isEnglish ? 'Min Stock Qty' : 'ปริมาณขั้นต่ำ', _minStockCtrl, keyboard: const TextInputType.numberWithOptions(decimal: true), formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))])),
        const SizedBox(width: 10),
        Expanded(child: _buildField(isEnglish ? 'Max Stock Qty' : 'ปริมาณสูงสุด', _maxStockCtrl, keyboard: const TextInputType.numberWithOptions(decimal: true), formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))])),
        const SizedBox(width: 10),
        Expanded(child: _buildField(isEnglish ? 'Reorder Point' : 'จุดสั่งซื้อซ้ำ', _reorderCtrl, keyboard: const TextInputType.numberWithOptions(decimal: true), formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))])),
      ]),
    ]);
  }

  Widget _buildGlAccountSection() {
    final isEnglish = _isEnglish;
    return _Section(title: isEnglish ? 'GL Account Overrides' : 'บัญชี GL เฉพาะรายการ', initiallyExpanded: false, children: [
      Text(
        isEnglish
            ? 'Leave blank to use the category\'s default account.'
            : 'เว้นว่างไว้เพื่อใช้บัญชีตั้งต้นของหมวดหมู่สินค้า',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _buildFkField(
          label: isEnglish ? 'Inventory Account' : 'บัญชีสินค้าคงคลัง',
          hasValue: _inventoryAccountId != null,
          displayText: '$_inventoryAccountCode — $_inventoryAccountName',
          onSearch: () => _pickAccount(isEnglish ? 'Select Inventory Account' : 'เลือกบัญชีสินค้าคงคลัง', (a) => setState(() {
                _inventoryAccountId = a.id; _inventoryAccountCode = a.accountCode;
                _inventoryAccountName = isEnglish && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai;
              })),
          onClear: () => setState(() { _inventoryAccountId = null; _inventoryAccountCode = null; _inventoryAccountName = null; }),
        )),
        const SizedBox(width: 10),
        Expanded(child: _buildFkField(
          label: isEnglish ? 'COGS Account' : 'บัญชีต้นทุนขาย',
          hasValue: _cogsAccountId != null,
          displayText: '$_cogsAccountCode — $_cogsAccountName',
          onSearch: () => _pickAccount(isEnglish ? 'Select COGS Account' : 'เลือกบัญชีต้นทุนขาย', (a) => setState(() {
                _cogsAccountId = a.id; _cogsAccountCode = a.accountCode;
                _cogsAccountName = isEnglish && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai;
              })),
          onClear: () => setState(() { _cogsAccountId = null; _cogsAccountCode = null; _cogsAccountName = null; }),
        )),
      ]),
      Row(children: [
        Expanded(child: _buildFkField(
          label: isEnglish ? 'Revenue Account' : 'บัญชีรายได้',
          hasValue: _revenueAccountId != null,
          displayText: '$_revenueAccountCode — $_revenueAccountName',
          onSearch: () => _pickAccount(isEnglish ? 'Select Revenue Account' : 'เลือกบัญชีรายได้', (a) => setState(() {
                _revenueAccountId = a.id; _revenueAccountCode = a.accountCode;
                _revenueAccountName = isEnglish && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai;
              })),
          onClear: () => setState(() { _revenueAccountId = null; _revenueAccountCode = null; _revenueAccountName = null; }),
        )),
        const SizedBox(width: 10),
        Expanded(child: _buildFkField(
          label: isEnglish ? 'Expense Account' : 'บัญชีค่าใช้จ่าย',
          hasValue: _expenseAccountId != null,
          displayText: '$_expenseAccountCode — $_expenseAccountName',
          onSearch: () => _pickAccount(isEnglish ? 'Select Expense Account' : 'เลือกบัญชีค่าใช้จ่าย', (a) => setState(() {
                _expenseAccountId = a.id; _expenseAccountCode = a.accountCode;
                _expenseAccountName = isEnglish && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai;
              })),
          onClear: () => setState(() { _expenseAccountId = null; _expenseAccountCode = null; _expenseAccountName = null; }),
        )),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = Provider.of<LanguageProvider>(context).isEnglish;
    _isEnglish = isEnglish;
    if (widget.isPlaceholder) {
      return Center(child: Text(isEnglish ? 'Select an item to view its data' : 'เลือกรายการเพื่อดูข้อมูล', style: const TextStyle(color: Colors.grey)));
    }

    return Form(
      key: _formKey,
      child: Column(children: [
        Container(
          color: Colors.teal[300],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Icon(Icons.inventory_2, color: Colors.teal[900], size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.mode == Mode.add
                    ? (isEnglish ? 'Add New Item' : 'เพิ่มสินค้าใหม่')
                    : widget.mode == Mode.edit
                        ? (isEnglish ? 'Edit Item' : 'แก้ไขสินค้า')
                        : (isEnglish ? 'Item Information' : 'ข้อมูลสินค้า'),
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
            _buildFlagsSection(),
            _buildStockSection(),
            _buildGlAccountSection(),
          ]),
        ),
      ]),
    );
  }
}
