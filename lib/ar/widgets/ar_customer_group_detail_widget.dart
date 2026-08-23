// widgets/ar_customer_group_detail_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../gl/models/gl_account.dart';
import '../../gl/services/gl_account_service.dart';
import '../models/ar_customer.dart';
import '../models/ar_customer_group.dart';
import 'ar_customer_detail_widget.dart'
    show showBillingConditionDialog, showPaymentConditionDialog;

// ---------------------------------------------------------------------------
// Collapsible section (local copy)
// ---------------------------------------------------------------------------
class _Section extends StatefulWidget {
  final String title;
  final bool initiallyExpanded;
  final List<Widget> children;
  final Widget? trailing;

  const _Section({
    required this.title,
    this.initiallyExpanded = true,
    required this.children,
    this.trailing,
  });

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
            child: Row(
              children: [
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.blueGrey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(widget.title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey.shade800)),
                ),
                if (widget.trailing != null) widget.trailing!,
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.children),
          ),
        const Divider(height: 1),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------
class ArCustomerGroupDetailWidget extends StatefulWidget {
  final Mode mode;
  final ArCustomerGroup? selected;
  final Function(ArCustomerGroup) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;
  // เพิ่มขึ้นทุกครั้งที่ผู้ใช้กดปุ่มเพิ่ม/แก้ไข/ดู/ยกเลิกจากหน้าจอหลัก — ใช้บังคับให้ didUpdateWidget เคลียร์ฟอร์ม
  // เสมอ แม้ mode/selected จะ "เหมือนเดิม" กับครั้งก่อน (เช่น กดเพิ่มกลุ่มลูกค้าซ้ำหลังพิมพ์ข้อมูลค้างไว้)
  final int requestSeq;

  const ArCustomerGroupDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
    this.requestSeq = 0,
  });

  @override
  State<ArCustomerGroupDetailWidget> createState() =>
      ArCustomerGroupDetailWidgetState();
}

class ArCustomerGroupDetailWidgetState
    extends State<ArCustomerGroupDetailWidget> {
  final _formKey = GlobalKey<FormState>();
  bool _isEnglish = false;

  // ── ข้อมูลทั่วไป ──────────────────────────────────────────────────────────
  late TextEditingController _codeController;
  late TextEditingController _nameThaController;
  late TextEditingController _nameEngController;
  late TextEditingController _descriptionController;
  late TextEditingController _creditTermMonthsController;
  late TextEditingController _creditTermDaysController;
  late TextEditingController _creditLimitController;
  late TextEditingController _discountPercentController;
  late bool _isActive;

  // ── รหัสอัตโนมัติ ─────────────────────────────────────────────────────────
  bool _isAutoNumber = false;
  late TextEditingController _runningPrefixCtrl;
  late TextEditingController _runningSeparatorCtrl;
  String _runningSuffixDate = '';
  late TextEditingController _runningLengthCtrl;
  late TextEditingController _runningNextNumberCtrl;

  // ── เงื่อนไขการวางบิล / ชำระเงิน ─────────────────────────────────────────
  bool _requiresBilling = false;
  List<ArCustomerBillingCondition> _billingConditions = [];
  List<ArCustomerPaymentCondition> _paymentConditions = [];

  // ── บัญชี GL ──────────────────────────────────────────────────────────────
  int? _glAccountId;
  String? _glAccountCode;
  String? _glAccountNameThai;

  bool _isSaving = false;

  List<DropdownMenuItem<String>> _suffixOptions(bool isEnglish) => [
        DropdownMenuItem(
            value: '', child: Text(isEnglish ? '— No date —' : '— ไม่มีวันที่ —')),
        DropdownMenuItem(
            value: 'YY', child: Text(isEnglish ? 'YY (e.g. 25)' : 'YY (เช่น 25)')),
        DropdownMenuItem(
            value: 'YYYY',
            child: Text(isEnglish ? 'YYYY (e.g. 2025)' : 'YYYY (เช่น 2025)')),
        DropdownMenuItem(
            value: 'YYMM',
            child: Text(isEnglish ? 'YYMM (e.g. 2503)' : 'YYMM (เช่น 2503)')),
        DropdownMenuItem(
            value: 'YYYYMM',
            child: Text(
                isEnglish ? 'YYYYMM (e.g. 202503)' : 'YYYYMM (เช่น 202503)')),
        DropdownMenuItem(
            value: 'YYMMDD',
            child: Text(
                isEnglish ? 'YYMMDD (e.g. 250315)' : 'YYMMDD (เช่น 250315)')),
      ];

  String get _sampleCode {
    String code = _runningPrefixCtrl.text;
    if (_runningSuffixDate.isNotEmpty) {
      final now = DateTime.now();
      final year = now.year.toString();
      final month = now.month.toString().padLeft(2, '0');
      final day = now.day.toString().padLeft(2, '0');
      switch (_runningSuffixDate) {
        case 'YY':     code += year.substring(2); break;
        case 'YYYY':   code += year; break;
        case 'YYMM':   code += year.substring(2) + month; break;
        case 'YYYYMM': code += year + month; break;
        case 'YYMMDD': code += year.substring(2) + month + day; break;
      }
    }
    code += _runningSeparatorCtrl.text;
    final len = int.tryParse(_runningLengthCtrl.text) ?? 4;
    final next = int.tryParse(_runningNextNumberCtrl.text) ?? 1;
    code += next.toString().padLeft(len, '0');
    return code;
  }

  @override
  void initState() {
    super.initState();
    _initFromSelected(widget.selected);
  }

  void _initFromSelected(ArCustomerGroup? data) {
    _codeController = TextEditingController(text: data?.groupCode ?? '');
    _nameThaController = TextEditingController(text: data?.groupNameThai ?? '');
    _nameEngController = TextEditingController(text: data?.groupNameEng ?? '');
    _descriptionController = TextEditingController(text: data?.description ?? '');
    _creditTermMonthsController =
        TextEditingController(text: (data?.creditTermMonths ?? 0).toString());
    _creditTermDaysController =
        TextEditingController(text: (data?.creditTermDays ?? 30).toString());
    _creditLimitController =
        TextEditingController(text: data?.creditLimit.toStringAsFixed(2) ?? '0.00');
    _discountPercentController =
        TextEditingController(text: data?.discountPercent.toStringAsFixed(2) ?? '0.00');
    _isActive = data?.isActive ?? true;
    _isAutoNumber = data?.isAutoNumber ?? false;
    _runningPrefixCtrl = TextEditingController(text: data?.runningPrefix ?? 'CUST');
    _runningSeparatorCtrl = TextEditingController(text: data?.runningSeparator ?? '-');
    _runningSuffixDate = data?.runningSuffixDate ?? '';
    _runningLengthCtrl = TextEditingController(text: (data?.runningLength ?? 4).toString());
    _runningNextNumberCtrl = TextEditingController(text: (data?.runningNextNumber ?? 1).toString());
    _requiresBilling = data?.requiresBilling ?? false;
    _billingConditions = List.from(data?.billingConditions ?? []);
    _paymentConditions = List.from(data?.paymentConditions ?? []);
    _glAccountId = data?.glAccountId;
    _glAccountCode = data?.glAccountCode;
    _glAccountNameThai = data?.glAccountNameThai;
  }

  void _applyFromSelected(ArCustomerGroup? d) {
    _codeController.text = d?.groupCode ?? '';
    _nameThaController.text = d?.groupNameThai ?? '';
    _nameEngController.text = d?.groupNameEng ?? '';
    _descriptionController.text = d?.description ?? '';
    _creditTermMonthsController.text = (d?.creditTermMonths ?? 0).toString();
    _creditTermDaysController.text = (d?.creditTermDays ?? 30).toString();
    _creditLimitController.text = d?.creditLimit.toStringAsFixed(2) ?? '0.00';
    _discountPercentController.text = d?.discountPercent.toStringAsFixed(2) ?? '0.00';
    _isActive = d?.isActive ?? true;
    _isAutoNumber = d?.isAutoNumber ?? false;
    _runningPrefixCtrl.text = d?.runningPrefix ?? 'CUST';
    _runningSeparatorCtrl.text = d?.runningSeparator ?? '-';
    _runningSuffixDate = d?.runningSuffixDate ?? '';
    _runningLengthCtrl.text = (d?.runningLength ?? 4).toString();
    _runningNextNumberCtrl.text = (d?.runningNextNumber ?? 1).toString();
    _requiresBilling = d?.requiresBilling ?? false;
    _billingConditions = List.from(d?.billingConditions ?? []);
    _paymentConditions = List.from(d?.paymentConditions ?? []);
    _glAccountId = d?.glAccountId;
    _glAccountCode = d?.glAccountCode;
    _glAccountNameThai = d?.glAccountNameThai;
  }

  void _applyAddDefaults() {
    _codeController.clear();
    _nameThaController.clear();
    _nameEngController.clear();
    _descriptionController.clear();
    _creditTermMonthsController.text = '0';
    _creditTermDaysController.text = '30';
    _creditLimitController.text = '0.00';
    _discountPercentController.text = '0.00';
    _isActive = true;
    _isAutoNumber = false;
    _runningPrefixCtrl.text = 'CUST';
    _runningSeparatorCtrl.text = '-';
    _runningSuffixDate = '';
    _runningLengthCtrl.text = '4';
    _runningNextNumberCtrl.text = '1';
    _requiresBilling = false;
    _billingConditions = [];
    _paymentConditions = [];
    _glAccountId = null;
    _glAccountCode = null;
    _glAccountNameThai = null;
  }

  @override
  void didUpdateWidget(covariant ArCustomerGroupDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      _applyFromSelected(widget.selected);
    } else if (widget.mode == Mode.add && oldWidget.mode != Mode.add) {
      _applyAddDefaults();
    } else if (widget.mode != oldWidget.mode ||
        widget.requestSeq != oldWidget.requestSeq) {
      // ครอบคลุมกรณีทั่วไปที่ mode เปลี่ยน (ไม่ใช่แค่การเข้าสู่ Mode.add) และกรณี requestSeq
      // เปลี่ยนแต่ mode/selected เหมือนเดิมกับครั้งก่อน (เช่น กดเพิ่มซ้ำหลังพิมพ์ข้อมูลค้างไว้)
      if (widget.mode == Mode.add) {
        _applyAddDefaults();
      } else {
        _applyFromSelected(widget.selected);
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameThaController.dispose();
    _nameEngController.dispose();
    _descriptionController.dispose();
    _creditTermMonthsController.dispose();
    _creditTermDaysController.dispose();
    _creditLimitController.dispose();
    _discountPercentController.dispose();
    _runningPrefixCtrl.dispose();
    _runningSeparatorCtrl.dispose();
    _runningLengthCtrl.dispose();
    _runningNextNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickGlAccount() async {
    final isEnglish = _isEnglish;
    final svc = Provider.of<AccountService>(context, listen: false);
    List<Account> accounts = [];
    try {
      final all = await svc.fetchRows();
      accounts = all.where((a) => a.isControlAccount && a.isActive).toList()
        ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
    } catch (_) {}
    if (!mounted) return;

    final searchCtrl = TextEditingController();
    List<Account> filtered = List.from(accounts);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        void doFilter(String q) {
          setDlg(() {
            if (q.isEmpty) {
              filtered = List.from(accounts);
            } else {
              final lq = q.toLowerCase();
              filtered = accounts
                  .where((a) =>
                      a.accountCode.toLowerCase().contains(lq) ||
                      a.accountNameThai.toLowerCase().contains(lq) ||
                      a.accountNameEng.toLowerCase().contains(lq))
                  .toList()
                ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
            }
          });
        }

        return AlertDialog(
          title: Text(isEnglish
              ? 'Select Control Account'
              : 'เลือกบัญชีควบคุม (Control Account)'),
          content: SizedBox(
            width: 520,
            height: 420,
            child: Column(children: [
              TextField(
                controller: searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: isEnglish
                      ? 'Search account code / name'
                      : 'ค้นหา รหัส / ชื่อบัญชี',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onChanged: doFilter,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: accounts.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? Center(
                            child: Text(isEnglish
                                ? 'No accounts found'
                                : 'ไม่พบบัญชี'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final a = filtered[i];
                              final isSelected = _glAccountId == a.id;
                              return ListTile(
                                dense: true,
                                selected: isSelected,
                                selectedTileColor: Colors.indigo.shade50,
                                leading: isSelected
                                    ? const Icon(Icons.check_circle,
                                        color: Colors.indigo, size: 18)
                                    : const SizedBox(width: 18),
                                title: Row(children: [
                                  SizedBox(
                                    width: 90,
                                    child: Text(a.accountCode,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.indigo)),
                                  ),
                                  Expanded(
                                      child: Text(isEnglish &&
                                              a.accountNameEng.isNotEmpty
                                          ? a.accountNameEng
                                          : a.accountNameThai)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      accountTypeLabel(
                                          a.accountType, isEnglish),
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey),
                                    ),
                                  ),
                                ]),
                                onTap: () {
                                  setState(() {
                                    _glAccountId = a.id;
                                    _glAccountCode = a.accountCode;
                                    _glAccountNameThai = a.accountNameThai;
                                  });
                                  Navigator.of(ctx).pop();
                                },
                              );
                            },
                          ),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(isEnglish ? 'Close' : 'ปิด')),
          ],
        );
      }),
    );
    searchCtrl.dispose();
  }

  Future<void> _submitForm() async {
    final isEnglish = _isEnglish;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final row = ArCustomerGroup(
        id: widget.selected?.id ?? 0,
        groupCode: _codeController.text.trim().toUpperCase(),
        groupNameThai: _nameThaController.text.trim(),
        groupNameEng: _nameEngController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        creditTermMonths: int.tryParse(_creditTermMonthsController.text) ?? 0,
        creditTermDays: int.tryParse(_creditTermDaysController.text) ?? 30,
        creditLimit: double.tryParse(_creditLimitController.text) ?? 0,
        discountPercent: double.tryParse(_discountPercentController.text) ?? 0,
        glAccountId: _glAccountId,
        glAccountCode: _glAccountCode,
        glAccountNameThai: _glAccountNameThai,
        isAutoNumber: _isAutoNumber,
        runningPrefix: _runningPrefixCtrl.text.trim(),
        runningSeparator: _runningSeparatorCtrl.text,
        runningSuffixDate: _runningSuffixDate,
        runningLength: int.tryParse(_runningLengthCtrl.text) ?? 4,
        runningNextNumber: int.tryParse(_runningNextNumberCtrl.text) ?? 1,
        isActive: _isActive,
        requiresBilling: _requiresBilling,
        billingConditions: List.from(_billingConditions),
        paymentConditions: List.from(_paymentConditions),
      );
      await widget.onSubmit(row);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  isEnglish ? 'An error occurred: $e' : 'เกิดข้อผิดพลาด: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Section builders ────────────────────────────────────────────────────────

  Widget _buildGeneralSection(bool readOnly, bool isEnglish) {
    return _Section(
      title: isEnglish ? 'General Information' : 'ข้อมูลทั่วไป',
      initiallyExpanded: true,
      children: [
        // รหัส
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextFormField(
            readOnly: widget.mode != Mode.add,
            controller: _codeController,
            style: const TextStyle(fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText:
                  isEnglish ? 'Customer Group Code *' : 'รหัสกลุ่มลูกค้า *',
              border: const OutlineInputBorder(),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? (isEnglish
                    ? 'Please enter the customer group code'
                    : 'โปรดระบุรหัสกลุ่มลูกค้า')
                : null,
          ),
        ),
        // ชื่อ
        Row(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10, right: 5),
              child: TextFormField(
                readOnly: readOnly,
                controller: _nameThaController,
                decoration: InputDecoration(
                  labelText: isEnglish
                      ? 'Customer Group Name (TH) *'
                      : 'ชื่อกลุ่มลูกค้า (ไทย) *',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? (isEnglish
                        ? 'Please enter the Thai name'
                        : 'โปรดระบุชื่อภาษาไทย')
                    : null,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 5),
              child: TextFormField(
                readOnly: readOnly,
                controller: _nameEngController,
                decoration: InputDecoration(
                  labelText: isEnglish
                      ? 'Customer Group Name (EN)'
                      : 'ชื่อกลุ่มลูกค้า (อังกฤษ)',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ),
        ]),
        // คำอธิบาย
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextFormField(
            readOnly: readOnly,
            controller: _descriptionController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: isEnglish ? 'Description' : 'คำอธิบาย',
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ),
        // เงื่อนไขเครดิต
        Row(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10, right: 5),
              child: TextFormField(
                readOnly: readOnly,
                controller: _creditTermMonthsController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Credit (Months)' : 'เครดิต (เดือน)',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || int.tryParse(v) == null || int.parse(v) < 0)
                        ? (isEnglish ? 'Required' : 'โปรดระบุ')
                        : null,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10, right: 5, left: 5),
              child: TextFormField(
                readOnly: readOnly,
                controller: _creditTermDaysController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Credit (Days)' : 'เครดิต (วัน)',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || int.tryParse(v) == null || int.parse(v) < 0)
                        ? (isEnglish ? 'Required' : 'โปรดระบุ')
                        : null,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10, right: 5, left: 5),
              child: TextFormField(
                readOnly: readOnly,
                controller: _creditLimitController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Credit Limit' : 'วงเงินเครดิต',
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v == null || double.tryParse(v) == null)
                    ? (isEnglish ? 'Required' : 'โปรดระบุ')
                    : null,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 5),
              child: TextFormField(
                readOnly: readOnly,
                controller: _discountPercentController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Discount (%)' : 'ส่วนลด (%)',
                  border: const OutlineInputBorder(),
                  suffixText: '%',
                ),
                validator: (v) {
                  final d = double.tryParse(v ?? '');
                  if (d == null) return isEnglish ? 'Required' : 'โปรดระบุ';
                  if (d < 0 || d > 100) return '0-100';
                  return null;
                },
              ),
            ),
          ),
        ]),
        // รหัสอัตโนมัติ
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SwitchListTile(
              title: Text(
                  isEnglish
                      ? 'Auto-generate customer code'
                      : 'ออกรหัสลูกหนี้อัตโนมัติ',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                _isAutoNumber
                    ? (isEnglish
                        ? 'Enabled — code will be generated automatically when a customer is added to this group'
                        : 'เปิดใช้งาน — รหัสจะถูกออกอัตโนมัติเมื่อเพิ่มลูกหนี้ในกลุ่มนี้')
                    : (isEnglish
                        ? 'Disabled — user must enter the customer code manually'
                        : 'ปิดใช้งาน — ผู้ใช้ต้องระบุรหัสลูกหนี้เอง'),
                style: TextStyle(
                    color: _isAutoNumber ? Colors.teal : Colors.grey,
                    fontSize: 12),
              ),
              value: _isAutoNumber,
              onChanged:
                  readOnly ? null : (v) => setState(() => _isAutoNumber = v),
            ),
            if (_isAutoNumber) ...[
              Divider(height: 1, color: Colors.grey.shade200),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            readOnly: readOnly,
                            controller: _runningPrefixCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Prefix',
                              border: OutlineInputBorder(),
                              hintText: 'CUST',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            readOnly: readOnly,
                            controller: _runningSeparatorCtrl,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              labelText: 'Separator',
                              border: OutlineInputBorder(),
                              hintText: '-',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _runningSuffixDate,
                            decoration: InputDecoration(
                              labelText: isEnglish
                                  ? 'Date in code'
                                  : 'วันที่ในรหัส',
                              border: const OutlineInputBorder(),
                            ),
                            items: _suffixOptions(isEnglish),
                            onChanged: readOnly
                                ? null
                                : (v) => setState(
                                    () => _runningSuffixDate = v ?? ''),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            readOnly: readOnly,
                            controller: _runningLengthCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            textAlign: TextAlign.right,
                            decoration: InputDecoration(
                              labelText: isEnglish
                                  ? 'Digit length'
                                  : 'ความยาวตัวเลข',
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                            validator: (v) {
                              if (!_isAutoNumber) return null;
                              final n = int.tryParse(v ?? '');
                              return (n == null || n < 1 || n > 10)
                                  ? '1-10'
                                  : null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            readOnly: readOnly,
                            controller: _runningNextNumberCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            textAlign: TextAlign.right,
                            decoration: InputDecoration(
                              labelText:
                                  isEnglish ? 'Next number' : 'เลขที่ถัดไป',
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                            validator: (v) =>
                                !_isAutoNumber || int.tryParse(v ?? '') != null
                                    ? null
                                    : (isEnglish
                                        ? 'Must be a number'
                                        : 'ต้องเป็นตัวเลข'),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Row(children: [
                          const Icon(Icons.auto_awesome,
                              color: Colors.teal, size: 16),
                          const SizedBox(width: 8),
                          Text(isEnglish ? 'Sample code: ' : 'ตัวอย่างรหัส: ',
                              style: const TextStyle(fontSize: 13, color: Colors.teal)),
                          Text(_sampleCode,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                  letterSpacing: 1)),
                        ]),
                      ),
                    ]),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 10),
        // สถานะ
        Row(children: [
          Expanded(
              child: Text(isEnglish
                  ? 'Status: ${_isActive ? 'Active' : 'Inactive'}'
                  : 'สถานะ: ${_isActive ? 'ใช้งาน' : 'หยุดใช้'}')),
          Switch(
            value: _isActive,
            onChanged:
                readOnly ? null : (v) => setState(() => _isActive = v),
          ),
        ]),
      ],
    );
  }

  Widget _buildBillingConditionsSection(bool readOnly, bool isEnglish) {
    return _Section(
      title: isEnglish
          ? 'Billing Conditions (${_billingConditions.length})'
          : 'เงื่อนไขการวางบิล (${_billingConditions.length})',
      initiallyExpanded: false,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text(isEnglish ? 'Requires billing' : 'ต้องวางบิล',
              style: TextStyle(
                  fontSize: 12,
                  color: _requiresBilling
                      ? Colors.indigo.shade700
                      : Colors.grey)),
          Switch(
            value: _requiresBilling,
            onChanged:
                readOnly ? null : (v) => setState(() => _requiresBilling = v),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ]),
        if (!readOnly)
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 20),
            tooltip: isEnglish ? 'Add billing condition' : 'เพิ่มเงื่อนไขวางบิล',
            onPressed: () async {
              final result =
                  await showBillingConditionDialog(context, null, false);
              if (result != null) {
                setState(() => _billingConditions.add(result.copyWith(
                    sortOrder: _billingConditions.length + 1)));
              }
            },
          ),
      ]),
      children: [
        if (!_requiresBilling)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
                isEnglish
                    ? 'No billing required: due date is calculated from the delivery date'
                    : 'ไม่ต้องวางบิล: วันครบกำหนดชำระนับจากวันส่งของ',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
        if (_billingConditions.isEmpty)
          Text(
              isEnglish
                  ? 'No billing conditions yet'
                  : 'ยังไม่มีเงื่อนไขการวางบิล',
              style: const TextStyle(color: Colors.grey)),
        ..._billingConditions.asMap().entries.map((entry) {
          final i = entry.key;
          final b = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.indigo.shade100,
                  child: Text('${i + 1}',
                      style: const TextStyle(fontSize: 11, color: Colors.indigo)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_billingConditionSummary(b, isEnglish),
                        style: const TextStyle(fontSize: 13)),
                  ),
                ),
                IconButton(
                  icon: Icon(readOnly ? Icons.visibility : Icons.edit,
                      size: 18,
                      color: readOnly ? Colors.green : Colors.blue),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () async {
                    final result =
                        await showBillingConditionDialog(context, b, readOnly);
                    if (result != null) {
                      setState(() => _billingConditions[i] = result);
                    }
                  },
                ),
                if (!readOnly)
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => setState(() {
                      _billingConditions.removeAt(i);
                      for (var j = 0; j < _billingConditions.length; j++) {
                        _billingConditions[j] =
                            _billingConditions[j].copyWith(sortOrder: j + 1);
                      }
                    }),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _billingConditionSummary(
      ArCustomerBillingCondition b, bool isEnglish) {
    const dayNames = ['อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์'];
    const dayNamesEn = [
      'Sun',
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat'
    ];
    const weekNames = {1: 'แรก', 2: 'ที่2', 3: 'ที่3', 4: 'ที่4', -1: 'สุดท้าย'};
    const weekNamesEn = {1: '1st', 2: '2nd', 3: '3rd', 4: '4th', -1: 'Last'};
    final parts = <String>[];
    if (b.billWithDelivery) {
      parts.add(isEnglish ? 'Bill with delivery' : 'วางบิลพร้อมส่งของ');
    }
    if (b.billingDayOfMonth.isNotEmpty) {
      parts.add(b.billingDayOfMonth
          .map((d) => isEnglish
              ? (d == 31 ? 'End of month' : 'Day $d')
              : (d == 31 ? 'สิ้นเดือน' : 'วันที่ $d'))
          .join(', '));
    }
    if (b.billingDayOfWeek.isNotEmpty) {
      parts.add(isEnglish
          ? b.billingDayOfWeek.map((d) => dayNamesEn[d]).join('-')
          : 'วัน${b.billingDayOfWeek.map((d) => dayNames[d]).join('-')}');
    }
    if (b.billingWeekOfMonth.isNotEmpty) {
      parts.add(isEnglish
          ? 'Week ${b.billingWeekOfMonth.map((w) => weekNamesEn[w] ?? '$w').join('/')}'
          : 'สัปดาห์${b.billingWeekOfMonth.map((w) => weekNames[w] ?? '$w').join('/')}');
    }
    if (b.billingTimeFrom != null || b.billingTimeTo != null) {
      parts.add('${b.billingTimeFrom ?? ''}–${b.billingTimeTo ?? ''}');
    }
    if (b.dueFromBillingDate) {
      parts.add(isEnglish ? 'Due from billing date' : 'due นับจากวางบิล');
    }
    return parts.isEmpty
        ? (isEnglish ? '(No condition specified)' : '(ไม่ระบุเงื่อนไข)')
        : parts.join('  ·  ');
  }

  Widget _buildPaymentConditionsSection(bool readOnly, bool isEnglish) {
    return _Section(
      title: isEnglish
          ? 'Payment Conditions (${_paymentConditions.length})'
          : 'เงื่อนไขการรับชำระเงิน (${_paymentConditions.length})',
      initiallyExpanded: false,
      trailing: readOnly
          ? null
          : IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              tooltip: isEnglish ? 'Add payment condition' : 'เพิ่มเงื่อนไขรับชำระ',
              onPressed: () async {
                final result =
                    await showPaymentConditionDialog(context, null, false);
                if (result != null) {
                  setState(() => _paymentConditions.add(result.copyWith(
                      sortOrder: _paymentConditions.length + 1)));
                }
              },
            ),
      children: [
        if (_paymentConditions.isEmpty)
          Text(
              isEnglish
                  ? 'No payment conditions yet — payment date will equal the due date'
                  : 'ยังไม่มีเงื่อนไขรับชำระ — วันชำระเงินจะเท่ากับวันครบกำหนด',
              style: const TextStyle(color: Colors.grey)),
        ..._paymentConditions.asMap().entries.map((entry) {
          final i = entry.key;
          final p = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.teal.shade100,
                  child: Text('${i + 1}',
                      style: const TextStyle(fontSize: 11, color: Colors.teal)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(_paymentConditionSummary(p, isEnglish),
                        style: const TextStyle(fontSize: 13)),
                  ),
                ),
                IconButton(
                  icon: Icon(readOnly ? Icons.visibility : Icons.edit,
                      size: 18,
                      color: readOnly ? Colors.green : Colors.blue),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () async {
                    final result =
                        await showPaymentConditionDialog(context, p, readOnly);
                    if (result != null) {
                      setState(() => _paymentConditions[i] = result);
                    }
                  },
                ),
                if (!readOnly)
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => setState(() {
                      _paymentConditions.removeAt(i);
                      for (var j = 0; j < _paymentConditions.length; j++) {
                        _paymentConditions[j] =
                            _paymentConditions[j].copyWith(sortOrder: j + 1);
                      }
                    }),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _paymentConditionSummary(
      ArCustomerPaymentCondition p, bool isEnglish) {
    const dayNames = ['อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์'];
    const dayNamesEn = [
      'Sun',
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat'
    ];
    const weekNames = {1: 'แรก', 2: 'ที่2', 3: 'ที่3', 4: 'ที่4', -1: 'สุดท้าย'};
    const weekNamesEn = {1: '1st', 2: '2nd', 3: '3rd', 4: '4th', -1: 'Last'};
    final parts = <String>[];
    if (p.paymentDayOfMonth.isNotEmpty) {
      parts.add(p.paymentDayOfMonth
          .map((d) => isEnglish
              ? (d == 31 ? 'End of month' : 'Day $d')
              : (d == 31 ? 'สิ้นเดือน' : 'วันที่ $d'))
          .join(', '));
    }
    if (p.paymentDayOfWeek.isNotEmpty) {
      parts.add(isEnglish
          ? p.paymentDayOfWeek.map((d) => dayNamesEn[d]).join('-')
          : 'วัน${p.paymentDayOfWeek.map((d) => dayNames[d]).join('-')}');
    }
    if (p.paymentWeekOfMonth.isNotEmpty) {
      parts.add(isEnglish
          ? 'Week ${p.paymentWeekOfMonth.map((w) => weekNamesEn[w] ?? '$w').join('/')}'
          : 'สัปดาห์${p.paymentWeekOfMonth.map((w) => weekNames[w] ?? '$w').join('/')}');
    }
    if (p.withinMonthsFromBilling > 0) {
      parts.add(isEnglish
          ? 'Within ${p.withinMonthsFromBilling} months from billing'
          : 'ภายใน ${p.withinMonthsFromBilling} เดือนจากวางบิล');
    }
    if (p.additionalDays != 0) {
      parts.add(isEnglish
          ? '+${p.additionalDays} days'
          : '+${p.additionalDays} วัน');
    }
    if (p.paymentTimeFrom != null || p.paymentTimeTo != null) {
      parts.add('${p.paymentTimeFrom ?? ''}–${p.paymentTimeTo ?? ''}');
    }
    return parts.isEmpty
        ? (isEnglish ? '(No condition specified)' : '(ไม่ระบุเงื่อนไข)')
        : parts.join('  ·  ');
  }

  Widget _buildGlAccountSection(bool readOnly, bool isEnglish) {
    return _Section(
      title: isEnglish ? 'Receivable GL Account' : 'รหัสบัญชีลูกหนี้ (GL)',
      initiallyExpanded: false,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: isEnglish
                  ? 'Receivable Account (Control Account)'
                  : 'บัญชีลูกหนี้ (Control Account)',
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Row(children: [
              Expanded(
                child: _glAccountCode != null
                    ? Row(children: [
                        const Icon(Icons.account_balance,
                            color: Colors.green, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$_glAccountCode — ${_glAccountNameThai ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ])
                    : Text(isEnglish ? '— Not specified —' : '— ไม่ระบุ —',
                        style: const TextStyle(color: Colors.grey)),
              ),
              if (!readOnly) ...[
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.blue),
                  tooltip: isEnglish ? 'Search account' : 'ค้นหาบัญชี',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _pickGlAccount,
                ),
                if (_glAccountId != null)
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red, size: 18),
                    tooltip: isEnglish ? 'Clear account' : 'ล้างบัญชี',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() {
                      _glAccountId = null;
                      _glAccountCode = null;
                      _glAccountNameThai = null;
                    }),
                  ),
              ],
            ]),
          ),
        ),
        if (_glAccountId == null)
          Text(
            isEnglish
                ? 'If not specified, the system will look up the receivable account from the Customer and Document Type, in that order'
                : 'หากไม่ระบุ ระบบจะค้นหาบัญชีลูกหนี้จาก ลูกหนี้การค้า และ ประเภทเอกสาร ตามลำดับ',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;

    if (widget.isPlaceholder) {
      return Center(
        child: Text(isEnglish
            ? 'Select a customer group to edit or delete, or press + to add a new one'
            : 'เลือกกลุ่มลูกค้าเพื่อแก้ไข หรือ ลบ หรือ กดปุ่ม + เพื่อเพิ่มใหม่'),
      );
    }

    final bool readOnly = widget.mode == Mode.view;
    final String title = readOnly
        ? (isEnglish ? 'View Customer Group' : 'ดูข้อมูลกลุ่มลูกค้า')
        : widget.mode == Mode.edit
            ? (isEnglish ? 'Edit Customer Group' : 'แก้ไขกลุ่มลูกค้า')
            : (isEnglish ? 'Add New Customer Group' : 'เพิ่มกลุ่มลูกค้าใหม่');

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            color: Colors.blueGrey[700],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              const Icon(Icons.group, color: Colors.white),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(color: Colors.white, fontSize: 24)),
            ]),
          ),
          // Sections
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGeneralSection(readOnly, isEnglish),
                  _buildBillingConditionsSection(readOnly, isEnglish),
                  _buildPaymentConditionsSection(readOnly, isEnglish),
                  _buildGlAccountSection(readOnly, isEnglish),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!readOnly)
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _submitForm,
                    icon: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save),
                    label: Text(_isSaving
                        ? (isEnglish ? 'Saving...' : 'กำลังบันทึก...')
                        : widget.mode == Mode.edit
                            ? (isEnglish ? 'Save' : 'บันทึก')
                            : (isEnglish ? 'Add' : 'เพิ่ม')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                  ),
                if (!readOnly) const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.cancel),
                  label: Text(isEnglish ? 'Cancel' : 'ยกเลิก'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
