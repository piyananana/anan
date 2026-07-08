// lib/cm/screens/cm_petty_cash_replenishment_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../../sa/services/auth_service.dart';
import '../../cm/models/cm_bank_account.dart';
import '../services/cm_period_service.dart';

const _kTheme = Color(0xFF1565C0);
final _fmt     = NumberFormat('#,##0.00', 'en_US');
final _dateFmt = DateFormat('dd/MM/yyyy');

const Map<String, String> _statusLabels = {
  'Draft':  'ร่าง',
  'Posted': 'บันทึก GL แล้ว',
  'Voided': 'ยกเลิก',
};

Color _statusColor(String s) {
  switch (s) {
    case 'Posted': return Colors.green.shade700;
    case 'Voided': return Colors.grey.shade600;
    default:       return Colors.blue.shade700;
  }
}

class CmPettyCashReplenishmentScreen extends StatefulWidget {
  const CmPettyCashReplenishmentScreen({super.key});
  @override
  State<CmPettyCashReplenishmentScreen> createState() => _State();
}

class _State extends State<CmPettyCashReplenishmentScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _leftExpanded = true;

  // Left panel
  List<Map<String, dynamic>> _list = [];
  bool _loadingList = false;
  String _statusFilter = 'All';
  List<CmBankAccount> _pettyCashAccounts = [];
  CmBankAccount?      _filterAccount;

  // Right panel
  Map<String, dynamic>? _selRpl;
  bool _isNew = false;
  bool _saving = false;
  bool _posting = false;

  // Form
  late DateTime _rplDate;
  CmBankAccount? _selPettyCashAccount;
  CmBankAccount? _selSourceAccount;
  final _descCtrl = TextEditingController();
  List<Map<String, dynamic>> _glDocTypes = [];
  int? _selGlDocId;
  List<Map<String, dynamic>> _pendingVouchers = [];
  bool _loadingVouchers = false;
  List<Map<String, dynamic>> _postedVouchers = [];

  List<CmBankAccount> _bankAccounts = [];

  @override
  void initState() {
    super.initState();
    _rplDate = DateTime.now();
    _loadAccounts();
    _loadGlDocTypes();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final headers = await AuthService().getAuthHeader();
      final resp = await http.get(Uri.parse('${AppConfig.apiCm}/cm_bank_account/active'), headers: headers);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final all = (json.decode(resp.body) as List)
            .map((j) => CmBankAccount.fromJson(j as Map<String, dynamic>))
            .toList();
        setState(() {
          _pettyCashAccounts = all.where((a) => a.cmType == 'PETTY_CASH').toList();
          _bankAccounts      = all.where((a) => a.cmType == 'BANK').toList();
        });
        await _loadList();
      }
    } catch (e) { _showError(e.toString()); }
  }

  Future<void> _loadGlDocTypes() async {
    try {
      final headers = await AuthService().getAuthHeader();
      final resp = await http.get(
          Uri.parse('${AppConfig.apiSa}/sa_module_document?is_active=true'), headers: headers);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final all = List<Map<String, dynamic>>.from(json.decode(resp.body) as List);
        setState(() => _glDocTypes = all.where((d) => d['is_doc_type'] == true).toList());
      }
    } catch (_) {}
  }

  Future<void> _loadList() async {
    setState(() => _loadingList = true);
    try {
      final headers = await AuthService().getAuthHeader();
      final params = <String, String>{};
      if (_statusFilter != 'All') params['status'] = _statusFilter;
      if (_filterAccount != null) params['petty_cash_account_id'] = _filterAccount!.id!.toString();
      final uri = Uri.parse('${AppConfig.apiCm}/cm_petty_cash_replenishment')
          .replace(queryParameters: params.isNotEmpty ? params : null);
      final resp = await http.get(uri, headers: headers);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        setState(() {
          _list = List<Map<String, dynamic>>.from(json.decode(resp.body) as List);
          _loadingList = false;
        });
      } else {
        throw Exception(json.decode(resp.body)['error'] ?? resp.body);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingList = false);
      _showError(e.toString());
    }
  }

  Future<void> _loadPendingVouchers(int pettyCashAccountId) async {
    setState(() { _loadingVouchers = true; _pendingVouchers = []; });
    try {
      final headers = await AuthService().getAuthHeader();
      final uri = Uri.parse('${AppConfig.apiCm}/cm_petty_cash_replenishment/pending_vouchers')
          .replace(queryParameters: {'petty_cash_account_id': pettyCashAccountId.toString()});
      final resp = await http.get(uri, headers: headers);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        setState(() {
          _pendingVouchers = List<Map<String, dynamic>>.from(json.decode(resp.body) as List);
          _loadingVouchers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingVouchers = false);
    }
  }

  Future<void> _loadPostedVouchers(int rplId) async {
    try {
      final headers = await AuthService().getAuthHeader();
      final resp = await http.get(
          Uri.parse('${AppConfig.apiCm}/cm_petty_cash_replenishment/$rplId/vouchers'), headers: headers);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        setState(() => _postedVouchers = List<Map<String, dynamic>>.from(json.decode(resp.body) as List));
      }
    } catch (_) {}
  }

  void _startNew() {
    setState(() {
      _selRpl = null;
      _isNew  = true;
      _rplDate = DateTime.now();
      _selPettyCashAccount = _pettyCashAccounts.isNotEmpty ? _pettyCashAccounts.first : null;
      _selSourceAccount    = _bankAccounts.isNotEmpty     ? _bankAccounts.first     : null;
      _selGlDocId   = null;
      _descCtrl.text = '';
      _pendingVouchers = [];
      _postedVouchers  = [];
    });
    if (_selPettyCashAccount != null) _loadPendingVouchers(_selPettyCashAccount!.id!);
  }

  void _selectRpl(Map<String, dynamic> rpl) {
    setState(() {
      _selRpl = rpl;
      _isNew  = false;
      try { _rplDate = DateTime.parse(rpl['replenishment_date'].toString()); } catch (_) {}
      _selPettyCashAccount = _pettyCashAccounts.where((a) => a.id == rpl['petty_cash_account_id']).firstOrNull;
      _selSourceAccount    = _bankAccounts.where((a) => a.id == rpl['source_bank_account_id']).firstOrNull;
      _selGlDocId   = rpl['gl_doc_id'] as int?;
      _descCtrl.text = rpl['description'] ?? '';
      _pendingVouchers = [];
      _postedVouchers  = [];
    });
    if (rpl['status'] == 'Posted') _loadPostedVouchers(rpl['id'] as int);
    if (rpl['status'] == 'Draft' && _selPettyCashAccount != null) {
      _loadPendingVouchers(_selPettyCashAccount!.id!);
    }
  }

  Future<void> _save() async {
    if (_selPettyCashAccount == null) { _showError('กรุณาเลือกกองทุนเงินสดย่อย'); return; }
    setState(() => _saving = true);
    try {
      final headers = {...await AuthService().getAuthHeader(), 'Content-Type': 'application/json'};
      final body = json.encode({
        'replenishment_date':     DateFormat('yyyy-MM-dd').format(_rplDate),
        'petty_cash_account_id':  _selPettyCashAccount!.id,
        'source_bank_account_id': _selSourceAccount?.id,
        'gl_doc_id':              _selGlDocId,
        'description':            _descCtrl.text.trim(),
        'total_amount':           0,
      });
      http.Response resp;
      if (_isNew) {
        resp = await http.post(Uri.parse('${AppConfig.apiCm}/cm_petty_cash_replenishment'),
            headers: headers, body: body);
      } else {
        resp = await http.put(
            Uri.parse('${AppConfig.apiCm}/cm_petty_cash_replenishment/${_selRpl!['id']}'),
            headers: headers, body: body);
      }
      if (!mounted) return;
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final saved = json.decode(resp.body) as Map<String, dynamic>;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_isNew ? 'สร้างใบเบิกชดเชยแล้ว: ${saved['replenishment_no']}' : 'บันทึกแล้ว'),
                backgroundColor: Colors.green.shade700));
        await _loadList();
        _selectRpl(saved);
        if (_selPettyCashAccount != null) _loadPendingVouchers(_selPettyCashAccount!.id!);
      } else {
        throw Exception(json.decode(resp.body)['error'] ?? resp.body);
      }
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _post() async {
    if (_selRpl == null) return;
    if (_pendingVouchers.isEmpty) {
      _showError('ไม่มีวาวเชอร์ที่ Approved รอการเบิกชดเชย');
      return;
    }
    if (!await CmPeriodService.canPost(context, _rplDate)) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยัน Post GL'),
        content: Text('ต้องการบันทึก GL สำหรับ ${_selRpl!['replenishment_no']} '
            'จำนวน ${_pendingVouchers.length} วาวเชอร์ รวม '
            '${_fmt.format(_pendingVouchers.fold<double>(0.0, (s, v) => s + (double.tryParse(v['amount']?.toString() ?? '0') ?? 0)))} บาท?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Post GL'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _posting = true);
    try {
      final headers = await AuthService().getAuthHeader();
      final resp = await http.put(
          Uri.parse('${AppConfig.apiCm}/cm_petty_cash_replenishment/${_selRpl!['id']}/post'),
          headers: headers);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final result = json.decode(resp.body) as Map<String, dynamic>;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Post GL สำเร็จ: ${result['gl_doc_no']} จำนวน ${_fmt.format(double.tryParse(result['total_amount']?.toString() ?? '0') ?? 0)} บาท'),
                backgroundColor: Colors.green.shade700));
        await _loadList();
        // refresh
        final refreshed = _list.where((r) => r['id'] == _selRpl!['id']).toList();
        if (refreshed.isNotEmpty) _selectRpl(refreshed.first);
      } else {
        throw Exception(json.decode(resp.body)['error'] ?? resp.body);
      }
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _void() async {
    if (_selRpl == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันยกเลิก'),
        content: Text('ยกเลิก ${_selRpl!['replenishment_no']} ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ไม่')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยกเลิก'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final headers = await AuthService().getAuthHeader();
      final resp = await http.put(
          Uri.parse('${AppConfig.apiCm}/cm_petty_cash_replenishment/${_selRpl!['id']}/void'),
          headers: headers);
      if (!mounted) return;
      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ยกเลิกแล้ว'), backgroundColor: Colors.orange));
        await _loadList();
        final refreshed = _list.where((r) => r['id'] == _selRpl!['id']).toList();
        if (refreshed.isNotEmpty) _selectRpl(refreshed.first);
      } else {
        throw Exception(json.decode(resp.body)['error'] ?? resp.body);
      }
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDraft  = _selRpl?['status'] == 'Draft';
    final isPosted = _selRpl?['status'] == 'Posted';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kTheme,
        foregroundColor: Colors.white,
        title: const Text('เบิกชดเชยเงินสดย่อย'),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        toolbarHeight: 40,
        actions: [
          if (_isNew || isDraft) ...[
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save, size: 16),
              label: const Text('บันทึก', style: TextStyle(fontSize: 13)),
            ),
          ],
          if (isDraft) ...[
            const SizedBox(width: 4),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: _posting ? null : _post,
              icon: _posting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.account_balance, size: 16),
              label: const Text('Post GL', style: TextStyle(fontSize: 13)),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.amber.shade200),
              onPressed: _void,
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('ยกเลิก', style: TextStyle(fontSize: 13)),
            ),
          ],
          if (!_isNew && !isDraft && !isPosted) const SizedBox.shrink(),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 36, color: _kTheme,
            child: IconButton(
              padding: EdgeInsets.zero, iconSize: 20, color: Colors.white,
              icon: Icon(_leftExpanded ? Icons.chevron_left : Icons.chevron_right),
              onPressed: () => setState(() => _leftExpanded = !_leftExpanded),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _leftExpanded ? 280 : 0,
            child: ClipRect(child: OverflowBox(
              alignment: Alignment.centerLeft, maxWidth: 280,
              child: _buildLeftPanel(),
            )),
          ),
          if (_leftExpanded) const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: _buildRightPanel()),
        ],
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Container(
      color: Colors.blueGrey.shade100,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(height: 36, color: Colors.blueGrey.shade200,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              const Expanded(child: Text('ใบเบิกชดเชย', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              IconButton(
                icon: const Icon(Icons.add, size: 18), onPressed: _startNew,
                padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28),
                tooltip: 'สร้างใหม่',
              ),
            ])),
        // Filter
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.blueGrey.shade50,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropdownButtonFormField<String>(
              value: _statusFilter,
              isDense: true,
              decoration: InputDecoration(labelText: 'สถานะ', isDense: true,
                  filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4))),
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              items: const [
                DropdownMenuItem(value: 'All',    child: Text('ทั้งหมด')),
                DropdownMenuItem(value: 'Draft',  child: Text('ร่าง')),
                DropdownMenuItem(value: 'Posted', child: Text('บันทึก GL แล้ว')),
                DropdownMenuItem(value: 'Voided', child: Text('ยกเลิก')),
              ],
              onChanged: (v) => setState(() { _statusFilter = v ?? 'All'; _loadList(); }),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<CmBankAccount?>(
              value: _filterAccount,
              isDense: true,
              decoration: InputDecoration(labelText: 'กองทุน', isDense: true,
                  filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4))),
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              items: [
                const DropdownMenuItem<CmBankAccount?>(value: null, child: Text('ทุกกองทุน')),
                ..._pettyCashAccounts.map((a) => DropdownMenuItem<CmBankAccount?>(
                  value: a,
                  child: Text('${a.accountCode} ${a.accountNameTh}', style: const TextStyle(fontSize: 12)),
                )),
              ],
              onChanged: (v) => setState(() { _filterAccount = v; _loadList(); }),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(child: _loadingList
            ? const Center(child: CircularProgressIndicator())
            : _list.isEmpty
                ? Center(child: Text('ไม่มีรายการ', style: TextStyle(color: Colors.grey.shade400)))
                : ListView.builder(
                    itemCount: _list.length,
                    itemBuilder: (_, i) {
                      final r = _list[i];
                      final sel = (_selRpl?['id']) == r['id'];
                      DateTime? dt;
                      try { dt = DateTime.parse(r['replenishment_date'].toString()); } catch (_) {}
                      return InkWell(
                        onTap: () => _selectRpl(r),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          color: sel ? _kTheme.withOpacity(0.10) : null,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text(r['replenishment_no'] ?? '',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                                      color: sel ? _kTheme : Colors.black87))),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: _statusColor(r['status'] ?? '').withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(_statusLabels[r['status']] ?? r['status'] ?? '',
                                    style: TextStyle(fontSize: 10, color: _statusColor(r['status'] ?? ''))),
                              ),
                            ]),
                            Text(dt != null ? _dateFmt.format(dt) : '',
                                style: const TextStyle(fontSize: 11, color: Colors.black45)),
                            Text('${r['petty_cash_account_code'] ?? ''} — ${_fmt.format(double.tryParse(r['total_amount']?.toString() ?? '0') ?? 0)} บาท',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          ]),
                        ),
                      );
                    },
                  )),
      ]),
    );
  }

  Widget _buildRightPanel() {
    if (!_isNew && _selRpl == null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.savings, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 8),
        Text('เลือกรายการ หรือกด + เพื่อสร้างใหม่',
            style: TextStyle(color: Colors.grey.shade400)),
      ]));
    }

    final status = _selRpl?['status'] as String? ?? 'Draft';
    final isDraft = _isNew || status == 'Draft';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header info (read-only for Posted/Voided)
        if (!_isNew && _selRpl != null)
          _infoRow('เลขที่', _selRpl!['replenishment_no'] ?? '', bold: true),
        const SizedBox(height: 12),
        Wrap(spacing: 16, runSpacing: 12, children: [
          _fieldLabel('วันที่:', _datePickerWidget(_rplDate, isDraft ? (d) => setState(() => _rplDate = d) : null)),
          _fieldLabel('กองทุนเงินสดย่อย *:', SizedBox(
            width: 260,
            child: DropdownButtonFormField<CmBankAccount?>(
              value: _selPettyCashAccount,
              isDense: true,
              decoration: InputDecoration(isDense: true, filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4))),
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              items: _pettyCashAccounts.map((a) => DropdownMenuItem<CmBankAccount?>(
                value: a,
                child: Text('${a.accountCode} ${a.accountNameTh}', style: const TextStyle(fontSize: 12)),
              )).toList(),
              onChanged: isDraft ? (v) {
                setState(() { _selPettyCashAccount = v; _pendingVouchers = []; });
                if (v != null) _loadPendingVouchers(v.id!);
              } : null,
            ),
          )),
          _fieldLabel('บัญชีธนาคารต้นทาง *:', SizedBox(
            width: 260,
            child: DropdownButtonFormField<CmBankAccount?>(
              value: _selSourceAccount,
              isDense: true,
              decoration: InputDecoration(isDense: true, filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4))),
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              items: _bankAccounts.map((a) => DropdownMenuItem<CmBankAccount?>(
                value: a,
                child: Text('${a.accountCode} ${a.accountNameTh}', style: const TextStyle(fontSize: 12)),
              )).toList(),
              onChanged: isDraft ? (v) => setState(() => _selSourceAccount = v) : null,
            ),
          )),
          _fieldLabel('ประเภทเอกสาร GL:', SizedBox(
            width: 220,
            child: DropdownButtonFormField<int?>(
              value: _selGlDocId,
              isDense: true,
              decoration: InputDecoration(isDense: true, filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4))),
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              hint: const Text('— ไม่ระบุ —', style: TextStyle(fontSize: 12)),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('— ไม่ระบุ —', style: TextStyle(fontSize: 12))),
                ..._glDocTypes.map((d) => DropdownMenuItem<int?>(
                  value: d['id'] as int?,
                  child: Text('${d['doc_code']} ${d['doc_name_thai']}', style: const TextStyle(fontSize: 12)),
                )),
              ],
              onChanged: isDraft ? (v) => setState(() => _selGlDocId = v) : null,
            ),
          )),
        ]),
        const SizedBox(height: 8),
        _fieldLabel('คำอธิบาย:', SizedBox(
          width: 400,
          child: TextField(
            controller: _descCtrl,
            enabled: isDraft,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                filled: true, fillColor: Colors.white),
          ),
        )),
        const SizedBox(height: 16),

        // Vouchers section
        Row(children: [
          Text(status == 'Posted' ? 'วาวเชอร์ที่รวมในการเบิกชดเชย' : 'วาวเชอร์ที่รออนุมัติการเบิกชดเชย',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          if (_loadingVouchers) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        ]),
        const SizedBox(height: 8),
        _buildVoucherTable(status == 'Posted' ? _postedVouchers : _pendingVouchers),

        // GL info for posted
        if (status == 'Posted' && _selRpl != null) ...[
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Row(children: [
            _infoRow('GL Doc No', _selRpl!['gl_doc_no'] ?? '—', bold: true),
            const SizedBox(width: 24),
            _infoRow('ยอดรวม', _fmt.format(double.tryParse(_selRpl!['total_amount']?.toString() ?? '0') ?? 0)),
          ]),
        ],
      ]),
    );
  }

  Widget _buildVoucherTable(List<Map<String, dynamic>> vouchers) {
    if (vouchers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(_selPettyCashAccount == null ? 'เลือกกองทุนเงินสดย่อยก่อน' : 'ไม่มีวาวเชอร์ที่รออนุมัติ',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
      );
    }
    final total = vouchers.fold<double>(0, (s, v) => s + (double.tryParse(v['amount']?.toString() ?? '0') ?? 0));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 32, dataRowMinHeight: 30, dataRowMaxHeight: 36,
          columnSpacing: 14,
          headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
          headingTextStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          columns: const [
            DataColumn(label: Text('เลขที่')),
            DataColumn(label: Text('วันที่')),
            DataColumn(label: Text('คำอธิบาย')),
            DataColumn(label: Text('บัญชีค่าใช้จ่าย')),
            DataColumn(label: Text('จำนวนเงิน'), numeric: true),
          ],
          rows: vouchers.map((v) {
            DateTime? dt;
            try { dt = DateTime.parse(v['voucher_date'].toString()); } catch (_) {}
            return DataRow(cells: [
              DataCell(Text(v['voucher_no'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              DataCell(Text(dt != null ? _dateFmt.format(dt) : '', style: const TextStyle(fontSize: 12))),
              DataCell(SizedBox(width: 150, child: Text(v['description'] ?? '',
                  style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
              DataCell(Text('${v['expense_gl_account_code'] ?? ''} ${v['expense_gl_account_name'] ?? ''}',
                  style: const TextStyle(fontSize: 11))),
              DataCell(Text(_fmt.format(double.tryParse(v['amount']?.toString() ?? '0') ?? 0),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
            ]);
          }).toList(),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 6, right: 8),
        child: Align(alignment: Alignment.centerRight,
            child: Text('รวม ${vouchers.length} รายการ: ${_fmt.format(total)} บาท',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
      ),
    ]);
  }

  Widget _infoRow(String label, String value, {bool bold = false}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      Text(value, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
    ]);
  }

  Widget _fieldLabel(String label, Widget child) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      const SizedBox(height: 2),
      child,
    ]);
  }

  Widget _datePickerWidget(DateTime value, void Function(DateTime)? onPick) {
    return InkWell(
      onTap: onPick == null ? null : () async {
        final p = await showDatePicker(context: context, initialDate: value,
            firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (p != null) onPick(p);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: onPick == null ? Colors.grey.shade100 : Colors.white,
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(_dateFmt.format(value), style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          Icon(Icons.calendar_today, size: 13, color: Colors.grey.shade500),
        ]),
      ),
    );
  }
}
