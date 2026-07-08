// lib/cm/screens/cm_inter_bank_transfer_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../../sa/services/auth_service.dart';
import '../models/cm_bank_account.dart';
import '../models/cm_inter_bank_transfer.dart';
import '../services/cm_bank_account_service.dart';
import '../services/cm_inter_bank_transfer_service.dart';
import '../services/cm_period_service.dart';

const _kTheme = Color(0xFF1565C0);
final _fmt     = NumberFormat('#,##0.00', 'en_US');
final _dateFmt = DateFormat('dd/MM/yyyy');

class CmInterBankTransferScreen extends StatefulWidget {
  const CmInterBankTransferScreen({super.key});
  @override
  State<CmInterBankTransferScreen> createState() => _State();
}

class _State extends State<CmInterBankTransferScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _accSvc = CmBankAccountService();
  final _txSvc  = CmInterBankTransferService();

  bool _leftExpanded = true;
  List<CmBankAccount>        _accounts  = [];
  List<CmInterBankTransfer>  _txList    = [];
  List<Map<String, dynamic>> _glDocTypes = [];
  CmInterBankTransfer? _selected;
  bool _isCreating = false;
  bool _loadingList = false;

  // Form state
  DateTime _fDate = DateTime.now();
  CmBankAccount? _fFromAcc, _fToAcc;
  final _fAmountCtrl = TextEditingController();
  final _fRateCtrl   = TextEditingController(text: '1');
  final _fAmountLcCtrl = TextEditingController();
  final _fDescCtrl   = TextEditingController();
  Map<String, dynamic>? _fGlDoc;
  bool _saving = false;

  DateTime? _filterFrom;
  DateTime? _filterTo;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _filterFrom = DateTime(now.year, now.month, 1);
    _filterTo   = DateTime(now.year, now.month + 1, 0);
    _loadMasterData();
  }

  @override
  void dispose() {
    _fAmountCtrl.dispose();
    _fRateCtrl.dispose();
    _fAmountLcCtrl.dispose();
    _fDescCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMasterData() async {
    try {
      final results = await Future.wait([
        _accSvc.fetchRows(),
        _fetchGlDocTypes(),
      ]);
      if (!mounted) return;
      setState(() {
        _accounts   = (results[0] as List<CmBankAccount>).where((a) => a.cmType == 'BANK' && a.isActive).toList();
        _glDocTypes = results[1] as List<Map<String, dynamic>>;
      });
      await _loadList();
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<List<Map<String, dynamic>>> _fetchGlDocTypes() async {
    final headers = await AuthService().getAuthHeader();
    final uri = Uri.parse('${AppConfig.apiSa}/sa_module_document')
        .replace(queryParameters: {'is_active': 'true'});
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode != 200) return [];
    final all = List<Map<String, dynamic>>.from(json.decode(resp.body) as List);
    return all.where((d) =>
        (d['is_doc_type'] == true || d['is_doc_type'] == 1) &&
        d['sys_module'] == '01' &&
        (d['is_active'] == true || d['is_active'] == 1)).toList();
  }

  Future<void> _loadList() async {
    setState(() => _loadingList = true);
    try {
      final df = _filterFrom != null ? DateFormat('yyyy-MM-dd').format(_filterFrom!) : null;
      final dt = _filterTo   != null ? DateFormat('yyyy-MM-dd').format(_filterTo!)   : null;
      final list = await _txSvc.fetchRows(dateFrom: df, dateTo: dt);
      if (!mounted) return;
      setState(() { _txList = list; _loadingList = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingList = false);
      _showError(e.toString());
    }
  }

  void _startCreate() {
    setState(() {
      _selected   = null;
      _isCreating = true;
      _fDate      = DateTime.now();
      _fFromAcc   = null;
      _fToAcc     = null;
      _fAmountCtrl.text   = '';
      _fRateCtrl.text     = '1';
      _fAmountLcCtrl.text = '';
      _fDescCtrl.text     = '';
      _fGlDoc     = null;
    });
  }

  void _startEdit(CmInterBankTransfer tx) {
    setState(() {
      _selected   = tx;
      _isCreating = false;
      _fDate      = tx.transferDate;
      _fFromAcc   = _accounts.firstWhere((a) => a.id == tx.fromBankAccountId, orElse: () => _accounts.first);
      _fToAcc     = _accounts.firstWhere((a) => a.id == tx.toBankAccountId,   orElse: () => _accounts.first);
      _fAmountCtrl.text   = tx.amount.toString();
      _fRateCtrl.text     = tx.exchangeRate.toString();
      _fAmountLcCtrl.text = tx.amountLc.toString();
      _fDescCtrl.text     = tx.description ?? '';
      _fGlDoc     = tx.glDocId != null
          ? _glDocTypes.firstWhere((d) => d['id'] == tx.glDocId, orElse: () => <String, dynamic>{})
          : null;
      if (_fGlDoc?.isEmpty ?? false) _fGlDoc = null;
    });
  }

  void _recalcLc() {
    final amt  = double.tryParse(_fAmountCtrl.text)  ?? 0;
    final rate = double.tryParse(_fRateCtrl.text)    ?? 1;
    final lc   = amt * rate;
    _fAmountLcCtrl.text = lc.toStringAsFixed(4);
  }

  bool get _isFcy => (_fFromAcc?.currencyCode ?? 'THB') != 'THB';

  Future<void> _save() async {
    if (_fFromAcc == null || _fToAcc == null) { _showError('กรุณาเลือกบัญชีต้นทางและปลายทาง'); return; }
    if (_fFromAcc!.id == _fToAcc!.id) { _showError('บัญชีต้นทางและปลายทางต้องไม่ใช่บัญชีเดียวกัน'); return; }
    final amt = double.tryParse(_fAmountCtrl.text) ?? 0;
    if (amt <= 0) { _showError('กรุณาระบุจำนวนเงิน'); return; }

    setState(() => _saving = true);
    try {
      final body = {
        'transfer_date':        DateFormat('yyyy-MM-dd').format(_fDate),
        'from_bank_account_id': _fFromAcc!.id,
        'to_bank_account_id':   _fToAcc!.id,
        'amount':               amt,
        'currency_code':        _fFromAcc!.currencyCode,
        'exchange_rate':        double.tryParse(_fRateCtrl.text) ?? 1,
        'amount_lc':            double.tryParse(_fAmountLcCtrl.text) ?? amt,
        'description':          _fDescCtrl.text.trim().isEmpty ? null : _fDescCtrl.text.trim(),
        if (_fGlDoc != null) 'gl_doc_id':   _fGlDoc!['id'],
        if (_fGlDoc != null) 'gl_doc_code': _fGlDoc!['doc_code'],
      };
      if (_isCreating) {
        final id = await _txSvc.createRow(body);
        if (!mounted) return;
        setState(() { _isCreating = false; });
        await _loadList();
        final created = _txList.firstWhere((t) => t.id == id, orElse: () => _txList.first);
        setState(() { _selected = created; });
      } else {
        await _txSvc.updateRow(_selected!.id!, body);
        await _loadList();
        if (mounted) {
          final updated = _txList.firstWhere((t) => t.id == _selected!.id, orElse: () => _txList.first);
          setState(() { _selected = updated; });
        }
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _post() async {
    if (_selected == null) return;
    if (_fGlDoc == null && _selected!.glDocId == null) {
      _showError('กรุณาเลือก GL Doc Type ก่อน Post');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยัน Post GL'),
        content: Text('ต้องการ Post GL รายการ ${_selected!.transferNo ?? ''} ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white),
              child: const Text('Post GL')),
        ],
      ),
    );
    if (confirm != true) return;
    if (!await CmPeriodService.canPost(context, _selected!.transferDate)) return;
    setState(() => _saving = true);
    try {
      await _txSvc.postRow(_selected!.id!,
          glDocId: _fGlDoc?['id'] ?? _selected!.glDocId,
          glDocCode: _fGlDoc?['doc_code'] ?? _selected!.glDocCode);
      await _loadList();
      if (mounted) {
        final updated = _txList.firstWhere((t) => t.id == _selected!.id, orElse: () => _txList.first);
        setState(() { _selected = updated; });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Post GL สำเร็จ: ${updated.glDocNo ?? ''}'),
                backgroundColor: Colors.green.shade700));
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _void() async {
    if (_selected == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันยกเลิก'),
        content: Text('ต้องการยกเลิกรายการ ${_selected!.transferNo ?? ''} ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ไม่ใช่')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('ยกเลิกรายการ')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _saving = true);
    try {
      await _txSvc.voidRow(_selected!.id!);
      await _loadList();
      if (mounted) {
        final updated = _txList.firstWhere((t) => t.id == _selected!.id, orElse: () => _txList.first);
        setState(() { _selected = updated; });
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_selected == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยืนยันลบ'),
        content: Text('ต้องการลบรายการ ${_selected!.transferNo ?? ''} ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('ลบ')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _saving = true);
    try {
      await _txSvc.deleteRow(_selected!.id!);
      setState(() { _selected = null; _isCreating = false; });
      await _loadList();
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kTheme,
        foregroundColor: Colors.white,
        title: const Text('โอนเงินระหว่างบัญชี'),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        toolbarHeight: 40,
      ),
      body: LayoutBuilder(
        builder: (_, __) => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 36, color: _kTheme,
              child: IconButton(
                padding: EdgeInsets.zero, iconSize: 20, color: Colors.white,
                icon: Icon(_leftExpanded ? Icons.filter_list_off : Icons.filter_list),
                onPressed: () => setState(() => _leftExpanded = !_leftExpanded),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _leftExpanded ? 280 : 0,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  maxWidth: 280,
                  child: _buildLeftPanel(),
                ),
              ),
            ),
            if (_leftExpanded) const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: _buildRightPanel()),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Container(
      color: Colors.blueGrey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header + New button
          Container(
            height: 36, color: Colors.blueGrey.shade200,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              const Expanded(child: Text('รายการโอน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              IconButton(
                padding: EdgeInsets.zero, iconSize: 18,
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'สร้างใหม่',
                onPressed: _startCreate,
              ),
            ]),
          ),
          // Date filter
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                _miniDatePicker('ตั้งแต่', _filterFrom, (d) { setState(() => _filterFrom = d); _loadList(); }),
                const SizedBox(height: 4),
                _miniDatePicker('ถึง',     _filterTo,   (d) { setState(() => _filterTo   = d); _loadList(); }),
              ],
            ),
          ),
          const Divider(height: 1),
          // List
          Expanded(
            child: _loadingList
                ? const Center(child: CircularProgressIndicator())
                : _txList.isEmpty
                    ? const Center(child: Text('ไม่มีรายการ', style: TextStyle(fontSize: 12, color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _txList.length,
                        itemBuilder: (_, i) => _buildTxCard(_txList[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTxCard(CmInterBankTransfer tx) {
    final selected = tx.id == _selected?.id;
    Color statusColor;
    if (tx.isPosted)      statusColor = Colors.green.shade700;
    else if (tx.isVoided) statusColor = Colors.grey;
    else                  statusColor = Colors.orange.shade700;

    return GestureDetector(
      onTap: () {
        if (tx.isDraft) {
          _startEdit(tx);
        } else {
          setState(() { _selected = tx; _isCreating = false; });
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? _kTheme.withOpacity(0.12) : Colors.white,
          border: Border.all(color: selected ? _kTheme : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(tx.transferNo ?? '—',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: statusColor.withOpacity(0.3))),
              child: Text(cmTransferStatusOptions[tx.status] ?? tx.status,
                  style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 3),
          Text(_dateFmt.format(tx.transferDate),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(height: 3),
          Text(
            '${tx.fromAccountCode ?? '?'} → ${tx.toAccountCode ?? '?'}',
            style: const TextStyle(fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(_fmt.format(tx.amountLc),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }

  Widget _buildRightPanel() {
    if (!_isCreating && _selected == null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.swap_horiz, size: 48, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('กดปุ่ม + เพื่อสร้างรายการใหม่', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      ]));
    }

    final showForm = _isCreating || (_selected?.isDraft ?? false);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(children: [
            Text(
              _isCreating ? 'สร้างรายการโอนเงินใหม่' : 'รายการโอนเงิน: ${_selected?.transferNo ?? ''}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            if (_selected != null && !_isCreating)
              _statusChip(_selected!.status),
          ]),
          const SizedBox(height: 16),

          if (showForm) ...[
            _buildForm(),
            const SizedBox(height: 20),
            _buildFormActions(),
          ] else ...[
            _buildDetail(),
            const SizedBox(height: 20),
            _buildDetailActions(),
          ],
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Transfer Date
        Row(children: [
          const SizedBox(width: 140, child: Text('วันที่โอน', style: TextStyle(fontSize: 13))),
          InkWell(
            onTap: () async {
              final p = await showDatePicker(context: context, initialDate: _fDate,
                  firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (p != null) setState(() => _fDate = p);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
              child: Row(children: [
                Text(_dateFmt.format(_fDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 12),

        // From account
        Row(children: [
          const SizedBox(width: 140, child: Text('บัญชีต้นทาง (โอนออก)', style: TextStyle(fontSize: 13))),
          Expanded(child: _accountDropdown(_fFromAcc, (acc) {
            setState(() {
              _fFromAcc = acc;
              if (acc != null && acc.currencyCode == 'THB') {
                _fRateCtrl.text = '1';
                _recalcLc();
              }
            });
          })),
        ]),
        const SizedBox(height: 12),

        // To account
        Row(children: [
          const SizedBox(width: 140, child: Text('บัญชีปลายทาง (รับเข้า)', style: TextStyle(fontSize: 13))),
          Expanded(child: _accountDropdown(_fToAcc, (acc) => setState(() => _fToAcc = acc))),
        ]),
        const SizedBox(height: 12),

        // Amount
        Row(children: [
          SizedBox(width: 140, child: Text(
            'จำนวนเงิน${_isFcy ? ' (${_fFromAcc?.currencyCode ?? ''})' : ''}',
            style: const TextStyle(fontSize: 13))),
          SizedBox(width: 160, child: TextField(
            controller: _fAmountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(8),
                border: OutlineInputBorder()),
            onChanged: (_) => _recalcLc(),
          )),
        ]),

        if (_isFcy) ...[
          const SizedBox(height: 12),
          Row(children: [
            const SizedBox(width: 140, child: Text('อัตราแลกเปลี่ยน', style: TextStyle(fontSize: 13))),
            SizedBox(width: 120, child: TextField(
              controller: _fRateCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(8),
                  border: OutlineInputBorder()),
              onChanged: (_) => _recalcLc(),
            )),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            const SizedBox(width: 140, child: Text('จำนวนเงิน (THB)', style: TextStyle(fontSize: 13))),
            SizedBox(width: 160, child: TextField(
              controller: _fAmountLcCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(8),
                  border: OutlineInputBorder()),
            )),
          ]),
        ],
        const SizedBox(height: 12),

        // GL Doc Type
        Row(children: [
          const SizedBox(width: 140, child: Text('GL Doc Type', style: TextStyle(fontSize: 13))),
          Expanded(child: _glDocDropdown()),
        ]),
        const SizedBox(height: 12),

        // Description
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(width: 140, child: Padding(padding: EdgeInsets.only(top: 8),
              child: Text('คำอธิบาย', style: TextStyle(fontSize: 13)))),
          Expanded(child: TextField(
            controller: _fDescCtrl,
            maxLines: 2,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.all(8),
                border: OutlineInputBorder()),
          )),
        ]),
      ],
    );
  }

  Widget _buildFormActions() {
    return Wrap(spacing: 8, children: [
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white,
            minimumSize: const Size(0, 36)),
        onPressed: _saving ? null : _save,
        icon: _saving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save, size: 16),
        label: const Text('บันทึก'),
      ),
      if (!_isCreating && _selected?.isDraft == true) ...[
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white,
              minimumSize: const Size(0, 36)),
          onPressed: _saving ? null : () async { await _save(); if (mounted && _selected?.isDraft == true) await _post(); },
          icon: const Icon(Icons.account_balance, size: 16),
          label: const Text('บันทึกและ Post GL'),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red, minimumSize: const Size(0, 36)),
          onPressed: _saving ? null : _delete,
          icon: const Icon(Icons.delete_outline, size: 16),
          label: const Text('ลบ'),
        ),
      ],
      if (_isCreating)
        TextButton(
          onPressed: () => setState(() => _isCreating = false),
          child: const Text('ยกเลิก'),
        ),
    ]);
  }

  Widget _buildDetail() {
    final tx = _selected!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade100),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _detailRow('วันที่โอน', _dateFmt.format(tx.transferDate)),
          _detailRow('บัญชีต้นทาง', '${tx.fromAccountCode ?? ''} - ${tx.fromAccountName ?? ''} (${tx.fromBankShortName ?? ''})'),
          _detailRow('บัญชีปลายทาง', '${tx.toAccountCode ?? ''} - ${tx.toAccountName ?? ''} (${tx.toBankShortName ?? ''})'),
          _detailRow('จำนวนเงิน', '${_fmt.format(tx.amount)} ${tx.currencyCode}'),
          if (tx.currencyCode != 'THB') ...[
            _detailRow('อัตราแลกเปลี่ยน', tx.exchangeRate.toStringAsFixed(4)),
            _detailRow('จำนวนเงิน (THB)', _fmt.format(tx.amountLc)),
          ],
          if (tx.description != null) _detailRow('คำอธิบาย', tx.description!),
          if (tx.glDocNo != null) ...[
            const Divider(height: 16),
            _detailRow('GL Doc No', tx.glDocNo!),
            _detailRow('GL Doc Type', tx.glDocName ?? tx.glDocCode ?? ''),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailActions() {
    if (_selected!.isVoided) return const SizedBox();
    return Wrap(spacing: 8, children: [
      if (_selected!.isPosted)
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white,
              minimumSize: const Size(0, 36)),
          onPressed: _saving ? null : _void,
          icon: const Icon(Icons.cancel_outlined, size: 16),
          label: const Text('ยกเลิกรายการ (Void)'),
        ),
    ]);
  }

  Widget _accountDropdown(CmBankAccount? value, void Function(CmBankAccount?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CmBankAccount>(
          value: value,
          isExpanded: true,
          hint: const Text('เลือกบัญชี', style: TextStyle(fontSize: 13)),
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          items: _accounts.map((a) => DropdownMenuItem(
            value: a,
            child: Text('${a.accountCode} - ${a.accountNameTh} (${a.bankShortName ?? ''}) ${a.currencyCode}',
                overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _glDocDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Map<String, dynamic>>(
          value: _fGlDoc,
          isExpanded: true,
          hint: const Text('เลือก GL Doc Type', style: TextStyle(fontSize: 13)),
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          items: _glDocTypes.map((d) => DropdownMenuItem(
            value: d,
            child: Text('${d['doc_code']} - ${d['doc_name_thai'] ?? d['doc_name']}',
                overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (v) => setState(() => _fGlDoc = v),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 160, child: Text('$label:', style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    if (status == 'Posted')      color = Colors.green.shade700;
    else if (status == 'Voided') color = Colors.grey;
    else                          color = Colors.orange.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Text(cmTransferStatusOptions[status] ?? status,
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _miniDatePicker(String label, DateTime? value, void Function(DateTime) onPick) {
    return InkWell(
      onTap: () async {
        final p = await showDatePicker(context: context, initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (p != null) onPick(p);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4)),
        child: Row(children: [
          Text('$label: ', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          Text(value != null ? _dateFmt.format(value) : '—', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const Spacer(),
          Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade400),
        ]),
      ),
    );
  }
}
