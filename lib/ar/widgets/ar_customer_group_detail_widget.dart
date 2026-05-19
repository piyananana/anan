// widgets/ar_customer_group_detail_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../sa/models/anan_module.dart';
import '../../gl/models/account.dart';
import '../../gl/services/account_service.dart';
import '../models/ar_customer.dart';
import '../models/ar_customer_group.dart';
import 'ar_customer_detail_widget.dart'
    show showBillingConditionDialog, showPaymentConditionDialog, accountTypeOptions;

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

  const ArCustomerGroupDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
  });

  @override
  State<ArCustomerGroupDetailWidget> createState() =>
      ArCustomerGroupDetailWidgetState();
}

class ArCustomerGroupDetailWidgetState
    extends State<ArCustomerGroupDetailWidget> {
  final _formKey = GlobalKey<FormState>();

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

  static const List<DropdownMenuItem<String>> _suffixOptions = [
    DropdownMenuItem(value: '', child: Text('— ไม่มีวันที่ —')),
    DropdownMenuItem(value: 'YY', child: Text('YY (เช่น 25)')),
    DropdownMenuItem(value: 'YYYY', child: Text('YYYY (เช่น 2025)')),
    DropdownMenuItem(value: 'YYMM', child: Text('YYMM (เช่น 2503)')),
    DropdownMenuItem(value: 'YYYYMM', child: Text('YYYYMM (เช่น 202503)')),
    DropdownMenuItem(value: 'YYMMDD', child: Text('YYMMDD (เช่น 250315)')),
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

  @override
  void didUpdateWidget(covariant ArCustomerGroupDetailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      final d = widget.selected;
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
    } else if (widget.mode == Mode.add && oldWidget.mode != Mode.add) {
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
                      a.accountNameThai.toLowerCase().contains(lq))
                  .toList()
                ..sort((a, b) => a.accountCode.compareTo(b.accountCode));
            }
          });
        }

        return AlertDialog(
          title: const Text('เลือกบัญชีควบคุม (Control Account)'),
          content: SizedBox(
            width: 520,
            height: 420,
            child: Column(children: [
              TextField(
                controller: searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'ค้นหา รหัส / ชื่อบัญชี',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10),
                ),
                onChanged: doFilter,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: accounts.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : filtered.isEmpty
                        ? const Center(child: Text('ไม่พบบัญชี'))
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
                                  Expanded(child: Text(a.accountNameThai)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      accountTypeOptions[a.accountType] ??
                                          a.accountType,
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
                child: const Text('ปิด')),
          ],
        );
      }),
    );
    searchCtrl.dispose();
  }

  Future<void> _submitForm() async {
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
              content: Text('เกิดข้อผิดพลาด: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Section builders ────────────────────────────────────────────────────────

  Widget _buildGeneralSection(bool readOnly) {
    return _Section(
      title: 'ข้อมูลทั่วไป',
      initiallyExpanded: true,
      children: [
        // รหัส
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextFormField(
            readOnly: widget.mode != Mode.add,
            controller: _codeController,
            style: const TextStyle(fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              labelText: 'รหัสกลุ่มลูกค้า *',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'โปรดระบุรหัสกลุ่มลูกค้า' : null,
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
                decoration: const InputDecoration(
                  labelText: 'ชื่อกลุ่มลูกค้า (ไทย) *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'โปรดระบุชื่อภาษาไทย' : null,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 5),
              child: TextFormField(
                readOnly: readOnly,
                controller: _nameEngController,
                decoration: const InputDecoration(
                  labelText: 'ชื่อกลุ่มลูกค้า (อังกฤษ)',
                  border: OutlineInputBorder(),
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
            decoration: const InputDecoration(
              labelText: 'คำอธิบาย',
              border: OutlineInputBorder(),
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
                decoration: const InputDecoration(
                  labelText: 'เครดิต (เดือน)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || int.tryParse(v) == null || int.parse(v) < 0)
                        ? 'โปรดระบุ'
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
                decoration: const InputDecoration(
                  labelText: 'เครดิต (วัน)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || int.tryParse(v) == null || int.parse(v) < 0)
                        ? 'โปรดระบุ'
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
                decoration: const InputDecoration(
                  labelText: 'วงเงินเครดิต',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || double.tryParse(v) == null)
                    ? 'โปรดระบุ'
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
                decoration: const InputDecoration(
                  labelText: 'ส่วนลด (%)',
                  border: OutlineInputBorder(),
                  suffixText: '%',
                ),
                validator: (v) {
                  final d = double.tryParse(v ?? '');
                  if (d == null) return 'โปรดระบุ';
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
              title: const Text('ออกรหัสลูกหนี้อัตโนมัติ',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                _isAutoNumber
                    ? 'เปิดใช้งาน — รหัสจะถูกออกอัตโนมัติเมื่อเพิ่มลูกหนี้ในกลุ่มนี้'
                    : 'ปิดใช้งาน — ผู้ใช้ต้องระบุรหัสลูกหนี้เอง',
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
                            decoration: const InputDecoration(
                              labelText: 'วันที่ในรหัส',
                              border: OutlineInputBorder(),
                            ),
                            items: _suffixOptions,
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
                            decoration: const InputDecoration(
                              labelText: 'ความยาวตัวเลข',
                              border: OutlineInputBorder(),
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
                            decoration: const InputDecoration(
                              labelText: 'เลขที่ถัดไป',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                            validator: (v) =>
                                !_isAutoNumber || int.tryParse(v ?? '') != null
                                    ? null
                                    : 'ต้องเป็นตัวเลข',
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
                          const Text('ตัวอย่างรหัส: ',
                              style: TextStyle(fontSize: 13, color: Colors.teal)),
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
          Expanded(child: Text('สถานะ: ${_isActive ? 'ใช้งาน' : 'หยุดใช้'}')),
          Switch(
            value: _isActive,
            onChanged:
                readOnly ? null : (v) => setState(() => _isActive = v),
          ),
        ]),
      ],
    );
  }

  Widget _buildBillingConditionsSection(bool readOnly) {
    return _Section(
      title: 'เงื่อนไขการวางบิล (${_billingConditions.length})',
      initiallyExpanded: false,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text('ต้องวางบิล',
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
            tooltip: 'เพิ่มเงื่อนไขวางบิล',
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
            child: Text('ไม่ต้องวางบิล: วันครบกำหนดชำระนับจากวันส่งของ',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
        if (_billingConditions.isEmpty)
          const Text('ยังไม่มีเงื่อนไขการวางบิล',
              style: TextStyle(color: Colors.grey)),
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
                    child: Text(_billingConditionSummary(b),
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

  String _billingConditionSummary(ArCustomerBillingCondition b) {
    const dayNames = ['อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์'];
    const weekNames = {1: 'แรก', 2: 'ที่2', 3: 'ที่3', 4: 'ที่4', -1: 'สุดท้าย'};
    final parts = <String>[];
    if (b.billWithDelivery) parts.add('วางบิลพร้อมส่งของ');
    if (b.billingDayOfMonth.isNotEmpty) {
      parts.add(b.billingDayOfMonth
          .map((d) => d == 31 ? 'สิ้นเดือน' : 'วันที่ $d')
          .join(', '));
    }
    if (b.billingDayOfWeek.isNotEmpty) {
      parts.add('วัน${b.billingDayOfWeek.map((d) => dayNames[d]).join('-')}');
    }
    if (b.billingWeekOfMonth.isNotEmpty) {
      parts.add(
          'สัปดาห์${b.billingWeekOfMonth.map((w) => weekNames[w] ?? '$w').join('/')}');
    }
    if (b.billingTimeFrom != null || b.billingTimeTo != null) {
      parts.add('${b.billingTimeFrom ?? ''}–${b.billingTimeTo ?? ''}');
    }
    if (b.dueFromBillingDate) parts.add('due นับจากวางบิล');
    return parts.isEmpty ? '(ไม่ระบุเงื่อนไข)' : parts.join('  ·  ');
  }

  Widget _buildPaymentConditionsSection(bool readOnly) {
    return _Section(
      title: 'เงื่อนไขการรับชำระเงิน (${_paymentConditions.length})',
      initiallyExpanded: false,
      trailing: readOnly
          ? null
          : IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              tooltip: 'เพิ่มเงื่อนไขรับชำระ',
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
          const Text(
              'ยังไม่มีเงื่อนไขรับชำระ — วันชำระเงินจะเท่ากับวันครบกำหนด',
              style: TextStyle(color: Colors.grey)),
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
                    child: Text(_paymentConditionSummary(p),
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

  String _paymentConditionSummary(ArCustomerPaymentCondition p) {
    const dayNames = ['อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์'];
    const weekNames = {1: 'แรก', 2: 'ที่2', 3: 'ที่3', 4: 'ที่4', -1: 'สุดท้าย'};
    final parts = <String>[];
    if (p.paymentDayOfMonth.isNotEmpty) {
      parts.add(p.paymentDayOfMonth
          .map((d) => d == 31 ? 'สิ้นเดือน' : 'วันที่ $d')
          .join(', '));
    }
    if (p.paymentDayOfWeek.isNotEmpty) {
      parts.add('วัน${p.paymentDayOfWeek.map((d) => dayNames[d]).join('-')}');
    }
    if (p.paymentWeekOfMonth.isNotEmpty) {
      parts.add(
          'สัปดาห์${p.paymentWeekOfMonth.map((w) => weekNames[w] ?? '$w').join('/')}');
    }
    if (p.withinMonthsFromBilling > 0) {
      parts.add('ภายใน ${p.withinMonthsFromBilling} เดือนจากวางบิล');
    }
    if (p.additionalDays != 0) parts.add('+${p.additionalDays} วัน');
    if (p.paymentTimeFrom != null || p.paymentTimeTo != null) {
      parts.add('${p.paymentTimeFrom ?? ''}–${p.paymentTimeTo ?? ''}');
    }
    return parts.isEmpty ? '(ไม่ระบุเงื่อนไข)' : parts.join('  ·  ');
  }

  Widget _buildGlAccountSection(bool readOnly) {
    return _Section(
      title: 'รหัสบัญชีลูกหนี้ (GL)',
      initiallyExpanded: false,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'บัญชีลูกหนี้ (Control Account)',
              border: OutlineInputBorder(),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    : const Text('— ไม่ระบุ —',
                        style: TextStyle(color: Colors.grey)),
              ),
              if (!readOnly) ...[
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.blue),
                  tooltip: 'ค้นหาบัญชี',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _pickGlAccount,
                ),
                if (_glAccountId != null)
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red, size: 18),
                    tooltip: 'ล้างบัญชี',
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
          const Text(
            'หากไม่ระบุ ระบบจะค้นหาบัญชีลูกหนี้จาก ลูกหนี้การค้า และ ประเภทเอกสาร ตามลำดับ',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPlaceholder) {
      return const Center(
        child: Text(
            'เลือกกลุ่มลูกค้าเพื่อแก้ไข หรือ ลบ หรือ กดปุ่ม + เพื่อเพิ่มใหม่'),
      );
    }

    final bool readOnly = widget.mode == Mode.view;
    final String title = readOnly
        ? 'ดูข้อมูลกลุ่มลูกค้า'
        : widget.mode == Mode.edit
            ? 'แก้ไขกลุ่มลูกค้า'
            : 'เพิ่มกลุ่มลูกค้าใหม่';

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
                  _buildGeneralSection(readOnly),
                  _buildBillingConditionsSection(readOnly),
                  _buildPaymentConditionsSection(readOnly),
                  _buildGlAccountSection(readOnly),
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
                        ? 'กำลังบันทึก...'
                        : widget.mode == Mode.edit
                            ? 'บันทึก'
                            : 'เพิ่ม'),
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
                  label: const Text('ยกเลิก'),
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
