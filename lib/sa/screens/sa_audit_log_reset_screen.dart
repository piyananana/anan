import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../services/auth_service.dart';
import '../services/language_provider.dart';
import '../utils/app_l10n.dart';
import '../utils/menu_scope.dart';

class SaAuditLogResetScreen extends StatefulWidget {
  const SaAuditLogResetScreen({super.key});

  @override
  State<SaAuditLogResetScreen> createState() => _SaAuditLogResetScreenState();
}

class _SaAuditLogResetScreenState extends State<SaAuditLogResetScreen> {
  static const String _baseUrl = AppConfig.apiSa;

  DateTime? _dateFrom;
  DateTime? _dateTo;

  final _confirmCtrl = TextEditingController();
  bool _isLoadingCounts = false;
  bool _isExecuting = false;
  Map<String, dynamic>? _counts;
  String? _error;

  final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  @override
  void dispose() {
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? _isoDate(DateTime? d) =>
      d == null ? null : DateFormat('yyyy-MM-dd').format(d);

  Future<void> _loadCounts() async {
    setState(() {
      _isLoadingCounts = true;
      _error = null;
    });
    try {
      final headers = await AuthService().getAuthHeader();
      final params = <String, String>{};
      if (_dateFrom != null) params['date_from'] = _isoDate(_dateFrom)!;
      if (_dateTo != null)   params['date_to']   = _isoDate(_dateTo)!;
      final uri = Uri.parse('$_baseUrl/user_audit_log/counts')
          .replace(queryParameters: params.isEmpty ? null : params);
      final res = await http.get(uri, headers: headers);
      if (res.statusCode == 200) {
        setState(() => _counts = json.decode(res.body));
      } else {
        setState(() =>
            _error = json.decode(res.body)['message'] ?? 'โหลดข้อมูลไม่สำเร็จ');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoadingCounts = false);
    }
  }

  bool get _canExecute =>
      _confirmCtrl.text.trim() == 'ยืนยัน' && !_isExecuting;

  Future<void> _pickDate(BuildContext ctx, bool isFrom) async {
    final now = DateTime.now();
    final initial = isFrom
        ? (_dateFrom ?? now.subtract(const Duration(days: 30)))
        : (_dateTo ?? now);
    final picked = await showDatePicker(
      context: ctx,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
        if (_dateTo != null && _dateTo!.isBefore(picked)) _dateTo = picked;
      } else {
        _dateTo = picked;
        if (_dateFrom != null && _dateFrom!.isAfter(picked)) _dateFrom = picked;
      }
    });
    _loadCounts();
  }

  Future<void> _execute() async {
    final l = AppL10n(Provider.of<LanguageProvider>(context, listen: false).isEnglish);
    final isEnglish = l.isEnglish;

    String rangeText;
    if (_dateFrom == null && _dateTo == null) {
      rangeText = isEnglish ? 'ALL records (no date filter)' : 'ทั้งหมด (ไม่กำหนดวันที่)';
    } else if (_dateFrom != null && _dateTo != null) {
      rangeText = '${_dateFmt.format(_dateFrom!)} – ${_dateFmt.format(_dateTo!)}';
    } else if (_dateFrom != null) {
      rangeText = isEnglish
          ? 'From ${_dateFmt.format(_dateFrom!)}'
          : 'ตั้งแต่ ${_dateFmt.format(_dateFrom!)}';
    } else {
      rangeText = isEnglish
          ? 'Until ${_dateFmt.format(_dateTo!)}'
          : 'ถึง ${_dateFmt.format(_dateTo!)}';
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
          const SizedBox(width: 8),
          Text(isEnglish ? 'Confirm Delete' : 'ยืนยันการลบข้อมูล'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEnglish
                  ? 'This action cannot be undone!\nDeleted data will be permanently lost.'
                  : 'การดำเนินการนี้ไม่สามารถยกเลิกได้!\nข้อมูลที่ลบจะหายไปถาวร',
              style: const TextStyle(
                  color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _confirmRow(
              Icons.manage_history,
              isEnglish ? 'Audit Log records' : 'ข้อมูล Audit Log',
              _counts?['total'],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Text(
                isEnglish ? 'Range: $rangeText' : 'ช่วง: $rangeText',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: Text(isEnglish ? 'Confirm Delete' : 'ยืนยัน ลบข้อมูล'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isExecuting = true);
    try {
      final headers = {
        ...await AuthService().getAuthHeader(),
        'Content-Type': 'application/json',
      };
      final res = await http.delete(
        Uri.parse('$_baseUrl/user_audit_log/reset'),
        headers: headers,
        body: json.encode({
          if (_dateFrom != null) 'date_from': _isoDate(_dateFrom),
          if (_dateTo != null)   'date_to':   _isoDate(_dateTo),
        }),
      );

      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(data['message'] ?? 'สำเร็จ'),
          backgroundColor: Colors.green[700],
          duration: const Duration(seconds: 4),
        ));
        _confirmCtrl.clear();
        await _loadCounts();
      } else {
        final msg = json.decode(res.body)['message'] ?? 'เกิดข้อผิดพลาด';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  isEnglish ? 'Failed: $msg' : 'ล้มเหลว: $msg'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isExecuting = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _confirmRow(IconData icon, String label, dynamic count) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Icon(icon, size: 16, color: Colors.red[700]),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.w500)),
          if (count != null) ...[
            const Spacer(),
            Text('$count รายการ',
                style: TextStyle(
                    color: Colors.red[700], fontWeight: FontWeight.bold)),
          ],
        ]),
      );

  Widget _countTile({
    required IconData icon,
    required String label,
    required String table,
    required dynamic count,
    required Color color,
  }) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(table,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ]),
          ),
          if (_isLoadingCounts)
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
          else
            Text(
              count != null ? '$count รายการ' : '-',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: (count ?? 0) > 0 ? Colors.red[700] : Colors.grey,
              ),
            ),
        ]),
      ),
    );
  }

  Widget _dateField({
    required BuildContext ctx,
    required String labelTh,
    required String labelEn,
    required DateTime? value,
    required bool isFrom,
    required bool isEnglish,
  }) {
    final label = isEnglish ? labelEn : labelTh;
    final hint = isEnglish ? 'All dates' : 'ทั้งหมด';
    return InkWell(
      onTap: () => _pickDate(ctx, isFrom),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.grey[50],
          suffixIcon: value != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  tooltip: isEnglish ? 'Clear' : 'ล้าง',
                  onPressed: () {
                    setState(() {
                      if (isFrom) { _dateFrom = null; }
                      else { _dateTo = null; }
                    });
                    _loadCounts();
                  },
                )
              : const Icon(Icons.calendar_today, size: 18),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        child: Text(
          value != null ? _dateFmt.format(value) : hint,
          style: TextStyle(
            color: value != null ? null : Colors.grey[500],
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.red[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: isEnglish ? 'Refresh' : 'รีเฟรช',
            onPressed: _loadCounts,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Warning Banner ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[300]!),
                  ),
                  child: Column(children: [
                    Row(children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.red[700], size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isEnglish
                              ? 'For System Developers Only'
                              : 'เครื่องมือสำหรับผู้พัฒนาระบบเท่านั้น',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[800],
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      isEnglish
                          ? 'This function permanently deletes User Audit Log records '
                              '(login/logout history) from the database. '
                              'Specify a date range to delete selectively, or leave both dates blank to delete all records.'
                          : 'ฟังก์ชันนี้จะลบข้อมูล Audit Log ของผู้ใช้งาน '
                              '(ประวัติการเข้า-ออกระบบ) ออกจากฐานข้อมูลอย่างถาวร '
                              'ระบุช่วงวันที่เพื่อลบเฉพาะบางช่วง หรือเว้นว่างทั้งสองช่องเพื่อลบทั้งหมด',
                      style: TextStyle(color: Colors.red[900], fontSize: 13),
                    ),
                  ]),
                ),

                const SizedBox(height: 24),

                // ── Date Range ────────────────────────────────────────────
                Text(
                  isEnglish ? 'Filter by Date Range (optional)' : 'กำหนดช่วงวันที่ (ไม่บังคับ)',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  isEnglish
                      ? 'Leave blank to delete all records without date restriction.'
                      : 'หากไม่ระบุวันที่ หมายถึงลบทุกรายการโดยไม่กำหนดช่วงเวลา',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 12),

                Row(children: [
                  Expanded(
                    child: _dateField(
                      ctx: context,
                      labelTh: 'ตั้งแต่วันที่',
                      labelEn: 'From Date',
                      value: _dateFrom,
                      isFrom: true,
                      isEnglish: isEnglish,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dateField(
                      ctx: context,
                      labelTh: 'ถึงวันที่',
                      labelEn: 'To Date',
                      value: _dateTo,
                      isFrom: false,
                      isEnglish: isEnglish,
                    ),
                  ),
                ]),

                if (_dateFrom == null && _dateTo == null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange[300]!),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline,
                          color: Colors.orange[800], size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isEnglish
                              ? 'No date filter — all audit log records will be deleted.'
                              : 'ไม่ได้ระบุวันที่ — จะลบข้อมูล Audit Log ทั้งหมด',
                          style: TextStyle(
                              color: Colors.orange[900], fontSize: 12),
                        ),
                      ),
                    ]),
                  ),
                ],

                const SizedBox(height: 20),

                // ── Count Cards ───────────────────────────────────────────
                Text(
                  isEnglish
                      ? 'Records in selected range'
                      : 'จำนวนข้อมูลในช่วงที่เลือก',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red)),
                  ),

                _countTile(
                  icon: Icons.manage_history,
                  label: isEnglish
                      ? 'Audit Log Records'
                      : 'รายการ Audit Log ทั้งหมด',
                  table: 'sa_user_audit_log',
                  count: _counts?['total'],
                  color: Colors.red[700]!,
                ),
                const SizedBox(height: 6),
                _countTile(
                  icon: Icons.sensors,
                  label: isEnglish
                      ? 'Active Sessions (not yet logged out)'
                      : 'Session ที่ยังค้างอยู่ (ยังไม่ได้ Logout)',
                  table: isEnglish ? 'logout_at IS NULL' : 'logout_at = NULL',
                  count: _counts?['active'],
                  color: Colors.orange[700]!,
                ),

                const SizedBox(height: 24),

                // ── Confirm Input ─────────────────────────────────────────
                Text(
                  isEnglish ? 'Confirm Deletion' : 'ยืนยันการลบ',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmCtrl,
                  decoration: InputDecoration(
                    labelText: isEnglish
                        ? 'Type "ยืนยัน" to enable the delete button'
                        : 'พิมพ์ "ยืนยัน" เพื่อเปิดใช้ปุ่มลบ',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey[50],
                    prefixIcon: const Icon(Icons.keyboard),
                  ),
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _canExecute ? _execute : null,
                    icon: _isExecuting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.delete_forever),
                    label: Text(
                      _isExecuting
                          ? (isEnglish
                              ? 'Deleting...'
                              : 'กำลังลบข้อมูล...')
                          : (isEnglish
                              ? 'Delete Selected Records'
                              : 'ลบข้อมูลที่เลือก'),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[800],
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Center(
                  child: Text(
                    isEnglish
                        ? 'Button activates when you type "ยืนยัน"'
                        : 'ปุ่มจะพร้อมใช้งานเมื่อพิมพ์ "ยืนยัน"',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
