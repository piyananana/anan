import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../models/im_item.dart';
import '../models/im_item_category.dart';
import '../models/im_uom.dart';
import '../models/im_warehouse.dart';
import '../models/im_location.dart';
import '../models/im_price_list.dart';
import '../services/im_item_running_service.dart';
import '../services/im_location_service.dart';
import '../services/im_price_list_service.dart';
import '../widgets/im_item_category_list_tree_widget.dart';
import '../widgets/im_uom_list_widget.dart';
import '../widgets/im_warehouse_list_widget.dart';

// ---------------------------------------------------------------------------
// Collapsible section — same look as ap_vendor_detail_widget's _Section
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
// Add/Edit alternate unit dialog
// ---------------------------------------------------------------------------
Future<ImUomConversion?> _showUomConversionDialog(BuildContext context, ImUomConversion? existing) async {
  final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
  int? uomId = existing?.uomId;
  String? uomCode = existing?.uomCode;
  String? uomName = isEnglish && (existing?.uomNameEn ?? '').isNotEmpty ? existing?.uomNameEn : existing?.uomNameTh;
  final factorCtrl = TextEditingController(text: existing != null ? '${existing.conversionFactor}' : '1');
  final barcodeCtrl = TextEditingController(text: existing?.barcode ?? '');
  bool isPurchaseDefault = existing?.isPurchaseDefault ?? false;
  bool isSalesDefault = existing?.isSalesDefault ?? false;

  return showDialog<ImUomConversion>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
      return AlertDialog(
        title: Text(existing == null ? (isEnglish ? 'Add Alternate Unit' : 'เพิ่มหน่วยนับทางเลือก') : (isEnglish ? 'Edit Alternate Unit' : 'แก้ไขหน่วยนับทางเลือก')),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InputDecorator(
                  decoration: InputDecoration(labelText: isEnglish ? 'Unit *' : 'หน่วยนับ *', border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  child: Row(children: [
                    Expanded(
                      child: uomId != null
                          ? Text('$uomCode — $uomName', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)
                          : Text(isEnglish ? '— Not specified —' : '— ไม่ระบุ —', style: TextStyle(color: Colors.grey.shade600)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.teal),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => ImUomListWidget.search(ctx, onSelected: (ImUom u) {
                        setDlg(() {
                          uomId = u.id; uomCode = u.uomCode;
                          uomName = isEnglish && (u.uomNameEn ?? '').isNotEmpty ? u.uomNameEn : u.uomNameTh;
                        });
                      }),
                    ),
                  ]),
                ),
              ),
              TextField(
                controller: factorCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Conversion Factor (per base unit) *' : 'อัตราแปลงหน่วย (ต่อหน่วยหลัก) *',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: barcodeCtrl,
                decoration: InputDecoration(labelText: isEnglish ? 'Barcode' : 'บาร์โค้ด', border: const OutlineInputBorder()),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(isEnglish ? 'Default purchase unit' : 'หน่วยซื้อเริ่มต้น'),
                value: isPurchaseDefault,
                onChanged: (v) => setDlg(() => isPurchaseDefault = v ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(isEnglish ? 'Default sales unit' : 'หน่วยขายเริ่มต้น'),
                value: isSalesDefault,
                onChanged: (v) => setDlg(() => isSalesDefault = v ?? false),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(
            onPressed: () {
              if (uomId == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please select a unit' : 'กรุณาเลือกหน่วยนับ')));
                return;
              }
              Navigator.of(ctx).pop(ImUomConversion(
                id: existing?.id,
                uomId: uomId!,
                uomCode: uomCode,
                uomNameTh: isEnglish ? null : uomName,
                uomNameEn: isEnglish ? uomName : null,
                conversionFactor: double.tryParse(factorCtrl.text) ?? 1,
                barcode: barcodeCtrl.text.trim().isEmpty ? null : barcodeCtrl.text.trim(),
                isPurchaseDefault: isPurchaseDefault,
                isSalesDefault: isSalesDefault,
              ));
            },
            child: Text(isEnglish ? 'OK' : 'ตกลง'),
          ),
        ],
      );
    }),
  );
}

// ---------------------------------------------------------------------------
// Add/Edit per-warehouse policy dialog
// ---------------------------------------------------------------------------
Future<ImItemWarehouse?> _showItemWarehouseDialog(BuildContext context, ImItemWarehouse? existing) async {
  final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
  int? warehouseId = existing?.warehouseId;
  String? warehouseCode = existing?.warehouseCode;
  String? warehouseName = isEnglish && (existing?.warehouseNameEn ?? '').isNotEmpty ? existing?.warehouseNameEn : existing?.warehouseNameTh;
  int? locationId = existing?.defaultLocationId;
  String? locationCode = existing?.defaultLocationCode;
  List<ImLocation> availableLocations = [];
  if (warehouseId != null) {
    try {
      final locations = await ImLocationService().fetchActiveRows(warehouseId: warehouseId);
      availableLocations = locations.where((l) => l.locationType == 'BIN').toList();
    } catch (_) {}
  }
  final minCtrl = TextEditingController(text: existing != null ? '${existing.minStockQty}' : '0');
  final maxCtrl = TextEditingController(text: existing != null ? '${existing.maxStockQty}' : '0');
  final reorderCtrl = TextEditingController(text: existing != null ? '${existing.reorderPoint}' : '0');

  if (!context.mounted) return null;
  return showDialog<ImItemWarehouse>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
      Future<void> loadLocationsFor(int whId) async {
        try {
          final locations = await ImLocationService().fetchActiveRows(warehouseId: whId);
          setDlg(() => availableLocations = locations.where((l) => l.locationType == 'BIN').toList());
        } catch (_) {}
      }

      return AlertDialog(
        title: Text(existing == null ? (isEnglish ? 'Add Warehouse Setting' : 'เพิ่มการตั้งค่าคลังสินค้า') : (isEnglish ? 'Edit Warehouse Setting' : 'แก้ไขการตั้งค่าคลังสินค้า')),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InputDecorator(
                  decoration: InputDecoration(labelText: isEnglish ? 'Warehouse *' : 'คลังสินค้า *', border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  child: Row(children: [
                    Expanded(
                      child: warehouseId != null
                          ? Text('$warehouseCode — $warehouseName', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)
                          : Text(isEnglish ? '— Not specified —' : '— ไม่ระบุ —', style: TextStyle(color: Colors.grey.shade600)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.teal),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => ImWarehouseListWidget.search(ctx, onSelected: (ImWarehouse w) {
                        setDlg(() {
                          warehouseId = w.id; warehouseCode = w.warehouseCode;
                          warehouseName = isEnglish && (w.warehouseNameEn ?? '').isNotEmpty ? w.warehouseNameEn : w.warehouseNameTh;
                          locationId = null; locationCode = null; availableLocations = [];
                        });
                        loadLocationsFor(w.id);
                      }),
                    ),
                  ]),
                ),
              ),
              Row(children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10, right: 8),
                    child: TextField(
                      controller: minCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      decoration: InputDecoration(labelText: isEnglish ? 'Min Qty' : 'ขั้นต่ำ', border: const OutlineInputBorder()),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10, right: 8),
                    child: TextField(
                      controller: maxCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      decoration: InputDecoration(labelText: isEnglish ? 'Max Qty' : 'สูงสุด', border: const OutlineInputBorder()),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: reorderCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      decoration: InputDecoration(labelText: isEnglish ? 'Reorder' : 'สั่งซื้อซ้ำ', border: const OutlineInputBorder()),
                    ),
                  ),
                ),
              ]),
              if (warehouseId != null)
                DropdownButtonFormField<int?>(
                  value: locationId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: isEnglish ? 'Default Location' : 'ตำแหน่งจัดเก็บเริ่มต้น', border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  items: [
                    DropdownMenuItem(value: null, child: Text(isEnglish ? '— Not specified —' : '— ไม่ระบุ —')),
                    ...availableLocations.map((l) => DropdownMenuItem(value: l.id, child: Text('${l.locationCode}  ${l.locationName ?? ''}'))),
                  ],
                  onChanged: (v) => setDlg(() {
                    locationId = v;
                    locationCode = availableLocations.where((l) => l.id == v).firstOrNull?.locationCode;
                  }),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(
            onPressed: () {
              if (warehouseId == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(isEnglish ? 'Please select a warehouse' : 'กรุณาเลือกคลังสินค้า')));
                return;
              }
              Navigator.of(ctx).pop(ImItemWarehouse(
                id: existing?.id,
                warehouseId: warehouseId!,
                warehouseCode: warehouseCode,
                warehouseNameTh: isEnglish ? null : warehouseName,
                warehouseNameEn: isEnglish ? warehouseName : null,
                minStockQty: double.tryParse(minCtrl.text) ?? 0,
                maxStockQty: double.tryParse(maxCtrl.text) ?? 0,
                reorderPoint: double.tryParse(reorderCtrl.text) ?? 0,
                defaultLocationId: locationId,
                defaultLocationCode: locationCode,
              ));
            },
            child: Text(isEnglish ? 'OK' : 'ตกลง'),
          ),
        ],
      );
    }),
  );
}

class ImItemDetailWidget extends StatefulWidget {
  final Mode mode;
  final ImItem? selected;
  final Future<void> Function(ImItem) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;
  // เพิ่มขึ้นทุกครั้งที่ผู้ใช้กดปุ่มเพิ่ม/แก้ไข/ดู/ยกเลิกจากหน้าจอหลัก — ใช้บังคับให้ didUpdateWidget เคลียร์ฟอร์ม
  // เสมอ แม้ mode/selected จะ "เหมือนเดิม" กับครั้งก่อน (เช่น กดเพิ่มสินค้าซ้ำหลังพิมพ์ข้อมูลค้างไว้)
  final int requestSeq;

  const ImItemDetailWidget({
    super.key,
    required this.mode,
    required this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
    this.requestSeq = 0,
  });

  @override
  State<ImItemDetailWidget> createState() => ImItemDetailWidgetState();
}

class ImItemDetailWidgetState extends State<ImItemDetailWidget> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isEnglish = false;

  late TextEditingController _codeCtrl;
  late TextEditingController _oldCodeCtrl;
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

  // รหัสอัตโนมัติ — ระดับส่วนกลาง (im_item_running) หรือระดับหมวดหมู่ (im_item_category)
  bool _autoNumberingEnabled = false;
  bool _categoryIsAutoNumber = false;
  bool _autoCodeOverridden = false;
  // true เมื่อระเบียนนี้ถูกสร้าง (ครั้งแรก) โดยรหัสถูกออกอัตโนมัติ — ล็อกหมวดหมู่ถาวร ไม่ขึ้นกับ setting ปัจจุบันของหมวดหมู่
  bool _isCodeAutoGenerated = false;

  bool get _effectiveAutoNumbering => _categoryIsAutoNumber || _autoNumberingEnabled;

  // แก้ไขระเบียนเดิม + รหัสถูกออกอัตโนมัติตอนสร้าง → ล็อกหมวดหมู่ถาวร เปลี่ยนไม่ได้
  bool get _categoryLocked => widget.mode == Mode.edit && _isCodeAutoGenerated;

  int? _categoryId; String? _categoryCode; String? _categoryName;
  int? _baseUomId; String? _baseUomCode; String? _baseUomName;
  int? _defaultWarehouseId; String? _defaultWarehouseCode; String? _defaultWarehouseName;
  int? _inventoryAccountId; String? _inventoryAccountCode; String? _inventoryAccountName;
  int? _cogsAccountId; String? _cogsAccountCode; String? _cogsAccountName;
  int? _revenueAccountId; String? _revenueAccountCode; String? _revenueAccountName;
  int? _expenseAccountId; String? _expenseAccountCode; String? _expenseAccountName;

  List<Account> _accounts = [];
  List<ImItemPriceRow> _priceRows = [];
  List<ImUomConversion> _uomConversions = [];
  List<ImItemWarehouse> _itemWarehouses = [];
  bool _isLoadingPrices = false;

  bool get _isReadOnly => widget.mode == Mode.view || widget.mode == Mode.none;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadAccounts();
    _loadAutoNumberingConfig();
    if (widget.selected != null) _populate(widget.selected!);
    if (widget.selected?.id != null) _loadPrices(widget.selected!.id!);
  }

  Future<void> _loadPrices(int itemId) async {
    setState(() => _isLoadingPrices = true);
    try {
      final rows = await ImPriceListService().fetchByItem(itemId);
      if (mounted) setState(() => _priceRows = rows);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingPrices = false);
    }
  }

  void _initControllers() {
    _codeCtrl = TextEditingController();
    _oldCodeCtrl = TextEditingController();
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
    if (widget.selected != oldWidget.selected || widget.mode != oldWidget.mode || widget.requestSeq != oldWidget.requestSeq) {
      if (widget.selected != null) {
        _populate(widget.selected!);
        if (widget.selected!.id != null) _loadPrices(widget.selected!.id!);
      } else {
        _clear();
      }
      if (widget.mode == Mode.add) _loadAutoNumberingConfig();
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose(); _oldCodeCtrl.dispose(); _barcodeCtrl.dispose(); _nameThCtrl.dispose(); _nameEnCtrl.dispose();
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
    _oldCodeCtrl.text = item.oldItemCode ?? '';
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
    _isCodeAutoGenerated = item.isCodeAutoGenerated;
    _baseUomId = item.baseUomId; _baseUomCode = item.baseUomCode;
    _baseUomName = _isEnglish && (item.baseUomNameEn ?? '').isNotEmpty ? item.baseUomNameEn : item.baseUomNameTh;
    _defaultWarehouseId = item.defaultWarehouseId; _defaultWarehouseCode = item.defaultWarehouseCode;
    _defaultWarehouseName = _isEnglish && (item.defaultWarehouseNameEn ?? '').isNotEmpty ? item.defaultWarehouseNameEn : item.defaultWarehouseNameTh;
    _inventoryAccountId = item.inventoryAccountId; _inventoryAccountCode = item.inventoryAccountCode; _inventoryAccountName = item.inventoryAccountName;
    _cogsAccountId = item.cogsAccountId; _cogsAccountCode = item.cogsAccountCode; _cogsAccountName = item.cogsAccountName;
    _revenueAccountId = item.revenueAccountId; _revenueAccountCode = item.revenueAccountCode; _revenueAccountName = item.revenueAccountName;
    _expenseAccountId = item.expenseAccountId; _expenseAccountCode = item.expenseAccountCode; _expenseAccountName = item.expenseAccountName;
    _uomConversions = List.from(item.uomConversions);
    _itemWarehouses = List.from(item.itemWarehouses);
  }

  void _clear() {
    _codeCtrl.clear(); _oldCodeCtrl.clear(); _barcodeCtrl.clear(); _nameThCtrl.clear(); _nameEnCtrl.clear(); _descCtrl.clear();
    _standardCostCtrl.text = '0'; _minStockCtrl.text = '0'; _maxStockCtrl.text = '0'; _reorderCtrl.text = '0';
    _isActive = true; _itemType = 'STOCK'; _costingMethod = 'AVG';
    _isPurchaseItem = true; _isSalesItem = true; _isManufactured = false;
    _isLotTracked = false; _isSerialTracked = false; _autoCodeOverridden = false;
    _categoryId = null; _categoryCode = null; _categoryName = null; _categoryIsAutoNumber = false;
    _isCodeAutoGenerated = false;
    _baseUomId = null; _baseUomCode = null; _baseUomName = null;
    _defaultWarehouseId = null; _defaultWarehouseCode = null; _defaultWarehouseName = null;
    _inventoryAccountId = null; _inventoryAccountCode = null; _inventoryAccountName = null;
    _cogsAccountId = null; _cogsAccountCode = null; _cogsAccountName = null;
    _revenueAccountId = null; _revenueAccountCode = null; _revenueAccountName = null;
    _expenseAccountId = null; _expenseAccountCode = null; _expenseAccountName = null;
    _priceRows = [];
    _uomConversions = [];
    _itemWarehouses = [];
  }

  Future<void> _addUomConversion() async {
    final result = await _showUomConversionDialog(context, null);
    if (result != null) setState(() => _uomConversions.add(result));
  }

  Future<void> _editUomConversion(int index) async {
    final result = await _showUomConversionDialog(context, _uomConversions[index]);
    if (result != null) setState(() => _uomConversions[index] = result);
  }

  void _removeUomConversion(int index) => setState(() => _uomConversions.removeAt(index));

  Future<void> _addItemWarehouse() async {
    final result = await _showItemWarehouseDialog(context, null);
    if (result != null) setState(() => _itemWarehouses.add(result));
  }

  Future<void> _editItemWarehouse(int index) async {
    final result = await _showItemWarehouseDialog(context, _itemWarehouses[index]);
    if (result != null) setState(() => _itemWarehouses[index] = result);
  }

  void _removeItemWarehouse(int index) => setState(() => _itemWarehouses.removeAt(index));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final item = ImItem(
        id: widget.selected?.id,
        itemCode: (_effectiveAutoNumbering && !_autoCodeOverridden) ? '' : _codeCtrl.text.trim().toUpperCase(),
        oldItemCode: _oldCodeCtrl.text.trim().isEmpty ? null : _oldCodeCtrl.text.trim(),
        barcode: _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
        itemNameTh: _nameThCtrl.text.trim(),
        itemNameEn: _nameEnCtrl.text.trim().isEmpty ? null : _nameEnCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        categoryId: _categoryId,
        baseUomId: _baseUomId,
        defaultWarehouseId: _defaultWarehouseId,
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
        uomConversions: _uomConversions,
        itemWarehouses: _itemWarehouses,
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

    if (isAdd && _effectiveAutoNumbering && !_autoCodeOverridden) {
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

    if (isAdd && _effectiveAutoNumbering && _autoCodeOverridden) {
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
            if (locked)
              Tooltip(
                message: _isEnglish ? 'Locked — code was auto-generated at creation' : 'ล็อก — รหัสถูกออกอัตโนมัติตอนสร้างข้อมูล',
                child: Icon(Icons.lock, color: Colors.grey.shade500, size: 16),
              )
            else if (!_isReadOnly) ...[
              IconButton(icon: const Icon(Icons.search, color: Colors.teal), tooltip: _isEnglish ? 'Search $label' : 'ค้นหา$label', padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onSearch),
              if (hasValue && onClear != null)
                IconButton(icon: const Icon(Icons.clear, color: Colors.red, size: 18), tooltip: _isEnglish ? 'Clear' : 'ล้าง', padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onClear),
            ],
          ]),
        ),
      );

  Future<void> _pickCategory() async {
    await ImItemCategoryListTreeWidget.search(context, onSelected: (ImItemCategory c) {
      // แก้ไขข้อมูลเดิม + รหัสป้อนเอง (ไม่ auto) → เปลี่ยนหมวดหมู่ได้เฉพาะหมวดหมู่ที่ไม่ auto ด้วยกัน
      if (widget.mode == Mode.edit && !_isCodeAutoGenerated &&
          c.isAutoNumber && c.id != _categoryId) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEnglish
              ? 'This item\'s code was entered manually — it can only be moved to another non-auto-numbering category.'
              : 'สินค้านี้ป้อนรหัสเอง สามารถเปลี่ยนไปยังหมวดหมู่ที่ไม่ตั้งค่ารหัสอัตโนมัติเท่านั้น'),
          backgroundColor: Colors.red,
        ));
        return;
      }
      setState(() {
        _categoryId = c.id; _categoryCode = c.categoryCode; _categoryName = c.categoryNameTh;
        _categoryIsAutoNumber = c.isAutoNumber;
        if (_categoryIsAutoNumber) _autoCodeOverridden = false;
      });
    });
  }

  Future<void> _pickUom() async {
    final isEnglish = _isEnglish;
    await ImUomListWidget.search(context, onSelected: (ImUom u) {
      setState(() {
        _baseUomId = u.id; _baseUomCode = u.uomCode;
        _baseUomName = isEnglish && (u.uomNameEn ?? '').isNotEmpty ? u.uomNameEn : u.uomNameTh;
      });
    });
  }

  Future<void> _pickWarehouse() async {
    final isEnglish = _isEnglish;
    await ImWarehouseListWidget.search(context, onSelected: (ImWarehouse w) {
      setState(() {
        _defaultWarehouseId = w.id; _defaultWarehouseCode = w.warehouseCode;
        _defaultWarehouseName = isEnglish && (w.warehouseNameEn ?? '').isNotEmpty ? w.warehouseNameEn : w.warehouseNameTh;
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
          onClear: () => setState(() { _categoryId = null; _categoryCode = null; _categoryName = null; _categoryIsAutoNumber = false; }),
          locked: _categoryLocked,
        )),
      ]),
      Row(children: [
        Expanded(child: _buildField(isEnglish ? 'Item Name (Thai) *' : 'ชื่อสินค้า (ไทย) *', _nameThCtrl, required: true)),
        const SizedBox(width: 10),
        Expanded(child: _buildField(isEnglish ? 'Item Name (English)' : 'ชื่อสินค้า (อังกฤษ)', _nameEnCtrl)),
      ]),
      Row(children: [
        Expanded(flex: 4, child: _buildField(isEnglish ? 'Description' : 'คำอธิบาย', _descCtrl)),
        const SizedBox(width: 10),
        Expanded(flex: 1, child: _buildField(isEnglish ? 'Old Item Code' : 'รหัสสินค้าเก่า', _oldCodeCtrl)),
      ]),
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
              onChanged: (_isReadOnly || _itemType != 'STOCK') ? null : (v) => setState(() {
                    _costingMethod = v ?? 'AVG';
                    // ต้นทุนเฉพาะเจาะจง (SPECIFIC) ต้องติดตาม serial เสมอ
                    if (_costingMethod == 'SPECIFIC') _isSerialTracked = true;
                  }),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _buildFkField(
          label: isEnglish ? 'Base Unit (UOM)' : 'หน่วยนับหลัก',
          hasValue: _baseUomId != null,
          displayText: '$_baseUomCode — $_baseUomName',
          onSearch: _pickUom,
          onClear: () => setState(() { _baseUomId = null; _baseUomCode = null; _baseUomName = null; }),
        )),
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
          subtitle: _costingMethod == 'SPECIFIC'
              ? Text(
                  isEnglish
                      ? 'Required — costing method is Specific Identification'
                      : 'จำเป็นต้องเปิด — เนื่องจากตั้งวิธีคิดต้นทุนเป็นเฉพาะเจาะจง (ตาม Serial)',
                  style: TextStyle(fontSize: 12, color: Colors.teal[700]),
                )
              : null,
          value: _isSerialTracked, activeColor: Colors.teal,
          onChanged: (_isReadOnly || _costingMethod == 'SPECIFIC') ? null : (v) => setState(() => _isSerialTracked = v),
        ),
      ],
    ]);
  }

  Widget _buildUomConversionSection() {
    final isEnglish = _isEnglish;
    return _Section(
      title: isEnglish ? 'Alternate Units (${_uomConversions.length})' : 'หน่วยนับทางเลือก (${_uomConversions.length})',
      initiallyExpanded: false,
      trailing: _isReadOnly ? null : IconButton(icon: const Icon(Icons.add_circle, color: Colors.teal), tooltip: isEnglish ? 'Add alternate unit' : 'เพิ่มหน่วยนับทางเลือก', onPressed: _addUomConversion),
      children: [
        if (_uomConversions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(isEnglish ? 'No alternate units — only the base unit is used' : 'ยังไม่มีหน่วยนับทางเลือก — ใช้หน่วยหลักเท่านั้น', style: TextStyle(color: Colors.grey.shade600)),
          )
        else
          ..._uomConversions.asMap().entries.map((entry) {
            final i = entry.key;
            final c = entry.value;
            final name = isEnglish && (c.uomNameEn ?? '').isNotEmpty ? c.uomNameEn : c.uomNameTh;
            final tags = [
              if (c.isPurchaseDefault) (isEnglish ? 'Purchase default' : 'ค่าเริ่มต้นซื้อ'),
              if (c.isSalesDefault) (isEnglish ? 'Sales default' : 'ค่าเริ่มต้นขาย'),
            ].join('  ·  ');
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 3),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.straighten, color: Colors.teal, size: 20),
                title: Text('${c.uomCode}  $name'),
                subtitle: Text(
                  isEnglish
                      ? '1 ${c.uomCode} = ${c.conversionFactor} base unit${c.barcode != null ? '  ·  Barcode: ${c.barcode}' : ''}${tags.isNotEmpty ? '  ·  $tags' : ''}'
                      : '1 ${c.uomCode} = ${c.conversionFactor} หน่วยหลัก${c.barcode != null ? '  ·  บาร์โค้ด: ${c.barcode}' : ''}${tags.isNotEmpty ? '  ·  $tags' : ''}',
                ),
                trailing: _isReadOnly
                    ? null
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _editUomConversion(i)),
                        IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _removeUomConversion(i)),
                      ]),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildItemWarehouseSection() {
    if (_itemType != 'STOCK') return const SizedBox.shrink();
    final isEnglish = _isEnglish;
    return _Section(
      title: isEnglish ? 'Warehouse Settings (${_itemWarehouses.length})' : 'การตั้งค่าต่อคลังสินค้า (${_itemWarehouses.length})',
      initiallyExpanded: false,
      trailing: _isReadOnly ? null : IconButton(icon: const Icon(Icons.add_circle, color: Colors.teal), tooltip: isEnglish ? 'Add warehouse setting' : 'เพิ่มการตั้งค่าคลังสินค้า', onPressed: _addItemWarehouse),
      children: [
        Text(
          isEnglish
              ? 'Overrides min/max/reorder for a specific warehouse; used later for physical count and opening balance setup.'
              : 'ใช้แทนค่าขั้นต่ำ/สูงสุด/จุดสั่งซื้อของคลังนั้นๆ โดยเฉพาะ — ใช้ประกอบการนับสต็อกและตั้งยอดยกมาในภายหลัง',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        if (_itemWarehouses.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(isEnglish ? 'No per-warehouse settings yet' : 'ยังไม่มีการตั้งค่าต่อคลังสินค้า', style: TextStyle(color: Colors.grey.shade600)),
          )
        else
          ..._itemWarehouses.asMap().entries.map((entry) {
            final i = entry.key;
            final w = entry.value;
            final name = isEnglish && (w.warehouseNameEn ?? '').isNotEmpty ? w.warehouseNameEn : w.warehouseNameTh;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 3),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.warehouse, color: Colors.teal, size: 20),
                title: Text('${w.warehouseCode}  $name'),
                subtitle: Text(
                  isEnglish
                      ? 'Min ${w.minStockQty} · Max ${w.maxStockQty} · Reorder ${w.reorderPoint}${w.defaultLocationCode != null ? '  ·  Location: ${w.defaultLocationCode}' : ''}'
                      : 'ขั้นต่ำ ${w.minStockQty} · สูงสุด ${w.maxStockQty} · สั่งซื้อซ้ำ ${w.reorderPoint}${w.defaultLocationCode != null ? '  ·  ตำแหน่ง: ${w.defaultLocationCode}' : ''}',
                ),
                trailing: _isReadOnly
                    ? null
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _editItemWarehouse(i)),
                        IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _removeItemWarehouse(i)),
                      ]),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildStockSection() {
    if (_itemType != 'STOCK') return const SizedBox.shrink();
    final isEnglish = _isEnglish;
    return _Section(title: isEnglish ? 'Replenishment' : 'การเติมสินค้า', initiallyExpanded: false, children: [
      Row(children: [
        Expanded(child: _buildFkField(
          label: isEnglish ? 'Default Warehouse' : 'คลังสินค้าเริ่มต้น',
          hasValue: _defaultWarehouseId != null,
          displayText: '$_defaultWarehouseCode — $_defaultWarehouseName',
          onSearch: _pickWarehouse,
          onClear: () => setState(() { _defaultWarehouseId = null; _defaultWarehouseCode = null; _defaultWarehouseName = null; }),
        )),
      ]),
      Row(children: [
        Expanded(child: _buildField(isEnglish ? 'Min Stock Qty' : 'ปริมาณขั้นต่ำ', _minStockCtrl, keyboard: const TextInputType.numberWithOptions(decimal: true), formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))])),
        const SizedBox(width: 10),
        Expanded(child: _buildField(isEnglish ? 'Max Stock Qty' : 'ปริมาณสูงสุด', _maxStockCtrl, keyboard: const TextInputType.numberWithOptions(decimal: true), formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))])),
        const SizedBox(width: 10),
        Expanded(child: _buildField(isEnglish ? 'Reorder Point' : 'จุดสั่งซื้อซ้ำ', _reorderCtrl, keyboard: const TextInputType.numberWithOptions(decimal: true), formatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))])),
      ]),
    ]);
  }

  Widget _buildPricesSection() {
    final isEnglish = _isEnglish;
    final title = isEnglish ? 'Prices (${_priceRows.length})' : 'ราคา (${_priceRows.length})';

    if (widget.selected?.id == null) {
      return _Section(title: title, initiallyExpanded: false, children: [
        Text(
          isEnglish ? 'Save the item first to see and manage its prices.' : 'บันทึกสินค้าก่อนจึงจะดู/จัดการราคาได้',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ]);
    }

    return _Section(title: title, initiallyExpanded: false, children: [
      Text(
        isEnglish
            ? 'Managed from the Price List screen — shown here for reference only.'
            : 'จัดการได้จากหน้าจอตารางราคา — ตรงนี้แสดงไว้เพื่ออ้างอิงเท่านั้น',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      const SizedBox(height: 8),
      if (_isLoadingPrices)
        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: CircularProgressIndicator()))
      else if (_priceRows.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(isEnglish ? 'This item is not on any price list yet' : 'สินค้านี้ยังไม่อยู่ในตารางราคาใด', style: TextStyle(color: Colors.grey.shade600)),
        )
      else
        ..._priceRows.map((r) {
          final rangeText = (r.effectiveFrom != null || r.effectiveTo != null)
              ? '  ·  ${r.effectiveFrom != null ? '${r.effectiveFrom!.day}/${r.effectiveFrom!.month}/${r.effectiveFrom!.year}' : '…'} - ${r.effectiveTo != null ? '${r.effectiveTo!.day}/${r.effectiveTo!.month}/${r.effectiveTo!.year}' : '…'}'
              : '';
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: ListTile(
              dense: true,
              leading: Icon(r.listType == 'PURCHASE' ? Icons.shopping_cart_outlined : Icons.sell_outlined, color: Colors.teal, size: 20),
              title: Text('${r.priceListCode}  ${r.priceListName}'),
              subtitle: Text(
                isEnglish
                    ? 'Price: ${r.unitPriceFc} ${r.currencyCode ?? ''} / ${r.uomCode ?? ''}${r.minQty > 0 ? '  ·  Min qty ${r.minQty}' : ''}$rangeText'
                    : 'ราคา: ${r.unitPriceFc} ${r.currencyCode ?? ''} / ${r.uomCode ?? ''}${r.minQty > 0 ? '  ·  ขั้นต่ำ ${r.minQty}' : ''}$rangeText',
              ),
            ),
          );
        }),
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
            _buildUomConversionSection(),
            _buildStockSection(),
            _buildItemWarehouseSection(),
            _buildGlAccountSection(),
            _buildPricesSection(),
          ]),
        ),
      ]),
    );
  }
}
