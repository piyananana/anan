import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../cd/models/cd_branch.dart';
import '../../cd/widgets/cd_branch_list_widget.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../models/im_warehouse.dart';
import '../screens/im_location_screen.dart';
import 'im_accounting_mode_field.dart';

class ImWarehouseDetailWidget extends StatefulWidget {
  final Mode mode;
  final ImWarehouse? selected;
  final Function(ImWarehouse) onSubmit;
  final VoidCallback onCancel;
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
    this.isPlaceholder = false,
    this.requestSeq = 0,
  });

  @override
  State<ImWarehouseDetailWidget> createState() => ImWarehouseDetailWidgetState();
}

class ImWarehouseDetailWidgetState extends State<ImWarehouseDetailWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeCtrl;
  late TextEditingController _nameThCtrl;
  late TextEditingController _nameEnCtrl;
  late TextEditingController _addressCtrl;
  bool _isActive = true;
  bool _isConsignee = false;
  bool _isSaving = false;
  bool _isEnglish = false;

  int? _branchId; String? _branchCode; String? _branchName;
  int? _inventoryAccountId; String? _inventoryAccountCode; String? _inventoryAccountName;
  String? _accountingMode;
  int? _purchasesAccountId; String? _purchasesAccountCode; String? _purchasesAccountName;
  List<Account> _accounts = [];

  bool get _isReadOnly => widget.mode == Mode.view;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController();
    _nameThCtrl = TextEditingController();
    _nameEnCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _populate(widget.selected, widget.mode);
  }

  @override
  void didUpdateWidget(covariant ImWarehouseDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected || widget.mode != oldWidget.mode || widget.requestSeq != oldWidget.requestSeq) {
      _populate(widget.selected, widget.mode);
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameThCtrl.dispose();
    _nameEnCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _populate(ImWarehouse? w, Mode mode) {
    final isNew = mode == Mode.add;
    _codeCtrl.text = isNew ? '' : (w?.warehouseCode ?? '');
    _nameThCtrl.text = isNew ? '' : (w?.warehouseNameTh ?? '');
    _nameEnCtrl.text = isNew ? '' : (w?.warehouseNameEn ?? '');
    _addressCtrl.text = isNew ? '' : (w?.address ?? '');
    _isActive = isNew ? true : (w?.isActive ?? true);
    _isConsignee = isNew ? false : (w?.isConsignee ?? false);
    final src = isNew ? null : w;
    _branchId = src?.branchId; _branchCode = src?.branchCode;
    _branchName = _isEnglish && (src?.branchNameEn ?? '').isNotEmpty ? src?.branchNameEn : src?.branchNameTh;
    _inventoryAccountId = src?.inventoryAccountId; _inventoryAccountCode = src?.inventoryAccountCode; _inventoryAccountName = src?.inventoryAccountName;
    _accountingMode = src?.accountingMode;
    _purchasesAccountId = src?.purchasesAccountId; _purchasesAccountCode = src?.purchasesAccountCode; _purchasesAccountName = src?.purchasesAccountName;
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
                              Expanded(child: Text(acctName(a))),
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

  void _openLocationLayout() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ImLocationScreen(
        onFieldsChanged: () {},
        initialWarehouseId: widget.selected?.id,
      ),
    ));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final row = ImWarehouse(
        id: widget.mode == Mode.edit ? widget.selected!.id : 0,
        warehouseCode: _codeCtrl.text.trim().toUpperCase(),
        warehouseNameTh: _nameThCtrl.text.trim(),
        warehouseNameEn: _nameEnCtrl.text.trim().isEmpty ? null : _nameEnCtrl.text.trim(),
        branchId: _branchId,
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        isActive: _isActive,
        isConsignee: _isConsignee,
        inventoryAccountId: _inventoryAccountId,
        accountingMode: _accountingMode,
        purchasesAccountId: _purchasesAccountId,
      );
      await widget.onSubmit(row);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickBranch() async {
    final isEnglish = _isEnglish;
    await BranchListWidget.search(context, onSelected: (Branch b) {
      setState(() {
        _branchId = b.id; _branchCode = b.branchCode;
        _branchName = isEnglish && b.branchNameEng.isNotEmpty ? b.branchNameEng : b.branchNameThai;
      });
    });
  }

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

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final l = AppL10n(isEnglish);

    if (widget.isPlaceholder) {
      return Center(
        child: Text(
          isEnglish ? 'Select a warehouse to view its data, or press + to add a new one' : 'เลือกคลังสินค้าเพื่อดูข้อมูล หรือกดปุ่ม + เพื่อเพิ่มคลังสินค้าใหม่',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.mode == Mode.view
                  ? (isEnglish ? 'View Data' : 'ดูข้อมูล')
                  : widget.mode == Mode.edit
                      ? (isEnglish ? 'Edit Warehouse' : 'แก้ไขคลังสินค้า')
                      : (isEnglish ? 'Add Warehouse' : 'เพิ่มคลังสินค้า'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            TextFormField(
              readOnly: _isReadOnly || widget.mode == Mode.edit,
              controller: _codeCtrl,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: isEnglish ? 'Warehouse Code' : 'รหัสคลังสินค้า', border: const OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? (isEnglish ? 'Please enter the warehouse code' : 'กรุณาป้อนรหัสคลังสินค้า') : null,
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: TextFormField(
                  readOnly: _isReadOnly,
                  controller: _nameThCtrl,
                  decoration: InputDecoration(labelText: isEnglish ? 'Warehouse Name (Thai)' : 'ชื่อคลังสินค้า (ไทย)', border: const OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? (isEnglish ? 'Please enter the warehouse name (Thai)' : 'กรุณาป้อนชื่อคลังสินค้า (ไทย)') : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  readOnly: _isReadOnly,
                  controller: _nameEnCtrl,
                  decoration: InputDecoration(labelText: isEnglish ? 'Warehouse Name (English)' : 'ชื่อคลังสินค้า (อังกฤษ)', border: const OutlineInputBorder()),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            _buildFkField(
              label: isEnglish ? 'Branch' : 'สาขา',
              hasValue: _branchId != null,
              displayText: '$_branchCode — $_branchName',
              onSearch: _pickBranch,
              onClear: () => setState(() { _branchId = null; _branchCode = null; _branchName = null; }),
            ),
            TextFormField(
              readOnly: _isReadOnly,
              controller: _addressCtrl,
              maxLines: 2,
              decoration: InputDecoration(labelText: isEnglish ? 'Address' : 'ที่อยู่', border: const OutlineInputBorder(), alignLabelWithHint: true),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Text(isEnglish ? 'Status: ${_isActive ? 'Active' : 'Inactive'}' : 'สถานะ: ${_isActive ? 'ใช้งาน' : 'หยุดใช้'}')),
              Switch(value: _isActive, activeColor: Colors.teal, onChanged: _isReadOnly ? null : (v) => setState(() => _isActive = v)),
            ]),
            // Consignment-OUT — คลังนี้แทนสถานที่ของผู้รับฝากขาย สินค้าที่โอนเข้ามาด้วยใบโอน (TRF) ยังเป็นของเราอยู่
            // จนกว่าจะขายออกจากคลังนี้ด้วยใบส่งสินค้า (DLN) ตามปกติ
            Row(children: [
              Expanded(
                child: Text(isEnglish
                    ? 'Consignee warehouse (goods held here are still ours until sold)'
                    : 'คลังผู้รับฝากขาย (สินค้าที่อยู่ในคลังนี้ยังเป็นของเราจนกว่าจะขาย)'),
              ),
              Switch(value: _isConsignee, activeColor: Colors.teal, onChanged: _isReadOnly ? null : (v) => setState(() => _isConsignee = v)),
            ]),
            const SizedBox(height: 16),
            Text(isEnglish ? 'GL Accounts' : 'บัญชี GL',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
            Text(
              isEnglish
                  ? 'Warehouse inventory account comes first (warehouse → item → category → document type). The mode applies when the item and its category follow the next level.'
                  : 'บัญชีสต็อกของคลังมีผลก่อน (คลัง → สินค้า → หมวดสินค้า → ประเภทเอกสาร) ส่วนโหมดของคลังมีผลเมื่อสินค้าและหมวดสินค้าไม่ได้กำหนดโหมดไว้',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: ImAccountingModeField(
                value: _accountingMode,
                isEnglish: isEnglish,
                readOnly: _isReadOnly,
                inheritLabelTh: 'ตามค่าเริ่มต้นของบริษัท',
                inheritLabelEn: 'Follow company default',
                onChanged: (v) => setState(() => _accountingMode = v),
              )),
              const SizedBox(width: 10),
              Expanded(child: _buildFkField(
                label: isEnglish ? 'Inventory Account' : 'บัญชีสินค้าคงคลัง',
                hasValue: _inventoryAccountId != null,
                displayText: '$_inventoryAccountCode — $_inventoryAccountName',
                onSearch: () => _pickAccount(isEnglish ? 'Select Inventory Account' : 'เลือกบัญชีสินค้าคงคลัง', (a) => setState(() {
                      _inventoryAccountId = a.id; _inventoryAccountCode = a.accountCode; _inventoryAccountName = _acctName(a);
                    })),
                onClear: () => setState(() { _inventoryAccountId = null; _inventoryAccountCode = null; _inventoryAccountName = null; }),
              )),
            ]),
            // บัญชีซื้อสินค้าใช้เฉพาะ Periodic — Perpetual ลง Dr บัญชีสต็อกแทน
            ImAccountingModeField.gate(
              enabled: _accountingMode != 'PERPETUAL',
              isEnglish: isEnglish,
              child: _buildFkField(
                label: isEnglish ? 'Purchases Account (Periodic)' : 'บัญชีซื้อสินค้า (Periodic)',
                hasValue: _purchasesAccountId != null,
                displayText: '$_purchasesAccountCode — $_purchasesAccountName',
                onSearch: () => _pickAccount(isEnglish ? 'Select Purchases Account' : 'เลือกบัญชีซื้อสินค้า', (a) => setState(() {
                      _purchasesAccountId = a.id; _purchasesAccountCode = a.accountCode; _purchasesAccountName = _acctName(a);
                    })),
                onClear: () => setState(() { _purchasesAccountId = null; _purchasesAccountCode = null; _purchasesAccountName = null; }),
              ),
            ),
            if (widget.mode == Mode.edit || widget.mode == Mode.view) ...[
              const SizedBox(height: 24),
              const Divider(),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.map_outlined, color: Colors.teal),
                  title: Text(isEnglish ? 'Storage Location Layout' : 'ผังตำแหน่งจัดเก็บ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(isEnglish ? 'Manage zones/bins and their assigned category' : 'จัดการโซน/ช่องเก็บ และหมวดหมู่ที่กำหนดให้เก็บ'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openLocationLayout,
                ),
              ),
            ],
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                widget.mode == Mode.view
                    ? Container()
                    : Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save),
                          label: Text(_isSaving ? (isEnglish ? 'Saving...' : 'กำลังบันทึก...') : widget.mode == Mode.edit ? l.save : l.add),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.cancel),
                    label: Text(l.cancel),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
