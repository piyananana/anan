import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../models/im_item_category.dart';

class ImItemCategoryDetailWidget extends StatefulWidget {
  final Mode mode;
  final ImItemCategory? selected;
  final Function(ImItemCategory) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;
  // เพิ่มขึ้นทุกครั้งที่ผู้ใช้กดปุ่มเพิ่ม/แก้ไข/ดู/ยกเลิกจากหน้าจอหลัก — ใช้บังคับให้ didUpdateWidget เคลียร์ฟอร์ม
  // เสมอ แม้ mode/selected จะ "เหมือนเดิม" กับครั้งก่อน (เช่น กดเพิ่มหมวดหมู่หลักซ้ำหลังพิมพ์ข้อมูลค้างไว้ หรือ
  // กดเพิ่มหมวดหมู่หลักหลังจากหน้าจออยู่ในสถานะ placeholder ที่ใช้ mode/selected ชุดเดียวกันโดยบังเอิญ)
  final int requestSeq;

  const ImItemCategoryDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
    this.requestSeq = 0,
  });

  @override
  State<ImItemCategoryDetailWidget> createState() => ImItemCategoryDetailWidgetState();
}

class ImItemCategoryDetailWidgetState extends State<ImItemCategoryDetailWidget> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeCtrl;
  late TextEditingController _nameThCtrl;
  late TextEditingController _nameEnCtrl;
  bool _isActive = true;
  bool _isSaving = false;
  bool _isEnglish = false;
  String _categoryType = 'CATEGORY';

  bool _isAutoNumber = false;
  late TextEditingController _prefixCtrl;
  late TextEditingController _separatorCtrl;
  String _suffixDate = '';
  late TextEditingController _lengthCtrl;
  late TextEditingController _nextNumCtrl;

  int? _inventoryAccountId; String? _inventoryAccountCode; String? _inventoryAccountName;
  int? _cogsAccountId; String? _cogsAccountCode; String? _cogsAccountName;
  int? _revenueAccountId; String? _revenueAccountCode; String? _revenueAccountName;
  int? _expenseAccountId; String? _expenseAccountCode; String? _expenseAccountName;
  int? _varianceAccountId; String? _varianceAccountCode; String? _varianceAccountName;
  int? _wipAccountId; String? _wipAccountCode; String? _wipAccountName;

  List<Account> _accounts = [];

  bool get _isReadOnly => widget.mode == Mode.view;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController();
    _nameThCtrl = TextEditingController();
    _nameEnCtrl = TextEditingController();
    _prefixCtrl = TextEditingController();
    _separatorCtrl = TextEditingController();
    _lengthCtrl = TextEditingController();
    _nextNumCtrl = TextEditingController();
    _loadAccounts();
    _populate(widget.selected, widget.mode);
  }

  @override
  void didUpdateWidget(covariant ImItemCategoryDetailWidget oldWidget) {
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
    _prefixCtrl.dispose();
    _separatorCtrl.dispose();
    _lengthCtrl.dispose();
    _nextNumCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final list = await AccountService().fetchRows();
      if (mounted) setState(() => _accounts = list.where((a) => a.isActive && a.isNormalAccount).toList());
    } catch (_) {}
  }

  void _populate(ImItemCategory? c, Mode mode) {
    // addChild passes the PARENT category as `selected`; the form itself starts blank.
    final isNewNode = mode == Mode.addRoot || mode == Mode.addChild;
    _codeCtrl.text = isNewNode ? '' : (c?.categoryCode ?? '');
    _nameThCtrl.text = isNewNode ? '' : (c?.categoryNameTh ?? '');
    _nameEnCtrl.text = isNewNode ? '' : (c?.categoryNameEn ?? '');
    _isActive = isNewNode ? true : (c?.isActive ?? true);
    _categoryType = isNewNode ? 'CATEGORY' : (c?.categoryType ?? 'CATEGORY');
    _isAutoNumber = isNewNode ? false : (c?.isAutoNumber ?? false);
    _prefixCtrl.text = isNewNode ? 'ITEM' : (c?.runningPrefix ?? 'ITEM');
    _separatorCtrl.text = isNewNode ? '-' : (c?.runningSeparator ?? '-');
    _suffixDate = isNewNode ? '' : (c?.runningSuffixDate ?? '');
    _lengthCtrl.text = (isNewNode ? 4 : (c?.runningLength ?? 4)).toString();
    _nextNumCtrl.text = (isNewNode ? 1 : (c?.runningNextNumber ?? 1)).toString();
    final src = isNewNode ? null : c;
    _inventoryAccountId = src?.inventoryAccountId; _inventoryAccountCode = src?.inventoryAccountCode; _inventoryAccountName = src?.inventoryAccountName;
    _cogsAccountId = src?.cogsAccountId; _cogsAccountCode = src?.cogsAccountCode; _cogsAccountName = src?.cogsAccountName;
    _revenueAccountId = src?.revenueAccountId; _revenueAccountCode = src?.revenueAccountCode; _revenueAccountName = src?.revenueAccountName;
    _expenseAccountId = src?.expenseAccountId; _expenseAccountCode = src?.expenseAccountCode; _expenseAccountName = src?.expenseAccountName;
    _varianceAccountId = src?.varianceAccountId; _varianceAccountCode = src?.varianceAccountCode; _varianceAccountName = src?.varianceAccountName;
    _wipAccountId = src?.wipAccountId; _wipAccountCode = src?.wipAccountCode; _wipAccountName = src?.wipAccountName;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final row = ImItemCategory(
        id: widget.mode == Mode.edit ? widget.selected!.id : 0,
        parentId: widget.mode == Mode.addRoot
            ? null
            : widget.mode == Mode.addChild
                ? widget.selected!.id
                : widget.selected!.parentId,
        categoryCode: _codeCtrl.text.trim().toUpperCase(),
        categoryNameTh: _nameThCtrl.text.trim(),
        categoryNameEn: _nameEnCtrl.text.trim().isEmpty ? null : _nameEnCtrl.text.trim(),
        isActive: _isActive,
        categoryType: _categoryType,
        isAutoNumber: _categoryType == 'CATEGORY' && _isAutoNumber,
        runningPrefix: _prefixCtrl.text.trim().isEmpty ? 'ITEM' : _prefixCtrl.text.trim(),
        runningSeparator: _separatorCtrl.text,
        runningSuffixDate: _suffixDate,
        runningLength: int.tryParse(_lengthCtrl.text) ?? 4,
        runningNextNumber: int.tryParse(_nextNumCtrl.text) ?? 1,
        inventoryAccountId: _inventoryAccountId,
        cogsAccountId: _cogsAccountId,
        revenueAccountId: _revenueAccountId,
        expenseAccountId: _expenseAccountId,
        varianceAccountId: _varianceAccountId,
        wipAccountId: _wipAccountId,
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
                      .where((a) =>
                          a.accountCode.toUpperCase().contains(q.toUpperCase()) ||
                          a.accountNameThai.toUpperCase().contains(q.toUpperCase()) ||
                          a.accountNameEng.toUpperCase().contains(q.toUpperCase()))
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

  Widget _buildFkField({
    required String label,
    required String? displayText,
    required bool hasValue,
    required VoidCallback onSearch,
    VoidCallback? onClear,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
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
              IconButton(
                icon: const Icon(Icons.search, color: Colors.teal),
                tooltip: _isEnglish ? 'Search' : 'ค้นหา',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onSearch,
              ),
              if (hasValue && onClear != null)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.red, size: 18),
                  tooltip: _isEnglish ? 'Clear' : 'ล้าง',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onClear,
                ),
            ],
          ]),
        ),
      );

  List<DropdownMenuItem<String>> _suffixOptions(bool isEnglish) => [
        DropdownMenuItem(value: '', child: Text(isEnglish ? '— No date —' : '— ไม่มีวันที่ —')),
        DropdownMenuItem(value: 'YY', child: Text(isEnglish ? 'YY (e.g. 25)' : 'YY (เช่น 25)')),
        DropdownMenuItem(value: 'YYYY', child: Text(isEnglish ? 'YYYY (e.g. 2025)' : 'YYYY (เช่น 2025)')),
        DropdownMenuItem(value: 'YYMM', child: Text(isEnglish ? 'YYMM (e.g. 2503)' : 'YYMM (เช่น 2503)')),
        DropdownMenuItem(value: 'YYYYMM', child: Text(isEnglish ? 'YYYYMM (e.g. 202503)' : 'YYYYMM (เช่น 202503)')),
        DropdownMenuItem(value: 'YYMMDD', child: Text(isEnglish ? 'YYMMDD (e.g. 250315)' : 'YYMMDD (เช่น 250315)')),
      ];

  String get _sampleCode {
    String code = _prefixCtrl.text;
    if (_suffixDate.isNotEmpty) {
      final now = DateTime.now();
      final year = now.year.toString();
      final month = now.month.toString().padLeft(2, '0');
      final day = now.day.toString().padLeft(2, '0');
      switch (_suffixDate) {
        case 'YY':     code += year.substring(2); break;
        case 'YYYY':   code += year; break;
        case 'YYMM':   code += year.substring(2) + month; break;
        case 'YYYYMM': code += year + month; break;
        case 'YYMMDD': code += year.substring(2) + month + day; break;
      }
    }
    code += _separatorCtrl.text;
    final len = int.tryParse(_lengthCtrl.text) ?? 4;
    final next = int.tryParse(_nextNumCtrl.text) ?? 1;
    code += next.toString().padLeft(len, '0');
    return code;
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final l = AppL10n(isEnglish);

    if (widget.isPlaceholder) {
      return Center(
        child: Text(
          isEnglish
              ? 'Select a category to view its data, or press + to add a new one'
              : 'เลือกหมวดหมู่เพื่อดูข้อมูล หรือกดปุ่ม + เพื่อเพิ่มหมวดหมู่ใหม่',
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
                      ? (isEnglish ? 'Edit Category' : 'แก้ไขหมวดหมู่')
                      : widget.mode == Mode.addChild
                          ? '${isEnglish ? 'Add sub-category under' : 'เพิ่มหมวดหมู่ย่อยของ'}: ${widget.selected?.categoryCode} ${isEnglish && (widget.selected?.categoryNameEn ?? '').isNotEmpty ? widget.selected?.categoryNameEn : widget.selected?.categoryNameTh}'
                          : (isEnglish ? 'Add Root Category' : 'เพิ่มหมวดหมู่หลัก'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            TextFormField(
              readOnly: _isReadOnly || widget.mode == Mode.edit,
              controller: _codeCtrl,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: isEnglish ? 'Category Code' : 'รหัสหมวดหมู่',
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? (isEnglish ? 'Please enter the category code' : 'กรุณาป้อนรหัสหมวดหมู่') : null,
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: TextFormField(
                  readOnly: _isReadOnly,
                  controller: _nameThCtrl,
                  decoration: InputDecoration(labelText: isEnglish ? 'Category Name (Thai)' : 'ชื่อหมวดหมู่ (ไทย)', border: const OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? (isEnglish ? 'Please enter the category name (Thai)' : 'กรุณาป้อนชื่อหมวดหมู่ (ไทย)') : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  readOnly: _isReadOnly,
                  controller: _nameEnCtrl,
                  decoration: InputDecoration(labelText: isEnglish ? 'Category Name (English)' : 'ชื่อหมวดหมู่ (อังกฤษ)', border: const OutlineInputBorder()),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Text(isEnglish ? 'Status: ${_isActive ? 'Active' : 'Inactive'}' : 'สถานะ: ${_isActive ? 'ใช้งาน' : 'หยุดใช้'}')),
              Switch(
                value: _isActive,
                activeColor: Colors.teal,
                onChanged: _isReadOnly ? null : (v) => setState(() => _isActive = v),
              ),
            ]),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _categoryType,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: isEnglish ? 'Type' : 'ประเภท',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: imCategoryTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(imCategoryTypeLabel(t, isEnglish))))
                  .toList(),
              onChanged: _isReadOnly ? null : (v) => setState(() => _categoryType = v ?? 'CATEGORY'),
            ),
            if (_categoryType == 'CATEGORY') ...[
            const SizedBox(height: 16),
            Text(isEnglish ? 'Default GL Accounts' : 'บัญชี GL ตั้งต้น',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
            Text(
              isEnglish
                  ? 'Used when an item under this category does not specify its own account.'
                  : 'ใช้เมื่อสินค้าภายใต้หมวดหมู่นี้ไม่ได้ระบุบัญชีของตัวเอง',
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
            Row(children: [
              Expanded(child: _buildFkField(
                label: isEnglish ? 'Variance Account' : 'บัญชีผลต่างต้นทุน',
                hasValue: _varianceAccountId != null,
                displayText: '$_varianceAccountCode — $_varianceAccountName',
                onSearch: () => _pickAccount(isEnglish ? 'Select Variance Account' : 'เลือกบัญชีผลต่างต้นทุน', (a) => setState(() {
                      _varianceAccountId = a.id; _varianceAccountCode = a.accountCode;
                      _varianceAccountName = isEnglish && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai;
                    })),
                onClear: () => setState(() { _varianceAccountId = null; _varianceAccountCode = null; _varianceAccountName = null; }),
              )),
              const SizedBox(width: 10),
              Expanded(child: _buildFkField(
                label: isEnglish ? 'WIP Account' : 'บัญชีงานระหว่างผลิต (WIP)',
                hasValue: _wipAccountId != null,
                displayText: '$_wipAccountCode — $_wipAccountName',
                onSearch: () => _pickAccount(isEnglish ? 'Select WIP Account' : 'เลือกบัญชีงานระหว่างผลิต', (a) => setState(() {
                      _wipAccountId = a.id; _wipAccountCode = a.accountCode;
                      _wipAccountName = isEnglish && a.accountNameEng.isNotEmpty ? a.accountNameEng : a.accountNameThai;
                    })),
                onClear: () => setState(() { _wipAccountId = null; _wipAccountCode = null; _wipAccountName = null; }),
              )),
            ]),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SwitchListTile(
                  title: Text(isEnglish ? 'Auto item numbering' : 'ออกรหัสสินค้าอัตโนมัติ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    _isAutoNumber
                        ? (isEnglish ? 'Enabled — a code is generated automatically when an item is added to this category' : 'เปิดใช้งาน — รหัสจะถูกออกอัตโนมัติเมื่อเพิ่มสินค้าในหมวดหมู่นี้')
                        : (isEnglish ? 'Disabled — the item code must be entered manually' : 'ปิดใช้งาน — ผู้ใช้ต้องระบุรหัสสินค้าเอง'),
                    style: TextStyle(color: _isAutoNumber ? Colors.teal[700] : Colors.grey, fontSize: 12),
                  ),
                  value: _isAutoNumber,
                  activeColor: Colors.teal,
                  onChanged: _isReadOnly ? null : (v) => setState(() => _isAutoNumber = v),
                ),
                if (_isAutoNumber) ...[
                  Divider(height: 1, color: Colors.grey.shade200),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: TextFormField(
                          readOnly: _isReadOnly, controller: _prefixCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(labelText: 'Prefix', border: OutlineInputBorder(), hintText: 'ITEM'),
                          onChanged: (_) => setState(() {}),
                        )),
                        const SizedBox(width: 8),
                        SizedBox(width: 80, child: TextFormField(
                          readOnly: _isReadOnly, controller: _separatorCtrl, textAlign: TextAlign.center,
                          decoration: const InputDecoration(labelText: 'Separator', border: OutlineInputBorder(), hintText: '-'),
                          onChanged: (_) => setState(() {}),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: DropdownButtonFormField<String>(
                          isExpanded: true, value: _suffixDate,
                          decoration: InputDecoration(labelText: isEnglish ? 'Date in code' : 'วันที่ในรหัส', border: const OutlineInputBorder()),
                          items: _suffixOptions(isEnglish),
                          onChanged: _isReadOnly ? null : (v) => setState(() => _suffixDate = v ?? ''),
                        )),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: TextFormField(
                          readOnly: _isReadOnly, controller: _lengthCtrl,
                          keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(labelText: isEnglish ? 'Number length' : 'ความยาวตัวเลข', border: const OutlineInputBorder()),
                          onChanged: (_) => setState(() {}),
                          validator: (v) { if (!_isAutoNumber) return null; final n = int.tryParse(v ?? ''); return (n == null || n < 1 || n > 10) ? '1-10' : null; },
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: TextFormField(
                          readOnly: _isReadOnly, controller: _nextNumCtrl,
                          keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(labelText: isEnglish ? 'Next number' : 'เลขที่ถัดไป', border: const OutlineInputBorder()),
                          onChanged: (_) => setState(() {}),
                          validator: (v) => !_isAutoNumber || int.tryParse(v ?? '') != null ? null : (isEnglish ? 'Must be a number' : 'ต้องเป็นตัวเลข'),
                        )),
                      ]),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.teal.shade200)),
                        child: Row(children: [
                          Icon(Icons.auto_awesome, color: Colors.teal[700], size: 16),
                          const SizedBox(width: 8),
                          Text(isEnglish ? 'Sample code: ' : 'ตัวอย่างรหัส: ', style: TextStyle(fontSize: 13, color: Colors.teal[700])),
                          Text(_sampleCode, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal[700], letterSpacing: 1)),
                        ]),
                      ),
                    ]),
                  ),
                ],
              ]),
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
