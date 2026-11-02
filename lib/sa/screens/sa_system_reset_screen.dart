import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../services/sa_auth_service.dart';
import '../services/sa_language_provider.dart';
import '../utils/sa_app_l10n.dart';
import '../utils/sa_menu_scope.dart';

// ล้างธุรกรรมทุกโมดูลเพื่อเริ่มต้นใหม่ — เก็บข้อมูลหลักและการตั้งค่าไว้ทั้งหมด
// (ข้อมูลหลักของแต่ละโมดูลล้างที่หน้าจอล้างข้อมูลรายโมดูล หลังล้างธุรกรรมที่หน้าจอนี้แล้ว)
class SaSystemResetScreen extends StatefulWidget {
  const SaSystemResetScreen({super.key});

  @override
  State<SaSystemResetScreen> createState() => _SaSystemResetScreenState();
}

class _SaSystemResetScreenState extends State<SaSystemResetScreen> {
  static const String _baseUrl = AppConfig.apiSa;

  // ชื่อกลุ่มตาม code ที่ backend ส่งมา (saSystemResetController GROUPS)
  static const Map<String, (String, String, IconData)> _groupLabels = {
    'AR': ('ลูกหนี้ (AR) + คำขออนุมัติวงเงิน', 'Accounts Receivable (AR) + credit approvals', Icons.call_received),
    'AP': ('เจ้าหนี้ (AP) + รอบจ่ายชำระ', 'Accounts Payable (AP) + payment runs', Icons.call_made),
    'CM': ('เงินสดและธนาคาร (CM) + ยอดยกมาธนาคาร', 'Cash Management (CM) + bank opening balances', Icons.account_balance),
    'IM': ('สินค้าคงคลัง (IM) + ยอดยกมา/นับสต็อก/เปลี่ยนราคา', 'Inventory (IM) + opening/stock count/price change', Icons.inventory_2),
    'MO': ('ใบสั่งผลิต (MO)', 'Manufacturing orders (MO)', Icons.precision_manufacturing),
    'PO': ('ใบขอซื้อ / ใบสั่งซื้อ', 'Purchase requisitions / orders', Icons.shopping_cart),
    'SO': ('ใบเสนอราคา / ใบสั่งขาย', 'Quotations / sales orders', Icons.point_of_sale),
    'VT': ('ภาษีซื้อ / ภาษีขาย', 'Input / output VAT', Icons.percent),
    'GL': ('บัญชีแยกประเภท (GL) + ยอดสะสม/ปิดงวด/ปิดปี', 'General Ledger (GL) + balances/period/year closing', Icons.menu_book),
    'SA': ('คิวอนุมัติ, ประวัติถอยเอกสาร, ไฟล์แนบ, Audit Log', 'Approval queue, reverse log, attachments, audit log', Icons.admin_panel_settings),
  };

  final _confirmCtrl = TextEditingController();
  bool _isLoadingCounts = false;
  bool _isExecuting = false;
  bool _resetDocNumbers = true;
  bool _resetCheckbooks = true;
  Map<String, dynamic>? _counts;
  String? _error;
  bool _isEnglish = false;

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

  String get _confirmText => _counts?['confirm_text'] ?? 'RESET ALL';

  List<Map<String, dynamic>> get _groups =>
      ((_counts?['groups'] as List?) ?? const []).cast<Map<String, dynamic>>();

  int get _grandTotal => _groups.fold(0, (s, g) => s + ((g['total'] as num?)?.toInt() ?? 0));

  Future<void> _loadCounts() async {
    setState(() {
      _isLoadingCounts = true;
      _error = null;
    });
    try {
      final headers = await AuthService().getAuthHeader();
      final res = await http.get(Uri.parse('$_baseUrl/system_reset/counts'), headers: headers);
      if (res.statusCode == 200) {
        setState(() => _counts = json.decode(res.body));
      } else {
        setState(() => _error = json.decode(res.body)['message'] ??
            (_isEnglish ? 'Failed to load data' : 'โหลดข้อมูลไม่สำเร็จ'));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingCounts = false);
    }
  }

  bool get _canExecute =>
      _counts != null && _confirmCtrl.text.trim() == _confirmText && !_isExecuting;

  Future<void> _execute() async {
    final l = AppL10n(Provider.of<LanguageProvider>(context, listen: false).isEnglish);
    final isEnglish = l.isEnglish;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
          const SizedBox(width: 8),
          Text(isEnglish ? 'Confirm System Reset' : 'ยืนยันการล้างธุรกรรมทุกโมดูล'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEnglish
                  ? 'This action cannot be undone!\nAll transactions in every module will be permanently lost.'
                  : 'การดำเนินการนี้ไม่สามารถยกเลิกได้!\nธุรกรรมทุกโมดูลจะหายไปถาวร',
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(isEnglish ? 'Rows to delete: $_grandTotal' : 'จำนวนแถวที่จะลบ: $_grandTotal รายการ'),
            if (_resetDocNumbers)
              Text(isEnglish ? '• Reset document numbers' : '• รีเซ็ตเลขที่เอกสาร'),
            if (_resetCheckbooks)
              Text(isEnglish ? '• Reset checkbook numbers' : '• รีเซ็ตเลขเช็คในสมุดเช็ค'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(isEnglish ? 'Confirm Reset' : 'ยืนยัน ล้างข้อมูล'),
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
      final res = await http.post(
        Uri.parse('$_baseUrl/system_reset'),
        headers: headers,
        body: json.encode({
          'confirm_text': _confirmCtrl.text.trim(),
          'resetDocNumbers': _resetDocNumbers,
          'resetCheckbooks': _resetCheckbooks,
        }),
      );

      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish ? 'All transactions have been reset' : 'ล้างธุรกรรมทุกโมดูลเรียบร้อย'),
          backgroundColor: Colors.green[700],
          duration: const Duration(seconds: 4),
        ));
        _confirmCtrl.clear();
        await _loadCounts();
      } else {
        final msg = json.decode(res.body)['message'] ?? (isEnglish ? 'An error occurred' : 'เกิดข้อผิดพลาด');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish ? 'Failed: $msg' : 'ล้มเหลว: $msg'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 8),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isExecuting = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _rows(int n) => _isEnglish ? '$n rows' : '$n รายการ';

  Widget _groupTile(Map<String, dynamic> g) {
    final code = g['code'] as String;
    final label = _groupLabels[code];
    final total = (g['total'] as num?)?.toInt() ?? 0;
    final tables = ((g['tables'] as List?) ?? const []).cast<Map<String, dynamic>>();
    return Card(
      elevation: 1,
      child: ExpansionTile(
        leading: Icon(label?.$3 ?? Icons.table_chart, color: total > 0 ? Colors.red[700] : Colors.grey),
        title: Text(label == null ? code : (_isEnglish ? label.$2 : label.$1),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        trailing: Text(
          _rows(total),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: total > 0 ? Colors.red[700] : Colors.grey,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(56, 0, 16, 8),
        children: [
          for (final t in tables)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Expanded(child: Text(t['table'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
                Text(_rows((t['count'] as num?)?.toInt() ?? 0), style: const TextStyle(fontSize: 12)),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _option({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String title,
    required String subtitle,
  }) {
    return CheckboxListTile(
      value: value,
      onChanged: (v) => setState(() => onChanged(v ?? false)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
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
            constraints: const BoxConstraints(maxWidth: 760),
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
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isEnglish ? 'For System Developers Only' : 'เครื่องมือสำหรับผู้พัฒนาระบบเท่านั้น',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red[800]),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      isEnglish
                          ? 'Permanently deletes every transaction in all modules (AR, AP, CM, IM, MO, PR/PO, '
                              'quotation/SO, VAT, GL), including opening balances, approval queues, reverse logs, '
                              'document attachments (files included) and the user audit log. Everything runs as one '
                              'transaction — if any step fails, nothing is deleted.'
                          : 'ลบธุรกรรมทุกโมดูลอย่างถาวร (AR, AP, CM, IM, MO, ใบขอซื้อ/ใบสั่งซื้อ, ใบเสนอราคา/ใบสั่งขาย, '
                              'ภาษีซื้อ/ภาษีขาย, GL) รวมถึงยอดยกมา, คิวอนุมัติ, ประวัติถอยเอกสาร, ไฟล์แนบเอกสาร (รวมไฟล์จริง) '
                              'และ Audit Log ของผู้ใช้ — ทำทั้งหมดในครั้งเดียว ถ้าขั้นตอนใดผิดพลาดจะไม่มีข้อมูลใดถูกลบ',
                      style: TextStyle(color: Colors.red[900], fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isEnglish
                          ? 'Kept: chart of accounts, dimensions, fiscal years/periods, customers, vendors, items, '
                              'warehouses, BOMs, bank accounts, checkbooks, GL setups, users and menus. Clear master '
                              'data on each module\'s reset screen after this.'
                          : 'เก็บไว้: ผังบัญชี, มิติ, ปีบัญชี/งวดบัญชี, ลูกค้า, ผู้ขาย, สินค้า, คลัง, สูตรการผลิต, '
                              'บัญชีธนาคาร, สมุดเช็ค, การตั้งค่าบัญชี, ผู้ใช้ และเมนู — ถ้าต้องการล้างข้อมูลหลัก '
                              'ให้ล้างที่หน้าจอล้างข้อมูลของแต่ละโมดูลหลังจากนี้',
                      style: TextStyle(color: Colors.grey[800], fontSize: 12),
                    ),
                  ]),
                ),

                const SizedBox(height: 24),

                Row(children: [
                  Expanded(
                    child: Text(
                      isEnglish ? 'Transactions to delete' : 'ธุรกรรมที่จะถูกลบ',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (_isLoadingCounts)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  else if (_counts != null)
                    Text(
                      isEnglish ? 'Total ${_rows(_grandTotal)}' : 'รวม ${_rows(_grandTotal)}',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[700]),
                    ),
                ]),
                const SizedBox(height: 8),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),

                for (final g in _groups) _groupTile(g),

                const SizedBox(height: 20),

                Text(
                  isEnglish ? 'Options' : 'ตัวเลือก',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                _option(
                  value: _resetDocNumbers,
                  onChanged: (v) => _resetDocNumbers = v,
                  title: isEnglish ? 'Reset document numbers' : 'รีเซ็ตเลขที่เอกสาร',
                  subtitle: isEnglish
                      ? 'Next running number = 1 for every document type and branch '
                          '(${_counts?['doc_numbers'] ?? 0} settings in use)'
                      : 'เลขถัดไป = 1 ทุกประเภทเอกสารและทุกสาขา (ที่ใช้ไปแล้ว ${_counts?['doc_numbers'] ?? 0} รายการ)',
                ),
                _option(
                  value: _resetCheckbooks,
                  onChanged: (v) => _resetCheckbooks = v,
                  title: isEnglish ? 'Reset checkbook numbers' : 'รีเซ็ตเลขเช็คในสมุดเช็ค',
                  subtitle: isEnglish
                      ? 'Next check number back to the first number of the book; used-up books become active '
                          '(${_counts?['checkbooks'] ?? 0} books)'
                      : 'เลขเช็คถัดไปกลับเป็นเลขแรกของเล่ม เล่มที่ใช้หมดกลับมาใช้งานได้ (${_counts?['checkbooks'] ?? 0} เล่ม)',
                ),

                const SizedBox(height: 24),

                // ── Confirm Input ─────────────────────────────────────────
                Text(
                  isEnglish ? 'Confirm' : 'ยืนยันการล้างข้อมูล',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmCtrl,
                  decoration: InputDecoration(
                    labelText: isEnglish
                        ? 'Type "$_confirmText" to enable the reset button'
                        : 'พิมพ์ "$_confirmText" เพื่อเปิดใช้ปุ่มล้างข้อมูล',
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
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.delete_forever),
                    label: Text(
                      _isExecuting
                          ? (isEnglish ? 'Resetting...' : 'กำลังล้างข้อมูล...')
                          : (isEnglish ? 'Reset All Transactions' : 'ล้างธุรกรรมทุกโมดูล'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[800],
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                    ),
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
