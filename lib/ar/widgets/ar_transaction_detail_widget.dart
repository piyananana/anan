import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/ar_transaction.dart';
import '../models/ar_customer.dart';
import '../services/ar_transaction_service.dart';
import '../services/ar_customer_service.dart';
import '../../gl/models/account.dart';
import '../../gl/services/account_service.dart';
import '../../cd/models/currency.dart';
import '../../cd/services/currency_service.dart';
import '../../sa/models/module_document.dart';
import '../../sa/services/auth_service.dart';
import '../../gl/models/period.dart';
import '../../gl/services/period_service.dart';

class ArTransactionDetailWidget extends StatefulWidget {
  final int? transactionId;
  final bool viewOnly;
  final VoidCallback onSaveSuccess;
  final VoidCallback onCancel;

  const ArTransactionDetailWidget({
    super.key,
    this.transactionId,
    this.viewOnly = false,
    required this.onSaveSuccess,
    required this.onCancel,
  });

  @override
  State<ArTransactionDetailWidget> createState() => _ArTransactionDetailWidgetState();
}

class _ArTransactionDetailWidgetState extends State<ArTransactionDetailWidget> {
  final _formKey = GlobalKey<FormState>();
  final ArTransactionService _service = ArTransactionService();
  final ArCustomerService _customerService = ArCustomerService();
  final AccountService _accountService = AccountService();
  final CurrencyService _currencyService = CurrencyService();
  final PeriodService _periodService = PeriodService();
  final AuthService _authService = AuthService();

  bool _isLoading = false;

  // Master data
  List<ModuleDocument> _allowedDocTypes = [];
  List<ArCustomer> _customers = [];
  List<Account> _accounts = [];
  List<Currency> _currencies = [];
  List<PostingPeriod> _openPeriods = [];

  // State
  ModuleDocument? _selectedDocType;
  ArCustomer? _selectedCustomer;
  Currency? _selectedCurrency;
  bool _isReadOnly = false;

  // Header values
  int _transactionId = 0;
  String _docNo = 'AUTO';
  DateTime _docDate = DateTime.now();
  DateTime? _dueDate;
  int? _arAccountId;
  double _exchangeRate = 1.0;
  final _refNoCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _status = 'Draft';

  // Detail rows
  List<_DetailRow> _detailRows = [];

  // Apply rows (for Receipt/CN)
  List<_ApplyRow> _applyRows = [];
  List<ArTransactionHeader> _openInvoices = [];

  // Totals
  double _subtotalFc = 0;
  double _discountAmountFc = 0;
  double _beforeVatFc = 0;
  double _vatAmountFc = 0;
  double _totalAmountFc = 0;

  final _fmt = NumberFormat('#,##0.00');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  bool get _isReceipt => _selectedDocType?.sysDocType == arDocTypeReceipt.toString();
  bool get _isCreditNote => _selectedDocType?.sysDocType == arDocTypeCreditNote.toString();

  @override
  void initState() {
    super.initState();
    _initMasterData();
  }

  @override
  void dispose() {
    _refNoCtrl.dispose();
    _descCtrl.dispose();
    for (final r in _detailRows) r.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ArTransactionDetailWidget old) {
    super.didUpdateWidget(old);
    if (widget.transactionId != old.transactionId || widget.viewOnly != old.viewOnly) {
      _loadTransactionData();
    }
  }

  Future<void> _initMasterData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _service.fetchDocTypesByUser(),
        _customerService.fetchRows(),
        _accountService.fetchRows(),
        _currencyService.fetchActiveRows(),
        _periodService.fetchOpenGlPeriods(),
      ]);
      _allowedDocTypes = results[0] as List<ModuleDocument>;
      _customers = results[1] as List<ArCustomer>;
      _accounts = results[2] as List<Account>;
      _currencies = results[3] as List<Currency>;
      _openPeriods = results[4] as List<PostingPeriod>;

      // Set default doc type
      if (_allowedDocTypes.isNotEmpty && _selectedDocType == null) {
        _selectedDocType = _allowedDocTypes.first;
      }
      // Set default currency (THB)
      if (_currencies.isNotEmpty) {
        try {
          _selectedCurrency = _currencies.firstWhere((c) => c.currencyCode == 'THB');
        } catch (_) {
          _selectedCurrency = _currencies.first;
        }
      }
      await _loadTransactionData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading master: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTransactionData() async {
    if (widget.transactionId == null) {
      _resetForm();
      return;
    }
    setState(() => _isLoading = true);
    try {
      final data = await _service.fetchRow(widget.transactionId!);
      final h = data.header;
      setState(() {
        _transactionId = h.id;
        _docNo = h.docNo;
        _docDate = h.docDate;
        _dueDate = h.dueDate;
        _arAccountId = h.arAccountId;
        _exchangeRate = h.exchangeRate;
        _refNoCtrl.text = h.refNo ?? '';
        _descCtrl.text = h.description ?? '';
        _status = h.status;
        _isReadOnly = widget.viewOnly || h.status != 'Draft';

        if (_allowedDocTypes.isNotEmpty) {
          try { _selectedDocType = _allowedDocTypes.firstWhere((d) => d.id == h.docId); } catch (_) {}
        }
        if (_customers.isNotEmpty) {
          try { _selectedCustomer = _customers.firstWhere((c) => c.id == h.customerId); } catch (_) {}
        }
        if (_currencies.isNotEmpty) {
          try { _selectedCurrency = _currencies.firstWhere((c) => c.id == h.currencyId); } catch (_) {
            try { _selectedCurrency = _currencies.firstWhere((c) => c.currencyCode == h.currencyCode); } catch (_) {}
          }
        }

        // Load detail rows
        for (final r in _detailRows) r.dispose();
        _detailRows = data.details.map((d) => _DetailRow.fromModel(d)).toList();

        // Load apply rows
        _applyRows = data.applies.map((a) => _ApplyRow(
          appliedToId: a.appliedToId,
          appliedToDocNo: a.appliedToDocNo ?? '',
          appliedToDocDate: a.appliedToDocDate,
          appliedToTotal: a.appliedToTotal ?? 0,
          appliedAmountLc: a.appliedAmountLc,
        )).toList();
      });
      _recalcTotals();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    setState(() {
      _transactionId = 0;
      _docNo = 'AUTO';
      _docDate = DateTime.now();
      _dueDate = null;
      _arAccountId = null;
      _exchangeRate = 1.0;
      _refNoCtrl.clear();
      _descCtrl.clear();
      _status = 'Draft';
      _isReadOnly = false;
      _selectedCustomer = null;
      for (final r in _detailRows) r.dispose();
      _detailRows = [];
      _applyRows = [];
      _openInvoices = [];
      _recalcTotals();
    });
  }

  void _onCustomerChanged(ArCustomer? customer) {
    setState(() {
      _selectedCustomer = customer;
      // Default AR account from customer
      _arAccountId = customer?.arAccountId;
      // Default due date based on credit days
      if (customer != null && customer.creditDays > 0) {
        _dueDate = _docDate.add(Duration(days: customer.creditDays));
      }
    });
    // Load open invoices for Receipt
    if (_isReceipt && customer != null) {
      _loadOpenInvoices(customer.id!);
    }
  }

  Future<void> _loadOpenInvoices(int customerId) async {
    try {
      final invoices = await _service.fetchOpenInvoices(customerId);
      setState(() => _openInvoices = invoices);
    } catch (_) {}
  }

  bool _validatePeriod(DateTime date) {
    return _openPeriods.any((p) =>
        !date.isBefore(p.periodStartDate) && !date.isAfter(p.periodEndDate));
  }

  Future<void> _selectDate(bool isDueDate) async {
    final initial = isDueDate ? (_dueDate ?? _docDate) : _docDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    if (!isDueDate && !_validatePeriod(picked)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('วันที่เอกสารต้องอยู่ในงวดบัญชีที่เปิดใช้งาน'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() {
      if (isDueDate) _dueDate = picked;
      else {
        _docDate = picked;
        if (_selectedCustomer != null && (_selectedCustomer!.creditDays) > 0) {
          _dueDate = picked.add(Duration(days: _selectedCustomer!.creditDays));
        }
      }
    });
  }

  void _addDetailRow() {
    setState(() => _detailRows.add(_DetailRow()));
  }

  void _removeDetailRow(int index) {
    setState(() {
      _detailRows[index].dispose();
      _detailRows.removeAt(index);
      _recalcTotals();
    });
  }

  void _recalcTotals() {
    double subFc = 0;
    double discFc = 0;
    double vatFc = 0;
    if (!_isReceipt) {
      for (final r in _detailRows) {
        final qty = double.tryParse(r.qtyCtrl.text) ?? 0;
        final price = double.tryParse(r.priceCtrl.text) ?? 0;
        final discPct = double.tryParse(r.discPctCtrl.text) ?? 0;
        final sub = qty * price;
        final disc = sub * discPct / 100;
        final afterDisc = sub - disc;
        final vatRate = r.vatType == 'VAT7' ? 7.0 : (r.vatType == 'VAT0' ? 0.0 : 0.0);
        final vat = r.vatType == 'NOVAT' ? 0.0 : afterDisc * vatRate / 100;
        subFc += sub;
        discFc += disc;
        vatFc += vat;
      }
    } else {
      // For receipt, total = sum of applied amounts
      double applied = 0;
      for (final a in _applyRows) {
        applied += a.appliedAmountLc;
      }
      subFc = applied;
    }
    final beforeVat = subFc - discFc;
    setState(() {
      _subtotalFc = subFc;
      _discountAmountFc = discFc;
      _beforeVatFc = beforeVat;
      _vatAmountFc = vatFc;
      _totalAmountFc = beforeVat + vatFc;
    });
  }

  Future<void> _save(String action) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDocType == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเลือกประเภทเอกสาร')));
      return;
    }
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเลือกลูกค้า')));
      return;
    }
    if (action == 'Post' && !_validatePeriod(_docDate)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('วันที่เอกสารไม่อยู่ในงวดบัญชีที่เปิด')));
      return;
    }

    _recalcTotals();
    final userName = _authService.currentUser?.userName ?? '';
    final lc = _exchangeRate;

    final header = ArTransactionHeader(
      id: _transactionId,
      docId: _selectedDocType!.id,
      docNo: _docNo,
      docDate: _docDate,
      dueDate: _dueDate,
      customerId: _selectedCustomer!.id!,
      customerCode: _selectedCustomer!.customerCode,
      customerNameTh: _selectedCustomer!.customerNameTh,
      arAccountId: _arAccountId,
      currencyId: _selectedCurrency?.id,
      currencyCode: _selectedCurrency?.currencyCode ?? 'THB',
      exchangeRate: _exchangeRate,
      subtotalFc: _subtotalFc,
      discountAmountFc: _discountAmountFc,
      beforeVatFc: _beforeVatFc,
      vatAmountFc: _vatAmountFc,
      totalAmountFc: _totalAmountFc,
      subtotalLc: _subtotalFc * lc,
      discountAmountLc: _discountAmountFc * lc,
      beforeVatLc: _beforeVatFc * lc,
      vatAmountLc: _vatAmountFc * lc,
      totalAmountLc: _totalAmountFc * lc,
      refNo: _refNoCtrl.text.isEmpty ? null : _refNoCtrl.text,
      description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
      status: _status,
      createdBy: _transactionId == 0 ? userName : null,
      updatedBy: _transactionId != 0 ? userName : null,
    );

    final details = _detailRows.asMap().entries.map((e) {
      final i = e.key;
      final r = e.value;
      final qty = double.tryParse(r.qtyCtrl.text) ?? 0;
      final price = double.tryParse(r.priceCtrl.text) ?? 0;
      final discPct = double.tryParse(r.discPctCtrl.text) ?? 0;
      final sub = qty * price;
      final disc = sub * discPct / 100;
      final afterDisc = sub - disc;
      final vatRate = r.vatType == 'VAT7' ? 7.0 : 0.0;
      final vat = r.vatType == 'NOVAT' ? 0.0 : afterDisc * vatRate / 100;
      return ArTransactionDetail(
        lineNo: i + 1,
        itemCode: r.itemCodeCtrl.text.isEmpty ? null : r.itemCodeCtrl.text,
        itemName: r.itemNameCtrl.text.isEmpty ? null : r.itemNameCtrl.text,
        description: r.descCtrl.text.isEmpty ? null : r.descCtrl.text,
        quantity: qty,
        unitPriceFc: price,
        discountPercent: discPct,
        discountAmountFc: disc,
        subtotalFc: afterDisc,
        vatType: r.vatType,
        vatRate: vatRate,
        vatAmountFc: vat,
        totalAmountFc: afterDisc + vat,
        revenueAccountId: r.revenueAccountId,
        subtotalLc: afterDisc * lc,
        vatAmountLc: vat * lc,
        totalAmountLc: (afterDisc + vat) * lc,
      );
    }).toList();

    final applies = _applyRows.map((a) => ArTransactionApply(
      appliedToId: a.appliedToId,
      appliedAmountLc: a.appliedAmountLc,
      appliedAmountFc: a.appliedAmountLc / lc,
    )).toList();

    setState(() => _isLoading = true);
    try {
      if (_transactionId == 0) {
        await _service.createTransaction(
          header: header, details: details, applies: applies, action: action,
        );
      } else {
        await _service.updateTransaction(
          id: _transactionId, header: header, details: details, applies: applies, action: action,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(action == 'Post' ? 'บันทึกและ Post เรียบร้อย' : 'บันทึก Draft เรียบร้อย')),
        );
        widget.onSaveSuccess();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _void() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันการยกเลิกเอกสาร'),
        content: const Text('เอกสารที่ยกเลิกแล้วไม่สามารถกู้คืนได้ ต้องการดำเนินการต่อ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('ยืนยัน Void')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isLoading = true);
    try {
      await _service.voidTransaction(_transactionId, voidReason: 'User request');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ยกเลิกเอกสารเรียบร้อย')));
        widget.onSaveSuccess();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---- Show customer picker dialog ----
  Future<ArCustomer?> _showCustomerPicker() async {
    final searchCtrl = TextEditingController();
    List<ArCustomer> filtered = List.from(_customers);

    return showDialog<ArCustomer>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        void doFilter() {
          final q = searchCtrl.text.toUpperCase();
          setS(() => filtered = q.isEmpty
              ? _customers
              : _customers.where((c) =>
                  c.customerCode.toUpperCase().contains(q) ||
                  c.customerNameTh.toUpperCase().contains(q)).toList());
        }
        return Dialog(
          child: SizedBox(
            width: 500, height: 500,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: searchCtrl,
                  decoration: const InputDecoration(labelText: 'ค้นหาลูกค้า', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
                  onChanged: (_) => doFilter(),
                  autofocus: true,
                ),
              ),
              Expanded(child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final c = filtered[i];
                  return ListTile(
                    dense: true,
                    title: Text('${c.customerCode} - ${c.customerNameTh}', style: const TextStyle(fontSize: 13)),
                    subtitle: c.customerNameEn != null ? Text(c.customerNameEn!, style: const TextStyle(fontSize: 11)) : null,
                    onTap: () => Navigator.pop(ctx, c),
                  );
                },
              )),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
            ]),
          ),
        );
      }),
    );
  }

  // ---- Show account picker dialog ----
  Future<Account?> _showAccountPicker() async {
    final searchCtrl = TextEditingController();
    // Only show normal accounts (can receive transactions) that are not control accounts
    final available = _accounts.where((a) => a.isNormalAccount && !a.isControlAccount && a.isActive).toList();
    List<Account> filtered = List.from(available);

    return showDialog<Account>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        void doFilter() {
          final q = searchCtrl.text.toUpperCase();
          setS(() => filtered = q.isEmpty
              ? available
              : available.where((a) =>
                  a.accountCode.toUpperCase().contains(q) ||
                  a.accountNameThai.toUpperCase().contains(q)).toList());
        }
        return Dialog(
          child: SizedBox(
            width: 520, height: 500,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: searchCtrl,
                  decoration: const InputDecoration(labelText: 'ค้นหาบัญชี', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
                  onChanged: (_) => doFilter(),
                  autofocus: true,
                ),
              ),
              Expanded(child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final a = filtered[i];
                  return ListTile(
                    dense: true,
                    title: Text('${a.accountCode} - ${a.accountNameThai}', style: const TextStyle(fontSize: 13)),
                    onTap: () => Navigator.pop(ctx, a),
                  );
                },
              )),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
            ]),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 16),
            if (!_isReceipt) ...[
              _buildDetailSection(),
              const SizedBox(height: 16),
            ],
            if (_isReceipt) ...[
              _buildApplySection(),
              const SizedBox(height: 16),
            ],
            _buildTotalsSection(),
            const SizedBox(height: 20),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.article_outlined, size: 18),
            const SizedBox(width: 6),
            Text('ข้อมูลหัวเอกสาร', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (_status != 'Draft')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _status == 'Posted' ? Colors.green[50] : Colors.red[50],
                  border: Border.all(color: _status == 'Posted' ? Colors.green : Colors.red),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_status, style: TextStyle(color: _status == 'Posted' ? Colors.green[800] : Colors.red[800], fontWeight: FontWeight.bold)),
              ),
          ]),
          const SizedBox(height: 16),
          Wrap(spacing: 16, runSpacing: 12, children: [
            // Doc type
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<ModuleDocument>(
                value: _selectedDocType,
                decoration: const InputDecoration(labelText: 'ประเภทเอกสาร *', border: OutlineInputBorder(), isDense: true),
                items: _allowedDocTypes.map((d) => DropdownMenuItem(value: d, child: Text('${d.docCode} ${d.docNameThai}'))).toList(),
                onChanged: _isReadOnly ? null : (v) {
                  setState(() {
                    _selectedDocType = v;
                    _detailRows.clear();
                    _applyRows.clear();
                    _openInvoices.clear();
                    if (_isReceipt && _selectedCustomer != null) {
                      _loadOpenInvoices(_selectedCustomer!.id!);
                    }
                    _recalcTotals();
                  });
                },
                validator: (v) => v == null ? 'กรุณาเลือก' : null,
              ),
            ),
            // Doc no
            SizedBox(
              width: 160,
              child: TextFormField(
                initialValue: _docNo == 'AUTO' ? '' : _docNo,
                decoration: InputDecoration(
                  labelText: 'เลขที่เอกสาร',
                  hintText: _selectedDocType?.isAutoNumbering == true ? 'อัตโนมัติ' : 'ระบุเลขที่',
                  border: const OutlineInputBorder(), isDense: true,
                ),
                readOnly: _isReadOnly || (_selectedDocType?.isAutoNumbering == true),
                onChanged: (v) => _docNo = v.isEmpty ? 'AUTO' : v,
              ),
            ),
            // Doc date
            InkWell(
              onTap: _isReadOnly ? null : () => _selectDate(false),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'วันที่เอกสาร *', border: OutlineInputBorder(), isDense: true),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_dateFmt.format(_docDate)),
                  const SizedBox(width: 4),
                  if (!_isReadOnly) const Icon(Icons.calendar_today, size: 14),
                ]),
              ),
            ),
            // Due date
            InkWell(
              onTap: _isReadOnly ? null : () => _selectDate(true),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'ครบกำหนด', border: OutlineInputBorder(), isDense: true),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_dueDate != null ? _dateFmt.format(_dueDate!) : '-'),
                  const SizedBox(width: 4),
                  if (!_isReadOnly) const Icon(Icons.calendar_today, size: 14),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          // Customer
          Row(children: [
            Expanded(
              flex: 3,
              child: InkWell(
                onTap: _isReadOnly ? null : () async {
                  final c = await _showCustomerPicker();
                  if (c != null) _onCustomerChanged(c);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'ลูกค้า *',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: _isReadOnly ? null : const Icon(Icons.search, size: 16),
                  ),
                  child: Text(
                    _selectedCustomer != null
                        ? '${_selectedCustomer!.customerCode} - ${_selectedCustomer!.customerNameTh}'
                        : 'คลิกเพื่อเลือกลูกค้า',
                    style: TextStyle(color: _selectedCustomer == null ? Colors.grey : null),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // AR Account
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: _isReadOnly ? null : () async {
                  // Pick from accounts that are control accounts (AR)
                  final controlAccounts = _accounts.where((a) => a.isControlAccount && a.isActive).toList();
                  List<Account> filtered = List.from(controlAccounts);
                  final searchCtrl = TextEditingController();
                  final picked = await showDialog<Account>(
                    context: context,
                    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
                      return Dialog(
                        child: SizedBox(width: 450, height: 400, child: Column(children: [
                          Padding(padding: const EdgeInsets.all(12), child: TextField(
                            controller: searchCtrl,
                            decoration: const InputDecoration(labelText: 'ค้นหาบัญชีลูกหนี้', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
                            onChanged: (q) => setS(() => filtered = q.isEmpty ? controlAccounts : controlAccounts.where((a) => a.accountCode.toUpperCase().contains(q.toUpperCase()) || a.accountNameThai.toUpperCase().contains(q.toUpperCase())).toList()),
                            autofocus: true,
                          )),
                          Expanded(child: ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) => ListTile(dense: true, title: Text('${filtered[i].accountCode} - ${filtered[i].accountNameThai}', style: const TextStyle(fontSize: 13)), onTap: () => Navigator.pop(ctx, filtered[i])),
                          )),
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
                        ])),
                      );
                    }),
                  );
                  if (picked != null) setState(() => _arAccountId = picked.id);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'บัญชีลูกหนี้',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: _isReadOnly ? null : const Icon(Icons.search, size: 16),
                  ),
                  child: Text(
                    _arAccountId != null
                        ? () { try { final a = _accounts.firstWhere((x) => x.id == _arAccountId); return '${a.accountCode} - ${a.accountNameThai}'; } catch (_) { return 'ID: $_arAccountId'; } }()
                        : 'เลือกบัญชีลูกหนี้',
                    style: TextStyle(color: _arAccountId == null ? Colors.grey : null, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          // Currency & exchange rate
          Wrap(spacing: 16, runSpacing: 12, children: [
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<Currency>(
                value: _selectedCurrency,
                decoration: const InputDecoration(labelText: 'สกุลเงิน', border: OutlineInputBorder(), isDense: true),
                items: _currencies.map((c) => DropdownMenuItem(value: c, child: Text(c.currencyCode))).toList(),
                onChanged: _isReadOnly ? null : (v) => setState(() { _selectedCurrency = v; _exchangeRate = v?.baseRate ?? 1.0; }),
              ),
            ),
            SizedBox(
              width: 140,
              child: TextFormField(
                initialValue: _exchangeRate.toStringAsFixed(6),
                decoration: const InputDecoration(labelText: 'อัตราแลกเปลี่ยน', border: OutlineInputBorder(), isDense: true),
                keyboardType: TextInputType.number,
                readOnly: _isReadOnly,
                onChanged: (v) => setState(() => _exchangeRate = double.tryParse(v) ?? 1.0),
              ),
            ),
            // Ref no
            SizedBox(
              width: 180,
              child: TextFormField(
                controller: _refNoCtrl,
                decoration: const InputDecoration(labelText: 'เลขที่อ้างอิง', border: OutlineInputBorder(), isDense: true),
                readOnly: _isReadOnly,
              ),
            ),
            // Description
            SizedBox(
              width: 300,
              child: TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'คำอธิบาย', border: OutlineInputBorder(), isDense: true),
                readOnly: _isReadOnly,
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _buildDetailSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.list_alt, size: 18),
            const SizedBox(width: 6),
            Text('รายละเอียดสินค้า/บริการ', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            if (!_isReadOnly)
              ElevatedButton.icon(
                onPressed: _addDetailRow,
                icon: const Icon(Icons.add, size: 14),
                label: const Text('เพิ่มรายการ'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700], foregroundColor: Colors.white, visualDensity: VisualDensity.compact),
              ),
          ]),
          const SizedBox(height: 12),
          if (_detailRows.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('ไม่มีรายการ', style: TextStyle(color: Colors.grey))))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.teal[50]),
                columnSpacing: 8,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 52,
                columns: [
                  const DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('รหัสสินค้า', style: TextStyle(fontWeight: FontWeight.bold))),
                  const DataColumn(label: Text('ชื่อสินค้า/บริการ', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('จำนวน', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                  DataColumn(label: Text('ราคา/หน่วย', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                  DataColumn(label: Text('ส่วนลด%', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                  DataColumn(label: Text('ยอดสุทธิ', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                  DataColumn(label: Text('VAT', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('ยอด VAT', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                  DataColumn(label: Text('รวม', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                  DataColumn(label: Text('บัญชีรายได้', style: TextStyle(fontWeight: FontWeight.bold))),
                  if (!_isReadOnly) DataColumn(label: Text('')),
                ],
                rows: _detailRows.asMap().entries.map((e) {
                  final i = e.key;
                  final r = e.value;
                  final qty = double.tryParse(r.qtyCtrl.text) ?? 0;
                  final price = double.tryParse(r.priceCtrl.text) ?? 0;
                  final discPct = double.tryParse(r.discPctCtrl.text) ?? 0;
                  final sub = qty * price;
                  final disc = sub * discPct / 100;
                  final afterDisc = sub - disc;
                  final vatRate = r.vatType == 'VAT7' ? 7.0 : 0.0;
                  final vat = r.vatType == 'NOVAT' ? 0.0 : afterDisc * vatRate / 100;
                  final total = afterDisc + vat;
                  final accName = r.revenueAccountId != null
                      ? () { try { final a = _accounts.firstWhere((x) => x.id == r.revenueAccountId); return '${a.accountCode}'; } catch (_) { return ''; } }()
                      : '';

                  return DataRow(cells: [
                    DataCell(Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                    DataCell(SizedBox(width: 90, child: TextFormField(
                      controller: r.itemCodeCtrl,
                      decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                      style: const TextStyle(fontSize: 12),
                      readOnly: _isReadOnly,
                    ))),
                    DataCell(SizedBox(width: 160, child: TextFormField(
                      controller: r.itemNameCtrl,
                      decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                      style: const TextStyle(fontSize: 12),
                      readOnly: _isReadOnly,
                    ))),
                    DataCell(SizedBox(width: 70, child: TextFormField(
                      controller: r.qtyCtrl,
                      decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                      style: const TextStyle(fontSize: 12),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      textAlign: TextAlign.right,
                      readOnly: _isReadOnly,
                      onChanged: (_) => setState(() => _recalcTotals()),
                    ))),
                    DataCell(SizedBox(width: 100, child: TextFormField(
                      controller: r.priceCtrl,
                      decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                      style: const TextStyle(fontSize: 12),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      textAlign: TextAlign.right,
                      readOnly: _isReadOnly,
                      onChanged: (_) => setState(() => _recalcTotals()),
                    ))),
                    DataCell(SizedBox(width: 60, child: TextFormField(
                      controller: r.discPctCtrl,
                      decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                      style: const TextStyle(fontSize: 12),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      textAlign: TextAlign.right,
                      readOnly: _isReadOnly,
                      onChanged: (_) => setState(() => _recalcTotals()),
                    ))),
                    DataCell(Text(_fmt.format(afterDisc), style: const TextStyle(fontSize: 12))),
                    DataCell(SizedBox(width: 90, child: _isReadOnly
                        ? Text(r.vatType, style: const TextStyle(fontSize: 12))
                        : DropdownButtonHideUnderline(child: DropdownButton<String>(
                            value: r.vatType,
                            isDense: true,
                            style: const TextStyle(fontSize: 12, color: Colors.black),
                            items: vatTypeOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                            onChanged: (v) => setState(() { r.vatType = v!; _recalcTotals(); }),
                          )))),
                    DataCell(Text(_fmt.format(vat), style: const TextStyle(fontSize: 12))),
                    DataCell(Text(_fmt.format(total), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                    DataCell(SizedBox(width: 120, child: InkWell(
                      onTap: _isReadOnly ? null : () async {
                        final a = await _showAccountPicker();
                        if (a != null) setState(() => r.revenueAccountId = a.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)),
                        child: Text(accName.isEmpty ? 'เลือกบัญชี' : accName, style: TextStyle(fontSize: 11, color: accName.isEmpty ? Colors.grey : null), overflow: TextOverflow.ellipsis),
                      ),
                    ))),
                    if (!_isReadOnly)
                      DataCell(IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red), onPressed: () => _removeDetailRow(i), visualDensity: VisualDensity.compact)),
                  ]);
                }).toList(),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildApplySection() {
    final totalApplied = _applyRows.fold(0.0, (s, a) => s + a.appliedAmountLc);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.link, size: 18),
            const SizedBox(width: 6),
            Text('จับคู่ชำระหนี้', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          if (_openInvoices.isEmpty && _selectedCustomer != null)
            const Text('ไม่พบใบแจ้งหนี้ค้างชำระ', style: TextStyle(color: Colors.grey))
          else if (_selectedCustomer == null)
            const Text('กรุณาเลือกลูกค้าก่อน', style: TextStyle(color: Colors.grey))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.teal[50]),
                columnSpacing: 12,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 46,
                columns: const [
                  DataColumn(label: Text('เลขที่ใบแจ้งหนี้', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('วันที่', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('ยอดรวม', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                  DataColumn(label: Text('คงเหลือ', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                  DataColumn(label: Text('ชำระ', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                ],
                rows: _openInvoices.map((inv) {
                  final existing = _applyRows.where((a) => a.appliedToId == inv.id).firstOrNull;
                  final applyCtrl = TextEditingController(text: existing?.appliedAmountLc.toStringAsFixed(2) ?? '');
                  return DataRow(cells: [
                    DataCell(Text(inv.docNo, style: const TextStyle(fontSize: 12))),
                    DataCell(Text(_dateFmt.format(inv.docDate), style: const TextStyle(fontSize: 12))),
                    DataCell(Text(_fmt.format(inv.totalAmountLc), style: const TextStyle(fontSize: 12))),
                    DataCell(Text(_fmt.format(inv.balanceAmountLc), style: const TextStyle(fontSize: 12, color: Colors.blue))),
                    DataCell(SizedBox(width: 100, child: TextFormField(
                      controller: applyCtrl,
                      decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                      style: const TextStyle(fontSize: 12),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      readOnly: _isReadOnly,
                      onChanged: (v) {
                        final amount = double.tryParse(v) ?? 0;
                        final idx = _applyRows.indexWhere((a) => a.appliedToId == inv.id);
                        if (amount <= 0) {
                          if (idx >= 0) setState(() => _applyRows.removeAt(idx));
                        } else {
                          final applyRow = _ApplyRow(
                            appliedToId: inv.id,
                            appliedToDocNo: inv.docNo,
                            appliedToDocDate: inv.docDate,
                            appliedToTotal: inv.totalAmountLc,
                            appliedAmountLc: amount,
                          );
                          setState(() {
                            if (idx >= 0) _applyRows[idx] = applyRow;
                            else _applyRows.add(applyRow);
                            _recalcTotals();
                          });
                        }
                      },
                    ))),
                  ]);
                }).toList(),
              ),
            ),
          const SizedBox(height: 8),
          Text('ยอดรวมชำระ: ${_fmt.format(totalApplied)} ${_selectedCurrency?.currencyCode ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _buildTotalsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          SizedBox(
            width: 320,
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                if (!_isReceipt) ...[
                  _totalRow('ยอดรวมสินค้า', _subtotalFc),
                  _totalRow('ส่วนลดรวม', _discountAmountFc),
                  _totalRow('ยอดก่อน VAT', _beforeVatFc),
                  _totalRow('VAT', _vatAmountFc),
                ],
                TableRow(children: [
                  const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('ยอดรวมสุทธิ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(
                    '${_fmt.format(_totalAmountFc)} ${_selectedCurrency?.currencyCode ?? 'THB'}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    textAlign: TextAlign.right,
                  )),
                ]),
                if (_exchangeRate != 1.0)
                  _totalRow('ยอดรวม (THB)', _totalAmountFc * _exchangeRate),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  TableRow _totalRow(String label, double amount) {
    return TableRow(children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(label, style: const TextStyle(fontSize: 13))),
      Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(_fmt.format(amount), textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
    ]);
  }

  Widget _buildActionButtons() {
    final isDraft = _status == 'Draft';
    final isPosted = _status == 'Posted';
    return Row(children: [
      if (!_isReadOnly && isDraft) ...[
        ElevatedButton.icon(
          onPressed: () => _save('Draft'),
          icon: const Icon(Icons.save_outlined, size: 16),
          label: const Text('บันทึก Draft'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700], foregroundColor: Colors.white),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => _save('Post'),
          icon: const Icon(Icons.check_circle_outline, size: 16),
          label: const Text('Post เอกสาร'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[700], foregroundColor: Colors.white),
        ),
        const SizedBox(width: 8),
        if (_transactionId != 0)
          OutlinedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('ลบ Draft'),
                  content: const Text('ต้องการลบเอกสาร Draft นี้?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
                    ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('ลบ')),
                  ],
                ),
              );
              if (confirm == true) {
                await _service.deleteTransaction(_transactionId);
                if (mounted) widget.onSaveSuccess();
              }
            },
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('ลบ'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          ),
      ],
      if (isPosted && !widget.viewOnly)
        ElevatedButton.icon(
          onPressed: _void,
          icon: const Icon(Icons.cancel_outlined, size: 16),
          label: const Text('ยกเลิก (Void)'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
        ),
      const Spacer(),
      TextButton(
        onPressed: widget.onCancel,
        child: const Text('กลับ'),
      ),
    ]);
  }
}

// ---- Helper: editable detail row state ----
class _DetailRow {
  final TextEditingController itemCodeCtrl;
  final TextEditingController itemNameCtrl;
  final TextEditingController descCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController discPctCtrl;
  String vatType;
  int? revenueAccountId;

  _DetailRow({
    String? itemCode,
    String? itemName,
    String? desc,
    double qty = 1,
    double price = 0,
    double discPct = 0,
    this.vatType = 'VAT7',
    this.revenueAccountId,
  })  : itemCodeCtrl = TextEditingController(text: itemCode ?? ''),
        itemNameCtrl = TextEditingController(text: itemName ?? ''),
        descCtrl = TextEditingController(text: desc ?? ''),
        qtyCtrl = TextEditingController(text: qty.toString()),
        priceCtrl = TextEditingController(text: price.toStringAsFixed(2)),
        discPctCtrl = TextEditingController(text: discPct.toStringAsFixed(2));

  factory _DetailRow.fromModel(ArTransactionDetail d) {
    return _DetailRow(
      itemCode: d.itemCode,
      itemName: d.itemName,
      desc: d.description,
      qty: d.quantity,
      price: d.unitPriceFc,
      discPct: d.discountPercent,
      vatType: d.vatType,
      revenueAccountId: d.revenueAccountId,
    );
  }

  void dispose() {
    itemCodeCtrl.dispose();
    itemNameCtrl.dispose();
    descCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
    discPctCtrl.dispose();
  }
}

// ---- Helper: apply row state ----
class _ApplyRow {
  final int appliedToId;
  final String appliedToDocNo;
  final DateTime? appliedToDocDate;
  final double appliedToTotal;
  double appliedAmountLc;

  _ApplyRow({
    required this.appliedToId,
    required this.appliedToDocNo,
    this.appliedToDocDate,
    this.appliedToTotal = 0,
    this.appliedAmountLc = 0,
  });
}
