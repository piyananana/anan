// lib/ap/widgets/ap_vendor_group_detail_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../sa/models/sa_anan_module.dart';
import '../../gl/models/account.dart';
import '../../gl/services/account_service.dart';
import '../models/ap_vendor_group.dart';

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
  void initState() { super.initState(); _expanded = widget.initiallyExpanded; }
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
      if (_expanded) Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: widget.children),
      ),
      const Divider(height: 1),
    ]);
  }
}

class ApVendorGroupDetailWidget extends StatefulWidget {
  final Mode mode;
  final ApVendorGroup? selected;
  final Future<void> Function(ApVendorGroup) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;

  const ApVendorGroupDetailWidget({
    super.key,
    required this.mode,
    this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
  });

  @override
  State<ApVendorGroupDetailWidget> createState() => ApVendorGroupDetailWidgetState();
}

class ApVendorGroupDetailWidgetState extends State<ApVendorGroupDetailWidget> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _codeCtrl;
  late TextEditingController _nameThaCtrl;
  late TextEditingController _nameEngCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _creditMonthsCtrl;
  late TextEditingController _creditDaysCtrl;
  late bool _isActive;
  String _currencyCode = 'THB';

  bool _isAutoNumber = false;
  late TextEditingController _prefixCtrl;
  late TextEditingController _separatorCtrl;
  String _suffixDate = '';
  late TextEditingController _lengthCtrl;
  late TextEditingController _nextNumCtrl;

  int? _apAccountId;
  String? _apAccountCode;
  String? _apAccountNameThai;

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
    final len  = int.tryParse(_lengthCtrl.text) ?? 4;
    final next = int.tryParse(_nextNumCtrl.text) ?? 1;
    code += next.toString().padLeft(len, '0');
    return code;
  }

  @override
  void initState() {
    super.initState();
    _initFromSelected(widget.selected);
  }

  void _initFromSelected(ApVendorGroup? d) {
    _codeCtrl        = TextEditingController(text: d?.groupCode ?? '');
    _nameThaCtrl     = TextEditingController(text: d?.groupNameThai ?? '');
    _nameEngCtrl     = TextEditingController(text: d?.groupNameEng ?? '');
    _descCtrl        = TextEditingController(text: d?.description ?? '');
    _creditMonthsCtrl = TextEditingController(text: (d?.creditTermMonths ?? 0).toString());
    _creditDaysCtrl  = TextEditingController(text: (d?.creditTermDays ?? 30).toString());
    _isActive        = d?.isActive ?? true;
    _currencyCode    = d?.currencyCode ?? 'THB';
    _isAutoNumber    = d?.isAutoNumber ?? false;
    _prefixCtrl      = TextEditingController(text: d?.runningPrefix ?? 'VEND');
    _separatorCtrl   = TextEditingController(text: d?.runningSeparator ?? '-');
    _suffixDate      = d?.runningSuffixDate ?? '';
    _lengthCtrl      = TextEditingController(text: (d?.runningLength ?? 4).toString());
    _nextNumCtrl     = TextEditingController(text: (d?.runningNextNumber ?? 1).toString());
    _apAccountId     = d?.apAccountId;
    _apAccountCode   = d?.apAccountCode;
    _apAccountNameThai = d?.apAccountNameThai;
  }

  @override
  void didUpdateWidget(covariant ApVendorGroupDetailWidget old) {
    super.didUpdateWidget(old);
    if (widget.selected != old.selected) {
      final d = widget.selected;
      _codeCtrl.text         = d?.groupCode ?? '';
      _nameThaCtrl.text      = d?.groupNameThai ?? '';
      _nameEngCtrl.text      = d?.groupNameEng ?? '';
      _descCtrl.text         = d?.description ?? '';
      _creditMonthsCtrl.text = (d?.creditTermMonths ?? 0).toString();
      _creditDaysCtrl.text   = (d?.creditTermDays ?? 30).toString();
      _isActive        = d?.isActive ?? true;
      _currencyCode    = d?.currencyCode ?? 'THB';
      _isAutoNumber    = d?.isAutoNumber ?? false;
      _prefixCtrl.text    = d?.runningPrefix ?? 'VEND';
      _separatorCtrl.text = d?.runningSeparator ?? '-';
      _suffixDate         = d?.runningSuffixDate ?? '';
      _lengthCtrl.text    = (d?.runningLength ?? 4).toString();
      _nextNumCtrl.text   = (d?.runningNextNumber ?? 1).toString();
      _apAccountId        = d?.apAccountId;
      _apAccountCode      = d?.apAccountCode;
      _apAccountNameThai  = d?.apAccountNameThai;
    } else if (widget.mode == Mode.add && old.mode != Mode.add) {
      _codeCtrl.clear(); _nameThaCtrl.clear(); _nameEngCtrl.clear(); _descCtrl.clear();
      _creditMonthsCtrl.text = '0'; _creditDaysCtrl.text = '30';
      _isActive = true; _currencyCode = 'THB'; _isAutoNumber = false;
      _prefixCtrl.text = 'VEND'; _separatorCtrl.text = '-'; _suffixDate = '';
      _lengthCtrl.text = '4'; _nextNumCtrl.text = '1';
      _apAccountId = null; _apAccountCode = null; _apAccountNameThai = null;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _codeCtrl.dispose(); _nameThaCtrl.dispose(); _nameEngCtrl.dispose(); _descCtrl.dispose();
    _creditMonthsCtrl.dispose(); _creditDaysCtrl.dispose();
    _prefixCtrl.dispose(); _separatorCtrl.dispose(); _lengthCtrl.dispose(); _nextNumCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickApAccount() async {
    List<Account> accounts = [];
    try {
      accounts = await AccountService().fetchRows();
    } catch (_) {}
    if (!mounted) return;

    final searchCtrl = TextEditingController();
    List<Account> filtered = List.from(accounts);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        void doFilter(String q) => setDlg(() {
          filtered = q.isEmpty
            ? List.from(accounts)
            : accounts.where((a) =>
                a.accountCode.toLowerCase().contains(q.toLowerCase()) ||
                (a.accountNameThai ?? '').toLowerCase().contains(q.toLowerCase())).toList();
        });

        return AlertDialog(
          title: const Text('เลือกบัญชีเจ้าหนี้ (AP Account)'),
          content: SizedBox(width: 520, height: 420, child: Column(children: [
            TextField(
              controller: searchCtrl, autofocus: true,
              decoration: const InputDecoration(hintText: 'ค้นหา รหัส / ชื่อบัญชี', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
              onChanged: doFilter,
            ),
            const SizedBox(height: 8),
            Expanded(child: filtered.isEmpty
              ? const Center(child: Text('ไม่พบบัญชี'))
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final a = filtered[i];
                    return ListTile(
                      dense: true,
                      selected: _apAccountId == a.id,
                      selectedTileColor: Colors.blue.shade50,
                      title: Row(children: [
                        SizedBox(width: 90, child: Text(a.accountCode, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
                        Expanded(child: Text(a.accountNameThai ?? '')),
                      ]),
                      onTap: () {
                        setState(() { _apAccountId = a.id; _apAccountCode = a.accountCode; _apAccountNameThai = a.accountNameThai; });
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                )),
          ])),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('ปิด'))],
        );
      }),
    );
    searchCtrl.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final row = ApVendorGroup(
        id: widget.selected?.id,
        groupCode: _codeCtrl.text.trim().toUpperCase(),
        groupNameThai: _nameThaCtrl.text.trim(),
        groupNameEng: _nameEngCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        creditTermMonths: int.tryParse(_creditMonthsCtrl.text) ?? 0,
        creditTermDays: int.tryParse(_creditDaysCtrl.text) ?? 30,
        currencyCode: _currencyCode,
        apAccountId: _apAccountId,
        apAccountCode: _apAccountCode,
        apAccountNameThai: _apAccountNameThai,
        isAutoNumber: _isAutoNumber,
        runningPrefix: _prefixCtrl.text.trim(),
        runningSeparator: _separatorCtrl.text,
        runningSuffixDate: _suffixDate,
        runningLength: int.tryParse(_lengthCtrl.text) ?? 4,
        runningNextNumber: int.tryParse(_nextNumCtrl.text) ?? 1,
        isActive: _isActive,
      );
      await widget.onSubmit(row);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildGeneralSection(bool readOnly) => _Section(
    title: 'ข้อมูลทั่วไป',
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          readOnly: widget.mode != Mode.add,
          controller: _codeCtrl,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(fontWeight: FontWeight.bold),
          decoration: const InputDecoration(labelText: 'รหัสกลุ่มผู้ขาย *', border: OutlineInputBorder()),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'โปรดระบุรหัส' : null,
        ),
      ),
      Row(children: [
        Expanded(child: Padding(
          padding: const EdgeInsets.only(bottom: 10, right: 5),
          child: TextFormField(
            readOnly: readOnly, controller: _nameThaCtrl,
            decoration: const InputDecoration(labelText: 'ชื่อกลุ่มผู้ขาย (ไทย) *', border: OutlineInputBorder()),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'โปรดระบุชื่อภาษาไทย' : null,
          ),
        )),
        Expanded(child: Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 5),
          child: TextFormField(
            readOnly: readOnly, controller: _nameEngCtrl,
            decoration: const InputDecoration(labelText: 'ชื่อกลุ่มผู้ขาย (อังกฤษ)', border: OutlineInputBorder()),
          ),
        )),
      ]),
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          readOnly: readOnly, controller: _descCtrl, maxLines: 2,
          decoration: const InputDecoration(labelText: 'คำอธิบาย', border: OutlineInputBorder(), alignLabelWithHint: true),
        ),
      ),
      // เงื่อนไขเครดิต + สกุลเงิน
      Row(children: [
        Expanded(child: Padding(
          padding: const EdgeInsets.only(bottom: 10, right: 5),
          child: TextFormField(
            readOnly: readOnly, controller: _creditMonthsCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.right,
            decoration: const InputDecoration(labelText: 'เครดิต (เดือน)', border: OutlineInputBorder()),
          ),
        )),
        Expanded(child: Padding(
          padding: const EdgeInsets.only(bottom: 10, right: 5, left: 5),
          child: TextFormField(
            readOnly: readOnly, controller: _creditDaysCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.right,
            decoration: const InputDecoration(labelText: 'เครดิต (วัน)', border: OutlineInputBorder()),
          ),
        )),
        Expanded(child: Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 5),
          child: readOnly
            ? InputDecorator(
                decoration: const InputDecoration(labelText: 'สกุลเงิน', border: OutlineInputBorder()),
                child: Text(_currencyCode, style: const TextStyle(fontWeight: FontWeight.bold)),
              )
            : DropdownButtonFormField<String>(
                value: _currencyCode,
                decoration: const InputDecoration(labelText: 'สกุลเงิน', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'THB', child: Text('THB')),
                  DropdownMenuItem(value: 'USD', child: Text('USD')),
                  DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                  DropdownMenuItem(value: 'JPY', child: Text('JPY')),
                  DropdownMenuItem(value: 'CNY', child: Text('CNY')),
                ],
                onChanged: (v) => setState(() => _currencyCode = v ?? 'THB'),
              ),
        )),
      ]),
      // รหัสอัตโนมัติ
      Container(
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SwitchListTile(
            title: const Text('ออกรหัสผู้ขายอัตโนมัติ', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              _isAutoNumber ? 'เปิดใช้งาน — รหัสจะถูกออกอัตโนมัติเมื่อเพิ่มผู้ขายในกลุ่มนี้'
                            : 'ปิดใช้งาน — ผู้ใช้ต้องระบุรหัสผู้ขายเอง',
              style: TextStyle(color: _isAutoNumber ? Colors.blue[700] : Colors.grey, fontSize: 12),
            ),
            value: _isAutoNumber,
            onChanged: readOnly ? null : (v) => setState(() => _isAutoNumber = v),
          ),
          if (_isAutoNumber) ...[
            Divider(height: 1, color: Colors.grey.shade200),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: TextFormField(
                    readOnly: readOnly, controller: _prefixCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Prefix', border: OutlineInputBorder(), hintText: 'VEND'),
                    onChanged: (_) => setState(() {}),
                  )),
                  const SizedBox(width: 8),
                  SizedBox(width: 80, child: TextFormField(
                    readOnly: readOnly, controller: _separatorCtrl, textAlign: TextAlign.center,
                    decoration: const InputDecoration(labelText: 'Separator', border: OutlineInputBorder(), hintText: '-'),
                    onChanged: (_) => setState(() {}),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: DropdownButtonFormField<String>(
                    isExpanded: true, value: _suffixDate,
                    decoration: const InputDecoration(labelText: 'วันที่ในรหัส', border: OutlineInputBorder()),
                    items: _suffixOptions,
                    onChanged: readOnly ? null : (v) => setState(() => _suffixDate = v ?? ''),
                  )),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextFormField(
                    readOnly: readOnly, controller: _lengthCtrl,
                    keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(labelText: 'ความยาวตัวเลข', border: OutlineInputBorder()),
                    onChanged: (_) => setState(() {}),
                    validator: (v) { if (!_isAutoNumber) return null; final n = int.tryParse(v ?? ''); return (n == null || n < 1 || n > 10) ? '1-10' : null; },
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: TextFormField(
                    readOnly: readOnly, controller: _nextNumCtrl,
                    keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(labelText: 'เลขที่ถัดไป', border: OutlineInputBorder()),
                    onChanged: (_) => setState(() {}),
                    validator: (v) => !_isAutoNumber || int.tryParse(v ?? '') != null ? null : 'ต้องเป็นตัวเลข',
                  )),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.blue.shade200)),
                  child: Row(children: [
                    Icon(Icons.auto_awesome, color: Colors.blue[700], size: 16),
                    const SizedBox(width: 8),
                    Text('ตัวอย่างรหัส: ', style: TextStyle(fontSize: 13, color: Colors.blue[700])),
                    Text(_sampleCode, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue[700], letterSpacing: 1)),
                  ]),
                ),
              ]),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: Text('สถานะ: ${_isActive ? 'ใช้งาน' : 'หยุดใช้'}')),
        Switch(value: _isActive, onChanged: readOnly ? null : (v) => setState(() => _isActive = v)),
      ]),
    ],
  );

  Widget _buildApAccountSection(bool readOnly) => _Section(
    title: 'บัญชีเจ้าหนี้ (GL)',
    initiallyExpanded: false,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'บัญชีเจ้าหนี้ (AP Account)',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: Row(children: [
            Expanded(child: _apAccountCode != null
              ? Row(children: [
                  Icon(Icons.account_balance, color: Colors.blue[600], size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text('$_apAccountCode — ${_apAccountNameThai ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold))),
                ])
              : const Text('— ไม่ระบุ —', style: TextStyle(color: Colors.grey))),
            if (!readOnly) ...[
              IconButton(icon: const Icon(Icons.search, color: Colors.blue), tooltip: 'ค้นหาบัญชี', padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: _pickApAccount),
              if (_apAccountId != null)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.red, size: 18),
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                  onPressed: () => setState(() { _apAccountId = null; _apAccountCode = null; _apAccountNameThai = null; }),
                ),
            ],
          ]),
        ),
      ),
      if (_apAccountId == null)
        const Text(
          'หากไม่ระบุ ระบบจะใช้บัญชีจากข้อมูลผู้ขาย หรือตามประเภทเอกสารที่ตั้งค่าไว้',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (widget.isPlaceholder) {
      return const Center(child: Text('เลือกกลุ่มผู้ขายเพื่อแก้ไข หรือกดปุ่ม + เพื่อเพิ่มใหม่'));
    }

    final readOnly = widget.mode == Mode.view;
    final title = readOnly ? 'ดูข้อมูลกลุ่มผู้ขาย'
        : widget.mode == Mode.edit ? 'แก้ไขกลุ่มผู้ขาย' : 'เพิ่มกลุ่มผู้ขายใหม่';

    return Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          color: Colors.blue[300],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            Icon(Icons.group, color: Colors.blue[900]),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: Colors.blue[900], fontSize: 20, fontWeight: FontWeight.bold)),
          ]),
        ),
        Expanded(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildGeneralSection(readOnly),
          _buildApAccountSection(readOnly),
          const SizedBox(height: 16),
        ]))),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (!readOnly) ...[
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _submit,
                icon: _isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                label: Text(_isSaving ? 'กำลังบันทึก...' : widget.mode == Mode.edit ? 'บันทึก' : 'เพิ่ม'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
              ),
              const SizedBox(width: 12),
            ],
            ElevatedButton.icon(
              onPressed: widget.onCancel,
              icon: const Icon(Icons.cancel),
              label: const Text('ยกเลิก'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
            ),
          ]),
        ),
      ]),
    );
  }
}
