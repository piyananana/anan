import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../../cd/models/cd_vat_rate.dart';
import '../../cd/services/cd_vat_rate_service.dart';
import '../models/im_item.dart';
import '../models/im_item_category.dart';
import '../models/im_uom.dart';
import '../models/im_warehouse.dart';
import '../models/im_location.dart';
import '../models/im_price_list.dart';
import '../services/im_item_running_service.dart';
import '../services/im_item_service.dart';
import 'im_master_kit.dart' show ImHScroll;
import '../services/im_item_category_service.dart';
import '../services/im_location_service.dart';
import '../services/im_price_list_service.dart';
import '../widgets/im_item_category_list_tree_widget.dart';
import '../widgets/im_uom_list_widget.dart';
import '../widgets/im_warehouse_list_widget.dart';
import '../../sa/utils/sa_menu_theme.dart';

// ---------------------------------------------------------------------------
// Add/Edit alternate unit dialog
// ---------------------------------------------------------------------------
/// เพิ่ม/แก้หน่วยของสินค้า: 1 [หน่วยนี้] = อัตรา × [หน่วยหลัก]
/// [baseUomId]/[baseLabel] = หน่วยหลักของสินค้า, [usedUomIds] = หน่วยที่มีในรายการแล้ว (ไม่รวมแถวที่กำลังแก้)
Future<ImUomConversion?> _showUomConversionDialog(
  BuildContext context,
  ImUomConversion? existing, {
  required int? baseUomId,
  required String baseLabel,
  required Set<int> usedUomIds,
}) async {
  final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
  int? uomId = existing?.uomId;
  String? uomCode = existing?.uomCode;
  String? uomNameTh = existing?.uomNameTh;
  String? uomNameEn = existing?.uomNameEn;
  final factorCtrl = TextEditingController(
      text: existing != null ? NumberFormat('0.######').format(existing.conversionFactor) : '');
  final barcodeCtrl = TextEditingController(text: existing?.barcode ?? '');
  bool allowPurchase = existing?.allowPurchase ?? true;
  bool allowSales = existing?.allowSales ?? true;
  bool allowProduction = existing?.allowProduction ?? true;
  bool isActive = existing?.isActive ?? true;
  bool isPurchaseDefault = existing?.isPurchaseDefault ?? false;
  bool isSalesDefault = existing?.isSalesDefault ?? false;
  bool isProductionDefault = existing?.isProductionDefault ?? false;
  bool isCountDefault = existing?.isCountDefault ?? false;
  bool isReportDefault = existing?.isReportDefault ?? false;

  String unitName() => isEnglish && (uomNameEn ?? '').isNotEmpty ? uomNameEn! : (uomNameTh ?? '');

  Widget check(String label, bool value, ValueChanged<bool> onChanged, {bool enabled = true}) => SizedBox(
        width: 180,
        child: CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(label, style: TextStyle(fontSize: 13, color: enabled ? null : Colors.grey)),
          value: value,
          onChanged: enabled ? (v) => onChanged(v ?? false) : null,
        ),
      );

  final result = await showDialog<ImUomConversion>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
      final factor = double.tryParse(factorCtrl.text);
      return AlertDialog(
        title: Text(existing == null ? (isEnglish ? 'Add Unit' : 'เพิ่มหน่วยของสินค้า') : (isEnglish ? 'Edit Unit' : 'แก้ไขหน่วยของสินค้า')),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
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
                            ? Text('$uomCode — ${unitName()}', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)
                            : Text(isEnglish ? '— Not specified —' : '— ไม่ระบุ —', style: TextStyle(color: Colors.grey.shade600)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.search, color: Colors.teal),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => ImUomListWidget.search(ctx, onSelected: (ImUom u) {
                          setDlg(() { uomId = u.id; uomCode = u.uomCode; uomNameTh = u.uomNameTh; uomNameEn = u.uomNameEn; });
                        }),
                      ),
                    ]),
                  ),
                ),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text('1 ${uomId != null ? unitName() : (isEnglish ? 'unit' : 'หน่วยนี้')} =', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: factorCtrl,
                      textAlign: TextAlign.right,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      onChanged: (_) => setDlg(() {}),
                      decoration: InputDecoration(labelText: isEnglish ? 'Factor *' : 'อัตรา *', border: const OutlineInputBorder(), isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(baseLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ]),
                if (factor != null && factor > 0 && factor < 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      isEnglish ? 'Smaller than the base unit — check the factor is not reversed' : 'หน่วยนี้เล็กกว่าหน่วยหลัก — ตรวจว่าไม่ได้ป้อนอัตรากลับด้าน',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                    ),
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: barcodeCtrl,
                  decoration: InputDecoration(labelText: isEnglish ? 'Barcode of this unit' : 'บาร์โค้ดของหน่วยนี้', border: const OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 10),
                Text(isEnglish ? 'Used for' : 'ใช้ในงาน', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Wrap(children: [
                  check(isEnglish ? 'Purchasing' : 'ซื้อ', allowPurchase, (v) => setDlg(() { allowPurchase = v; if (!v) isPurchaseDefault = false; })),
                  check(isEnglish ? 'Sales' : 'ขาย', allowSales, (v) => setDlg(() { allowSales = v; if (!v) isSalesDefault = false; })),
                  check(isEnglish ? 'Production' : 'ผลิต', allowProduction, (v) => setDlg(() { allowProduction = v; if (!v) isProductionDefault = false; })),
                ]),
                const SizedBox(height: 4),
                Text(isEnglish ? 'Default unit for' : 'เป็นหน่วยเริ่มต้นของ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Wrap(children: [
                  check(isEnglish ? 'Purchasing' : 'ซื้อ', isPurchaseDefault, (v) => setDlg(() => isPurchaseDefault = v), enabled: allowPurchase && isActive),
                  check(isEnglish ? 'Sales' : 'ขาย', isSalesDefault, (v) => setDlg(() => isSalesDefault = v), enabled: allowSales && isActive),
                  check(isEnglish ? 'Production' : 'ผลิต', isProductionDefault, (v) => setDlg(() => isProductionDefault = v), enabled: allowProduction && isActive),
                  check(isEnglish ? 'Stock count' : 'ตรวจนับ', isCountDefault, (v) => setDlg(() => isCountDefault = v), enabled: isActive),
                  check(isEnglish ? 'Reports' : 'รายงาน', isReportDefault, (v) => setDlg(() => isReportDefault = v), enabled: isActive),
                ]),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(isEnglish ? 'Active (usable on new documents)' : 'ใช้งาน (เลือกได้ในเอกสารใหม่)'),
                  value: isActive,
                  activeColor: Colors.teal,
                  onChanged: (v) => setDlg(() {
                    isActive = v;
                    if (!v) { isPurchaseDefault = false; isSalesDefault = false; isProductionDefault = false; isCountDefault = false; isReportDefault = false; }
                  }),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(
            onPressed: () {
              String? err;
              final f = double.tryParse(factorCtrl.text);
              if (uomId == null) {
                err = isEnglish ? 'Please select a unit' : 'กรุณาเลือกหน่วยนับ';
              } else if (uomId == baseUomId) {
                err = isEnglish ? 'This is already the base unit' : 'หน่วยนี้เป็นหน่วยหลักของสินค้าอยู่แล้ว';
              } else if (usedUomIds.contains(uomId)) {
                err = isEnglish ? 'This unit is already in the list' : 'หน่วยนี้มีในรายการแล้ว';
              } else if (f == null || f <= 0) {
                err = isEnglish ? 'Factor must be greater than 0' : 'อัตราแปลงต้องมากกว่า 0';
              }
              if (err != null) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
                return;
              }
              Navigator.of(ctx).pop(ImUomConversion(
                id: existing?.id,
                uomId: uomId!,
                uomCode: uomCode,
                uomNameTh: uomNameTh,
                uomNameEn: uomNameEn,
                conversionFactor: f!,
                barcode: barcodeCtrl.text.trim().isEmpty ? null : barcodeCtrl.text.trim(),
                isPurchaseDefault: isPurchaseDefault,
                isSalesDefault: isSalesDefault,
                isProductionDefault: isProductionDefault,
                isCountDefault: isCountDefault,
                isReportDefault: isReportDefault,
                allowPurchase: allowPurchase,
                allowSales: allowSales,
                allowProduction: allowProduction,
                isActive: isActive,
              ));
            },
            child: Text(isEnglish ? 'OK' : 'ตกลง'),
          ),
        ],
      );
    }),
  );
  factorCtrl.dispose();
  barcodeCtrl.dispose();
  return result;
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
                    ...availableLocations.map((l) => DropdownMenuItem(value: l.id, child: Text('${l.locationCode}  ${l.displayName(isEnglish)}'))),
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

// ---------------------------------------------------------------------------
// หน้ารายละเอียดสินค้า (แบบ B, user 2026-11-25): แถบหัวพร้อมปุ่ม, แถบลิงก์ข้ามส่วน (เลื่อนหน้าเดียว ไม่ใช่แท็บ),
// ตัวเลขสรุปสต็อก, ฟอร์ม 4 กลุ่มสีแบบหัวเอกสาร IM, การ์ดหน่วยนับ/คลังสินค้า/ตารางราคา (อ่านอย่างเดียว)/บัญชี GL (มาจาก)
// ---------------------------------------------------------------------------
class _TCol {
  final String label;
  final int flex;
  final bool num;
  const _TCol(this.label, this.flex, {this.num = false});
}

/// บัญชีที่ใช้จริงของ 1 ชนิด หลังรวมค่าที่กรอกในฟอร์ม (ยังไม่บันทึก) กับชั้นถัดไปจาก backend
class _GlEff {
  final String kind; // ITEM | CATEGORY | DOC_TYPE | COMPANY | NONE
  final String? code;
  final String? name;
  const _GlEff(this.kind, this.code, this.name);
}

class ImItemDetailWidget extends StatefulWidget {
  final Mode mode;
  final ImItem? selected;
  /// เพิ่มสินค้าใหม่โดยสำเนาจากสินค้านี้ (mode = add) — ล้างรหัส/บาร์โค้ด/ยอด ใช้ข้อมูลอื่นเป็นค่าตั้งต้น
  final ImItem? copyFrom;
  final Future<void> Function(ImItem) onSubmit;
  final VoidCallback onCancel;
  final VoidCallback? onEdit;
  final VoidCallback? onCopy;
  final VoidCallback? onDelete;
  final bool isPlaceholder;
  /// ปุ่มย่อ/ขยายรายการซ้าย — วางหน้ารหัส/ชื่อสินค้าบนแถบหัว (แทนแถบปุ่มแนวตั้งเดิม)
  final Widget? leading;
  // เพิ่มขึ้นทุกครั้งที่ผู้ใช้กดปุ่มเพิ่ม/แก้ไข/ดู/ยกเลิกจากหน้าจอหลัก — ใช้บังคับให้ didUpdateWidget เคลียร์ฟอร์ม
  // เสมอ แม้ mode/selected จะ "เหมือนเดิม" กับครั้งก่อน (เช่น กดเพิ่มสินค้าซ้ำหลังพิมพ์ข้อมูลค้างไว้)
  final int requestSeq;

  const ImItemDetailWidget({
    super.key,
    required this.mode,
    required this.selected,
    this.copyFrom,
    required this.onSubmit,
    required this.onCancel,
    this.onEdit,
    this.onCopy,
    this.onDelete,
    this.isPlaceholder = false,
    this.leading,
    this.requestSeq = 0,
  });

  @override
  State<ImItemDetailWidget> createState() => ImItemDetailWidgetState();
}

class ImItemDetailWidgetState extends State<ImItemDetailWidget> {
  bool _isSaving = false;
  bool _isEnglish = false;
  final _svc = ImItemService();

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
  late TextEditingController _shelfLifeCtrl;

  bool _isActive = true;
  String _itemType = 'STOCK';
  String _costingMethod = 'AVG';
  String _defaultVatType = 'VAT7';
  List<VatRate> _vatRates = [];
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
  bool _baseUomLocked = false; List<String> _baseUomUsedIn = const [];
  int? _defaultWarehouseId; String? _defaultWarehouseCode; String? _defaultWarehouseName;
  int? _inventoryAccountId; String? _inventoryAccountCode; String? _inventoryAccountName;
  int? _cogsAccountId; String? _cogsAccountCode; String? _cogsAccountName;
  int? _revenueAccountId; String? _revenueAccountCode; String? _revenueAccountName;
  int? _expenseAccountId; String? _expenseAccountCode; String? _expenseAccountName;
  String? _accountingMode;
  int? _purchasesAccountId; String? _purchasesAccountCode; String? _purchasesAccountName;

  List<Account> _accounts = [];
  List<ImItemPriceRow> _priceRows = [];
  List<ImUomConversion> _uomConversions = [];
  List<ImItemWarehouse> _itemWarehouses = [];
  bool _isLoadingPrices = false;

  // สรุปสต็อก/บัญชี (GET im_item/:id/summary) — สินค้าใหม่/สำเนา = เฉพาะชั้นบัญชีตั้งต้น
  ImItemSummary? _summary;
  bool _loadingSummary = false;
  int _summarySeq = 0;
  // บัญชีของหมวดสินค้าที่เลือกในฟอร์ม (เปลี่ยนหมวดแล้วยังไม่บันทึก ก็คำนวณ "มาจาก" ได้ทันที)
  Map<String, ImGlAccountRef?> _catGl = {};

  // แถบลิงก์ข้ามส่วน: 0 ข้อมูลหลัก, 1 หน่วยนับ, 2 คลังสินค้า, 3 ราคา, 4 บัญชี GL
  final _scrollCtrl = ScrollController();
  final _bodyKey = GlobalKey();
  final List<GlobalKey> _secKeys = List.generate(5, (_) => GlobalKey());
  int _activeSec = 0;
  bool _activeScheduled = false;
  bool _glExpanded = false;

  // ค่าตอนโหลดเสร็จ — เทียบเพื่อรู้ว่ามีการแก้ไขค้าง (เปลี่ยนสินค้า/ยกเลิก ต้องยืนยันก่อน)
  String _snapshot = '';

  bool get _isReadOnly => widget.mode == Mode.view || widget.mode == Mode.none;
  bool get _isCopy => widget.mode == Mode.add && widget.copyFrom != null;

  /// มีการแก้ไขที่ยังไม่บันทึก (เฉพาะโหมดเพิ่ม/แก้ไข)
  bool get isDirty => !_isReadOnly && !widget.isPlaceholder && _fingerprint() != _snapshot;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadAccounts();
    _loadVatRates();
    _applyWidget();
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
    _shelfLifeCtrl = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant ImItemDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected || widget.mode != oldWidget.mode ||
        widget.requestSeq != oldWidget.requestSeq || widget.copyFrom != oldWidget.copyFrom) {
      _applyWidget();
    }
  }

  // ตั้งฟอร์มตาม mode/selected/copyFrom — ไม่เรียก setState ตรงนี้ (เรียกจาก initState/didUpdateWidget)
  void _applyWidget() {
    _activeSec = 0;
    _summary = null;
    _catGl = {};
    _summarySeq++;
    final sel = widget.selected;
    final src = widget.copyFrom;
    if (sel != null) {
      _populate(sel);
      if (sel.id != null) {
        _loadPrices(sel.id!);
        _loadSummary(sel.id!);
      }
    } else if (widget.mode == Mode.add && src != null) {
      _populate(src);
      _applyCopy();
      _loadSummary(src.id ?? 0, glOnly: true);
      if (src.categoryId != null) _loadCategoryAutoNumber(src.categoryId!);
    } else {
      _clear();
      if (widget.mode == Mode.add) _loadSummary(0, glOnly: true);
    }
    if (widget.mode == Mode.add) _loadAutoNumberingConfig();
    // เลื่อนกลับบนสุดหลังเฟรม — jumpTo ระหว่าง build จะส่ง ScrollNotification → setState ระหว่าง build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
    });
    _snapshot = _fingerprint();
  }

  @override
  void dispose() {
    _codeCtrl.dispose(); _oldCodeCtrl.dispose(); _barcodeCtrl.dispose(); _nameThCtrl.dispose(); _nameEnCtrl.dispose();
    _descCtrl.dispose(); _standardCostCtrl.dispose(); _minStockCtrl.dispose();
    _maxStockCtrl.dispose(); _reorderCtrl.dispose(); _shelfLifeCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrices(int itemId) async {
    _isLoadingPrices = true;
    try {
      final rows = await ImPriceListService().fetchByItem(itemId);
      if (mounted) setState(() => _priceRows = rows);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingPrices = false);
    }
  }

  Future<void> _loadSummary(int itemId, {bool glOnly = false}) async {
    final seq = ++_summarySeq;
    _loadingSummary = true;
    try {
      final s = await _svc.fetchSummary(itemId);
      if (!mounted || seq != _summarySeq) return;
      setState(() {
        // สำเนา/สินค้าใหม่: ใช้เฉพาะชั้นบัญชี (หมวด/ประเภทเอกสาร/บริษัท) — ไม่เอายอดและบัญชีของคลังจากสินค้าต้นทาง
        _summary = glOnly
            ? ImItemSummary(gl: [
                for (final g in s.gl) ImItemGlLayers(key: g.key, category: g.category, docType: g.docType, company: g.company),
              ])
            : s;
        _catGl = {for (final g in s.gl) g.key: g.category};
      });
    } catch (_) {
    } finally {
      if (mounted && seq == _summarySeq) setState(() => _loadingSummary = false);
    }
  }

  Future<void> _loadCategoryAutoNumber(int categoryId) async {
    try {
      final c = await ImItemCategoryService().fetchRow(categoryId);
      if (mounted && _categoryId == categoryId) setState(() => _categoryIsAutoNumber = c.isAutoNumber);
    } catch (_) {}
  }

  Future<void> _loadAccounts() async {
    try {
      final list = await AccountService().fetchRows();
      if (mounted) setState(() => _accounts = list.where((a) => a.isActive && a.isNormalAccount).toList());
    } catch (_) {}
  }

  Future<void> _loadVatRates() async {
    try {
      final list = await VatRateService().fetchRows();
      if (!mounted) return;
      setState(() {
        _vatRates = list.where((v) => v.isActive).toList();
        // 'VAT7' เป็นแค่ placeholder ตอนสร้างสินค้าใหม่ (widget.selected == null) ไม่ใช่รหัสที่รับประกันว่ามีจริง
        // ในระบบ (แต่ละบริษัทตั้งรหัส VAT เองไม่เหมือนกัน) — ถ้าไม่พบใน _vatRates ต้องเปลี่ยนเป็นรหัสแรกที่มีจริง
        // ไม่เช่นนั้นจะบันทึก default_vat_type ที่ไม่มีอยู่จริงแบบเงียบๆ (dropdown โชว์ "ไม่ระบุ" แต่ค่าจริงยังเป็น 'VAT7')
        if (widget.selected == null && !_vatRates.any((v) => v.vatCode == _defaultVatType) && _vatRates.isNotEmpty) {
          final wasClean = _fingerprint() == _snapshot;
          _defaultVatType = _vatRates.first.vatCode;
          if (wasClean) _snapshot = _fingerprint();
        }
      });
    } catch (_) {}
  }

  String _vatLabel(String vatCode) {
    final v = _vatRates.cast<VatRate?>().firstWhere((x) => x?.vatCode == vatCode, orElse: () => null);
    if (v != null) {
      final rateStr = v.rate == v.rate.roundToDouble() ? v.rate.toStringAsFixed(0) : v.rate.toString();
      return '${v.vatCode}  $rateStr%';
    }
    return vatCode;
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
    _standardCostCtrl.text = _numText(item.standardCost);
    _minStockCtrl.text = _numText(item.minStockQty);
    _maxStockCtrl.text = _numText(item.maxStockQty);
    _reorderCtrl.text = _numText(item.reorderPoint);
    _shelfLifeCtrl.text = item.shelfLifeDays?.toString() ?? '';
    _isActive = item.isActive;
    _itemType = item.itemType;
    _costingMethod = item.costingMethod;
    _defaultVatType = item.defaultVatType;
    _isPurchaseItem = item.isPurchaseItem;
    _isSalesItem = item.isSalesItem;
    _isManufactured = item.isManufactured;
    _isLotTracked = item.isLotTracked;
    _isSerialTracked = item.isSerialTracked;
    _categoryId = item.categoryId; _categoryCode = item.categoryCode; _categoryName = item.categoryName;
    _categoryIsAutoNumber = false;
    _autoCodeOverridden = false;
    _isCodeAutoGenerated = item.isCodeAutoGenerated;
    _baseUomId = item.baseUomId; _baseUomCode = item.baseUomCode;
    _baseUomLocked = item.baseUomLocked; _baseUomUsedIn = item.baseUomUsedIn;
    _baseUomName = _isEnglish && (item.baseUomNameEn ?? '').isNotEmpty ? item.baseUomNameEn : item.baseUomNameTh;
    _defaultWarehouseId = item.defaultWarehouseId; _defaultWarehouseCode = item.defaultWarehouseCode;
    _defaultWarehouseName = _isEnglish && (item.defaultWarehouseNameEn ?? '').isNotEmpty ? item.defaultWarehouseNameEn : item.defaultWarehouseNameTh;
    _inventoryAccountId = item.inventoryAccountId; _inventoryAccountCode = item.inventoryAccountCode; _inventoryAccountName = item.inventoryAccountName;
    _cogsAccountId = item.cogsAccountId; _cogsAccountCode = item.cogsAccountCode; _cogsAccountName = item.cogsAccountName;
    _revenueAccountId = item.revenueAccountId; _revenueAccountCode = item.revenueAccountCode; _revenueAccountName = item.revenueAccountName;
    _expenseAccountId = item.expenseAccountId; _expenseAccountCode = item.expenseAccountCode; _expenseAccountName = item.expenseAccountName;
    _accountingMode = item.accountingMode;
    _purchasesAccountId = item.purchasesAccountId; _purchasesAccountCode = item.purchasesAccountCode; _purchasesAccountName = item.purchasesAccountName;
    _uomConversions = List.from(item.uomConversions);
    _itemWarehouses = List.from(item.itemWarehouses);
    _priceRows = [];
  }

  // สำเนาเป็นสินค้าใหม่: รหัส/รหัสเก่า/บาร์โค้ด (รวมบาร์โค้ดของหน่วย) ต้องไม่ซ้ำ จึงล้างทิ้ง; ราคา/ยอดไม่ติดมา
  void _applyCopy() {
    _codeCtrl.clear();
    _oldCodeCtrl.clear();
    _barcodeCtrl.clear();
    _isCodeAutoGenerated = false;
    _autoCodeOverridden = false;
    _baseUomLocked = false;
    _baseUomUsedIn = const [];
    _uomConversions = [
      for (final c in _uomConversions)
        ImUomConversion(
          uomId: c.uomId, uomCode: c.uomCode, uomNameTh: c.uomNameTh, uomNameEn: c.uomNameEn,
          conversionFactor: c.conversionFactor,
          isPurchaseDefault: c.isPurchaseDefault, isSalesDefault: c.isSalesDefault,
          isProductionDefault: c.isProductionDefault, isCountDefault: c.isCountDefault, isReportDefault: c.isReportDefault,
          allowPurchase: c.allowPurchase, allowSales: c.allowSales, allowProduction: c.allowProduction, isActive: c.isActive,
        ),
    ];
    _itemWarehouses = [
      for (final w in _itemWarehouses)
        ImItemWarehouse(
          warehouseId: w.warehouseId, warehouseCode: w.warehouseCode, warehouseNameTh: w.warehouseNameTh,
          warehouseNameEn: w.warehouseNameEn, minStockQty: w.minStockQty, maxStockQty: w.maxStockQty,
          reorderPoint: w.reorderPoint, defaultLocationId: w.defaultLocationId, defaultLocationCode: w.defaultLocationCode,
        ),
    ];
    _priceRows = [];
  }

  void _clear() {
    _codeCtrl.clear(); _oldCodeCtrl.clear(); _barcodeCtrl.clear(); _nameThCtrl.clear(); _nameEnCtrl.clear(); _descCtrl.clear();
    _standardCostCtrl.text = '0'; _minStockCtrl.text = '0'; _maxStockCtrl.text = '0'; _reorderCtrl.text = '0';
    _shelfLifeCtrl.clear();
    _isActive = true; _itemType = 'STOCK'; _costingMethod = 'AVG';
    _defaultVatType = _vatRates.isNotEmpty ? _vatRates.first.vatCode : 'VAT7';
    _isPurchaseItem = true; _isSalesItem = true; _isManufactured = false;
    _isLotTracked = false; _isSerialTracked = false; _autoCodeOverridden = false;
    _categoryId = null; _categoryCode = null; _categoryName = null; _categoryIsAutoNumber = false;
    _isCodeAutoGenerated = false;
    _baseUomId = null; _baseUomCode = null; _baseUomName = null;
    _baseUomLocked = false; _baseUomUsedIn = const [];
    _defaultWarehouseId = null; _defaultWarehouseCode = null; _defaultWarehouseName = null;
    _inventoryAccountId = null; _inventoryAccountCode = null; _inventoryAccountName = null;
    _cogsAccountId = null; _cogsAccountCode = null; _cogsAccountName = null;
    _revenueAccountId = null; _revenueAccountCode = null; _revenueAccountName = null;
    _expenseAccountId = null; _expenseAccountCode = null; _expenseAccountName = null;
    _accountingMode = null;
    _purchasesAccountId = null; _purchasesAccountCode = null; _purchasesAccountName = null;
    _priceRows = [];
    _uomConversions = [];
    _itemWarehouses = [];
  }

  static String _numText(double v) => NumberFormat('0.######').format(v);

  String get _baseUomLabel => _baseUomId == null
      ? (_isEnglish ? 'base unit' : 'หน่วยหลัก')
      : (_baseUomName ?? _baseUomCode ?? '');

  Future<ImUomConversion?> _openUomConversionDialog(int? index) {
    final used = <int>{
      for (var i = 0; i < _uomConversions.length; i++)
        if (i != index) _uomConversions[i].uomId,
    };
    return _showUomConversionDialog(context, index == null ? null : _uomConversions[index],
        baseUomId: _baseUomId, baseLabel: _baseUomLabel, usedUomIds: used);
  }

  // หน่วยเริ่มต้นแต่ละงานมีได้หน่วยเดียว — ตั้งที่แถวใหม่แล้วล้างของแถวอื่น
  void _putUomConversion(int? index, ImUomConversion row) {
    setState(() {
      _uomConversions = [
        for (var i = 0; i < _uomConversions.length; i++)
          if (i == index) row
          else _uomConversions[i].copyWith(
            isPurchaseDefault: row.isPurchaseDefault ? false : null,
            isSalesDefault: row.isSalesDefault ? false : null,
            isProductionDefault: row.isProductionDefault ? false : null,
            isCountDefault: row.isCountDefault ? false : null,
            isReportDefault: row.isReportDefault ? false : null,
          ),
        if (index == null) row,
      ];
    });
  }

  Future<void> _addUomConversion() async {
    final result = await _openUomConversionDialog(null);
    if (result != null) _putUomConversion(null, result);
  }

  Future<void> _editUomConversion(int index) async {
    final result = await _openUomConversionDialog(index);
    if (result != null) _putUomConversion(index, result);
  }

  void _removeUomConversion(int index) => setState(() => _uomConversions.removeAt(index));

  Future<void> _addItemWarehouse([ImItemWarehouse? prefill]) async {
    final result = await _showItemWarehouseDialog(context, prefill);
    if (result == null) return;
    if (_itemWarehouses.any((w) => w.warehouseId == result.warehouseId)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEnglish ? 'This warehouse already has a setting' : 'คลังนี้มีการตั้งค่าแล้ว'),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }
    setState(() => _itemWarehouses.add(result));
  }

  Future<void> _editItemWarehouse(int index) async {
    final result = await _showItemWarehouseDialog(context, _itemWarehouses[index]);
    if (result != null) setState(() => _itemWarehouses[index] = result);
  }

  void _removeItemWarehouse(int index) => setState(() => _itemWarehouses.removeAt(index));

  ImItem _buildItem() => ImItem(
        id: widget.selected?.id,
        itemCode: (widget.mode == Mode.add && _effectiveAutoNumbering && !_autoCodeOverridden) ? '' : _codeCtrl.text.trim().toUpperCase(),
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
        shelfLifeDays: _shelfLifeCtrl.text.trim().isEmpty ? null : int.tryParse(_shelfLifeCtrl.text.trim()),
        defaultVatType: _defaultVatType,
        inventoryAccountId: _inventoryAccountId,
        cogsAccountId: _cogsAccountId,
        revenueAccountId: _revenueAccountId,
        expenseAccountId: _expenseAccountId,
        accountingMode: _accountingMode,
        purchasesAccountId: _purchasesAccountId,
        isActive: _isActive,
        uomConversions: _uomConversions,
        itemWarehouses: _itemWarehouses,
      );

  String _fingerprint() => docFingerprint(_buildItem().toJson());

  Future<void> _save() async {
    final isEnglish = _isEnglish;
    final codeNeeded = widget.mode == Mode.add && (!_effectiveAutoNumbering || _autoCodeOverridden);
    String? err;
    if (codeNeeded && _codeCtrl.text.trim().isEmpty) {
      err = isEnglish ? 'Please enter the item code' : 'กรุณาป้อนรหัสสินค้า';
    } else if (_nameThCtrl.text.trim().isEmpty) {
      err = isEnglish ? 'Please enter the item name (Thai)' : 'กรุณาป้อนชื่อสินค้า (ไทย)';
    }
    if (err != null) {
      _jumpTo(0);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.onSubmit(_buildItem());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

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
      ImGlAccountRef? ref(int? id, String? code, String? name) =>
          id == null ? null : ImGlAccountRef(id: id, code: code ?? '', nameThai: name ?? '');
      setState(() {
        _categoryId = c.id; _categoryCode = c.categoryCode; _categoryName = c.categoryNameTh;
        _categoryIsAutoNumber = c.isAutoNumber;
        if (_categoryIsAutoNumber) _autoCodeOverridden = false;
        _catGl = {
          'inventory': ref(c.inventoryAccountId, c.inventoryAccountCode, c.inventoryAccountName),
          'cogs': ref(c.cogsAccountId, c.cogsAccountCode, c.cogsAccountName),
          'revenue': ref(c.revenueAccountId, c.revenueAccountCode, c.revenueAccountName),
          'expense': ref(c.expenseAccountId, c.expenseAccountCode, c.expenseAccountName),
          'purchases': ref(c.purchasesAccountId, c.purchasesAccountCode, c.purchasesAccountName),
        };
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

  // ── สไตล์ (ตรงกับหัวเอกสาร IM) ───────────────────────────────────────────
  static const _hAuto = Color(0xFFE3EEFA);
  static const _hRo = Color(0xFFEEF0F2);
  static const _gDoc = Color(0xFF1E5AA8);
  static const _gParty = Color(0xFF1F7A4D);
  static const _gFin = Color(0xFFB45309);
  static const _gMore = Color(0xFF5B6B7C);
  Color get _im => ScreenTheme.of(context).ink;
  Color get _imSoft => ScreenTheme.of(context).soft;
  static const _line = Color(0xFFE1E6E3);
  static const _ink2 = Color(0xFF55625B);
  static const _ink3 = Color(0xFF8B968F);
  static const _red = Color(0xFFC62828);
  static const _gold = Color(0xFFE0A526);
  static const double _hFieldH = 40;
  static const double _hFontSize = 13;

  final _qtyFmt = NumberFormat('#,##0.##');
  final _amtFmt = NumberFormat('#,##0.00');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  InputDecoration _hDec(String label, {bool auto = false, bool editable = true, Widget? suffixIcon}) {
    final req = label.endsWith(' *');
    final text = req ? label.substring(0, label.length - 2) : label;
    return InputDecoration(
      label: req
          ? Text.rich(TextSpan(text: text, children: const [TextSpan(text: ' *', style: TextStyle(color: _red))]))
          : Text(text),
      labelStyle: const TextStyle(fontSize: _hFontSize),
      floatingLabelStyle: const TextStyle(fontSize: 16),
      border: const OutlineInputBorder(),
      // กรอบสูงเท่ากันทุกช่อง — ดู pattern_input_border_height (ไม่ dense + tightFor height)
      isDense: false,
      constraints: const BoxConstraints.tightFor(height: _hFieldH),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 24, maxHeight: 24),
      filled: !editable || auto,
      fillColor: !editable ? _hRo : _hAuto,
      suffixIcon: suffixIcon,
    );
  }

  Widget _txt(String label, TextEditingController c,
          {bool auto = false, bool? editable, bool numeric = false, bool digitsOnly = false, TextCapitalization cap = TextCapitalization.none}) {
    final ed = editable ?? !_isReadOnly;
    return TextField(
      controller: c,
      readOnly: !ed,
      textCapitalization: cap,
      textAlign: numeric ? TextAlign.right : TextAlign.start,
      keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : null,
      inputFormatters: digitsOnly
          ? [FilteringTextInputFormatter.digitsOnly]
          : numeric ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))] : null,
      style: const TextStyle(fontSize: _hFontSize),
      decoration: _hDec(label, auto: auto, editable: ed),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _dd<T>(String label, T? value, List<DropdownMenuItem<T>> items, ValueChanged<T?>? onChanged, {bool auto = true}) =>
      DropdownButtonFormField<T>(
        value: value,
        isExpanded: true,
        isDense: true,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: _hFontSize, color: Colors.black87),
        decoration: _hDec(label, auto: auto, editable: onChanged != null),
        items: items,
        onChanged: onChanged,
      );

  Widget _fk({required String label, required String? text, required bool hasValue, VoidCallback? onSearch, VoidCallback? onClear,
      bool auto = false, bool locked = false, String? lockedTip}) {
    final ed = !_isReadOnly && !locked && onSearch != null;
    return InkWell(
      onTap: ed ? onSearch : null,
      child: InputDecorator(
        decoration: _hDec(label, auto: auto, editable: ed),
        child: Row(children: [
          Expanded(
            child: hasValue
                ? Text(text ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: _hFontSize))
                : Text(_isEnglish ? '— Not specified —' : '— ไม่ระบุ —', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: _hFontSize, color: Colors.grey.shade600)),
          ),
          if (locked && !_isReadOnly)
            Tooltip(
              message: lockedTip ?? (_isEnglish ? 'Locked — code was auto-generated at creation' : 'ล็อก — รหัสถูกออกอัตโนมัติตอนสร้างข้อมูล'),
              child: Icon(Icons.lock, color: Colors.grey.shade500, size: 16),
            )
          else if (ed) ...[
            if (hasValue && onClear != null)
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.red, size: 16),
                tooltip: _isEnglish ? 'Clear' : 'ล้าง',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                onPressed: onClear,
              ),
            const Icon(Icons.search, color: Colors.teal, size: 18),
          ],
        ]),
      ),
    );
  }

  Widget _ck(String label, bool value, ValueChanged<bool>? onChanged, {String? tooltip}) {
    final w = InkWell(
      onTap: onChanged == null ? null : () => onChanged(!value),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: value ? const Color(0xFFEFF7F1) : null,
          border: Border.all(color: value ? const Color(0xFFB9DCC4) : _line),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(value ? Icons.check_box : Icons.check_box_outline_blank, size: 16,
              color: onChanged == null ? Colors.grey : (value ? _gParty : Colors.grey.shade600)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12.5, color: onChanged == null && !value ? Colors.grey : null)),
        ]),
      ),
    );
    return tooltip == null ? w : Tooltip(message: tooltip, child: w);
  }

  Widget _hRow(List<Widget> children, [List<int>? flex]) {
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) out.add(const SizedBox(width: 8));
      out.add(Expanded(flex: flex != null && i < flex.length ? flex[i] : 1, child: children[i]));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: out);
  }

  Widget _hGroup(int no, String title, Color color, List<Widget> rows) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFBFCFD),
          border: Border.all(color: const Color(0xFFDDE3EA)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(height: 3, color: color),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Container(
                  width: 18, height: 18, alignment: Alignment.center,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9)),
                  child: Text('$no', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 6),
                Flexible(child: Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 10),
              for (var i = 0; i < rows.length; i++) ...[if (i > 0) const SizedBox(height: 8), rows[i]],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _chip(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg)),
      );

  Widget _card({Key? key, required String title, String? count, Widget? trailing, required Widget child,
      bool collapsed = false, VoidCallback? onToggle, EdgeInsetsGeometry padding = const EdgeInsets.all(14)}) {
    return Container(
      key: key,
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _line), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 30),
              child: Row(children: [
                if (onToggle != null) ...[
                  Icon(collapsed ? Icons.chevron_right : Icons.expand_more, size: 20, color: _ink3),
                  const SizedBox(width: 4),
                ],
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                const SizedBox(width: 8),
                Expanded(
                  child: count == null
                      ? const SizedBox.shrink()
                      : Text(count, style: const TextStyle(fontSize: 12, color: _ink3), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                if (trailing != null) trailing,
              ]),
            ),
          ),
        ),
        if (!collapsed) ...[
          const Divider(height: 1, color: _line),
          Padding(padding: padding, child: child),
        ],
      ]),
    );
  }

  // ตาราง 36px: หัวเทาอ่อน, แถวเส้นคั่นบาง; แคบกว่า minWidth → เลื่อนแนวนอน
  Widget _table(List<_TCol> cols, List<List<Widget>> rows, {double minWidth = 600, List<VoidCallback?>? onTap, String? empty}) {
    Widget row(List<Widget> cells, {bool head = false, VoidCallback? tap}) => InkWell(
          onTap: tap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: head ? const Color(0xFFF6F8FA) : null,
              border: Border(bottom: BorderSide(color: head ? const Color(0xFFDDE3EA) : const Color(0xFFEEF1F4))),
            ),
            child: Row(children: [
              for (var i = 0; i < cols.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  flex: cols[i].flex,
                  child: Align(alignment: cols[i].num ? Alignment.centerRight : Alignment.centerLeft, child: cells[i]),
                ),
              ],
            ]),
          ),
        );
    final head = [
      for (final c in cols)
        Text(c.label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ink2)),
    ];
    final body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      row(head, head: true),
      for (var i = 0; i < rows.length; i++) row(rows[i], tap: onTap != null && i < onTap.length ? onTap[i] : null),
      if (rows.isEmpty && empty != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Text(empty, style: const TextStyle(color: _ink3, fontSize: 12.5)),
        ),
    ]);
    return LayoutBuilder(
      builder: (c, cons) => cons.maxWidth >= minWidth
          ? body
          : ImHScroll(width: minWidth, child: body),
    );
  }

  Widget _cell(String text, {bool bold = false, Color? color, bool mono = false}) => Text(
        text.isEmpty ? '—' : text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: bold ? FontWeight.w600 : null,
          color: color ?? (text.isEmpty ? _ink3 : null),
          fontFeatures: mono ? const [FontFeature.tabularFigures()] : null,
        ),
      );

  Widget _ghostButton(String label, IconData icon, VoidCallback onPressed) => TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: TextStyle(fontSize: 12.5, fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily)),
        style: TextButton.styleFrom(
          foregroundColor: _im,
          side: const BorderSide(color: _line),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, 30),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );

  // ── แถบลิงก์ข้ามส่วน ────────────────────────────────────────────────────
  List<(int, String)> get _sections => [
        (0, _isEnglish ? 'Main' : 'ข้อมูลหลัก'),
        (1, _isEnglish ? 'Units' : 'หน่วยนับ'),
        if (_itemType == 'STOCK') (2, _isEnglish ? 'Warehouses' : 'คลังสินค้า'),
        (3, _isEnglish ? 'Prices' : 'ราคา'),
        (4, _isEnglish ? 'GL Accounts' : 'บัญชี GL'),
      ];

  void _jumpTo(int i) {
    setState(() {
      _activeSec = i;
      if (i == 4) _glExpanded = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _secKeys[i].currentContext;
      if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  void _updateActiveSection() {
    final root = _bodyKey.currentContext?.findRenderObject() as RenderBox?;
    if (root == null || !_scrollCtrl.hasClients) return;
    final present = _sections.map((s) => s.$1).toList();
    var active = present.first;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 2 && pos.maxScrollExtent > 0) {
      active = present.last;
    } else {
      for (final i in present) {
        final b = _secKeys[i].currentContext?.findRenderObject() as RenderBox?;
        if (b == null || !b.attached) continue;
        if (b.localToGlobal(Offset.zero, ancestor: root).dy <= 60) active = i;
      }
    }
    if (active != _activeSec) setState(() => _activeSec = active);
  }

  Widget _buildAnchors() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final s in _sections)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: () => _jumpTo(s.$1),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                  decoration: BoxDecoration(
                    color: _activeSec == s.$1 ? _imSoft : null,
                    border: Border.all(color: _activeSec == s.$1 ? const Color(0xFFB7D6D3) : _line),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(s.$2,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _activeSec == s.$1 ? _im : _ink2,
                        fontWeight: _activeSec == s.$1 ? FontWeight.w600 : null,
                      )),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  // ── ตัวเลขสรุป (สินค้านับสต็อกที่บันทึกแล้ว) ─────────────────────────────
  Widget _buildKpis() {
    final isEnglish = _isEnglish;
    final s = _summary;
    final uom = _baseUomName ?? _baseUomCode ?? '';
    Widget tile(String label, String value, String sub, {bool warn = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: warn ? const Color(0xFFFFF8F7) : _imSoft,
            border: Border.all(color: warn ? const Color(0xFFF3C0BB) : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11.5, color: _ink2), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: warn ? _red : null,
                    fontFeatures: const [FontFeature.tabularFigures()])),
            Text(sub, style: const TextStyle(fontSize: 11.5, color: _ink2), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        );
    if (s == null) {
      return SizedBox(
        height: 64,
        child: Center(child: _loadingSummary ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const SizedBox.shrink()),
      );
    }
    String belowSub() {
      if (s.belowWarehouses.isNotEmpty) {
        final w = s.belowWarehouses.first;
        final more = s.belowWarehouses.length > 1 ? (isEnglish ? ' +${s.belowWarehouses.length - 1}' : ' และอีก ${s.belowWarehouses.length - 1}') : '';
        return isEnglish
            ? '${w['warehouse_code']} on hand ${_qtyFmt.format(_num(w['qty']))} · reorder ${_qtyFmt.format(_num(w['reorder_point']))}$more'
            : '${w['warehouse_code']} คงเหลือ ${_qtyFmt.format(_num(w['qty']))} · จุดสั่งซื้อ ${_qtyFmt.format(_num(w['reorder_point']))}$more';
      }
      if (s.belowItemLevel) {
        return isEnglish
            ? 'All warehouses below item reorder ${_qtyFmt.format(s.itemReorderPoint)}'
            : 'รวมทุกคลังต่ำกว่าจุดสั่งซื้อ ${_qtyFmt.format(s.itemReorderPoint)}';
      }
      return isEnglish ? 'All warehouses OK' : 'ทุกคลังปกติ';
    }

    final tiles = [
      tile(isEnglish ? 'On hand (all warehouses)' : 'คงเหลือทุกคลัง', '${_qtyFmt.format(s.totalQty)} $uom',
          isEnglish ? '${s.warehouseCount} warehouse(s)' : '${s.warehouseCount} คลัง'),
      tile(isEnglish ? 'Stock value' : 'มูลค่าคงเหลือ', _amtFmt.format(s.totalValue),
          isEnglish ? 'Avg cost ${_amtFmt.format(s.avgCost)} / $uom' : 'ต้นทุนเฉลี่ย ${_amtFmt.format(s.avgCost)} / $uom'),
      tile(isEnglish ? 'Below reorder point' : 'ต่ำกว่าจุดสั่งซื้อ',
          isEnglish ? '${s.belowCount}' : '${s.belowCount}${s.belowWarehouses.isNotEmpty ? ' คลัง' : ''}', belowSub(),
          warn: s.belowCount > 0),
      tile(isEnglish ? 'Last movement' : 'เคลื่อนไหวล่าสุด',
          s.lastMovementDate == null ? '—' : _dateFmt.format(s.lastMovementDate!),
          s.lastMovementDocNo == null
              ? (isEnglish ? 'No movement yet' : 'ยังไม่มีความเคลื่อนไหว')
              : '${s.lastMovementDocCode ?? ''} ${s.lastMovementDocNo} · ${_qtyFmt.format(s.lastMovementQty ?? 0)}'),
    ];
    return LayoutBuilder(builder: (c, cons) {
      final cols = cons.maxWidth >= 760 ? 4 : 2;
      final w = (cons.maxWidth - 8 * (cols - 1)) / cols;
      return Wrap(spacing: 8, runSpacing: 8, children: [for (final t in tiles) SizedBox(width: w, child: t)]);
    });
  }

  static double _num(dynamic v) => double.tryParse('${v ?? ''}') ?? 0;

  // ── การ์ดข้อมูลหลัก: 4 กลุ่มสี ─────────────────────────────────────────
  Widget _buildCodeField() {
    final isEnglish = _isEnglish;
    final isAdd = widget.mode == Mode.add;
    if (isAdd && _effectiveAutoNumbering && !_autoCodeOverridden) {
      return InputDecorator(
        decoration: _hDec(isEnglish ? 'Item Code' : 'รหัสสินค้า', auto: true),
        child: Row(children: [
          const Icon(Icons.auto_awesome, color: Colors.teal, size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Text(isEnglish ? 'Auto on save' : 'ออกรหัสอัตโนมัติ', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.teal, fontStyle: FontStyle.italic, fontSize: _hFontSize)),
          ),
          InkWell(
            onTap: () => setState(() => _autoCodeOverridden = true),
            child: Text(isEnglish ? 'Enter' : 'ป้อนเอง', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, decoration: TextDecoration.underline)),
          ),
        ]),
      );
    }
    if (isAdd && _effectiveAutoNumbering && _autoCodeOverridden) {
      return TextField(
        controller: _codeCtrl,
        textCapitalization: TextCapitalization.characters,
        style: const TextStyle(fontSize: _hFontSize),
        onChanged: (_) => setState(() {}),
        decoration: _hDec(isEnglish ? 'Item Code *' : 'รหัสสินค้า *',
            suffixIcon: IconButton(
              icon: const Icon(Icons.auto_awesome, color: Colors.teal, size: 16),
              tooltip: isEnglish ? 'Revert to auto-numbering' : 'กลับไปใช้รหัสอัตโนมัติ',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 24),
              onPressed: () => setState(() { _autoCodeOverridden = false; _codeCtrl.clear(); }),
            )),
      );
    }
    return _txt(isAdd ? (isEnglish ? 'Item Code *' : 'รหัสสินค้า *') : (isEnglish ? 'Item Code' : 'รหัสสินค้า'), _codeCtrl,
        editable: isAdd, cap: TextCapitalization.characters);
  }

  Widget _buildMainCard() {
    final isEnglish = _isEnglish;
    final ed = !_isReadOnly;
    final stock = _itemType == 'STOCK';

    final g1 = _hGroup(1, isEnglish ? 'Main Information' : 'ข้อมูลหลัก', _gDoc, [
      _hRow([_buildCodeField(), _txt(isEnglish ? 'Old Item Code' : 'รหัสสินค้าเก่า', _oldCodeCtrl)]),
      _txt(isEnglish ? 'Item Name (Thai) *' : 'ชื่อสินค้า (ไทย) *', _nameThCtrl),
      _txt(isEnglish ? 'Item Name (English)' : 'ชื่อสินค้า (อังกฤษ)', _nameEnCtrl),
      _hRow([
        _fk(
          label: isEnglish ? 'Category' : 'หมวดหมู่',
          hasValue: _categoryId != null,
          text: '$_categoryCode  ${_categoryName ?? ''}',
          onSearch: _pickCategory,
          onClear: () => setState(() {
            _categoryId = null; _categoryCode = null; _categoryName = null; _categoryIsAutoNumber = false;
            _catGl = {};
          }),
          locked: _categoryLocked,
        ),
        _txt(isEnglish ? 'Barcode' : 'บาร์โค้ด', _barcodeCtrl),
      ]),
    ]);

    final g2 = _hGroup(2, isEnglish ? 'Usage' : 'การใช้งาน', _gParty, [
      _hRow([
        _dd<String>(isEnglish ? 'Item Type' : 'ประเภทสินค้า', _itemType,
            imItemTypes.map((t) => DropdownMenuItem(value: t, child: Text(imItemTypeLabel(t, isEnglish), overflow: TextOverflow.ellipsis))).toList(),
            ed ? (v) => setState(() => _itemType = v ?? 'STOCK') : null),
        _fk(
          label: isEnglish ? 'Base Unit' : 'หน่วยนับหลัก',
          hasValue: _baseUomId != null,
          text: '$_baseUomCode  ${_baseUomName ?? ''}',
          onSearch: _pickUom,
          onClear: () => setState(() { _baseUomId = null; _baseUomCode = null; _baseUomName = null; }),
          // ใช้งานแล้ว = สต็อก/ต้นทุน/เอกสารเก่าคิดเป็นหน่วยนี้ เปลี่ยนไม่ได้
          locked: widget.mode == Mode.edit && _baseUomLocked,
          lockedTip: isEnglish
              ? 'Locked — this item is already used in: ${_baseUomUsedIn.join(', ')}'
              : 'ล็อก — สินค้านี้ใช้งานแล้วใน: ${_baseUomUsedIn.join(', ')}',
        ),
      ]),
      Wrap(spacing: 6, runSpacing: 6, children: [
        _ck(isEnglish ? 'Purchase' : 'ซื้อ', _isPurchaseItem, ed ? (v) => setState(() => _isPurchaseItem = v) : null,
            tooltip: isEnglish ? 'Can appear on purchase documents' : 'แสดงในเอกสารฝั่งซื้อ'),
        _ck(isEnglish ? 'Sales' : 'ขาย', _isSalesItem, ed ? (v) => setState(() => _isSalesItem = v) : null,
            tooltip: isEnglish ? 'Can appear on sales documents' : 'แสดงในเอกสารฝั่งขาย'),
        if (stock) ...[
          _ck(isEnglish ? 'Manufactured' : 'ผลิตเอง', _isManufactured, ed ? (v) => setState(() => _isManufactured = v) : null,
              tooltip: isEnglish ? 'Produced via a Bill of Materials' : 'ผลิตจาก Bill of Materials'),
          _ck(isEnglish ? 'Lot tracked' : 'ติดตามล็อต', _isLotTracked, ed ? (v) => setState(() => _isLotTracked = v) : null),
          _ck(isEnglish ? 'Serial tracked' : 'ติดตามซีเรียล', _isSerialTracked,
              (ed && _costingMethod != 'SPECIFIC') ? (v) => setState(() => _isSerialTracked = v) : null,
              tooltip: _costingMethod == 'SPECIFIC'
                  ? (isEnglish ? 'Required — costing method is Specific Identification' : 'จำเป็นต้องเปิด — วิธีคิดต้นทุนเป็นเฉพาะเจาะจง (ตาม Serial)')
                  : null),
        ],
      ]),
      if (stock)
        _hRow([
          _txt(isEnglish ? 'Shelf Life (days)' : 'อายุสินค้า (วัน)', _shelfLifeCtrl, numeric: true, digitsOnly: true),
          _fk(
            label: isEnglish ? 'Default Warehouse' : 'คลังเริ่มต้น',
            hasValue: _defaultWarehouseId != null,
            text: '$_defaultWarehouseCode  ${_defaultWarehouseName ?? ''}',
            onSearch: _pickWarehouse,
            onClear: () => setState(() { _defaultWarehouseId = null; _defaultWarehouseCode = null; _defaultWarehouseName = null; }),
            auto: true,
          ),
        ]),
    ]);

    final g3 = _hGroup(3, isEnglish ? 'Cost / Tax' : 'ต้นทุน / ภาษี', _gFin, [
      _hRow([
        _dd<String>(isEnglish ? 'Costing Method' : 'วิธีคิดต้นทุน', _costingMethod,
            imCostingMethods.map((m) => DropdownMenuItem(value: m, child: Text(imCostingMethodLabel(m, isEnglish), overflow: TextOverflow.ellipsis))).toList(),
            (ed && stock)
                ? (v) => setState(() {
                      _costingMethod = v ?? 'AVG';
                      // ต้นทุนเฉพาะเจาะจง (SPECIFIC) ต้องติดตาม serial เสมอ
                      if (_costingMethod == 'SPECIFIC') _isSerialTracked = true;
                    })
                : null),
        _txt(isEnglish ? 'Standard Cost' : 'ต้นทุนมาตรฐาน', _standardCostCtrl,
            numeric: true, editable: ed && _costingMethod == 'STANDARD'),
      ]),
      _hRow([
        _dd<String>(isEnglish ? 'Default VAT' : 'ประเภท VAT ตั้งต้น',
            _vatRates.any((v) => v.vatCode == _defaultVatType) ? _defaultVatType : null,
            _vatRates.map((v) => DropdownMenuItem(value: v.vatCode, child: Text(_vatLabel(v.vatCode)))).toList(),
            ed ? (v) => setState(() => _defaultVatType = v ?? _defaultVatType) : null),
        _dd<String?>(isEnglish ? 'Accounting Mode' : 'โหมดบัญชีสินค้า', _accountingMode, [
          DropdownMenuItem<String?>(value: null,
              child: Text(isEnglish ? 'Follow category / warehouse / default' : 'ตามหมวด / คลัง / ค่าเริ่มต้น', overflow: TextOverflow.ellipsis)),
          DropdownMenuItem<String?>(value: 'PERPETUAL', child: Text(isEnglish ? 'Perpetual' : 'Perpetual (โพสต์บัญชีทันที)', overflow: TextOverflow.ellipsis)),
          DropdownMenuItem<String?>(value: 'PERIODIC', child: Text(isEnglish ? 'Periodic' : 'Periodic (ปิดงวดครั้งเดียว)', overflow: TextOverflow.ellipsis)),
        ], ed ? (v) => setState(() => _accountingMode = v) : null),
      ]),
    ]);

    final g4 = _hGroup(4, isEnglish ? 'More' : 'เพิ่มเติม', _gMore, [
      if (stock)
        _hRow([
          _txt(isEnglish ? 'Min Stock' : 'สต็อกขั้นต่ำ', _minStockCtrl, numeric: true),
          _txt(isEnglish ? 'Max Stock' : 'สต็อกสูงสุด', _maxStockCtrl, numeric: true),
          _txt(isEnglish ? 'Reorder Point' : 'จุดสั่งซื้อ', _reorderCtrl, numeric: true),
        ]),
      _txt(isEnglish ? 'Description' : 'คำอธิบาย', _descCtrl),
      Align(
        alignment: Alignment.centerLeft,
        child: _ck(isEnglish ? 'Active' : 'ใช้งาน', _isActive, ed ? (v) => setState(() => _isActive = v) : null),
      ),
    ]);

    Widget legend(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 14, height: 10, decoration: BoxDecoration(color: c, border: Border.all(color: const Color(0xFFC9D1CC)), borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          Text(t, style: const TextStyle(fontSize: 11.5, color: _ink2)),
        ]);

    return _card(
      title: isEnglish ? 'Item Information' : 'ข้อมูลสินค้า',
      trailing: _isReadOnly
          ? null
          : Wrap(spacing: 12, children: [
              legend(Colors.white, isEnglish ? 'Entered' : 'กรอกเอง'),
              legend(_hAuto, isEnglish ? 'System default, editable' : 'ค่าตั้งต้นจากระบบ แก้ได้'),
              legend(_hRo, isEnglish ? 'Read-only' : 'อ่านอย่างเดียว'),
            ]),
      child: LayoutBuilder(builder: (c, cons) {
        if (cons.maxWidth < 860) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            g1, const SizedBox(height: 12), g2, const SizedBox(height: 12), g3, const SizedBox(height: 12), g4,
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: g1), const SizedBox(width: 12), Expanded(child: g2)]),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: g3), const SizedBox(width: 12), Expanded(child: g4)]),
        ]);
      }),
    );
  }

  // ── การ์ดหน่วยนับ ───────────────────────────────────────────────────────
  Widget _buildUnitsCard() {
    final isEnglish = _isEnglish;
    final ed = !_isReadOnly;
    final cols = [
      _TCol(isEnglish ? 'Unit' : 'หน่วย', 3),
      _TCol(isEnglish ? 'Conversion' : 'อัตราแปลง', 3, num: true),
      _TCol(isEnglish ? 'Barcode' : 'บาร์โค้ด', 3),
      _TCol(isEnglish ? 'Used for' : 'ใช้ใน', 3),
      _TCol(isEnglish ? 'Default for' : 'ตั้งต้นของ', 3),
      _TCol(isEnglish ? 'Status' : 'สถานะ', 2),
      if (ed) const _TCol('', 2, num: true),
    ];
    final baseRow = <Widget>[
      Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: _cell(_baseUomId == null ? '' : '$_baseUomCode  ${_baseUomName ?? ''}', bold: true)),
        const SizedBox(width: 6),
        _chip(isEnglish ? 'Base' : 'หลัก', _hRo, _gMore),
      ]),
      _cell('1', mono: true),
      _cell(_barcodeCtrl.text.trim()),
      _cell(isEnglish ? 'All' : 'ทุกงาน'),
      _cell(''),
      _chip(isEnglish ? 'Active' : 'ใช้งาน', const Color(0xFFE6F4EA), const Color(0xFF1E6B3A)),
      if (ed) const SizedBox.shrink(),
    ];
    final rows = <List<Widget>>[baseRow];
    final taps = <VoidCallback?>[null];
    for (var i = 0; i < _uomConversions.length; i++) {
      final c = _uomConversions[i];
      final uses = [
        if (c.allowPurchase) (isEnglish ? 'Buy' : 'ซื้อ'),
        if (c.allowSales) (isEnglish ? 'Sell' : 'ขาย'),
        if (c.allowProduction) (isEnglish ? 'Make' : 'ผลิต'),
      ].join(' · ');
      final defaults = [
        if (c.isPurchaseDefault) (isEnglish ? 'Buy' : 'ซื้อ'),
        if (c.isSalesDefault) (isEnglish ? 'Sell' : 'ขาย'),
        if (c.isProductionDefault) (isEnglish ? 'Make' : 'ผลิต'),
        if (c.isCountDefault) (isEnglish ? 'Count' : 'ตรวจนับ'),
        if (c.isReportDefault) (isEnglish ? 'Report' : 'รายงาน'),
      ].join(' · ');
      rows.add([
        _cell('${c.uomCode ?? ''}  ${c.displayName(isEnglish)}', color: c.isActive ? null : Colors.grey),
        _cell('= ${NumberFormat('#,##0.######').format(c.conversionFactor)} $_baseUomLabel', mono: true),
        _cell(c.barcode ?? ''),
        _cell(uses),
        _cell(defaults),
        c.isActive
            ? _chip(isEnglish ? 'Active' : 'ใช้งาน', const Color(0xFFE6F4EA), const Color(0xFF1E6B3A))
            : _chip(isEnglish ? 'Inactive' : 'ปิดใช้', const Color(0xFFFDECEA), _red),
        if (ed)
          Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: const Icon(Icons.edit, size: 16), tooltip: isEnglish ? 'Edit' : 'แก้ไข',
                visualDensity: VisualDensity.compact, onPressed: () => _editUomConversion(i)),
            IconButton(icon: const Icon(Icons.delete, size: 16, color: Colors.red), tooltip: isEnglish ? 'Delete' : 'ลบ',
                visualDensity: VisualDensity.compact, onPressed: () => _removeUomConversion(i)),
          ]),
      ]);
      taps.add(ed ? () => _editUomConversion(i) : null);
    }
    return _card(
      title: isEnglish ? 'Units' : 'หน่วยนับ',
      count: isEnglish ? '${_uomConversions.length + 1} unit(s)' : '${_uomConversions.length + 1} หน่วย',
      trailing: ed ? _ghostButton(isEnglish ? 'Add unit' : 'เพิ่มหน่วย', Icons.add, _addUomConversion) : null,
      padding: EdgeInsets.zero,
      child: _table(cols, rows, onTap: taps, minWidth: 760),
    );
  }

  // ── การ์ดคลังสินค้า: การตั้งค่าต่อคลัง (แก้ได้) + คงเหลือจริงต่อคลัง ──────────────
  Widget _buildWarehouseCard() {
    final isEnglish = _isEnglish;
    final ed = !_isReadOnly;
    final stockByWh = {for (final w in _summary?.warehouses ?? const <ImItemStockRow>[]) w.warehouseId: w};
    final settingIds = _itemWarehouses.map((w) => w.warehouseId).toSet();
    final extra = (_summary?.warehouses ?? const <ImItemStockRow>[])
        .where((w) => !settingIds.contains(w.warehouseId) && w.qty != 0)
        .toList();
    final cols = [
      _TCol(isEnglish ? 'Warehouse' : 'คลัง', 4),
      _TCol(isEnglish ? 'Default location' : 'ตำแหน่งเริ่มต้น', 3),
      _TCol(isEnglish ? 'On hand' : 'คงเหลือ', 2, num: true),
      _TCol(isEnglish ? 'Stock level' : 'ระดับสต็อก', 3),
      _TCol(isEnglish ? 'Min' : 'ขั้นต่ำ', 2, num: true),
      _TCol(isEnglish ? 'Reorder' : 'จุดสั่งซื้อ', 2, num: true),
      _TCol(isEnglish ? 'Max' : 'สูงสุด', 2, num: true),
      if (ed) const _TCol('', 2, num: true),
    ];
    Widget bar(double qty, double reorder, double max) {
      final cap = max > 0 ? max : (reorder > 0 ? reorder * 2 : 0);
      if (cap <= 0) return _cell('');
      final low = reorder > 0 && qty < reorder;
      return ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: (qty / cap).clamp(0.0, 1.0),
          minHeight: 6,
          backgroundColor: const Color(0xFFEEF1F4),
          valueColor: AlwaysStoppedAnimation(low ? _red : _im),
        ),
      );
    }

    String q(double? v) => v == null || v == 0 ? '' : _qtyFmt.format(v);
    final rows = <List<Widget>>[];
    final taps = <VoidCallback?>[];
    for (var i = 0; i < _itemWarehouses.length; i++) {
      final w = _itemWarehouses[i];
      final st = stockByWh[w.warehouseId];
      final qty = st?.qty ?? 0;
      final low = w.reorderPoint > 0 && qty < w.reorderPoint;
      final name = isEnglish && (w.warehouseNameEn ?? '').isNotEmpty ? w.warehouseNameEn : (w.warehouseNameTh ?? st?.displayName(isEnglish) ?? '');
      rows.add([
        _cell('${w.warehouseCode ?? ''}  ${name ?? ''}'),
        _cell(w.defaultLocationCode ?? ''),
        _cell(_summary == null ? '' : _qtyFmt.format(qty), mono: true, bold: low, color: low ? _red : null),
        bar(qty, w.reorderPoint, w.maxStockQty),
        _cell(q(w.minStockQty), mono: true),
        _cell(q(w.reorderPoint), mono: true),
        _cell(q(w.maxStockQty), mono: true),
        if (ed)
          Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: const Icon(Icons.edit, size: 16), tooltip: isEnglish ? 'Edit' : 'แก้ไข',
                visualDensity: VisualDensity.compact, onPressed: () => _editItemWarehouse(i)),
            IconButton(icon: const Icon(Icons.delete, size: 16, color: Colors.red), tooltip: isEnglish ? 'Delete setting' : 'ลบการตั้งค่า',
                visualDensity: VisualDensity.compact, onPressed: () => _removeItemWarehouse(i)),
          ]),
      ]);
      taps.add(ed ? () => _editItemWarehouse(i) : null);
    }
    for (final w in extra) {
      rows.add([
        _cell('${w.warehouseCode}  ${w.displayName(isEnglish)}'),
        _cell(''),
        _cell(_qtyFmt.format(w.qty), mono: true),
        _cell(''),
        _cell(''),
        _cell(''),
        _cell(''),
        if (ed)
          Tooltip(
            message: isEnglish ? 'Add min/max/reorder for this warehouse' : 'ตั้งขั้นต่ำ/สูงสุด/จุดสั่งซื้อของคลังนี้',
            child: IconButton(
              icon: const Icon(Icons.tune, size: 16, color: Colors.teal),
              visualDensity: VisualDensity.compact,
              onPressed: () => _addItemWarehouse(ImItemWarehouse(
                warehouseId: w.warehouseId, warehouseCode: w.warehouseCode,
                warehouseNameTh: w.warehouseNameTh, warehouseNameEn: w.warehouseNameEn,
              )),
            ),
          ),
      ]);
      taps.add(null);
    }
    final total = _itemWarehouses.length + extra.length;
    final s = _summary;
    return _card(
      title: isEnglish ? 'Warehouses' : 'คลังสินค้า',
      count: isEnglish ? '$total warehouse(s)' : '$total คลัง',
      trailing: ed ? _ghostButton(isEnglish ? 'Warehouse setting' : 'ตั้งค่าคลัง', Icons.add, () => _addItemWarehouse()) : null,
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _table(cols, rows, onTap: taps, minWidth: 820,
            empty: isEnglish ? 'No stock and no per-warehouse settings yet' : 'ยังไม่มียอดคงเหลือและการตั้งค่าต่อคลัง'),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Text(
            (s != null && s.belowItemLevel)
                ? (isEnglish
                    ? 'Total on hand ${_qtyFmt.format(s.totalQty)} is below the item reorder point ${_qtyFmt.format(s.itemReorderPoint)}'
                    : 'ยอดรวมทุกคลัง ${_qtyFmt.format(s.totalQty)} ต่ำกว่าจุดสั่งซื้อระดับสินค้า ${_qtyFmt.format(s.itemReorderPoint)}')
                : (isEnglish
                    ? 'Warehouses without their own setting use the item-level min/max/reorder (compared with the total of all warehouses).'
                    : 'คลังที่ไม่ได้ตั้งค่าเอง ใช้ขั้นต่ำ/สูงสุด/จุดสั่งซื้อระดับสินค้า (เทียบกับยอดรวมทุกคลัง)'),
            style: TextStyle(fontSize: 12, color: (s != null && s.belowItemLevel) ? _red : _ink3),
          ),
        ),
      ]),
    );
  }

  // ── การ์ดตารางราคา: อ่านอย่างเดียว + ลิงก์ไปหน้าตารางราคา ─────────────────
  void _openPriceList() {
    if (!MenuOpener.open('ImPriceListScreen') && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEnglish ? 'You do not have access to the Price List menu' : 'ไม่มีสิทธิ์เข้าถึงเมนูตารางราคา'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Widget _buildPricesCard() {
    final isEnglish = _isEnglish;
    String d(DateTime? x) => x == null ? '' : _dateFmt.format(x);
    final cols = [
      _TCol(isEnglish ? 'Price list' : 'ตารางราคา', 5),
      _TCol(isEnglish ? 'Unit' : 'หน่วย', 2),
      _TCol(isEnglish ? 'Min qty' : 'จำนวนขั้นต่ำ', 2, num: true),
      _TCol(isEnglish ? 'Price / unit' : 'ราคา/หน่วย', 3, num: true),
      _TCol(isEnglish ? 'Incl. VAT' : 'รวม VAT', 2),
      _TCol(isEnglish ? 'Effective' : 'มีผล', 4),
    ];
    final rows = [
      for (final r in _priceRows)
        <Widget>[
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(r.listType == 'PURCHASE' ? Icons.shopping_cart_outlined : Icons.sell_outlined, size: 15, color: Colors.teal),
            const SizedBox(width: 6),
            Flexible(child: _cell('${r.priceListCode}  ${r.priceListName}')),
          ]),
          _cell(isEnglish && (r.uomNameEn ?? '').isNotEmpty ? r.uomNameEn! : (r.uomNameTh ?? r.uomCode ?? '')),
          _cell(r.minQty > 0 ? _qtyFmt.format(r.minQty) : '', mono: true),
          _cell('${NumberFormat('#,##0.00##').format(r.unitPriceFc)}${(r.currencyCode ?? '').isNotEmpty ? ' ${r.currencyCode}' : ''}', mono: true),
          _cell(r.priceIncludesVat ? (isEnglish ? 'Incl.' : 'รวม') : (isEnglish ? 'Excl.' : 'ไม่รวม')),
          _cell((r.effectiveFrom == null && r.effectiveTo == null) ? '' : '${d(r.effectiveFrom)} – ${d(r.effectiveTo)}'),
        ],
    ];
    final saved = widget.selected?.id != null;
    return _card(
      title: isEnglish ? 'Price Lists' : 'ตารางราคา',
      count: saved ? (isEnglish ? '${_priceRows.length} line(s)' : '${_priceRows.length} รายการ') : null,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(isEnglish ? 'Read-only' : 'อ่านอย่างเดียว', style: const TextStyle(fontSize: 12, color: _ink3)),
        const SizedBox(width: 8),
        _ghostButton(isEnglish ? 'Open Price List' : 'ไปหน้าตารางราคา', Icons.open_in_new, _openPriceList),
      ]),
      padding: EdgeInsets.zero,
      child: !saved
          ? Padding(
              padding: const EdgeInsets.all(14),
              child: Text(isEnglish ? 'Save the item first, then add it to a price list.' : 'บันทึกสินค้าก่อน แล้วจึงเพิ่มในตารางราคา',
                  style: const TextStyle(fontSize: 12.5, color: _ink3)),
            )
          : _isLoadingPrices
              ? const Padding(padding: EdgeInsets.all(14), child: Center(child: CircularProgressIndicator()))
              : _table(cols, rows, minWidth: 720,
                  empty: isEnglish ? 'This item is not on any price list yet' : 'สินค้านี้ยังไม่อยู่ในตารางราคาใด'),
    );
  }

  // ── การ์ดบัญชี GL: บัญชีที่ใช้จริง + มาจาก + กำหนดที่สินค้านี้ ─────────────────
  ImItemGlLayers? _layers(String key) => _summary?.gl.where((g) => g.key == key).firstOrNull;

  _GlEff _glEff(String key, int? itemId, String? itemCode, String? itemName) {
    if (itemId != null) return _GlEff('ITEM', itemCode, itemName);
    final cat = _categoryId == null ? null : _catGl[key];
    if (cat != null) return _GlEff('CATEGORY', cat.code, cat.name(_isEnglish));
    final l = _layers(key);
    if (l == null) return const _GlEff('NONE', null, null);
    if (l.docType) return _GlEff('DOC_TYPE', l.company?.code, l.company?.name(_isEnglish));
    if (l.company != null) return _GlEff('COMPANY', l.company!.code, l.company!.name(_isEnglish));
    return const _GlEff('NONE', null, null);
  }

  Widget _srcChip(_GlEff e) {
    final isEnglish = _isEnglish;
    switch (e.kind) {
      case 'ITEM':
        return _chip(isEnglish ? 'This item' : 'สินค้านี้', const Color(0xFFE6F4EA), const Color(0xFF1E6B3A));
      case 'CATEGORY':
        return _chip(isEnglish ? 'Category ${_categoryCode ?? ''}' : 'หมวด ${_categoryCode ?? ''}', _hRo, _ink2);
      case 'DOC_TYPE':
        return Tooltip(
          message: isEnglish
              ? 'Uses the account set on each document type (IM/AR GL account setup); if a type has none, the company default is used'
              : 'ใช้บัญชีที่ตั้งไว้ของแต่ละประเภทเอกสาร (หน้าตั้งค่าบัญชี IM/AR) ถ้าประเภทเอกสารไม่ได้ตั้ง ใช้ค่าเริ่มต้นบริษัท',
          child: _chip(isEnglish ? 'By document type' : 'ตามประเภทเอกสาร', _hAuto, _gDoc),
        );
      case 'COMPANY':
        return _chip(isEnglish ? 'Company default' : 'ค่าเริ่มต้นบริษัท', _hAuto, _gDoc);
      default:
        return _chip(isEnglish ? 'Not set' : 'ยังไม่ได้ตั้ง', const Color(0xFFFDECEA), _red);
    }
  }

  Widget _buildGlCard() {
    final isEnglish = _isEnglish;
    final ed = !_isReadOnly;
    final defs = <(String, String, int?, String?, String?, void Function(Account), VoidCallback)>[
      ('inventory', isEnglish ? 'Inventory' : 'สินค้าคงคลัง', _inventoryAccountId, _inventoryAccountCode, _inventoryAccountName,
          (a) => setState(() { _inventoryAccountId = a.id; _inventoryAccountCode = a.accountCode; _inventoryAccountName = _acctName(a); }),
          () => setState(() { _inventoryAccountId = null; _inventoryAccountCode = null; _inventoryAccountName = null; })),
      ('cogs', isEnglish ? 'Cost of sales' : 'ต้นทุนขาย', _cogsAccountId, _cogsAccountCode, _cogsAccountName,
          (a) => setState(() { _cogsAccountId = a.id; _cogsAccountCode = a.accountCode; _cogsAccountName = _acctName(a); }),
          () => setState(() { _cogsAccountId = null; _cogsAccountCode = null; _cogsAccountName = null; })),
      ('revenue', isEnglish ? 'Revenue' : 'รายได้', _revenueAccountId, _revenueAccountCode, _revenueAccountName,
          (a) => setState(() { _revenueAccountId = a.id; _revenueAccountCode = a.accountCode; _revenueAccountName = _acctName(a); }),
          () => setState(() { _revenueAccountId = null; _revenueAccountCode = null; _revenueAccountName = null; })),
      ('purchases', isEnglish ? 'Purchases (Periodic)' : 'ซื้อสินค้า (Periodic)', _purchasesAccountId, _purchasesAccountCode, _purchasesAccountName,
          (a) => setState(() { _purchasesAccountId = a.id; _purchasesAccountCode = a.accountCode; _purchasesAccountName = _acctName(a); }),
          () => setState(() { _purchasesAccountId = null; _purchasesAccountCode = null; _purchasesAccountName = null; })),
      ('expense', isEnglish ? 'Expense (not posted yet)' : 'ค่าใช้จ่าย (ยังไม่ใช้ลงบัญชี)', _expenseAccountId, _expenseAccountCode, _expenseAccountName,
          (a) => setState(() { _expenseAccountId = a.id; _expenseAccountCode = a.accountCode; _expenseAccountName = _acctName(a); }),
          () => setState(() { _expenseAccountId = null; _expenseAccountCode = null; _expenseAccountName = null; })),
    ];
    final effs = [for (final d in defs) _glEff(d.$1, d.$3, d.$4, d.$5)];
    final counts = <String, int>{};
    for (final e in effs) {
      counts[e.kind] = (counts[e.kind] ?? 0) + 1;
    }
    final summaryParts = [
      if ((counts['ITEM'] ?? 0) > 0) isEnglish ? 'item ${counts['ITEM']}' : 'กำหนดเอง ${counts['ITEM']}',
      if ((counts['CATEGORY'] ?? 0) > 0) isEnglish ? 'category ${counts['CATEGORY']}' : 'จากหมวด ${counts['CATEGORY']}',
      if ((counts['DOC_TYPE'] ?? 0) > 0) isEnglish ? 'doc type ${counts['DOC_TYPE']}' : 'ตามประเภทเอกสาร ${counts['DOC_TYPE']}',
      if ((counts['COMPANY'] ?? 0) > 0) isEnglish ? 'company ${counts['COMPANY']}' : 'ค่าเริ่มต้นบริษัท ${counts['COMPANY']}',
      if ((counts['NONE'] ?? 0) > 0) isEnglish ? 'not set ${counts['NONE']}' : 'ยังไม่ได้ตั้ง ${counts['NONE']}',
    ];

    final cols = [
      _TCol(isEnglish ? 'Account' : 'บัญชี', 3),
      _TCol(isEnglish ? 'Account used' : 'รหัสที่ใช้จริง', 4),
      _TCol(isEnglish ? 'Source' : 'มาจาก', 3),
      _TCol(isEnglish ? 'Set on this item' : 'กำหนดที่สินค้านี้', 5),
    ];
    final rows = <List<Widget>>[];
    for (var i = 0; i < defs.length; i++) {
      final d = defs[i];
      final e = effs[i];
      final usedText = e.code == null ? '' : '${e.code}  ${e.name ?? ''}';
      final override = Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ed
            ? SizedBox(
                height: 34,
                child: InkWell(
                  onTap: () => _pickAccount(isEnglish ? 'Select ${d.$2} Account' : 'เลือกบัญชี${d.$2}', d.$6),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      isDense: true,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      suffixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 20, maxHeight: 24),
                      suffixIcon: d.$3 != null
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 15, color: Colors.red),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 24, minHeight: 20),
                              tooltip: isEnglish ? 'Clear (use next level)' : 'ล้าง (ใช้ลำดับถัดไป)',
                              onPressed: d.$7,
                            )
                          : const Icon(Icons.search, size: 16, color: Colors.teal),
                    ),
                    child: Text(
                      d.$3 != null ? '${d.$4}  ${d.$5 ?? ''}' : (isEnglish ? '— use next level' : '— ใช้ตามลำดับถัดไป'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: d.$3 != null ? null : _ink3),
                    ),
                  ),
                ),
              )
            : _cell(d.$3 != null ? '${d.$4}  ${d.$5 ?? ''}' : ''),
      );
      final wh = _layers(d.$1)?.warehouseOverride ?? const <String>[];
      final row = <Widget>[
        _cell(d.$2),
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _cell(usedText, bold: e.kind != 'DOC_TYPE', color: e.kind == 'DOC_TYPE' ? _ink3 : null),
          if (wh.isNotEmpty)
            Text(isEnglish ? 'Warehouse account first: ${wh.join(', ')}' : 'คลัง ${wh.join(', ')} ใช้บัญชีของคลังก่อน',
                style: const TextStyle(fontSize: 11, color: _gFin), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
        _srcChip(e),
        override,
      ];
      // ซื้อสินค้าใช้เฉพาะ Periodic — Perpetual ลง Dr บัญชีสต็อกแทน
      if (d.$1 == 'purchases' && _accountingMode == 'PERPETUAL') {
        rows.add([for (final w in row) Opacity(opacity: 0.45, child: IgnorePointer(child: w))]);
      } else {
        rows.add(row);
      }
    }

    return _card(
      title: isEnglish ? 'GL Accounts' : 'บัญชี GL',
      count: summaryParts.join(' · '),
      collapsed: !_glExpanded,
      onToggle: () => setState(() => _glExpanded = !_glExpanded),
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _table(cols, rows, minWidth: 820),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Text(
            isEnglish
                ? 'Order used when posting: this item → category → document type → company default (inventory/purchases: a warehouse\'s own account comes first).'
                : 'ลำดับที่ใช้ตอนลงบัญชี: สินค้านี้ → หมวดสินค้า → ประเภทเอกสาร → ค่าเริ่มต้นบริษัท (บัญชีสต็อก/ซื้อสินค้า: บัญชีที่ตั้งที่คลังใช้ก่อน)',
            style: const TextStyle(fontSize: 12, color: _ink3),
          ),
        ),
      ]),
    );
  }

  String _acctName(Account a) => _isEnglish && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai;

  // ── แถบหัว + ปุ่ม ─────────────────────────────────────────────────────────
  Widget _buildHeaderBar() {
    final isEnglish = _isEnglish;
    final saved = widget.selected?.id != null && widget.mode != Mode.add;
    final acts = <DocBarAction>[
      if (_isReadOnly) ...[
        if (widget.onCopy != null)
          DocBarAction(isEnglish ? 'Copy as new item' : 'สำเนาเป็นสินค้าใหม่', widget.onCopy, fg: _im),
        if (widget.onDelete != null)
          DocBarAction(isEnglish ? 'Delete' : 'ลบ', widget.onDelete, fg: _red),
        DocBarAction(isEnglish ? 'Close' : 'ปิด', widget.onCancel, fg: _im),
        if (widget.onEdit != null)
          DocBarAction(isEnglish ? 'Edit' : 'แก้ไข', widget.onEdit, fg: Colors.white, bg: _im, primary: true),
      ] else ...[
        DocBarAction(isEnglish ? 'Cancel' : 'ยกเลิก', _isSaving ? null : widget.onCancel, fg: _im),
        DocBarAction(_isSaving ? (isEnglish ? 'Saving...' : 'กำลังบันทึก...') : (isEnglish ? 'Save' : 'บันทึก'),
            _isSaving ? null : _save, fg: const Color(0xFF0B3A2A), bg: _gold, primary: true),
      ],
    ];
    final title = widget.mode == Mode.add
        ? (_isCopy
            ? (isEnglish ? 'New item (copy of ${widget.copyFrom!.itemCode})' : 'เพิ่มสินค้าใหม่ (สำเนาจาก ${widget.copyFrom!.itemCode})')
            : (isEnglish ? 'Add New Item' : 'เพิ่มสินค้าใหม่'))
        : _nameThCtrl.text.isEmpty
            ? ''
            : (isEnglish && _nameEnCtrl.text.trim().isNotEmpty ? _nameEnCtrl.text.trim() : _nameThCtrl.text.trim());
    return Container(
      color: ScreenTheme.of(context).strip,
      padding: EdgeInsets.fromLTRB(widget.leading != null ? 4 : 14, 6, 14, 6),
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(children: [
        if (widget.leading != null) widget.leading!,
        // รหัส + ชื่อสินค้า + ป้ายสถานะ ชิดซ้ายต่อกัน — ชื่อยาวขึ้นบรรทัดใหม่ ไม่ตัด; ปุ่มชิดขวา
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              if (saved)
                Text(_codeCtrl.text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14,
                    fontFeatures: [FontFeature.tabularFigures()])),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              if (widget.mode == Mode.edit)
                _chip(isEnglish ? 'Editing' : 'กำลังแก้ไข', const Color(0xFFFFF4DA), const Color(0xFF8A5A00)),
              if (saved)
                _isActive
                    ? _chip(isEnglish ? 'Active' : 'ใช้งาน', const Color(0xFFE6F4EA), const Color(0xFF1E6B3A))
                    : _chip(isEnglish ? 'Inactive' : 'หยุดใช้', const Color(0xFFFDECEA), _red),
            ],
          ),
        ),
        const SizedBox(width: 8),
        buildDocBarActions(context, acts, busy: _isSaving, isEnglish: isEnglish),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = Provider.of<LanguageProvider>(context).isEnglish;
    _isEnglish = isEnglish;
    if (widget.isPlaceholder) {
      return Container(
        color: const Color(0xFFF3F5F4),
        child: Stack(children: [
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 8),
              Text(isEnglish ? 'Select an item on the left to view its data' : 'เลือกสินค้าทางซ้ายเพื่อดูข้อมูล',
                  style: const TextStyle(color: Colors.grey)),
            ]),
          ),
          if (widget.leading != null) Positioned(left: 4, top: 4, child: widget.leading!),
        ]),
      );
    }
    if (!_sections.any((s) => s.$1 == _activeSec)) _activeSec = 0;
    final showKpis = widget.selected?.id != null && widget.mode != Mode.add && _itemType == 'STOCK';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _buildHeaderBar(),
      _buildAnchors(),
      const Divider(height: 1, color: _line),
      Expanded(
        child: ColoredBox(
          color: const Color(0xFFF3F5F4),
          child: NotificationListener<ScrollNotification>(
            onNotification: (_) {
              // วัดตำแหน่งหลังเฟรม (ไม่วัดระหว่าง layout) — ครั้งเดียวต่อเฟรม
              if (!_activeScheduled) {
                _activeScheduled = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _activeScheduled = false;
                  if (mounted) _updateActiveSection();
                });
              }
              return false;
            },
            child: SingleChildScrollView(
              key: _bodyKey,
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (showKpis) ...[_buildKpis(), const SizedBox(height: 12)],
                KeyedSubtree(key: _secKeys[0], child: _buildMainCard()),
                const SizedBox(height: 12),
                KeyedSubtree(key: _secKeys[1], child: _buildUnitsCard()),
                if (_itemType == 'STOCK') ...[
                  const SizedBox(height: 12),
                  KeyedSubtree(key: _secKeys[2], child: _buildWarehouseCard()),
                ],
                const SizedBox(height: 12),
                KeyedSubtree(key: _secKeys[3], child: _buildPricesCard()),
                const SizedBox(height: 12),
                KeyedSubtree(key: _secKeys[4], child: _buildGlCard()),
                const SizedBox(height: 240),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}
