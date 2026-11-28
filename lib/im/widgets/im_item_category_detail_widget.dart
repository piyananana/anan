import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/widgets/sa_doc_appbar_actions.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../models/im_item.dart';
import '../models/im_item_category.dart';
import '../services/im_item_category_service.dart';
import 'im_master_kit.dart';
import '../../sa/utils/sa_menu_theme.dart';

// หน้ารายละเอียดหมวดหมู่สินค้า (user 2026-11-25): ตัวเลขสรุป (สินค้าในหมวดรวมหมวดย่อย, มูลค่า, หมวดย่อย, ตำแหน่งที่กำหนด),
// 4 กลุ่ม (ข้อมูลหลัก / รหัสสินค้าอัตโนมัติ / บัญชี / เพิ่มเติม), ตารางบัญชี GL ตั้งต้น 7 บัญชี + "ถ้าเว้นว่าง ใช้",
// การ์ดสินค้าในหมวด (อ่านอย่างเดียว)
// mode addChild: selected = หมวดแม่ (ฟอร์มว่าง), addRoot: ไม่มีแม่
class ImItemCategoryDetailWidget extends StatefulWidget {
  final Mode mode;
  final ImItemCategory? selected;
  final Future<void> Function(ImItemCategory) onSubmit;
  final VoidCallback onCancel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onAddChild;
  /// เส้นทางแม่ของหมวดนี้ เช่น "1 สินค้าสำเร็จรูป › 11 อุปกรณ์ไฟฟ้า" (ว่าง = ระดับบนสุด)
  final String parentPath;
  final bool isPlaceholder;
  // เพิ่มขึ้นทุกครั้งที่ผู้ใช้กดปุ่มเพิ่ม/แก้ไข/ดู/ยกเลิกจากหน้าจอหลัก — บังคับให้ฟอร์มเคลียร์เสมอแม้ mode/selected ซ้ำ
  final int requestSeq;

  const ImItemCategoryDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.onEdit,
    this.onDelete,
    this.onAddChild,
    this.parentPath = '',
    this.isPlaceholder = false,
    this.requestSeq = 0,
  });

  @override
  State<ImItemCategoryDetailWidget> createState() => ImItemCategoryDetailWidgetState();
}

class ImItemCategoryDetailWidgetState extends State<ImItemCategoryDetailWidget> with ImMasterKit {
  final _svc = ImItemCategoryService();
  final _codeCtrl = TextEditingController();
  final _nameThCtrl = TextEditingController();
  final _nameEnCtrl = TextEditingController();
  final _prefixCtrl = TextEditingController();
  final _separatorCtrl = TextEditingController();
  final _lengthCtrl = TextEditingController();
  final _nextNumCtrl = TextEditingController();
  bool _isActive = true;
  bool _isSaving = false;
  bool _isEnglish = false;
  String _categoryType = 'CATEGORY';
  bool _isAutoNumber = false;
  String _suffixDate = '';

  int? _inventoryAccountId; String? _inventoryAccountCode; String? _inventoryAccountName;
  int? _cogsAccountId; String? _cogsAccountCode; String? _cogsAccountName;
  int? _revenueAccountId; String? _revenueAccountCode; String? _revenueAccountName;
  int? _expenseAccountId; String? _expenseAccountCode; String? _expenseAccountName;
  int? _varianceAccountId; String? _varianceAccountCode; String? _varianceAccountName;
  String? _accountingMode;
  int? _purchasesAccountId; String? _purchasesAccountCode; String? _purchasesAccountName;
  int? _wipAccountId; String? _wipAccountCode; String? _wipAccountName;
  List<Account> _accounts = [];

  ImCategorySummary? _summary;
  bool _loadingSummary = false;
  int _summarySeq = 0;
  String _snapshot = '';

  static final _qtyFmt = NumberFormat('#,##0.##');
  static final _amtFmt = NumberFormat('#,##0.00');

  bool get _isNew => widget.mode == Mode.addRoot || widget.mode == Mode.addChild;
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
  void didUpdateWidget(covariant ImItemCategoryDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected || widget.mode != oldWidget.mode || widget.requestSeq != oldWidget.requestSeq) _apply();
  }

  @override
  void dispose() {
    for (final c in [_codeCtrl, _nameThCtrl, _nameEnCtrl, _prefixCtrl, _separatorCtrl, _lengthCtrl, _nextNumCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _apply() {
    // addChild ส่งหมวดแม่มาเป็น selected — ฟอร์มเริ่มว่าง
    final c = _isNew ? null : widget.selected;
    _codeCtrl.text = c?.categoryCode ?? '';
    _nameThCtrl.text = c?.categoryNameTh ?? '';
    _nameEnCtrl.text = c?.categoryNameEn ?? '';
    _isActive = c?.isActive ?? true;
    _categoryType = c?.categoryType ?? 'CATEGORY';
    _isAutoNumber = c?.isAutoNumber ?? false;
    _prefixCtrl.text = c?.runningPrefix ?? 'ITEM';
    _separatorCtrl.text = c?.runningSeparator ?? '-';
    _suffixDate = c?.runningSuffixDate ?? '';
    _lengthCtrl.text = '${c?.runningLength ?? 4}';
    _nextNumCtrl.text = '${c?.runningNextNumber ?? 1}';
    _inventoryAccountId = c?.inventoryAccountId; _inventoryAccountCode = c?.inventoryAccountCode; _inventoryAccountName = c?.inventoryAccountName;
    _cogsAccountId = c?.cogsAccountId; _cogsAccountCode = c?.cogsAccountCode; _cogsAccountName = c?.cogsAccountName;
    _revenueAccountId = c?.revenueAccountId; _revenueAccountCode = c?.revenueAccountCode; _revenueAccountName = c?.revenueAccountName;
    _expenseAccountId = c?.expenseAccountId; _expenseAccountCode = c?.expenseAccountCode; _expenseAccountName = c?.expenseAccountName;
    _varianceAccountId = c?.varianceAccountId; _varianceAccountCode = c?.varianceAccountCode; _varianceAccountName = c?.varianceAccountName;
    _wipAccountId = c?.wipAccountId; _wipAccountCode = c?.wipAccountCode; _wipAccountName = c?.wipAccountName;
    _accountingMode = c?.accountingMode;
    _purchasesAccountId = c?.purchasesAccountId; _purchasesAccountCode = c?.purchasesAccountCode; _purchasesAccountName = c?.purchasesAccountName;
    _summary = null;
    _summarySeq++;
    if (widget.mode != Mode.none) _loadSummary(c?.id ?? 0);
    kScrollTop();
    _snapshot = _fingerprint();
  }

  Future<void> _loadSummary(int id) async {
    final seq = ++_summarySeq;
    _loadingSummary = true;
    try {
      final r = await _svc.fetchSummary(id);
      if (mounted && seq == _summarySeq) setState(() => _summary = r);
    } catch (_) {
    } finally {
      if (mounted && seq == _summarySeq) setState(() => _loadingSummary = false);
    }
  }

  ImItemCategory _build() => ImItemCategory(
        id: widget.mode == Mode.edit ? widget.selected!.id : 0,
        parentId: widget.mode == Mode.addRoot
            ? null
            : widget.mode == Mode.addChild
                ? widget.selected?.id
                : widget.selected?.parentId,
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
        accountingMode: _accountingMode,
        purchasesAccountId: _purchasesAccountId,
      );

  String _fingerprint() => docFingerprint(_build().toJson());

  Future<void> _save() async {
    final e = _isEnglish;
    String? err;
    if (_codeCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter the category code' : 'กรุณาป้อนรหัสหมวดหมู่';
    } else if (_nameThCtrl.text.trim().isEmpty) {
      err = e ? 'Please enter the category name (Thai)' : 'กรุณาป้อนชื่อหมวดหมู่ (ไทย)';
    } else if (_categoryType == 'CATEGORY' && _isAutoNumber &&
        ((int.tryParse(_lengthCtrl.text) ?? 0) <= 0 || (int.tryParse(_nextNumCtrl.text) ?? 0) <= 0)) {
      err = e ? 'Number length and next number must be numbers greater than 0' : 'ความยาวตัวเลขและเลขที่ถัดไปต้องเป็นตัวเลขมากกว่า 0';
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

  String get _sampleCode {
    String code = _prefixCtrl.text;
    if (_suffixDate.isNotEmpty) {
      final now = DateTime.now();
      final year = now.year.toString();
      final month = now.month.toString().padLeft(2, '0');
      final day = now.day.toString().padLeft(2, '0');
      switch (_suffixDate) {
        case 'YY': code += year.substring(2); break;
        case 'YYYY': code += year; break;
        case 'YYMM': code += year.substring(2) + month; break;
        case 'YYYYMM': code += year + month; break;
        case 'YYMMDD': code += year.substring(2) + month + day; break;
      }
    }
    code += _separatorCtrl.text;
    final len = int.tryParse(_lengthCtrl.text) ?? 4;
    final next = int.tryParse(_nextNumCtrl.text) ?? 1;
    return code + next.toString().padLeft(len, '0');
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

  // ── การ์ด ──
  Widget _mainCard() {
    final e = _isEnglish;
    final ed = !_isReadOnly;
    final autoOk = ed && _categoryType == 'CATEGORY';
    final autoFields = autoOk && _isAutoNumber;
    final parentText = widget.mode == Mode.addChild
        ? '${widget.selected?.categoryCode ?? ''}  ${widget.selected?.displayName(e) ?? ''}'
        : (widget.parentPath.isEmpty ? (e ? '— Top level —' : '— ระดับบนสุด —') : widget.parentPath);
    return kCard(
      title: e ? 'Category Information' : 'ข้อมูลหมวดหมู่',
      trailing: _isReadOnly ? null : kLegend(),
      child: kGroups([
        kGroup(1, e ? 'Main Information' : 'ข้อมูลหลัก', ImKit.gDoc, [
          kRow([
            kTxt(_isNew ? (e ? 'Category Code *' : 'รหัสหมวดหมู่ *') : (e ? 'Category Code' : 'รหัสหมวดหมู่'), _codeCtrl,
                editable: _isNew, cap: TextCapitalization.characters),
            kDd<String>(e ? 'Type' : 'ประเภท', _categoryType,
                imCategoryTypes.map((t) => DropdownMenuItem(value: t, child: Text('${imCategoryTypeLabel(t, e)} ($t)'))).toList(),
                ed ? (v) => setState(() => _categoryType = v ?? 'CATEGORY') : null),
          ]),
          kRow([
            kTxt(e ? 'Category Name (Thai) *' : 'ชื่อหมวดหมู่ (ไทย) *', _nameThCtrl),
            kTxt(e ? 'Category Name (English)' : 'ชื่อหมวดหมู่ (อังกฤษ)', _nameEnCtrl),
          ]),
          InputDecorator(
            decoration: kDec(e ? 'Parent' : 'อยู่ภายใต้', editable: false),
            child: Text(parentText, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: ImKit.font)),
          ),
        ]),
        kGroup(2, e ? 'Auto Item Numbering' : 'รหัสสินค้าอัตโนมัติ', ImKit.gParty, [
          kChecks([
            kCk(e ? 'Generate item codes automatically in this category' : 'ออกรหัสสินค้าอัตโนมัติเมื่อเพิ่มสินค้าในหมวดนี้',
                _categoryType == 'CATEGORY' && _isAutoNumber, autoOk ? (v) => setState(() => _isAutoNumber = v) : null,
                tooltip: _categoryType == 'HEADER' ? (e ? 'Headers cannot hold items' : 'หัวข้อใช้จัดกลุ่ม ไม่มีสินค้า') : null),
          ]),
          kRow([
            kTxt(e ? 'Prefix' : 'คำนำหน้า', _prefixCtrl, editable: autoFields, cap: TextCapitalization.characters),
            kDd<String>(e ? 'Date in code' : 'วันที่ในรหัส', _suffixDate, [
              DropdownMenuItem(value: '', child: Text(e ? '— No date —' : '— ไม่มีวันที่ —')),
              DropdownMenuItem(value: 'YY', child: Text(e ? 'YY (e.g. 26)' : 'YY (เช่น 26)')),
              DropdownMenuItem(value: 'YYYY', child: Text(e ? 'YYYY (e.g. 2026)' : 'YYYY (เช่น 2026)')),
              DropdownMenuItem(value: 'YYMM', child: Text(e ? 'YYMM (e.g. 2611)' : 'YYMM (เช่น 2611)')),
              DropdownMenuItem(value: 'YYYYMM', child: Text(e ? 'YYYYMM (e.g. 202611)' : 'YYYYMM (เช่น 202611)')),
              DropdownMenuItem(value: 'YYMMDD', child: Text(e ? 'YYMMDD (e.g. 261125)' : 'YYMMDD (เช่น 261125)')),
            ], autoFields ? (v) => setState(() => _suffixDate = v ?? '') : null),
            kTxt(e ? 'Separator' : 'ตัวคั่น', _separatorCtrl, editable: autoFields),
          ], [2, 3, 1]),
          kRow([
            kTxt(e ? 'Number length' : 'ความยาวตัวเลข', _lengthCtrl, numeric: true, digitsOnly: true, editable: autoFields),
            kTxt(e ? 'Next number' : 'เลขที่ถัดไป', _nextNumCtrl, numeric: true, digitsOnly: true, editable: autoFields),
            InputDecorator(
              decoration: kDec(e ? 'Sample code' : 'ตัวอย่างรหัส', editable: false),
              child: Text(_categoryType == 'CATEGORY' && _isAutoNumber ? _sampleCode : '—',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: ImKit.font, fontWeight: FontWeight.w600)),
            ),
          ]),
          kNote(e ? 'Format: prefix + date + separator + running number' : 'รูปแบบ: คำนำหน้า + วันที่ + ตัวคั่น + เลขลำดับ'),
        ]),
        kGroup(3, e ? 'Accounting' : 'บัญชี', ImKit.gFin, [
          kDd<String?>(e ? 'Accounting Mode' : 'โหมดบัญชีสินค้า', _accountingMode, [
            DropdownMenuItem<String?>(value: null, child: Text(e ? 'Follow warehouse / default' : 'ตามคลัง / ค่าเริ่มต้น', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem<String?>(value: 'PERPETUAL', child: Text(e ? 'Perpetual' : 'Perpetual (โพสต์บัญชีทันที)', overflow: TextOverflow.ellipsis)),
            DropdownMenuItem<String?>(value: 'PERIODIC', child: Text(e ? 'Periodic' : 'Periodic (ปิดงวดครั้งเดียว)', overflow: TextOverflow.ellipsis)),
          ], ed ? (v) => setState(() => _accountingMode = v) : null),
          kNote(e ? 'The 7 default GL accounts are in the card below.' : 'บัญชี GL ตั้งต้นทั้ง 7 บัญชีอยู่ในการ์ดด้านล่าง'),
        ]),
        kGroup(4, e ? 'More' : 'เพิ่มเติม', ImKit.gMore, [
          kChecks([kCk(e ? 'Active' : 'ใช้งาน', _isActive, ed ? (v) => setState(() => _isActive = v) : null)]),
        ]),
      ]),
    );
  }

  Widget _glCard() {
    final e = _isEnglish;
    final ed = !_isReadOnly;
    ImCategoryGlDefault? def(String k) => _summary?.glDefaults.where((g) => g.key == k).firstOrNull;
    String fallback(String key) {
      final d = def(key);
      switch (key) {
        case 'inventory':
        case 'cogs':
          if (d == null) return '';
          if (d.docType) {
            return e
                ? 'By IM document type${d.companyCode != null ? ' (else company ${d.companyCode})' : ''}'
                : 'ตามประเภทเอกสาร IM${d.companyCode != null ? ' (ถ้าไม่ได้ตั้ง ใช้ ${d.companyCode})' : ''}';
          }
          return d.companyCode != null ? (e ? 'Company default ${d.companyCode}' : 'ค่าเริ่มต้นบริษัท ${d.companyCode}') : (e ? 'Not set' : 'ยังไม่ได้ตั้ง');
        case 'revenue':
          if (d == null) return '';
          return d.docType ? (e ? 'By AR document type' : 'ตามประเภทเอกสาร AR') : (e ? 'Not set' : 'ยังไม่ได้ตั้ง');
        case 'purchases':
          if (d == null) return '';
          return d.companyCode != null ? (e ? 'Company default ${d.companyCode}' : 'ค่าเริ่มต้นบริษัท ${d.companyCode}') : (e ? 'Not set' : 'ยังไม่ได้ตั้ง');
        default:
          return '';
      }
    }

    final unused = ImKit.chip(e ? 'not posted yet' : 'ยังไม่ใช้ลงบัญชี', ImKit.ro, ImKit.gMore);
    final rows = <(String, String, bool, int?, String?, String?, void Function(Account), VoidCallback)>[
      ('inventory', e ? 'Inventory' : 'สินค้าคงคลัง', false, _inventoryAccountId, _inventoryAccountCode, _inventoryAccountName,
          (a) => setState(() { _inventoryAccountId = a.id; _inventoryAccountCode = a.accountCode; _inventoryAccountName = _acctName(a); }),
          () => setState(() { _inventoryAccountId = null; _inventoryAccountCode = null; _inventoryAccountName = null; })),
      ('cogs', e ? 'Cost of sales' : 'ต้นทุนขาย', false, _cogsAccountId, _cogsAccountCode, _cogsAccountName,
          (a) => setState(() { _cogsAccountId = a.id; _cogsAccountCode = a.accountCode; _cogsAccountName = _acctName(a); }),
          () => setState(() { _cogsAccountId = null; _cogsAccountCode = null; _cogsAccountName = null; })),
      ('revenue', e ? 'Revenue' : 'รายได้', false, _revenueAccountId, _revenueAccountCode, _revenueAccountName,
          (a) => setState(() { _revenueAccountId = a.id; _revenueAccountCode = a.accountCode; _revenueAccountName = _acctName(a); }),
          () => setState(() { _revenueAccountId = null; _revenueAccountCode = null; _revenueAccountName = null; })),
      ('purchases', e ? 'Purchases (Periodic)' : 'ซื้อสินค้า (Periodic)', false, _purchasesAccountId, _purchasesAccountCode, _purchasesAccountName,
          (a) => setState(() { _purchasesAccountId = a.id; _purchasesAccountCode = a.accountCode; _purchasesAccountName = _acctName(a); }),
          () => setState(() { _purchasesAccountId = null; _purchasesAccountCode = null; _purchasesAccountName = null; })),
      ('expense', e ? 'Expense' : 'ค่าใช้จ่าย', true, _expenseAccountId, _expenseAccountCode, _expenseAccountName,
          (a) => setState(() { _expenseAccountId = a.id; _expenseAccountCode = a.accountCode; _expenseAccountName = _acctName(a); }),
          () => setState(() { _expenseAccountId = null; _expenseAccountCode = null; _expenseAccountName = null; })),
      ('wip', e ? 'Work in process (WIP)' : 'งานระหว่างผลิต (WIP)', true, _wipAccountId, _wipAccountCode, _wipAccountName,
          (a) => setState(() { _wipAccountId = a.id; _wipAccountCode = a.accountCode; _wipAccountName = _acctName(a); }),
          () => setState(() { _wipAccountId = null; _wipAccountCode = null; _wipAccountName = null; })),
      ('variance', e ? 'Cost variance' : 'ผลต่างต้นทุน', true, _varianceAccountId, _varianceAccountCode, _varianceAccountName,
          (a) => setState(() { _varianceAccountId = a.id; _varianceAccountCode = a.accountCode; _varianceAccountName = _acctName(a); }),
          () => setState(() { _varianceAccountId = null; _varianceAccountCode = null; _varianceAccountName = null; })),
    ];
    final cells = <List<Widget>>[];
    for (final r in rows) {
      final set = r.$4 != null;
      final field = ed
          ? SizedBox(
              height: 32,
              child: InkWell(
                onTap: () => _pickAccount(e ? 'Select ${r.$2} account' : 'เลือกบัญชี${r.$2}', r.$7),
                child: InputDecorator(
                  decoration: InputDecoration(
                    isDense: true,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    suffixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 20, maxHeight: 24),
                    suffixIcon: set
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 15, color: Colors.red),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 24, minHeight: 20),
                            tooltip: e ? 'Clear' : 'ล้าง',
                            onPressed: r.$8,
                          )
                        : const Icon(Icons.search, size: 16, color: Colors.teal),
                  ),
                  child: Text(set ? '${r.$5}  ${r.$6 ?? ''}' : (e ? '— Not specified —' : '— ไม่ระบุ —'),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: set ? null : ImKit.ink3)),
                ),
              ),
            )
          : kCell(set ? '${r.$5}  ${r.$6 ?? ''}' : '', bold: set);
      final row = <Widget>[
        Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: kCell(r.$2)), if (r.$3) ...[const SizedBox(width: 6), unused]]),
        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: field),
        kCell(set ? (e ? '(set here)' : '(กำหนดที่หมวดนี้)') : fallback(r.$1), color: ImKit.ink2),
      ];
      // ซื้อสินค้าใช้เฉพาะ Periodic — Perpetual ลง Dr บัญชีสต็อกแทน
      cells.add(r.$1 == 'purchases' && _accountingMode == 'PERPETUAL'
          ? [for (final w in row) Opacity(opacity: 0.45, child: IgnorePointer(child: w))]
          : row);
    }
    return kCard(
      title: e ? 'Default GL Accounts' : 'บัญชี GL ตั้งต้น',
      count: e ? 'Used by items in this category that set none themselves' : 'ใช้กับสินค้าในหมวดที่ไม่ได้กำหนดเอง',
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        kTable([
          KCol(e ? 'Account' : 'บัญชี', 4),
          KCol(e ? 'Set on this category' : 'กำหนดที่หมวดนี้', 5),
          KCol(e ? 'If blank, uses' : 'ถ้าเว้นว่าง ใช้', 4),
        ], cells, minWidth: 760),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: kNote(e
              ? 'Posting order: warehouse (inventory/purchases) → item → category → document type → company default.'
              : 'ลำดับตอนลงบัญชี: คลัง (สต็อก/ซื้อสินค้า) → สินค้า → หมวดสินค้า → ประเภทเอกสาร → ค่าเริ่มต้นบริษัท'),
        ),
      ]),
    );
  }

  Widget _itemsCard() {
    final e = _isEnglish;
    final s = _summary;
    final items = s?.items ?? const <ImCategoryItemRow>[];
    final self = widget.selected?.categoryCode;
    return kCard(
      title: e ? 'Items in Category' : 'สินค้าในหมวด',
      count: s == null
          ? null
          : e
              ? 'Read-only · ${s.itemCount} item(s) incl. sub-categories${items.length < s.itemCount ? ' (first ${items.length})' : ''}'
              : 'อ่านอย่างเดียว · ${s.itemCount} สินค้า รวมหมวดย่อย${items.length < s.itemCount ? ' (แสดง ${items.length} แรก)' : ''}',
      trailing: kGhost(e ? 'Open Items' : 'ไปหน้าข้อมูลสินค้า', Icons.open_in_new,
          () => ImKit.openMenu(context, 'ImItemScreen', 'ข้อมูลสินค้า', 'Items', e)),
      padding: EdgeInsets.zero,
      child: s == null
          ? Padding(
              padding: const EdgeInsets.all(14),
              child: Center(child: _loadingSummary ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const SizedBox.shrink()),
            )
          : kTable([
              KCol(e ? 'Item' : 'สินค้า', 6),
              KCol(e ? 'Category' : 'หมวด', 2),
              KCol(e ? 'Type' : 'ประเภท', 3),
              KCol(e ? 'Base unit' : 'หน่วยหลัก', 2),
              KCol(e ? 'On hand' : 'คงเหลือ', 2, num: true),
              KCol(e ? 'Status' : 'สถานะ', 2),
            ], [
              for (final it in items)
                [
                  kCell('${it.itemCode}  ${it.displayName(e)}'),
                  kCell(it.categoryCode == self ? '' : (it.categoryCode ?? ''), color: ImKit.ink2),
                  kCell(imItemTypeLabel(it.itemType, e)),
                  kCell(it.uomName(e)),
                  kCell(it.itemType == 'STOCK' ? _qtyFmt.format(it.onHand) : '', mono: true),
                  ImKit.activeChip(it.isActive, e),
                ],
            ], minWidth: 760, empty: e ? 'No item in this category yet' : 'ยังไม่มีสินค้าในหมวดนี้'),
    );
  }

  List<ImKpi> _kpis() {
    final e = _isEnglish;
    final s = _summary;
    if (s == null) return const [];
    return [
      ImKpi(e ? 'Items in category' : 'สินค้าในหมวด', '${s.itemCount}',
          e ? 'active ${s.activeCount} · inactive ${s.inactiveCount}' : 'ใช้งาน ${s.activeCount} · หยุดใช้ ${s.inactiveCount}'),
      ImKpi(e ? 'Stock value' : 'มูลค่าคงเหลือ', _amtFmt.format(s.stockValue), e ? 'All warehouses, incl. sub-categories' : 'ทุกคลัง รวมหมวดย่อย'),
      ImKpi(e ? 'Sub-categories' : 'หมวดย่อย', '${s.childCount}', s.childCount == 0 ? (e ? 'Leaf category' : 'หมวดปลายทาง') : (e ? 'direct children' : 'ระดับถัดไป')),
      ImKpi(e ? 'Assigned storage locations' : 'ตำแหน่งที่กำหนดให้เก็บ', '${s.locations.length}',
          s.locations.isEmpty ? (e ? 'None' : 'ยังไม่มี') : s.locations.join(', ')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    _isEnglish = context.watch<LanguageProvider>().isEnglish;
    final e = _isEnglish;
    if (widget.isPlaceholder) {
      return kPlaceholder(Icons.category_outlined, e ? 'Select a category on the left to view its data' : 'เลือกหมวดหมู่ทางซ้ายเพื่อดูข้อมูล');
    }
    final saved = !_isNew && widget.selected != null;
    final c = widget.selected;
    final title = saved
        ? c!.displayName(e)
        : widget.mode == Mode.addChild
            ? (e ? 'Add sub-category under ${c?.categoryCode ?? ''}' : 'เพิ่มหมวดย่อยของ ${c?.categoryCode ?? ''} ${c?.displayName(e) ?? ''}')
            : (e ? 'Add Root Category' : 'เพิ่มหมวดหมู่หลัก');
    return kPage(
      header: kHeaderBar(
        code: saved ? c!.categoryCode : null,
        title: title,
        badges: [
          if (widget.mode == Mode.edit) kEditingBadge(),
          if (saved)
            c!.categoryType == 'HEADER'
                ? ImKit.chip(e ? 'Header' : 'หัวข้อ', ImKit.blueSoft, ImKit.blue)
                : ImKit.chip(e ? 'Category' : 'หมวด', ImKit.okSoft, ImKit.ok),
          if (saved && c!.isAutoNumber) ImKit.chip(e ? 'Auto numbering' : 'รหัสอัตโนมัติ', ImKit.goldSoft, ImKit.amber),
          if (saved) ImKit.activeChip(_isActive, e),
          if (saved && widget.parentPath.isNotEmpty)
            Text(widget.parentPath, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
        acts: kStdActs(
          saving: _isSaving,
          onEdit: widget.onEdit,
          onDelete: widget.onDelete,
          onClose: widget.onCancel,
          onCancel: widget.onCancel,
          onSave: _save,
          extra: [
            if (widget.onAddChild != null) DocBarAction(e ? '+ Sub-category' : '+ หมวดย่อย', widget.onAddChild, fg: ScreenTheme.of(context).ink),
          ],
        ),
        busy: _isSaving,
      ),
      top: saved ? kKpis(_kpis(), loading: _loadingSummary) : null,
      sections: [
        (0, e ? 'Main' : 'ข้อมูลหลัก', _mainCard()),
        (1, e ? 'GL accounts' : 'บัญชี GL', _glCard()),
        if (saved) (2, e ? 'Items in category' : 'สินค้าในหมวด', _itemsCard()),
      ],
    );
  }
}
