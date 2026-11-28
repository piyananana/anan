import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../../cd/models/cd_branch.dart';
import '../../cd/widgets/cd_branch_list_widget.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../models/im_warehouse.dart';
import '../screens/im_location_screen.dart';
import '../services/im_warehouse_service.dart';
import 'im_master_kit.dart';
import '../../sa/utils/sa_menu_theme.dart';

// หน้ารายละเอียดคลังสินค้า (แบบ B, user 2026-11-25): ตัวเลขสรุปของคลัง, 4 กลุ่ม (ข้อมูลหลัก / ที่ตั้ง / บัญชี / เพิ่มเติม),
// การ์ดตำแหน่งจัดเก็บ (สรุปโซน + ปุ่มจัดการตำแหน่ง), การ์ดสินค้าในคลัง (อ่านอย่างเดียว เรียงตามมูลค่า)
class ImWarehouseDetailWidget extends StatefulWidget {
  final Mode mode;
  final ImWarehouse? selected;
  final Future<void> Function(ImWarehouse) onSubmit;
  final VoidCallback onCancel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isPlaceholder;
  // เพิ่มขึ้นทุกครั้งที่ผู้ใช้กดปุ่มเพิ่ม/แก้ไข/ดู/ยกเลิกจากหน้าจอหลัก — ใช้บังคับให้ didUpdateWidget เคลียร์ฟอร์ม
  // เสมอ แม้ mode/selected จะ "เหมือนเดิม" กับครั้งก่อน (เช่น กดเพิ่มคลังสินค้าซ้ำหลังพิมพ์ข้อมูลค้างไว้)
  final int requestSeq;

  const ImWarehouseDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.onEdit,
    this.onDelete,
    this.isPlaceholder = false,
    this.requestSeq = 0,
  });

  @override
  State<ImWarehouseDetailWidget> createState() => ImWarehouseDetailWidgetState();
}

class ImWarehouseDetailWidgetState extends State<ImWarehouseDetailWidget> with ImMasterKit {
  final _svc = ImWarehouseService();
  final _codeCtrl = TextEditingController();
  final _nameThCtrl = TextEditingController();
  final _nameEnCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _isActive = true;
  bool _isConsignee = false;
  bool _isDefault = false;
  bool _isSaving = false;
  bool _isEnglish = false;

  int? _branchId; String? _branchCode; String? _branchName;
  int? _inventoryAccountId; String? _inventoryAccountCode; String? _inventoryAccountName;
  String? _accountingMode;
  int? _purchasesAccountId; String? _purchasesAccountCode; String? _purchasesAccountName;
  List<Account> _accounts = [];

  ImWarehouseSummary? _summary;
  bool _loadingSummary = false;
  int _summarySeq = 0;
  bool _belowOnly = false;
  String _snapshot = '';

  static final _qtyFmt = NumberFormat('#,##0.##');
  static final _amtFmt = NumberFormat('#,##0.00');
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  bool get _isReadOnly => widget.mode == Mode.view || widget.mode == Mode.none;
  @override
  bool get kitEnglish => _isEnglish;
  @override
  bool get kitReadOnly => _isReadOnly;

  /// มีการแก้ไขที่ยังไม่บันทึก
  bool get isDirty => !_isReadOnly && !widget.isPlaceholder && _fingerprint() != _snapshot;

  @override
  void initState() {
    super.initState();
    _apply();
  }

  @override
  void didUpdateWidget(covariant ImWarehouseDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected || widget.mode != oldWidget.mode || widget.requestSeq != oldWidget.requestSeq) _apply();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameThCtrl.dispose();
    _nameEnCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final w = widget.mode == Mode.add ? null : widget.selected;
    _codeCtrl.text = w?.warehouseCode ?? '';
    _nameThCtrl.text = w?.warehouseNameTh ?? '';
    _nameEnCtrl.text = w?.warehouseNameEn ?? '';
    _addressCtrl.text = w?.address ?? '';
    _isActive = w?.isActive ?? true;
    _isConsignee = w?.isConsignee ?? false;
    _isDefault = w?.isDefault ?? false;
    _branchId = w?.branchId; _branchCode = w?.branchCode;
    _branchName = _isEnglish && (w?.branchNameEn ?? '').isNotEmpty ? w?.branchNameEn : w?.branchNameTh;
    _inventoryAccountId = w?.inventoryAccountId; _inventoryAccountCode = w?.inventoryAccountCode; _inventoryAccountName = w?.inventoryAccountName;
    _accountingMode = w?.accountingMode;
    _purchasesAccountId = w?.purchasesAccountId; _purchasesAccountCode = w?.purchasesAccountCode; _purchasesAccountName = w?.purchasesAccountName;
    _summary = null;
    _belowOnly = false;
    _summarySeq++;
    if (w != null && w.id != 0) _loadSummary(w.id);
    kScrollTop();
    _snapshot = _fingerprint();
  }

  Future<void> _loadSummary(int id) async {
    final seq = ++_summarySeq;
    _loadingSummary = true;
    try {
      final r = await _svc.fetchSummary(id, belowOnly: _belowOnly);
      if (mounted && seq == _summarySeq) setState(() => _summary = r);
    } catch (_) {
    } finally {
      if (mounted && seq == _summarySeq) setState(() => _loadingSummary = false);
    }
  }

  void _toggleBelow() {
    final id = widget.selected?.id;
    if (id == null) return;
    setState(() => _belowOnly = !_belowOnly);
    _loadSummary(id);
    kJumpTo(2);
  }

  ImWarehouse _build() => ImWarehouse(
        id: widget.mode == Mode.edit ? widget.selected!.id : 0,
        warehouseCode: _codeCtrl.text.trim().toUpperCase(),
        warehouseNameTh: _nameThCtrl.text.trim(),
        warehouseNameEn: _nameEnCtrl.text.trim().isEmpty ? null : _nameEnCtrl.text.trim(),
        branchId: _branchId,
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        isActive: _isActive,
        isConsignee: _isConsignee,
        isDefault: _isDefault && _isActive,
        inventoryAccountId: _inventoryAccountId,
        accountingMode: _accountingMode,
        purchasesAccountId: _purchasesAccountId,
      );

  String _fingerprint() => docFingerprint(_build().toJson());

  Future<void> _save() async {
    final e = _isEnglish;
    String? err;
    if (_codeCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter the warehouse code' : 'กรุณาป้อนรหัสคลังสินค้า';
    } else if (_nameThCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter the warehouse name (Thai)' : 'กรุณาป้อนชื่อคลังสินค้า (ไทย)';
    }
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.onSubmit(_build());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickAccount(String title, void Function(Account) onPicked) async {
    if (_accounts.isEmpty) {
      try {
        final list = await AccountService().fetchRows();
        _accounts = list.where((a) => a.isActive && a.isNormalAccount).toList();
      } catch (_) {}
    }
    if (!mounted) return;
    final isEnglish = _isEnglish;
    final searchCtrl = TextEditingController();
    List<Account> filtered = List.from(_accounts);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        void doFilter(String q) => setDlg(() {
              final uq = q.toUpperCase();
              filtered = q.isEmpty
                  ? List.from(_accounts)
                  : _accounts.where((a) =>
                      a.accountCode.toUpperCase().contains(uq) ||
                      a.accountNameThai.toUpperCase().contains(uq) ||
                      a.accountNameEng.toUpperCase().contains(uq)).toList();
            });
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 520,
            height: 400,
            child: Column(children: [
              TextField(
                controller: searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: isEnglish ? 'Search account code / name' : 'ค้นหา รหัส / ชื่อบัญชี',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onChanged: doFilter,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text(isEnglish ? 'No data found' : 'ไม่พบข้อมูล'))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final a = filtered[i];
                          return ListTile(
                            dense: true,
                            title: Row(children: [
                              SizedBox(width: 110, child: Text(a.accountCode, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))),
                              Expanded(child: Text(_acctName(a))),
                            ]),
                            onTap: () {
                              onPicked(a);
                              Navigator.of(ctx).pop();
                            },
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

  String _acctName(Account a) => _isEnglish && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai;

  Future<void> _pickBranch() async {
    final isEnglish = _isEnglish;
    await BranchListWidget.search(context, onSelected: (Branch b) {
      setState(() {
        _branchId = b.id; _branchCode = b.branchCode;
        _branchName = isEnglish && b.branchNameEng.isNotEmpty ? b.branchNameEng : b.branchNameThai;
      });
    });
  }

  Future<void> _openLocationLayout() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ImLocationScreen(onFieldsChanged: () {}, initialWarehouseId: widget.selected?.id),
    ));
    final id = widget.selected?.id;
    if (mounted && id != null) _loadSummary(id);
  }

  // ── การ์ด ──
  Widget _mainCard() {
    final e = _isEnglish;
    final ed = !_isReadOnly;
    return kCard(
      title: e ? 'Warehouse Information' : 'ข้อมูลคลังสินค้า',
      trailing: _isReadOnly ? null : kLegend(),
      child: kGroups([
        kGroup(1, e ? 'Main Information' : 'ข้อมูลหลัก', ImKit.gDoc, [
          kRow([
            kTxt(widget.mode == Mode.add ? (e ? 'Warehouse Code *' : 'รหัสคลังสินค้า *') : (e ? 'Warehouse Code' : 'รหัสคลังสินค้า'), _codeCtrl,
                editable: widget.mode == Mode.add, cap: TextCapitalization.characters),
            const SizedBox.shrink(),
          ]),
          kTxt(e ? 'Warehouse Name (Thai) *' : 'ชื่อคลังสินค้า (ไทย) *', _nameThCtrl),
          kTxt(e ? 'Warehouse Name (English)' : 'ชื่อคลังสินค้า (อังกฤษ)', _nameEnCtrl),
        ]),
        kGroup(2, e ? 'Location' : 'ที่ตั้ง', ImKit.gParty, [
          kFk(
            label: e ? 'Branch' : 'สาขา',
            hasValue: _branchId != null,
            text: '$_branchCode  ${_branchName ?? ''}',
            onSearch: _pickBranch,
            onClear: () => setState(() { _branchId = null; _branchCode = null; _branchName = null; }),
            auto: true,
          ),
          kTxt(e ? 'Address' : 'ที่อยู่', _addressCtrl),
        ]),
        kGroup(3, e ? 'Accounting' : 'บัญชี', ImKit.gFin, [
          kDd<String?>(e ? 'Accounting Mode' : 'โหมดบัญชีสินค้า', _accountingMode, [
            DropdownMenuItem<String?>(value: null, child: Text(e ? 'Follow company default' : 'ตามค่าเริ่มต้นของบริษัท', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem<String?>(value: 'PERPETUAL', child: Text(e ? 'Perpetual' : 'Perpetual (โพสต์บัญชีทันที)', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem<String?>(value: 'PERIODIC', child: Text(e ? 'Periodic' : 'Periodic (ปิดงวดครั้งเดียว)', overflow: TextOverflow.ellipsis)),
          ], ed ? (v) => setState(() => _accountingMode = v) : null),
          kRow([
            kFk(
              label: e ? 'Inventory Account' : 'บัญชีสินค้าคงคลัง',
              hasValue: _inventoryAccountId != null,
              text: '$_inventoryAccountCode  ${_inventoryAccountName ?? ''}',
              onSearch: () => _pickAccount(e ? 'Select Inventory Account' : 'เลือกบัญชีสินค้าคงคลัง', (a) => setState(() {
                    _inventoryAccountId = a.id; _inventoryAccountCode = a.accountCode; _inventoryAccountName = _acctName(a);
                  })),
              onClear: () => setState(() { _inventoryAccountId = null; _inventoryAccountCode = null; _inventoryAccountName = null; }),
            ),
            // บัญชีซื้อสินค้าใช้เฉพาะ Periodic — Perpetual ลง Dr บัญชีสต็อกแทน
            Opacity(
              opacity: _accountingMode == 'PERPETUAL' ? 0.45 : 1,
              child: IgnorePointer(
                ignoring: _accountingMode == 'PERPETUAL',
                child: kFk(
                  label: e ? 'Purchases Account (Periodic)' : 'บัญชีซื้อสินค้า (Periodic)',
                  hasValue: _purchasesAccountId != null,
                  text: '$_purchasesAccountCode  ${_purchasesAccountName ?? ''}',
                  onSearch: () => _pickAccount(e ? 'Select Purchases Account' : 'เลือกบัญชีซื้อสินค้า', (a) => setState(() {
                        _purchasesAccountId = a.id; _purchasesAccountCode = a.accountCode; _purchasesAccountName = _acctName(a);
                      })),
                  onClear: () => setState(() { _purchasesAccountId = null; _purchasesAccountCode = null; _purchasesAccountName = null; }),
                ),
              ),
            ),
          ]),
          kNote(e
              ? 'The warehouse inventory account comes first (warehouse → item → category → document type). The mode applies when the item and its category follow the next level.'
              : 'บัญชีสต็อกของคลังมีผลก่อน (คลัง → สินค้า → หมวดสินค้า → ประเภทเอกสาร) ส่วนโหมดของคลังมีผลเมื่อสินค้าและหมวดสินค้าไม่ได้กำหนดโหมดไว้'),
        ]),
        kGroup(4, e ? 'More' : 'เพิ่มเติม', ImKit.gMore, [
          kChecks([
            // คลังหลัก — มีได้คลังเดียวทั้งบริษัท เอกสาร IM ใหม่ใช้เป็นคลังเริ่มต้น (ตั้งคลังใหม่ คลังเดิมจะถูกยกเลิกอัตโนมัติ)
            kCk(e ? 'Main warehouse' : 'คลังหลัก', _isDefault && _isActive,
                ed && _isActive ? (v) => setState(() => _isDefault = v) : null,
                tooltip: e
                    ? 'Default on new inventory documents; only one per company'
                    : 'ใช้เป็นคลังเริ่มต้นของเอกสารสินค้าใหม่ มีได้คลังเดียว'),
            // Consignment-OUT — สินค้าที่โอนเข้าคลังนี้ยังเป็นของเราจนกว่าจะขายออก
            kCk(e ? 'Consignee warehouse' : 'คลังผู้รับฝากขาย', _isConsignee, ed ? (v) => setState(() => _isConsignee = v) : null,
                tooltip: e ? 'Goods held here are still ours until sold' : 'สินค้าที่อยู่ในคลังนี้ยังเป็นของเราจนกว่าจะขาย'),
            kCk(e ? 'Active' : 'ใช้งาน', _isActive, ed ? (v) => setState(() => _isActive = v) : null),
          ]),
        ]),
      ]),
    );
  }

  Widget _locationCard() {
    final e = _isEnglish;
    final s = _summary;
    final zones = s?.zones ?? const <ImWarehouseZone>[];
    return kCard(
      title: e ? 'Storage Locations' : 'ตำแหน่งจัดเก็บ',
      count: s == null ? null : (e ? '${s.zoneCount} zone(s) · ${s.binCount} bin(s)' : '${s.zoneCount} โซน · ${s.binCount} ช่องเก็บ'),
      trailing: kGhost(e ? 'Manage locations' : 'จัดการตำแหน่ง', Icons.open_in_new, _openLocationLayout),
      child: s == null
          ? const SizedBox(height: 24)
          : zones.isEmpty
              ? kNote(e ? 'No zones/bins yet — press "Manage locations" to set them up.' : 'ยังไม่มีโซน/ช่องเก็บ กด "จัดการตำแหน่ง" เพื่อสร้าง')
              : LayoutBuilder(builder: (c, cons) {
                  final cols = cons.maxWidth >= 760 ? 3 : (cons.maxWidth >= 480 ? 2 : 1);
                  final w = (cons.maxWidth - 8 * (cols - 1)) / cols;
                  return Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final z in zones)
                      SizedBox(
                        width: w,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(border: Border.all(color: ImKit.line), borderRadius: BorderRadius.circular(8)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${z.code}  ${z.displayName(e)}', maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: z.isActive ? null : ImKit.ink3)),
                            const SizedBox(height: 2),
                            Text(
                              [
                                e ? '${z.binCount} bin(s)' : '${z.binCount} ช่อง',
                                if (z.defaultItemCount > 0) e ? 'default of ${z.defaultItemCount} item(s)' : 'ตั้งต้นของ ${z.defaultItemCount} สินค้า',
                                z.categoryCode != null ? (e ? 'category ${z.categoryCode}' : 'หมวด ${z.categoryCode}') : (e ? 'no category' : 'ไม่ได้กำหนดหมวด'),
                              ].join(' · '),
                              maxLines: 2,
                              style: const TextStyle(fontSize: 11.5, color: ImKit.ink2),
                            ),
                          ]),
                        ),
                      ),
                  ]);
                }),
    );
  }

  Widget _itemsCard() {
    final e = _isEnglish;
    final s = _summary;
    final items = s?.items ?? const <ImWarehouseItemStock>[];
    Widget bar(ImWarehouseItemStock it) {
      final reorder = it.reorderPoint ?? 0, max = it.maxStockQty ?? 0;
      final cap = max > 0 ? max : (reorder > 0 ? reorder * 2 : 0);
      if (cap <= 0) return kCell('');
      return ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: (it.qty / cap).clamp(0.0, 1.0),
          minHeight: 6,
          backgroundColor: const Color(0xFFEEF1F4),
          valueColor: AlwaysStoppedAnimation(it.belowReorder ? ImKit.red : ScreenTheme.of(context).ink),
        ),
      );
    }

    return kCard(
      title: e ? 'Items in Warehouse' : 'สินค้าในคลัง',
      count: s == null
          ? null
          : _belowOnly
              ? (e ? 'Read-only · below reorder only' : 'อ่านอย่างเดียว · เฉพาะต่ำกว่าจุดสั่งซื้อ')
              : (e ? 'Read-only · by value (top ${items.length})' : 'อ่านอย่างเดียว · เรียงตามมูลค่า (แสดง ${items.length} แรก)'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (_belowOnly) ...[kGhost(e ? 'Show all' : 'แสดงทั้งหมด', Icons.filter_alt_off, _toggleBelow), const SizedBox(width: 6)],
        kGhost(e ? 'Stock balance report' : 'รายงานยอดคงเหลือ', Icons.open_in_new,
            () => ImKit.openMenu(context, 'ImStockBalanceByItemReportScreen', 'รายงานยอดคงเหลือ', 'Stock Balance Report', e)),
      ]),
      padding: EdgeInsets.zero,
      child: s == null
          ? Padding(
              padding: const EdgeInsets.all(14),
              child: Center(child: _loadingSummary ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const SizedBox.shrink()),
            )
          : kTable([
              KCol(e ? 'Item' : 'สินค้า', 6),
              KCol(e ? 'On hand' : 'คงเหลือ', 3, num: true),
              KCol(e ? 'Stock level' : 'ระดับสต็อก', 3),
              KCol(e ? 'Reorder' : 'จุดสั่งซื้อ', 2, num: true),
              KCol(e ? 'Value' : 'มูลค่า', 3, num: true),
            ], [
              for (final it in items)
                [
                  kCell('${it.itemCode}  ${it.displayName(e)}'),
                  kCell('${_qtyFmt.format(it.qty)} ${it.uomName(e)}', mono: true, bold: it.belowReorder, color: it.belowReorder ? ImKit.red : null),
                  bar(it),
                  kCell((it.reorderPoint ?? 0) > 0 ? _qtyFmt.format(it.reorderPoint) : '', mono: true),
                  kCell(_amtFmt.format(it.value), mono: true),
                ],
            ], minWidth: 720, empty: e ? 'No stock in this warehouse yet' : 'ยังไม่มียอดสินค้าในคลังนี้'),
    );
  }

  List<ImKpi> _kpis() {
    final e = _isEnglish;
    final s = _summary;
    if (s == null) return const [];
    return [
      ImKpi(e ? 'Items with stock' : 'สินค้าที่มียอด', '${s.itemCount}',
          e ? 'of ${s.settingCount} with warehouse settings' : 'ตั้งค่าต่อคลังไว้ ${s.settingCount} รายการ'),
      ImKpi(e ? 'Stock value' : 'มูลค่าคงเหลือ', _amtFmt.format(s.totalValue), e ? 'At inventory cost' : 'ต้นทุนตามบัญชีสต็อก'),
      ImKpi(e ? 'Below reorder point' : 'ต่ำกว่าจุดสั่งซื้อ', '${s.belowCount}',
          s.belowCount > 0 ? (e ? 'item(s) · tap to filter' : 'สินค้า · กดเพื่อกรองการ์ดด้านล่าง') : (e ? 'All OK' : 'ปกติทั้งหมด'),
          warn: s.belowCount > 0, onTap: s.belowCount > 0 || _belowOnly ? _toggleBelow : null),
      ImKpi(e ? 'Last movement' : 'เคลื่อนไหวล่าสุด', s.lastMovementDate == null ? '—' : _dateFmt.format(s.lastMovementDate!),
          s.lastMovementDocNo == null ? (e ? 'No movement yet' : 'ยังไม่มีความเคลื่อนไหว') : '${s.lastMovementDocCode ?? ''} ${s.lastMovementDocNo}'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    _isEnglish = context.watch<LanguageProvider>().isEnglish;
    final e = _isEnglish;
    if (widget.isPlaceholder) {
      return kPlaceholder(Icons.warehouse_outlined, e ? 'Select a warehouse on the left to view its data' : 'เลือกคลังสินค้าทางซ้ายเพื่อดูข้อมูล');
    }
    final saved = widget.mode != Mode.add && widget.selected != null;
    final header = kHeaderBar(
      code: saved ? widget.selected!.warehouseCode : null,
      title: saved ? widget.selected!.warehouseName(e) : (e ? 'Add Warehouse' : 'เพิ่มคลังสินค้า'),
      badges: [
        if (widget.mode == Mode.edit) kEditingBadge(),
        if (saved && widget.selected!.isDefault) ImKit.chip(e ? 'Main' : 'คลังหลัก', ImKit.goldSoft, ImKit.amber),
        if (saved && widget.selected!.isConsignee) ImKit.chip(e ? 'Consignee' : 'ฝากขาย', ImKit.purSoft, ImKit.pur),
        if (saved) ImKit.activeChip(_isActive, e),
      ],
      acts: kStdActs(saving: _isSaving, onEdit: widget.onEdit, onDelete: widget.onDelete, onClose: widget.onCancel,
          onCancel: widget.onCancel, onSave: _save),
      busy: _isSaving,
    );
    return kPage(
      header: header,
      top: saved ? kKpis(_kpis(), loading: _loadingSummary) : null,
      sections: [
        (0, e ? 'Main' : 'ข้อมูลหลัก', _mainCard()),
        if (saved) (1, e ? 'Storage locations' : 'ตำแหน่งจัดเก็บ', _locationCard()),
        if (saved) (2, e ? 'Items in warehouse' : 'สินค้าในคลัง', _itemsCard()),
      ],
    );
  }
}
