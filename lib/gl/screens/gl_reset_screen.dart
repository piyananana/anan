import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/auth_service.dart';

class GlResetScreen extends StatefulWidget {
  const GlResetScreen({super.key});

  @override
  State<GlResetScreen> createState() => _GlResetScreenState();
}

class _GlResetScreenState extends State<GlResetScreen> {
  static const String _baseUrl = AppConfig.apiGl;

  bool _deleteEntries = true;
  bool _resetDocNumbers = false;

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
        Uri.parse('$_baseUrl/gl_reset_transactions/counts'),
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
      _confirmCtrl.text.trim() == 'ยืนยัน' &&
      (_deleteEntries || _resetDocNumbers) &&
      !_isExecuting;

  Future<void> _execute() async {
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
            if (_deleteEntries) ...[
              _confirmRow(Icons.receipt_long, 'GL Entry Headers', _counts?['gl_entry_header']),
              _confirmRow(Icons.list_alt, 'GL Entry Details', _counts?['gl_entry_detail']),
              _confirmRow(Icons.lock_clock, 'Year-End Closing Sessions', _counts?['gl_year_end_closing']),
            ],
            if (_resetDocNumbers)
              _confirmRow(Icons.format_list_numbered, 'Reset เลขที่เอกสาร GL', null),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
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
        Uri.parse('$_baseUrl/gl_reset_transactions'),
        headers: headers,
        body: json.encode({
          'deleteEntries': _deleteEntries,
          'resetDocNumbers': _resetDocNumbers,
        }),
      );

      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'สำเร็จ'),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 4),
          ),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.delete_forever, color: Colors.white, size: 22),
          SizedBox(width: 8),
          Text('ล้างข้อมูลธุรกรรม GL'),
        ]),
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
                // Warning banner
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
                      'ฟังก์ชันนี้จะลบข้อมูลธุรกรรม GL ออกจากฐานข้อมูลอย่างถาวร '
                      'ข้อมูลหลัก (ผังบัญชี, งวดบัญชี, แบบงบการเงิน, Dimension) จะยังคงอยู่ '
                      'ใช้สำหรับเริ่มต้นระบบใหม่หลังการทดสอบเท่านั้น',
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

                _countCard(Icons.receipt_long, 'GL Entry Headers', 'gl_entry_header',
                    _counts?['gl_entry_header'], Colors.orange[700]!),
                const SizedBox(height: 6),
                _countCard(Icons.list_alt, 'GL Entry Details', 'gl_entry_detail',
                    _counts?['gl_entry_detail'], Colors.deepOrange[400]!),
                const SizedBox(height: 6),
                _countCard(Icons.lock_clock, 'Year-End Closing Sessions', 'gl_year_end_closing',
                    _counts?['gl_year_end_closing'], Colors.red[300]!),
                const SizedBox(height: 6),
                _countCard(Icons.format_list_numbered, 'Running Number GL (> 0)',
                    'sa_doc_number_branch', _counts?['gl_doc_number_rows'], Colors.purple[700]!),

                const SizedBox(height: 24),
                const Text('เลือกข้อมูลที่ต้องการลบ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                CheckboxListTile(
                  title: const Text('ลบ GL Entries ทั้งหมด'),
                  subtitle: Text(
                    'gl_entry_header (${_counts?['gl_entry_header'] ?? '-'}) + '
                    'gl_entry_detail (${_counts?['gl_entry_detail'] ?? '-'}) + '
                    'gl_year_end_closing (${_counts?['gl_year_end_closing'] ?? '-'}) รายการ',
                  ),
                  value: _deleteEntries,
                  activeColor: Colors.red[700],
                  onChanged: (v) => setState(() => _deleteEntries = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  title: const Text('Reset เลขที่เอกสาร GL เป็น 1'),
                  subtitle: Text(
                    'sa_doc_number_branch สำหรับ module GL '
                    '(${_counts?['gl_doc_number_rows'] ?? '-'} branch/doc ที่มีค่า > 0)',
                  ),
                  value: _resetDocNumbers,
                  activeColor: Colors.purple[700],
                  onChanged: (v) => setState(() => _resetDocNumbers = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),

                const SizedBox(height: 24),

                // Confirmation field
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

                // Execute button
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _canExecute ? _execute : null,
                    icon: _isExecuting
                        ? const SizedBox(
                            width: 20, height: 20,
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
