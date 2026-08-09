// lib/cm/screens/cm_post_dated_check_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../services/cm_period_service.dart';
import '../../utils/date_utils.dart';

const _kTheme   = Color(0xFF1565C0);
final _fmt      = NumberFormat('#,##0.00', 'en_US');
final _dateFmt  = DateFormat('dd/MM/yyyy');

const Map<String, String> _dirLabels = {
  'RECEIVED': 'รับ (Received)',
  'ISSUED':   'จ่าย (Issued)',
};
const Map<String, String> _dirLabelsEng = {
  'RECEIVED': 'Received',
  'ISSUED':   'Issued',
};
const Map<String, String> _statusLabels = {
  'Holding':   'ถือไว้',
  'Deposited': 'นำฝากแล้ว',
  'Cleared':   'เคลียร์แล้ว',
  'Returned':  'คืนแล้ว',
  'Cancelled': 'ยกเลิก',
};
const Map<String, String> _statusLabelsEng = {
  'Holding':   'Holding',
  'Deposited': 'Deposited',
  'Cleared':   'Cleared',
  'Returned':  'Returned',
  'Cancelled': 'Cancelled',
};
const Map<String, Color> _statusColors = {
  'Holding':   Colors.blue,
  'Deposited': Colors.orange,
  'Cleared':   Colors.green,
  'Returned':  Colors.purple,
  'Cancelled': Colors.grey,
};
const Map<String, String> _actionLabelsEng = {
  'present': 'Deposit',
  'clear':   'Clear',
  'return':  'Return',
  'cancel':  'Cancel',
};

class CmPostDatedCheckScreen extends StatefulWidget {
  const CmPostDatedCheckScreen({super.key});
  @override
  State<CmPostDatedCheckScreen> createState() => _CmPostDatedCheckScreenState();
}

class _CmPostDatedCheckScreenState extends State<CmPostDatedCheckScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isEnglish = false;
  bool _panelOpen = true;
  double _leftWidth = 300.0;
  bool _isDragging  = false;

  // list filters
  String _filterDir    = '';
  String _filterStatus = 'Holding';
  String _searchQuery  = '';

  List<Map<String, dynamic>> _list = [];
  Map<String, dynamic>? _selected;
  bool _loading = false;
  bool _saving  = false;

  // form fields
  String   _fDir       = 'RECEIVED';
  DateTime _fCheckDate = DateTime.now();
  int?     _fBankId;
  int?     _fOurBankId;
  bool     _isNew      = false;

  List<Map<String, dynamic>> _banks = [];

  final _checkNoCtrl    = TextEditingController();
  final _payerPayeeCtrl = TextEditingController();
  final _amountCtrl     = TextEditingController();
  final _remarkCtrl     = TextEditingController();

  // summary
  int    _sumCount  = 0;
  double _sumAmount = 0;

  @override
  void initState() {
    super.initState();
    _loadBanks();
    _loadList();
    _loadSummary();
  }

  @override
  void dispose() {
    _checkNoCtrl.dispose();
    _payerPayeeCtrl.dispose();
    _amountCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _headers() async =>
      {...await AuthService().getAuthHeader(), 'Content-Type': 'application/json'};

  Future<void> _loadBanks() async {
    try {
      final h = await _headers();
      final r = await http.get(Uri.parse('${AppConfig.apiCm}/cm_bank_account'), headers: h);
      if (r.statusCode == 200) {
        final data = json.decode(r.body) as List;
        setState(() => _banks = data.cast<Map<String, dynamic>>());
      }
    } catch (_) {}
  }

  Future<void> _loadList() async {
    setState(() => _loading = true);
    try {
      final h = await _headers();
      final params = <String, String>{};
      if (_filterDir.isNotEmpty)    params['direction'] = _filterDir;
      if (_filterStatus.isNotEmpty) params['status']    = _filterStatus;
      final uri = Uri.parse('${AppConfig.apiCm}/cm_post_dated_check')
          .replace(queryParameters: params.isNotEmpty ? params : null);
      final r = await http.get(uri, headers: h);
      if (r.statusCode == 200) {
        final data = json.decode(r.body) as List;
        setState(() => _list = data.cast<Map<String, dynamic>>());
      }
    } catch (e) { _showErr('$e'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _loadSummary() async {
    try {
      final h = await _headers();
      final r = await http.get(
          Uri.parse('${AppConfig.apiCm}/cm_post_dated_check/summary'), headers: h);
      if (r.statusCode == 200) {
        final d = json.decode(r.body) as Map<String, dynamic>;
        setState(() {
          _sumCount  = (d['total_count'] as num?)?.toInt() ?? 0;
          _sumAmount = (d['total_amount'] as num?)?.toDouble() ?? 0;
        });
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _filteredList {
    if (_searchQuery.isEmpty) return _list;
    final q = _searchQuery.toLowerCase();
    return _list.where((row) {
      final checkNo = (row['check_no'] ?? '').toString().toLowerCase();
      final payee   = (row['payee_payer_name'] ?? '').toString().toLowerCase();
      return checkNo.contains(q) || payee.contains(q);
    }).toList();
  }

  void _startNew() {
    setState(() {
      _selected   = null;
      _isNew      = true;
      _fDir       = 'RECEIVED';
      _fCheckDate = DateTime.now();
      _fBankId    = null;
      _fOurBankId = null;
      _checkNoCtrl.text    = '';
      _payerPayeeCtrl.text = '';
      _amountCtrl.text     = '';
      _remarkCtrl.text     = '';
    });
  }

  void _selectItem(Map<String, dynamic> row) {
    setState(() {
      _selected = row;
      _isNew    = false;
      _fDir       = row['direction'] ?? 'RECEIVED';
      _fCheckDate = parseLocalDate(row['check_date']);
      _fBankId    = row['bank_id'] as int?;
      _fOurBankId = row['our_bank_account_id'] as int?;
      _checkNoCtrl.text    = row['check_no'] ?? '';
      _payerPayeeCtrl.text = row['payee_payer_name'] ?? '';
      _amountCtrl.text     = (row['amount'] as num?)?.toStringAsFixed(2) ?? '';
      _remarkCtrl.text     = row['remark'] ?? '';
    });
  }

  Future<void> _save() async {
    final perm = MenuScope.of(context);
    if (!(_isNew ? (perm?.canCreate ?? true) : (perm?.canEdit ?? true))) return;
    if (_checkNoCtrl.text.trim().isEmpty) {
      _showErr(_isEnglish ? 'Please enter a check number' : 'กรุณากรอกเลขที่เช็ค');
      return;
    }
    if (_fOurBankId == null) {
      _showErr(_isEnglish ? 'Please select our bank account' : 'กรุณาเลือกบัญชีธนาคารของเรา');
      return;
    }

    final checkDate = formatLocalDate(_fCheckDate);
    if (!await CmPeriodService.canPost(context, _fCheckDate)) return;

    setState(() => _saving = true);
    try {
      final h = await _headers();
      final body = json.encode({
        'direction':         _fDir,
        'check_no':          _checkNoCtrl.text.trim(),
        'check_date':        checkDate,
        'payee_payer_name':  _payerPayeeCtrl.text.trim(),
        'amount':            double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0,
        'bank_id':           _fBankId,
        'our_bank_account_id': _fOurBankId,
        'remark':            _remarkCtrl.text.trim().isEmpty ? null : _remarkCtrl.text.trim(),
      });
      if (_isNew) {
        await http.post(Uri.parse('${AppConfig.apiCm}/cm_post_dated_check'), headers: h, body: body);
      } else {
        await http.put(Uri.parse('${AppConfig.apiCm}/cm_post_dated_check/${_selected!['id']}'),
            headers: h, body: body);
      }
      _showOk(_isNew
          ? (_isEnglish ? 'Check added successfully' : 'เพิ่มเช็คสำเร็จ')
          : (_isEnglish ? 'Check updated successfully' : 'แก้ไขเช็คสำเร็จ'));
      await _loadList();
      await _loadSummary();
      setState(() { _selected = null; _isNew = false; });
    } catch (e) { _showErr('$e'); }
    finally { if (mounted) setState(() => _saving = false); }
  }

  Future<void> _action(String action, Map<String, dynamic> row) async {
    if (!(MenuScope.of(context)?.canEdit ?? true)) return;
    final isEnglish = _isEnglish;
    final label = isEnglish
        ? (_actionLabelsEng[action] ?? action)
        : switch (action) {
            'present' => 'นำฝาก',
            'clear'   => 'เคลียร์',
            'return'  => 'คืน',
            'cancel'  => 'ยกเลิก',
            _         => action,
          };
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEnglish ? 'Confirm $label' : 'ยืนยัน$label'),
        content: Text(isEnglish
            ? 'Do you want to $label check ${row['check_no']}?'
            : 'ต้องการ$labelเช็คเลขที่ ${row['check_no']} ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kTheme, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(label),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final h = await _headers();
      await http.put(
          Uri.parse('${AppConfig.apiCm}/cm_post_dated_check/${row['id']}/$action'), headers: h);
      _showOk(isEnglish ? '$label successful' : '$label สำเร็จ');
      await _loadList();
      await _loadSummary();
      if (_selected?['id'] == row['id']) setState(() => _selected = null);
    } catch (e) { _showErr('$e'); }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if (!(MenuScope.of(context)?.canDelete ?? true)) return;
    final isEnglish = _isEnglish;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEnglish ? 'Confirm Delete' : 'ยืนยันลบ'),
        content: Text(isEnglish ? 'Delete check ${row['check_no']}?' : 'ต้องการลบเช็คเลขที่ ${row['check_no']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(isEnglish ? 'Cancel' : 'ยกเลิก')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(isEnglish ? 'Delete' : 'ลบ'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final h = await _headers();
      await http.delete(
          Uri.parse('${AppConfig.apiCm}/cm_post_dated_check/${row['id']}'), headers: h);
      _showOk(isEnglish ? 'Deleted successfully' : 'ลบสำเร็จ');
      await _loadList();
      await _loadSummary();
      if (_selected?['id'] == row['id']) setState(() => _selected = null);
    } catch (e) { _showErr('$e'); }
  }

  void _showOk(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.green.shade700));
  }

  void _showErr(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kTheme,
        foregroundColor: Colors.white,
        toolbarHeight: 40,
        title: const MenuTitle(),
        actions: [
          if (_isNew || (_selected != null && _selected!['status'] == 'Holding'))
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save, size: 16),
              label: Text(isEnglish ? 'Save' : 'บันทึก', style: const TextStyle(fontSize: 13)),
            ),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () => setState(() { _selected = null; _isNew = false; }),
            icon: const Icon(Icons.close, size: 16),
            label: Text(isEnglish ? 'Cancel' : 'ยกเลิก', style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(builder: (_, constraints) {
        final maxLeft = (constraints.maxWidth - 36 - 320).clamp(100.0, double.infinity);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Toggle strip
            Container(
              width: 36,
              color: _kTheme,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 20,
                color: Colors.white,
                icon: Icon(_panelOpen ? Icons.chevron_left : Icons.chevron_right),
                onPressed: () => setState(() => _panelOpen = !_panelOpen),
              ),
            ),
            // Left panel
            AnimatedContainer(
              duration: _isDragging ? Duration.zero : const Duration(milliseconds: 200),
              width: _panelOpen ? _leftWidth : 0,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  maxWidth: _leftWidth, minWidth: _leftWidth,
                  child: SizedBox(
                    width: _leftWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          color: Colors.blueGrey.shade100,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Column(children: [
                            Row(children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _filterDir,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                      labelText: isEnglish ? 'Direction' : 'ทิศทาง',
                                      border: const OutlineInputBorder()),
                                  items: [
                                    DropdownMenuItem(value: '', child: Text(isEnglish ? 'All' : 'ทั้งหมด')),
                                    DropdownMenuItem(value: 'RECEIVED', child: Text(isEnglish ? 'Received' : 'รับ')),
                                    DropdownMenuItem(value: 'ISSUED', child: Text(isEnglish ? 'Issued' : 'จ่าย')),
                                  ],
                                  onChanged: (v) { setState(() => _filterDir = v ?? ''); _loadList(); },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _filterStatus,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                      labelText: isEnglish ? 'Status' : 'สถานะ',
                                      border: const OutlineInputBorder()),
                                  items: [
                                    DropdownMenuItem(value: '', child: Text(isEnglish ? 'All' : 'ทั้งหมด')),
                                    ...(isEnglish ? _statusLabelsEng : _statusLabels).entries.map((e) =>
                                        DropdownMenuItem(value: e.key, child: Text(e.value))),
                                  ],
                                  onChanged: (v) { setState(() => _filterStatus = v ?? ''); _loadList(); },
                                ),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            TextField(
                              decoration: InputDecoration(
                                hintText: isEnglish ? 'Search (check no. / name)' : 'ค้นหา (เลขที่เช็ค / ชื่อ)',
                                prefixIcon: const Icon(Icons.search),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (v) => setState(() => _searchQuery = v),
                            ),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12)),
                                onPressed: (MenuScope.of(context)?.canCreate ?? true) ? _startNew : null,
                                icon: const Icon(Icons.add),
                                label: Text(isEnglish ? 'Add New' : 'เพิ่มใหม่'),
                              )),
                              const SizedBox(width: 8),
                              Expanded(child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12)),
                                onPressed: _loadList,
                                icon: const Icon(Icons.refresh),
                                label: Text(isEnglish ? 'Refresh' : 'รีเฟรช'),
                              )),
                            ]),
                          ]),
                        ),
                        // Summary bar
                        Container(
                          color: Colors.blueGrey.shade100,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Text(
                            isEnglish
                                ? 'Holding: $_sumCount items | ${_fmt.format(_sumAmount)} THB'
                                : 'ถือไว้: $_sumCount รายการ | ${_fmt.format(_sumAmount)} บาท',
                            style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            color: Colors.blueGrey.shade100,
                            child: _loading
                                ? const Center(child: CircularProgressIndicator())
                                : _filteredList.isEmpty
                                    ? Center(child: Text(isEnglish ? 'No items' : 'ไม่มีรายการ',
                                        style: const TextStyle(color: Colors.grey)))
                                    : ListView.builder(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        itemCount: _filteredList.length,
                                        itemBuilder: (_, i) {
                                          final row = _filteredList[i];
                                          final sel = _selected?['id'] == row['id'];
                                          final chkDate = parseLocalDateNullable(row['check_date']);
                                          final status = row['status'] as String? ?? '';
                                          final statusColor = _statusColors[status] ?? Colors.grey;
                                          return Card(
                                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            child: ListTile(
                                              selected: sel,
                                              selectedTileColor: _kTheme.withOpacity(0.12),
                                              leading: CircleAvatar(
                                                backgroundColor: statusColor.withOpacity(0.15),
                                                child: Icon(
                                                  row['direction'] == 'RECEIVED' ? Icons.call_received : Icons.call_made,
                                                  color: statusColor, size: 18),
                                              ),
                                              title: Text(row['check_no'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                              subtitle: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(row['payee_payer_name'] ?? '',
                                                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                                                      overflow: TextOverflow.ellipsis),
                                                  Text(
                                                    chkDate != null ? _dateFmt.format(chkDate) : '',
                                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                                  ),
                                                ],
                                              ),
                                              trailing: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(_fmt.format((row['amount'] as num?)?.toDouble() ?? 0),
                                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                                  const SizedBox(height: 3),
                                                  Chip(
                                                    label: Text((isEnglish ? _statusLabelsEng[status] : _statusLabels[status]) ?? status,
                                                        style: TextStyle(fontSize: 11, color: statusColor)),
                                                    backgroundColor: statusColor.withOpacity(0.12),
                                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                    visualDensity: VisualDensity.compact,
                                                  ),
                                                ],
                                              ),
                                              onTap: () => _selectItem(row),
                                            ),
                                          );
                                        },
                                      ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_panelOpen)
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  onHorizontalDragStart: (_) => setState(() => _isDragging = true),
                  onHorizontalDragUpdate: (d) => setState(() {
                    _leftWidth = (_leftWidth + d.delta.dx).clamp(220.0, maxLeft);
                  }),
                  onHorizontalDragEnd: (_) => setState(() => _isDragging = false),
                  child: Container(width: 5, color: Colors.grey[400]),
                ),
              ),
            // Right panel
            Expanded(child: _buildRight()),
          ],
        );
      }),
    );
  }

  Widget _buildRight() {
    final isEnglish = _isEnglish;
    if (_isNew || (_selected != null && _selected!['status'] == 'Holding')) {
      return _buildForm();
    }
    if (_selected != null) {
      return _buildDetail(_selected!);
    }
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.receipt_long, size: 64, color: Colors.blueGrey.shade200),
        const SizedBox(height: 12),
        Text(isEnglish ? 'Select an item from the left, or press "Add New"' : 'เลือกรายการจากแผงซ้าย หรือกด "เพิ่มใหม่"',
            style: TextStyle(color: Colors.blueGrey.shade400)),
      ]),
    );
  }

  Widget _buildForm() {
    final isEnglish = _isEnglish;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_isNew ? (isEnglish ? 'Add New Post-Dated Check' : 'เพิ่มเช็คล่วงหน้าใหม่') : (isEnglish ? 'Edit Post-Dated Check' : 'แก้ไขเช็คล่วงหน้า'),
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        // Row 1: Direction / Check No. / Check Date
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(
            value: _fDir,
            isExpanded: true,
            decoration: InputDecoration(
                labelText: isEnglish ? 'Direction *' : 'ทิศทาง *',
                border: const OutlineInputBorder()),
            items: (isEnglish ? _dirLabelsEng : _dirLabels).entries.map((e) =>
                DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setState(() => _fDir = v ?? 'RECEIVED'),
          )),
          const SizedBox(width: 8),
          Expanded(child: TextFormField(
            controller: _checkNoCtrl,
            decoration: InputDecoration(
                labelText: isEnglish ? 'Check No. *' : 'เลขที่เช็ค *',
                border: const OutlineInputBorder()),
          )),
          const SizedBox(width: 8),
          Expanded(child: _datePicker(isEnglish ? 'Check Date *' : 'วันที่บนเช็ค *',
              _fCheckDate, (d) => setState(() => _fCheckDate = d))),
        ]),
        const SizedBox(height: 12),
        // Row 2: Payee/Payer Name (full width)
        TextFormField(
          controller: _payerPayeeCtrl,
          decoration: InputDecoration(
              labelText: isEnglish ? 'Payee/Payer Name' : 'ชื่อผู้รับ/จ่าย',
              border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        // Row 3: Amount / Our Bank Account
        Row(children: [
          Expanded(child: TextFormField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: isEnglish ? 'Amount (THB)' : 'จำนวนเงิน (บาท)',
                border: const OutlineInputBorder()),
          )),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: DropdownButtonFormField<int?>(
            value: _fOurBankId,
            isExpanded: true,
            decoration: InputDecoration(
                labelText: isEnglish ? 'Our Bank Account *' : 'บัญชีธนาคารของเรา *',
                border: const OutlineInputBorder()),
            hint: Text(isEnglish ? 'Select an account' : 'เลือกบัญชี'),
            items: _banks.map((b) => DropdownMenuItem<int?>(
                value: b['id'] as int?,
                child: Text('${b['account_code'] ?? ''} - ${b['account_name'] ?? ''}',
                    overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => _fOurBankId = v),
          )),
        ]),
        const SizedBox(height: 12),
        // Row 4: Note (full width)
        TextFormField(
          controller: _remarkCtrl,
          maxLines: 2,
          decoration: InputDecoration(
              labelText: isEnglish ? 'Note' : 'หมายเหตุ',
              border: const OutlineInputBorder(),
              alignLabelWithHint: true),
        ),
      ]),
    );
  }

  Widget _buildDetail(Map<String, dynamic> row) {
    final isEnglish = _isEnglish;
    final status = row['status'] as String? ?? '';
    final chkDate = parseLocalDateNullable(row['check_date']);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('${isEnglish ? 'Check No.' : 'เช็คเลขที่'} ${row['check_no'] ?? ''}',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(width: 12),
          Chip(
            label: Text((isEnglish ? _statusLabelsEng[status] : _statusLabels[status]) ?? status,
                style: TextStyle(color: _statusColors[status] ?? Colors.grey)),
            backgroundColor: (_statusColors[status] ?? Colors.grey).withOpacity(0.12),
          ),
        ]),
        const SizedBox(height: 20),
        // Row 1: Direction / Check Date / Amount
        Row(children: [
          Expanded(child: _infoBlock(isEnglish ? 'Direction' : 'ทิศทาง',
              (isEnglish ? _dirLabelsEng[row['direction']] : _dirLabels[row['direction']]) ?? row['direction'] ?? '')),
          const SizedBox(width: 8),
          Expanded(child: _infoBlock(isEnglish ? 'Check Date' : 'วันที่บนเช็ค',
              chkDate != null ? _dateFmt.format(chkDate) : '')),
          const SizedBox(width: 8),
          Expanded(child: _infoBlock(isEnglish ? 'Amount' : 'จำนวนเงิน',
              '${_fmt.format((row['amount'] as num?)?.toDouble() ?? 0)} THB')),
        ]),
        const SizedBox(height: 12),
        // Row 2: Payee/Payer Name (full width)
        _infoBlock(isEnglish ? 'Payee/Payer Name' : 'ชื่อผู้รับ/จ่าย', row['payee_payer_name'] ?? ''),
        const SizedBox(height: 12),
        // Row 3: Our Bank Account (full width)
        _infoBlock(isEnglish ? 'Our Bank Account' : 'บัญชีธนาคารของเรา',
            '${row['our_account_code'] ?? ''} ${row['our_account_name'] ?? ''}'.trim()),
        if (row['remark'] != null && (row['remark'] as String).isNotEmpty) ...[
          const SizedBox(height: 12),
          _infoBlock(isEnglish ? 'Note' : 'หมายเหตุ', row['remark'] as String),
        ],
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          if (status == 'Holding') ...[
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
              onPressed: () => _action('present', row),
              child: Text(isEnglish ? 'Deposit' : 'นำฝาก'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
              onPressed: () => _action('cancel', row),
              child: Text(isEnglish ? 'Cancel' : 'ยกเลิก'),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
              onPressed: () => _delete(row),
              child: Text(isEnglish ? 'Delete' : 'ลบ'),
            ),
          ],
          if (status == 'Deposited') ...[
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
              onPressed: () => _action('clear', row),
              child: Text(isEnglish ? 'Clear' : 'เคลียร์'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
              onPressed: () => _action('return', row),
              child: Text(isEnglish ? 'Return' : 'คืน'),
            ),
          ],
        ]),
      ]),
    );
  }

  Widget _infoBlock(String label, String value) => InputDecorator(
    decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    child: Text(value.isEmpty ? '—' : value),
  );

  Widget _datePicker(String label, DateTime value, void Function(DateTime) onPick) =>
      InkWell(
        onTap: () async {
          final d = await showDatePicker(context: context, initialDate: value,
              firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (d != null) onPick(d);
        },
        child: InputDecorator(
          decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.calendar_today, size: 18)),
          child: Text(_dateFmt.format(value)),
        ),
      );
}
