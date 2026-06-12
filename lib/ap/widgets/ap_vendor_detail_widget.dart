import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../sa/models/anan_module.dart';
import '../../cd/models/business_type.dart';
import '../../cd/services/business_type_service.dart';
import '../../gl/models/account.dart';
import '../../gl/services/account_service.dart';
import '../models/ap_vendor.dart';
import '../widgets/ap_vendor_group_list_widget.dart';

// ── Collapsible Section ───────────────────────────────────────────────────
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

// ── Main Widget ───────────────────────────────────────────────────────────
class ApVendorDetailWidget extends StatefulWidget {
  final Mode mode;
  final ApVendor? selected;
  final Future<void> Function(ApVendor) onSubmit;
  final VoidCallback onCancel;
  final bool isPlaceholder;

  const ApVendorDetailWidget({
    super.key,
    required this.mode,
    required this.selected,
    required this.onSubmit,
    required this.onCancel,
    this.isPlaceholder = false,
  });

  @override
  State<ApVendorDetailWidget> createState() => ApVendorDetailWidgetState();
}

class ApVendorDetailWidgetState extends State<ApVendorDetailWidget> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSaving = false;

  // Basic fields
  final _codeCtrl          = TextEditingController();
  final _oldCodeCtrl       = TextEditingController();
  final _nameTHCtrl        = TextEditingController();
  final _nameENCtrl        = TextEditingController();
  final _taxIdCtrl         = TextEditingController();
  final _remarkCtrl        = TextEditingController();
  final _creditMonthsCtrl  = TextEditingController();
  final _creditDaysCtrl    = TextEditingController();
  bool _isActive = true;
  String _currencyCode = 'THB';

  // Linked entities
  int? _vendorGroupId;
  String? _vendorGroupCode;
  String? _vendorGroupName;
  int? _businessTypeId;
  String? _businessTypeCode;
  String? _businessTypeNameThai;
  int? _apAccountId;
  String? _apAccountCode;
  String? _apAccountNameThai;

  // Sub-lists
  List<ApVendorAddress> _addresses = [];
  List<ApVendorContact> _contacts = [];
  List<ApVendorBankAccount> _bankAccounts = [];

  // Dropdown options
  List<BusinessType> _businessTypes = [];
  List<Account> _glAccounts = [];

  bool get _isReadOnly => widget.mode == Mode.view || widget.mode == Mode.none;

  @override
  void initState() {
    super.initState();
    _creditMonthsCtrl.text = '0';
    _creditDaysCtrl.text   = '30';
    _loadDropdowns();
    if (widget.selected != null) _populate(widget.selected!);
  }

  @override
  void didUpdateWidget(covariant ApVendorDetailWidget old) {
    super.didUpdateWidget(old);
    if (widget.selected != old.selected || widget.mode != old.mode) {
      if (widget.selected != null) _populate(widget.selected!);
      else _clear();
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose(); _oldCodeCtrl.dispose(); _nameTHCtrl.dispose();
    _nameENCtrl.dispose(); _taxIdCtrl.dispose(); _remarkCtrl.dispose();
    _creditMonthsCtrl.dispose(); _creditDaysCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDropdowns() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        BusinessTypeService().fetchRows(),
        AccountService().fetchRows(),
      ]);
      if (mounted) setState(() {
        _businessTypes = results[0] as List<BusinessType>;
        _glAccounts    = results[1] as List<Account>;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _populate(ApVendor v) {
    _codeCtrl.text          = v.vendorCode;
    _oldCodeCtrl.text       = v.oldVendorCode ?? '';
    _nameTHCtrl.text        = v.vendorNameTh;
    _nameENCtrl.text        = v.vendorNameEn ?? '';
    _taxIdCtrl.text         = v.taxId ?? '';
    _remarkCtrl.text        = v.remark ?? '';
    _creditMonthsCtrl.text  = '${v.creditTermMonths}';
    _creditDaysCtrl.text    = '${v.creditTermDays}';
    _isActive               = v.isActive;
    _currencyCode           = v.currencyCode;
    _vendorGroupId          = v.vendorGroupId;
    _vendorGroupCode        = v.vendorGroupCode;
    _vendorGroupName        = v.vendorGroupName;
    _businessTypeId         = v.businessTypeId;
    _businessTypeCode       = v.businessTypeCode;
    _businessTypeNameThai   = v.businessTypeNameThai;
    _apAccountId            = v.apAccountId;
    _apAccountCode          = v.apAccountCode;
    _apAccountNameThai      = v.apAccountNameThai;
    _addresses   = List.from(v.addresses);
    _contacts    = List.from(v.contacts);
    _bankAccounts = List.from(v.bankAccounts);
  }

  void _clear() {
    _codeCtrl.clear(); _oldCodeCtrl.clear(); _nameTHCtrl.clear();
    _nameENCtrl.clear(); _taxIdCtrl.clear(); _remarkCtrl.clear();
    _creditMonthsCtrl.text = '0'; _creditDaysCtrl.text = '30';
    _isActive = true; _currencyCode = 'THB';
    _vendorGroupId = null; _vendorGroupCode = null; _vendorGroupName = null;
    _businessTypeId = null; _businessTypeCode = null; _businessTypeNameThai = null;
    _apAccountId = null; _apAccountCode = null; _apAccountNameThai = null;
    _addresses = []; _contacts = []; _bankAccounts = [];
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final vendor = ApVendor(
        id: widget.selected?.id,
        vendorCode: _codeCtrl.text.trim().toUpperCase(),
        oldVendorCode: _oldCodeCtrl.text.trim().isEmpty ? null : _oldCodeCtrl.text.trim(),
        vendorNameTh: _nameTHCtrl.text.trim(),
        vendorNameEn: _nameENCtrl.text.trim().isEmpty ? null : _nameENCtrl.text.trim(),
        taxId: _taxIdCtrl.text.trim().isEmpty ? null : _taxIdCtrl.text.trim(),
        vendorGroupId: _vendorGroupId,
        vendorGroupCode: _vendorGroupCode,
        vendorGroupName: _vendorGroupName,
        businessTypeId: _businessTypeId,
        businessTypeCode: _businessTypeCode,
        businessTypeNameThai: _businessTypeNameThai,
        creditTermMonths: int.tryParse(_creditMonthsCtrl.text) ?? 0,
        creditTermDays: int.tryParse(_creditDaysCtrl.text) ?? 30,
        currencyCode: _currencyCode,
        isActive: _isActive,
        remark: _remarkCtrl.text.trim().isEmpty ? null : _remarkCtrl.text.trim(),
        apAccountId: _apAccountId,
        apAccountCode: _apAccountCode,
        apAccountNameThai: _apAccountNameThai,
        addresses: _addresses,
        contacts: _contacts,
        bankAccounts: _bankAccounts,
      );
      await widget.onSubmit(vendor);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Field helpers ─────────────────────────────────────────────────────────

  Widget _buildField(
    String label,
    TextEditingController ctrl, {
    bool required = false,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    int? maxLength,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: ctrl,
      readOnly: _isReadOnly,
      keyboardType: keyboard,
      inputFormatters: formatters,
      maxLength: maxLength,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'กรุณาระบุ' : null : null,
    ),
  );

  Widget _buildBusinessTypeField() => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: InputDecorator(
      decoration: const InputDecoration(
        labelText: 'ประเภทธุรกิจ',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
      child: Row(children: [
        Expanded(child: _businessTypeId == null
          ? const Text('— ไม่ระบุ —', style: TextStyle(color: Colors.grey, fontSize: 13))
          : Text('$_businessTypeCode — $_businessTypeNameThai',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
        if (!_isReadOnly) ...[
          IconButton(
            icon: const Icon(Icons.search, color: Colors.blue, size: 18),
            tooltip: 'ค้นหาประเภทธุรกิจ',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _pickBusinessType,
          ),
          if (_businessTypeId != null)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.red, size: 18),
              tooltip: 'ล้าง',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() {
                _businessTypeId = null; _businessTypeCode = null; _businessTypeNameThai = null;
              }),
            ),
        ],
      ]),
    ),
  );

  Widget _buildVendorGroupField() => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: InputDecorator(
      decoration: const InputDecoration(
        labelText: 'กลุ่มผู้ขาย',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
      child: Row(children: [
        Expanded(child: _vendorGroupId == null
          ? const Text('— ไม่ระบุ —', style: TextStyle(color: Colors.grey, fontSize: 13))
          : Text('$_vendorGroupCode — $_vendorGroupName',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
        if (!_isReadOnly) ...[
          IconButton(
            icon: const Icon(Icons.search, color: Colors.blue, size: 18),
            tooltip: 'ค้นหากลุ่มผู้ขาย',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _pickVendorGroup,
          ),
          if (_vendorGroupId != null)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.red, size: 18),
              tooltip: 'ล้าง',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() {
                _vendorGroupId = null; _vendorGroupCode = null; _vendorGroupName = null;
              }),
            ),
        ],
      ]),
    ),
  );

  Future<void> _pickVendorGroup() async {
    await ApVendorGroupListWidget.search(context, onSelected: (group) {
      setState(() {
        _vendorGroupId   = group.id;
        _vendorGroupCode = group.groupCode;
        _vendorGroupName = group.groupNameThai;
        // Auto-fill credit terms and currency from group defaults
        _creditMonthsCtrl.text = '${group.creditTermMonths}';
        _creditDaysCtrl.text   = '${group.creditTermDays}';
        _currencyCode          = group.currencyCode;
      });
    });
  }

  Widget _buildCurrencyField() => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: _isReadOnly
      ? InputDecorator(
          decoration: const InputDecoration(
            labelText: 'สกุลเงิน',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
          ),
          child: Text(_currencyCode, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        )
      : DropdownButtonFormField<String>(
          value: _currencyCode,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'สกุลเงิน',
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
          items: const [
            DropdownMenuItem(value: 'THB', child: Text('THB')),
            DropdownMenuItem(value: 'USD', child: Text('USD')),
            DropdownMenuItem(value: 'EUR', child: Text('EUR')),
            DropdownMenuItem(value: 'JPY', child: Text('JPY')),
            DropdownMenuItem(value: 'CNY', child: Text('CNY')),
          ],
          onChanged: (v) => setState(() => _currencyCode = v ?? 'THB'),
        ),
  );

  Future<void> _pickBusinessType() async {
    if (_businessTypes.isEmpty) return;
    final searchCtrl = TextEditingController();
    List<BusinessType> filtered = List.from(_businessTypes);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        void doFilter(String q) => setDlg(() {
          filtered = q.isEmpty
            ? List.from(_businessTypes)
            : _businessTypes.where((b) =>
                b.businessTypeCode.toLowerCase().contains(q.toLowerCase()) ||
                b.businessTypeNameThai.toLowerCase().contains(q.toLowerCase())).toList();
        });

        return AlertDialog(
          title: const Text('เลือกประเภทธุรกิจ'),
          content: SizedBox(
            width: 480, height: 380,
            child: Column(children: [
              TextField(
                controller: searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'ค้นหา รหัส / ชื่อประเภทธุรกิจ',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10),
                ),
                onChanged: doFilter,
              ),
              const SizedBox(height: 8),
              Expanded(child: filtered.isEmpty
                ? const Center(child: Text('ไม่พบข้อมูล'))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final bt = filtered[i];
                      return ListTile(
                        dense: true,
                        title: Text('${bt.businessTypeCode} — ${bt.businessTypeNameThai}', style: const TextStyle(fontSize: 13)),
                        onTap: () {
                          setState(() {
                            _businessTypeId = bt.id;
                            _businessTypeCode = bt.businessTypeCode;
                            _businessTypeNameThai = bt.businessTypeNameThai;
                          });
                          Navigator.of(ctx).pop();
                        },
                      );
                    },
                  )),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('ปิด'))],
        );
      }),
    );
    searchCtrl.dispose();
  }

  // ── Sections ──────────────────────────────────────────────────────────────

  Widget _buildBasicSection() => _Section(
    title: 'ข้อมูลพื้นฐาน',
    children: [
      // Row 1: รหัสเจ้าหนี้ + เลขผู้เสียภาษี + รหัสเก่า
      Row(children: [
        Expanded(child: _buildField('รหัสเจ้าหนี้ *', _codeCtrl, required: true, maxLength: 50)),
        const SizedBox(width: 10),
        Expanded(child: _buildField('เลขผู้เสียภาษี', _taxIdCtrl, maxLength: 30)),
        const SizedBox(width: 10),
        Expanded(child: _buildField('รหัสเก่า', _oldCodeCtrl, maxLength: 50)),
      ]),
      // Row 2: ชื่อ (ไทย) + ชื่อ (อังกฤษ)
      Row(children: [
        Expanded(child: _buildField('ชื่อเจ้าหนี้ (ไทย) *', _nameTHCtrl, required: true)),
        const SizedBox(width: 10),
        Expanded(child: _buildField('ชื่อเจ้าหนี้ (อังกฤษ)', _nameENCtrl)),
      ]),
      // Row 3: ประเภทธุรกิจ (full width)
      _buildBusinessTypeField(),
      // Row 4: กลุ่มผู้ขาย (full width)
      _buildVendorGroupField(),
      // Row 5: เครดิต (เดือน) + เครดิต (วัน) + สกุลเงิน
      Row(children: [
        Expanded(child: _buildField('เครดิต (เดือน)', _creditMonthsCtrl,
          keyboard: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly])),
        const SizedBox(width: 10),
        Expanded(child: _buildField('เครดิต (วัน)', _creditDaysCtrl,
          keyboard: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly])),
        const SizedBox(width: 10),
        Expanded(child: _buildCurrencyField()),
      ]),
      // Row 5: สถานะ
      SwitchListTile(
        dense: true,
        title: Text('สถานะ: ${_isActive ? 'ใช้งาน' : 'หยุดใช้'}', style: const TextStyle(fontSize: 13)),
        value: _isActive,
        onChanged: _isReadOnly ? null : (v) => setState(() => _isActive = v),
      ),
      _buildField('หมายเหตุ', _remarkCtrl),
    ],
  );

  Widget _buildAddressSection() => _Section(
    title: 'ที่อยู่',
    initiallyExpanded: false,
    trailing: _isReadOnly ? null : IconButton(
      icon: const Icon(Icons.add, size: 18),
      tooltip: 'เพิ่มที่อยู่',
      onPressed: () => setState(() => _addresses.add(ApVendorAddress())),
    ),
    children: [
      if (_addresses.isEmpty) const Text('ไม่มีที่อยู่', style: TextStyle(color: Colors.grey, fontSize: 13)),
      ..._addresses.asMap().entries.map((e) => _AddressCard(
        index: e.key, address: e.value, readOnly: _isReadOnly,
        onChanged: (updated) => setState(() => _addresses[e.key] = updated),
        onDelete: () => setState(() => _addresses.removeAt(e.key)),
      )),
    ],
  );

  Widget _buildContactSection() => _Section(
    title: 'ผู้ติดต่อ',
    initiallyExpanded: false,
    trailing: _isReadOnly ? null : IconButton(
      icon: const Icon(Icons.add, size: 18),
      tooltip: 'เพิ่มผู้ติดต่อ',
      onPressed: () => setState(() => _contacts.add(ApVendorContact())),
    ),
    children: [
      if (_contacts.isEmpty) const Text('ไม่มีผู้ติดต่อ', style: TextStyle(color: Colors.grey, fontSize: 13)),
      ..._contacts.asMap().entries.map((e) => _ContactCard(
        index: e.key, contact: e.value, readOnly: _isReadOnly,
        onChanged: (updated) => setState(() => _contacts[e.key] = updated),
        onDelete: () => setState(() => _contacts.removeAt(e.key)),
      )),
    ],
  );

  Widget _buildBankSection() => _Section(
    title: 'บัญชีธนาคาร',
    initiallyExpanded: false,
    trailing: _isReadOnly ? null : IconButton(
      icon: const Icon(Icons.add, size: 18),
      tooltip: 'เพิ่มบัญชีธนาคาร',
      onPressed: () => setState(() => _bankAccounts.add(ApVendorBankAccount())),
    ),
    children: [
      if (_bankAccounts.isEmpty) const Text('ไม่มีบัญชีธนาคาร', style: TextStyle(color: Colors.grey, fontSize: 13)),
      ..._bankAccounts.asMap().entries.map((e) => _BankCard(
        index: e.key, bank: e.value, readOnly: _isReadOnly,
        onChanged: (updated) => setState(() => _bankAccounts[e.key] = updated),
        onDelete: () => setState(() => _bankAccounts.removeAt(e.key)),
      )),
    ],
  );

  Widget _buildGlAccountSection() => _Section(
    title: 'บัญชีเจ้าหนี้ (GL)',
    initiallyExpanded: false,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'บัญชีเจ้าหนี้',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            isDense: true,
          ),
          child: Row(children: [
            Expanded(child: Text(
              _apAccountCode != null ? '$_apAccountCode — $_apAccountNameThai' : '— ไม่ระบุ —',
              style: TextStyle(
                fontSize: 13,
                fontWeight: _apAccountCode != null ? FontWeight.bold : FontWeight.normal,
                color: _apAccountCode != null ? null : Colors.grey,
              ),
            )),
            if (!_isReadOnly) ...[
              IconButton(
                icon: const Icon(Icons.search, color: Colors.blue, size: 18),
                tooltip: 'เลือกบัญชีเจ้าหนี้',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () async {
                  final picked = await showDialog<Account>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('เลือกบัญชีเจ้าหนี้'),
                      content: SizedBox(width: 500, height: 400,
                        child: _AccountPickerList(accounts: _glAccounts, onPick: (a) => Navigator.of(ctx).pop(a))),
                      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('ยกเลิก'))],
                    ),
                  );
                  if (picked != null) setState(() {
                    _apAccountId = picked.id;
                    _apAccountCode = picked.accountCode;
                    _apAccountNameThai = picked.accountNameThai;
                  });
                },
              ),
              if (_apAccountId != null)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.red, size: 18),
                  tooltip: 'ล้าง',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() {
                    _apAccountId = null; _apAccountCode = null; _apAccountNameThai = null;
                  }),
                ),
            ],
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 4),
        child: Text(
          'หากไม่ระบุ ระบบจะใช้บัญชีจาก กลุ่มผู้ขาย และ ประเภทเอกสาร ตามลำดับ',
          style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade400, fontStyle: FontStyle.italic),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (widget.isPlaceholder) {
      return const Center(child: Text('เลือกรายการเพื่อดูข้อมูล', style: TextStyle(color: Colors.grey)));
    }
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Form(
      key: _formKey,
      child: Column(children: [
        // Detail header bar (lighter than AppBar for visual separation)
        Container(
          color: Colors.blue[300],
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            Icon(Icons.business, color: Colors.blue[900], size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(
              widget.mode == Mode.add ? 'เพิ่มเจ้าหนี้ใหม่'
                : widget.mode == Mode.edit ? 'แก้ไขเจ้าหนี้'
                : 'ข้อมูลเจ้าหนี้',
              style: TextStyle(color: Colors.blue[900], fontSize: 16, fontWeight: FontWeight.bold),
            )),
            if (!_isReadOnly) ...[
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save, size: 16),
                label: Text(_isSaving ? 'กำลังบันทึก...' : 'บันทึก'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
              ),
              const SizedBox(width: 8),
            ],
            TextButton(
              onPressed: widget.onCancel,
              child: Text('ปิด', style: TextStyle(color: Colors.blue[900])),
            ),
          ]),
        ),
        Expanded(child: ListView(children: [
          _buildBasicSection(),
          _buildAddressSection(),
          _buildContactSection(),
          _buildBankSection(),
          _buildGlAccountSection(),
        ])),
      ]),
    );
  }
}

// ── Address Card ───────────────────────────────────────────────────────────
class _AddressCard extends StatelessWidget {
  final int index;
  final ApVendorAddress address;
  final bool readOnly;
  final void Function(ApVendorAddress) onChanged;
  final VoidCallback onDelete;

  const _AddressCard({required this.index, required this.address, required this.readOnly, required this.onChanged, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    Widget tf(String hint, String val, void Function(String) onChange) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TextFormField(
        initialValue: val,
        readOnly: readOnly,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(hintText: hint, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: readOnly ? InputBorder.none : const OutlineInputBorder(), filled: readOnly, fillColor: Colors.grey.shade100),
        onChanged: onChange,
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('ที่อยู่ ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const Spacer(),
            if (!readOnly) Switch(value: address.isDefault, onChanged: (v) => onChanged(address.copyWith(isDefault: v))),
            if (!readOnly) Text('ค่าเริ่มต้น', style: const TextStyle(fontSize: 12)),
            if (!readOnly) IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: onDelete),
          ]),
          tf('เลขที่', address.addressNo ?? '', (v) => onChanged(address.copyWith(addressNo: v))),
          tf('อาคาร/หมู่บ้าน', address.addressBuildingVillage ?? '', (v) => onChanged(address.copyWith(addressBuildingVillage: v))),
          tf('ซอย', address.addressAlley ?? '', (v) => onChanged(address.copyWith(addressAlley: v))),
          tf('ถนน', address.addressRoad ?? '', (v) => onChanged(address.copyWith(addressRoad: v))),
          tf('แขวง/ตำบล', address.addressSubDistrict ?? '', (v) => onChanged(address.copyWith(addressSubDistrict: v))),
          tf('เขต/อำเภอ', address.addressDistrict ?? '', (v) => onChanged(address.copyWith(addressDistrict: v))),
          tf('จังหวัด', address.addressProvince ?? '', (v) => onChanged(address.copyWith(addressProvince: v))),
          tf('รหัสไปรษณีย์', address.addressZipCode ?? '', (v) => onChanged(address.copyWith(addressZipCode: v))),
        ]),
      ),
    );
  }
}

// ── Contact Card ───────────────────────────────────────────────────────────
class _ContactCard extends StatelessWidget {
  final int index;
  final ApVendorContact contact;
  final bool readOnly;
  final void Function(ApVendorContact) onChanged;
  final VoidCallback onDelete;

  const _ContactCard({required this.index, required this.contact, required this.readOnly, required this.onChanged, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    Widget tf(String hint, String val, void Function(String) onChange) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TextFormField(
        initialValue: val,
        readOnly: readOnly,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(hintText: hint, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: readOnly ? InputBorder.none : const OutlineInputBorder(), filled: readOnly, fillColor: Colors.grey.shade100),
        onChanged: onChange,
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('ผู้ติดต่อ ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const Spacer(),
            if (!readOnly) Switch(value: contact.isDefault, onChanged: (v) => onChanged(contact.copyWith(isDefault: v))),
            if (!readOnly) Text('ค่าเริ่มต้น', style: const TextStyle(fontSize: 12)),
            if (!readOnly) IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: onDelete),
          ]),
          tf('ชื่อผู้ติดต่อ *', contact.contactName, (v) => onChanged(contact.copyWith(contactName: v))),
          tf('ตำแหน่ง', contact.position ?? '', (v) => onChanged(contact.copyWith(position: v))),
          tf('โทรศัพท์', contact.phone ?? '', (v) => onChanged(contact.copyWith(phone: v))),
          tf('มือถือ', contact.mobile ?? '', (v) => onChanged(contact.copyWith(mobile: v))),
          tf('อีเมล', contact.email ?? '', (v) => onChanged(contact.copyWith(email: v))),
        ]),
      ),
    );
  }
}

// ── Bank Account Card ──────────────────────────────────────────────────────
class _BankCard extends StatelessWidget {
  final int index;
  final ApVendorBankAccount bank;
  final bool readOnly;
  final void Function(ApVendorBankAccount) onChanged;
  final VoidCallback onDelete;

  const _BankCard({required this.index, required this.bank, required this.readOnly, required this.onChanged, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    Widget tf(String hint, String val, void Function(String) onChange) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TextFormField(
        initialValue: val,
        readOnly: readOnly,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(hintText: hint, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: readOnly ? InputBorder.none : const OutlineInputBorder(), filled: readOnly, fillColor: Colors.grey.shade100),
        onChanged: onChange,
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('บัญชีธนาคาร ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const Spacer(),
            if (!readOnly) Switch(value: bank.isDefault, onChanged: (v) => onChanged(bank.copyWith(isDefault: v))),
            if (!readOnly) Text('ค่าเริ่มต้น', style: const TextStyle(fontSize: 12)),
            if (!readOnly) IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: onDelete),
          ]),
          tf('ธนาคาร', bank.bankName ?? '', (v) => onChanged(bank.copyWith(bankName: v))),
          tf('สาขา', bank.branchName ?? '', (v) => onChanged(bank.copyWith(branchName: v))),
          tf('เลขบัญชี', bank.accountNumber ?? '', (v) => onChanged(bank.copyWith(accountNumber: v))),
          tf('ชื่อบัญชี', bank.accountName ?? '', (v) => onChanged(bank.copyWith(accountName: v))),
        ]),
      ),
    );
  }
}

// ── Account Picker List ────────────────────────────────────────────────────
class _AccountPickerList extends StatefulWidget {
  final List<Account> accounts;
  final void Function(Account) onPick;
  const _AccountPickerList({required this.accounts, required this.onPick});
  @override
  State<_AccountPickerList> createState() => _AccountPickerListState();
}

class _AccountPickerListState extends State<_AccountPickerList> {
  String _search = '';
  @override
  Widget build(BuildContext context) {
    final filtered = widget.accounts.where((a) =>
      a.accountCode.toUpperCase().contains(_search.toUpperCase()) ||
      (a.accountNameThai ?? '').toUpperCase().contains(_search.toUpperCase())
    ).toList();
    return Column(children: [
      TextField(
        decoration: const InputDecoration(hintText: 'ค้นหาบัญชี', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
        onChanged: (v) => setState(() => _search = v),
      ),
      const SizedBox(height: 8),
      Expanded(child: ListView.builder(
        itemCount: filtered.length,
        itemBuilder: (ctx, i) {
          final a = filtered[i];
          return ListTile(
            dense: true,
            title: Text('${a.accountCode} - ${a.accountNameThai ?? ''}', style: const TextStyle(fontSize: 13)),
            onTap: () => widget.onPick(a),
          );
        },
      )),
    ]);
  }
}
