import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/utils/sa_menu_scope.dart';

class ApResetScreen extends StatefulWidget {
  const ApResetScreen({super.key});

  @override
  State<ApResetScreen> createState() => _ApResetScreenState();
}

class _ApResetScreenState extends State<ApResetScreen> {
  static const String _baseUrl = AppConfig.apiAp;

  bool _deleteTransactions = true;
  bool _resetDocNumbers = false;
  bool _resetVendorRunning = false;
  bool _resetVendorGroups = false;
  bool _resetVendors = false;
  bool _resetGlAccountSetup = false;

  final _confirmCtrl = TextEditingController();
  bool _isLoadingCounts = false;
  bool _isExecuting = false;
  Map<String, dynamic>? _counts;
  String? _error;

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

  Future<void> _loadCounts() async {
    setState(() {
      _isLoadingCounts = true;
      _error = null;
    });
    try {
      final headers = await AuthService().getAuthHeader();
      final res = await http.get(
        Uri.parse('$_baseUrl/ap_reset_transactions/counts'),
        headers: headers,
      );
      if (res.statusCode == 200) {
        setState(() => _counts = json.decode(res.body));
      } else {
        setState(() => _error = json.decode(res.body)['message'] ?? 'โหลดข้อมูลไม่สำเร็จ');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoadingCounts = false);
    }
  }

  bool get _canExecute =>
      (MenuScope.of(context)?.canDelete ?? true) &&
      _confirmCtrl.text.trim() == 'ยืนยัน' &&
      (_deleteTransactions ||
          _resetDocNumbers ||
          _resetVendorRunning ||
          _resetVendorGroups ||
          _resetVendors ||
          _resetGlAccountSetup) &&
      !_isExecuting;

  Future<void> _execute() async {
    final l = AppL10n(Provider.of<LanguageProvider>(context, listen: false).isEnglish);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
          SizedBox(width: 8),
          Text('ยืนยันการลบข้อมูล'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'การดำเนินการนี้ไม่สามารถยกเลิกได้!\nข้อมูลที่ลบจะหายไปถาวร',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_deleteTransactions) ...[
              _confirmRow(Icons.receipt_long, 'AP Transactions', _counts?['ap_transaction']),
              _confirmRow(Icons.list_alt, 'AP Transaction Details', _counts?['ap_transaction_detail']),
              _confirmRow(Icons.link, 'AP Transaction Apply', _counts?['ap_transaction_apply']),
              _confirmRow(Icons.payment, 'AP Transaction Payments', _counts?['ap_transaction_payment']),
              _confirmRow(Icons.percent, 'VAT Records (AP)', _counts?['vt_transaction']),
            ],
            if (_resetDocNumbers)
              _confirmRow(Icons.format_list_numbered, 'Reset เลขที่เอกสาร AP เป็น 1', null),
            if (_resetVendors)
              _confirmRow(Icons.business, 'เจ้าหนี้ (และที่อยู่/ผู้ติดต่อ/บัญชีธนาคาร)',
                  _counts?['ap_vendor']),
            if (_resetVendorGroups)
              _confirmRow(Icons.groups, 'กลุ่มเจ้าหนี้', _counts?['ap_vendor_group']),
            if (_resetGlAccountSetup)
              _confirmRow(Icons.account_balance, 'ตั้งค่าเชื่อมต่อ GL', _counts?['ap_gl_account_setup']),
            if (_resetVendorRunning)
              _confirmRow(Icons.tag, 'ตั้งค่ารหัสเจ้าหนี้อัตโนมัติ (คืนค่าเริ่มต้น)', null),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('ยืนยัน ลบข้อมูล'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isExecuting = true);
    try {
      final headers = await AuthService().getAuthHeader();
      final res = await http.delete(
        Uri.parse('$_baseUrl/ap_reset_transactions'),
        headers: headers,
        body: json.encode({
          'deleteTransactions': _deleteTransactions,
          'resetDocNumbers':    _resetDocNumbers,
          'resetVendors':       _resetVendors,
          'resetVendorGroups':  _resetVendorGroups,
          'resetGlAccountSetup': _resetGlAccountSetup,
          'resetVendorRunning': _resetVendorRunning,
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
          SnackBar(content: Text('ล้มเหลว: $msg'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isExecuting = false);
    }
  }

  Widget _confirmRow(IconData icon, String label, dynamic count) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Icon(icon, size: 16, color: Colors.red[700]),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          if (count != null) ...[
            const Spacer(),
            Text('$count รายการ',
                style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold)),
          ],
        ]),
      );

  Widget _countCard(IconData icon, String label, String table, dynamic count, Color color) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(table, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ]),
          ),
          if (_isLoadingCounts)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
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

  Widget _masterDataCard({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required Color color,
    required String title,
    required String subtitle,
    required List<String> detailLines,
  }) {
    return Card(
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
            value: value,
            activeColor: color,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: onChanged,
          ),
          if (value)
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: detailLines
                    .map((line) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text('• $line',
                              style: TextStyle(fontSize: 12, color: color)),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.red[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรช',
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
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[300]!),
                  ),
                  child: Column(children: [
                    Row(children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'เครื่องมือสำหรับผู้พัฒนาระบบเท่านั้น',
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
                      'ฟังก์ชันนี้จะลบข้อมูลธุรกรรม AP และ/หรือข้อมูลหลัก '
                      '(เจ้าหนี้, กลุ่มเจ้าหนี้, ตั้งค่าต่างๆ) ตามที่เลือกไว้ด้านล่าง '
                      'ออกจากฐานข้อมูลอย่างถาวร '
                      'หมายเหตุ: GL Entries ที่สร้างจาก AP ต้องล้างแยกที่ GL Reset',
                      style: TextStyle(color: Colors.red[900], fontSize: 13),
                    ),
                  ]),
                ),

                const SizedBox(height: 20),
                const Text('จำนวนข้อมูลในระบบปัจจุบัน',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),

                _countCard(Icons.receipt_long, 'AP Transactions', 'ap_transaction',
                    _counts?['ap_transaction'], Colors.orange[700]!),
                const SizedBox(height: 6),
                _countCard(Icons.list_alt, 'AP Transaction Details', 'ap_transaction_detail',
                    _counts?['ap_transaction_detail'], Colors.deepOrange[400]!),
                const SizedBox(height: 6),
                _countCard(Icons.link, 'AP Transaction Apply', 'ap_transaction_apply',
                    _counts?['ap_transaction_apply'], Colors.amber[700]!),
                const SizedBox(height: 6),
                _countCard(Icons.payment, 'AP Transaction Payments', 'ap_transaction_payment',
                    _counts?['ap_transaction_payment'], Colors.brown[400]!),
                const SizedBox(height: 6),
                _countCard(Icons.percent, 'VAT Records (AP)', 'vt_transaction (module_code=AP)',
                    _counts?['vt_transaction'], Colors.teal[600]!),
                const SizedBox(height: 6),
                _countCard(Icons.format_list_numbered, 'Running Number AP (> 1)',
                    'sa_doc_number_branch', _counts?['ap_doc_number_rows'], Colors.purple[700]!),

                const SizedBox(height: 24),
                const Text('เลือกข้อมูลที่ต้องการลบ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                CheckboxListTile(
                  title: const Text('ลบ AP Transactions ทั้งหมด'),
                  subtitle: Text(
                    'ap_transaction (${_counts?['ap_transaction'] ?? '-'}) + '
                    'detail (${_counts?['ap_transaction_detail'] ?? '-'}) + '
                    'apply (${_counts?['ap_transaction_apply'] ?? '-'}) + '
                    'payment (${_counts?['ap_transaction_payment'] ?? '-'}) + '
                    'VAT (${_counts?['vt_transaction'] ?? '-'}) รายการ',
                  ),
                  value: _deleteTransactions,
                  activeColor: Colors.red[700],
                  onChanged: (v) => setState(() => _deleteTransactions = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  title: const Text('Reset เลขที่เอกสาร AP เป็น 1'),
                  subtitle: Text(
                    'sa_doc_number_branch สำหรับ module AP '
                    '(${_counts?['ap_doc_number_rows'] ?? '-'} branch/doc ที่มีค่า > 1)',
                  ),
                  value: _resetDocNumbers,
                  activeColor: Colors.purple[700],
                  onChanged: (v) => setState(() => _resetDocNumbers = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),

                const SizedBox(height: 24),
                const Text('เลือกข้อมูลหลักที่ต้องการลบ/รีเซ็ต',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'ใช้สำหรับล้างข้อมูลตั้งต้น/ทดสอบก่อนใช้งานจริง — ไม่เลือกรายการใด การ์ดนั้นจะถูกย่อ',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 8),

                _masterDataCard(
                  title: 'ตั้งค่ารหัสเจ้าหนี้อัตโนมัติ',
                  subtitle: 'ap_vendor_running — เปิดใช้งาน: '
                      '${(_counts?['ap_vendor_running']?['is_auto_numbering'] == true) ? 'ใช่' : 'ไม่ใช่'}, '
                      'เลขที่ถัดไป: ${_counts?['ap_vendor_running']?['next_running_number'] ?? '-'}',
                  value: _resetVendorRunning,
                  color: Colors.indigo[700]!,
                  onChanged: (v) => setState(() => _resetVendorRunning = v ?? false),
                  detailLines: const [
                    'คืนค่าเป็นค่าเริ่มต้น: ปิดใช้งาน, รูปแบบ VENDOR-0001, เลขที่ถัดไป = 1',
                  ],
                ),
                const SizedBox(height: 6),

                _masterDataCard(
                  title: 'กลุ่มเจ้าหนี้',
                  subtitle: 'ap_vendor_group (${_counts?['ap_vendor_group'] ?? '-'} รายการ)',
                  value: _resetVendorGroups,
                  color: Colors.blue[700]!,
                  onChanged: (v) => setState(() => _resetVendorGroups = v ?? false),
                  detailLines: const [
                    'ลบกลุ่มเจ้าหนี้ทั้งหมด',
                    'หากเจ้าหนี้ยังอ้างอิงกลุ่มอยู่ ควรเลือก "เจ้าหนี้" ด้วย ไม่เช่นนั้นจะลบไม่ได้',
                  ],
                ),
                const SizedBox(height: 6),

                _masterDataCard(
                  title: 'เจ้าหนี้',
                  subtitle: 'ap_vendor (${_counts?['ap_vendor'] ?? '-'} รายการ)',
                  value: _resetVendors,
                  color: Colors.red[700]!,
                  onChanged: (v) => setState(() => _resetVendors = v ?? false),
                  detailLines: const [
                    'ลบเจ้าหนี้ทั้งหมด รวมที่อยู่/ผู้ติดต่อ/บัญชีธนาคาร',
                    'หากยังมี AP Transactions ของเจ้าหนี้นี้ ต้องเลือก "ลบ AP Transactions ทั้งหมด" ด้วย ไม่เช่นนั้นจะลบไม่ได้',
                  ],
                ),
                const SizedBox(height: 6),

                _masterDataCard(
                  title: 'ตั้งค่าเชื่อมต่อ GL',
                  subtitle: 'ap_gl_account_setup (${_counts?['ap_gl_account_setup'] ?? '-'} รายการ)',
                  value: _resetGlAccountSetup,
                  color: Colors.teal[700]!,
                  onChanged: (v) => setState(() => _resetGlAccountSetup = v ?? false),
                  detailLines: const [
                    'ลบการตั้งค่าบัญชีเชื่อมต่อ GL ตามประเภทเอกสาร/วิธีชำระเงินทั้งหมด',
                  ],
                ),

                const SizedBox(height: 24),

                TextFormField(
                  controller: _confirmCtrl,
                  decoration: InputDecoration(
                    labelText: 'พิมพ์ "ยืนยัน" เพื่อเปิดใช้ปุ่มลบ',
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
                      _isExecuting ? 'กำลังลบข้อมูล...' : 'ลบข้อมูลที่เลือก',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                    'ปุ่มจะพร้อมใช้งานเมื่อพิมพ์ "ยืนยัน" และเลือกอย่างน้อย 1 รายการ',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
