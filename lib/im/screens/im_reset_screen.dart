import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/utils/sa_menu_scope.dart';

class ImResetScreen extends StatefulWidget {
  const ImResetScreen({super.key});

  @override
  State<ImResetScreen> createState() => _ImResetScreenState();
}

class _ImResetScreenState extends State<ImResetScreen> {
  static const String _baseUrl = AppConfig.apiIm;

  bool _deleteTransactions = true;
  bool _resetDocNumbers = false;

  // ข้อมูลหลัก (master data) — ปิดไว้เป็นค่าเริ่มต้นเพราะมีผลกว้างกว่าข้อมูลธุรกรรม
  bool _resetBom = false;
  bool _resetPriceList = false;
  bool _resetItems = false;
  bool _resetItemCategories = false;
  bool _resetUom = false;
  bool _resetWarehouses = false;
  bool _resetGlAccountSetup = false;
  bool _resetAccountingSetting = false;
  bool _resetItemRunning = false;

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
        Uri.parse('$_baseUrl/im_reset_transactions/counts'),
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
          _resetBom ||
          _resetPriceList ||
          _resetItems ||
          _resetItemCategories ||
          _resetUom ||
          _resetWarehouses ||
          _resetGlAccountSetup ||
          _resetAccountingSetting ||
          _resetItemRunning) &&
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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'การดำเนินการนี้ไม่สามารถยกเลิกได้!\nข้อมูลที่ลบจะหายไปถาวร',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (_deleteTransactions) ...[
                _confirmRow(Icons.receipt_long, 'IM Transactions', _counts?['im_transaction']),
                _confirmRow(Icons.list_alt, 'IM Transaction Details', _counts?['im_transaction_detail']),
                _confirmRow(Icons.layers, 'Stock Layers', _counts?['im_stock_layer']),
                _confirmRow(Icons.fact_check, 'ชุดตรวจนับสต็อก', _counts?['im_stock_count']),
                _confirmRow(Icons.pie_chart, 'ยอดคงเหลือสินค้า (Stock Balance)', _counts?['im_stock_balance']),
                _confirmRow(Icons.event_note, 'ประวัติปิดงวดสินค้าคงคลัง', _counts?['im_period_closing']),
                _confirmRow(Icons.upload_file, 'ประวัตินำเข้ายอดยกมา', _counts?['im_opening_balance_batch']),
              ],
              if (_resetDocNumbers)
                _confirmRow(Icons.format_list_numbered, 'Reset เลขที่เอกสาร IM เป็น 1', null),
              if (_resetBom)
                _confirmRow(Icons.precision_manufacturing, 'สูตรการผลิต (BOM)', _counts?['im_bom_header']),
              if (_resetPriceList)
                _confirmRow(Icons.sell, 'ราคาขาย (Price List)', _counts?['im_price_list']),
              if (_resetItems)
                _confirmRow(Icons.inventory_2, 'สินค้า (และหน่วยนับทางเลือก/คลังตั้งต้นของสินค้า)', _counts?['im_item']),
              if (_resetItemCategories)
                _confirmRow(Icons.category, 'หมวดหมู่สินค้า', _counts?['im_item_category']),
              if (_resetUom)
                _confirmRow(Icons.straighten, 'หน่วยนับ', _counts?['im_uom']),
              if (_resetWarehouses)
                _confirmRow(Icons.warehouse, 'คลังสินค้า (และตำแหน่งจัดเก็บในคลัง)', _counts?['im_warehouse']),
              if (_resetGlAccountSetup)
                _confirmRow(Icons.account_balance, 'ตั้งค่าเชื่อมต่อ GL', _counts?['im_gl_account_setup']),
              if (_resetAccountingSetting)
                _confirmRow(Icons.settings, 'ตั้งค่าโหมดบัญชีสินค้าคงคลัง (คืนค่าเป็น Perpetual)', null),
              if (_resetItemRunning)
                _confirmRow(Icons.tag, 'ตั้งค่ารหัสอัตโนมัติ (สินค้า + ชุดนับสต็อก, คืนค่าเริ่มต้น)', null),
            ],
          ),
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
        Uri.parse('$_baseUrl/im_reset_transactions'),
        headers: headers,
        body: json.encode({
          'deleteTransactions': _deleteTransactions,
          'resetDocNumbers': _resetDocNumbers,
          'resetBom': _resetBom,
          'resetPriceList': _resetPriceList,
          'resetItems': _resetItems,
          'resetItemCategories': _resetItemCategories,
          'resetUom': _resetUom,
          'resetWarehouses': _resetWarehouses,
          'resetGlAccountSetup': _resetGlAccountSetup,
          'resetAccountingSetting': _resetAccountingSetting,
          'resetItemRunning': _resetItemRunning,
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
      Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
      if (count != null) ...[
        const SizedBox(width: 8),
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
                          child: Text('• $line', style: TextStyle(fontSize: 12, color: color)),
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
                      'ฟังก์ชันนี้จะลบข้อมูลธุรกรรม IM และ/หรือข้อมูลหลัก '
                      '(สินค้า, หมวดหมู่, หน่วยนับ, คลังสินค้า, BOM, ราคาขาย, ตั้งค่าต่างๆ) ตามที่เลือกไว้ด้านล่าง '
                      'ออกจากฐานข้อมูลอย่างถาวร\n'
                      'หมายเหตุ: ใบตั้งหนี้ AP / ใบแจ้งหนี้ AR ที่ IM สร้างให้อัตโนมัติ (GRN/DLN Billing, CN/DN) '
                      'ต้องล้างแยกที่ AP Reset / AR Reset — GL Entries ต้องล้างแยกที่ GL Reset',
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

                _countCard(Icons.receipt_long, 'IM Transactions', 'im_transaction',
                    _counts?['im_transaction'], Colors.orange[700]!),
                const SizedBox(height: 6),
                _countCard(Icons.list_alt, 'IM Transaction Details', 'im_transaction_detail',
                    _counts?['im_transaction_detail'], Colors.deepOrange[400]!),
                const SizedBox(height: 6),
                _countCard(Icons.layers, 'Stock Layers (FIFO/SPECIFIC)', 'im_stock_layer',
                    _counts?['im_stock_layer'], Colors.amber[700]!),
                const SizedBox(height: 6),
                _countCard(Icons.pie_chart, 'ยอดคงเหลือสินค้า (Stock Balance)', 'im_stock_balance',
                    _counts?['im_stock_balance'], Colors.brown[400]!),
                const SizedBox(height: 6),
                _countCard(Icons.fact_check, 'ชุดตรวจนับสต็อก', 'im_stock_count',
                    _counts?['im_stock_count'], Colors.teal[600]!),
                const SizedBox(height: 6),
                _countCard(Icons.event_note, 'ประวัติปิดงวดสินค้าคงคลัง', 'im_period_closing',
                    _counts?['im_period_closing'], Colors.indigo[400]!),
                const SizedBox(height: 6),
                _countCard(Icons.upload_file, 'ประวัตินำเข้ายอดยกมา', 'im_opening_balance_batch',
                    _counts?['im_opening_balance_batch'], Colors.blueGrey[400]!),
                const SizedBox(height: 6),
                _countCard(Icons.format_list_numbered, 'Running Number IM (> 1)',
                    'sa_doc_number_branch', _counts?['im_doc_number_rows'], Colors.purple[700]!),

                const SizedBox(height: 24),
                const Text('เลือกข้อมูลที่ต้องการลบ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                CheckboxListTile(
                  title: const Text('ลบ IM Transactions ทั้งหมด'),
                  subtitle: Text(
                    'im_transaction (${_counts?['im_transaction'] ?? '-'}) + '
                    'detail (${_counts?['im_transaction_detail'] ?? '-'}) + '
                    'stock layer (${_counts?['im_stock_layer'] ?? '-'}) + '
                    'ชุดตรวจนับ (${_counts?['im_stock_count'] ?? '-'}) + '
                    'ยอดคงเหลือสินค้า + ประวัติปิดงวด + ประวัตินำเข้ายอดยกมา',
                  ),
                  value: _deleteTransactions,
                  activeColor: Colors.red[700],
                  onChanged: (v) => setState(() => _deleteTransactions = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  title: const Text('Reset เลขที่เอกสาร IM เป็น 1'),
                  subtitle: Text(
                    'sa_doc_number_branch สำหรับ module IM '
                    '(${_counts?['im_doc_number_rows'] ?? '-'} branch/doc ที่มีค่า > 1)',
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
                  title: 'สูตรการผลิต (BOM)',
                  subtitle: 'im_bom_header (${_counts?['im_bom_header'] ?? '-'} รายการ)',
                  value: _resetBom,
                  color: Colors.deepPurple[600]!,
                  onChanged: (v) => setState(() => _resetBom = v ?? false),
                  detailLines: const [
                    'ลบสูตรการผลิต (BOM) ทั้งหมด รวมรายการวัตถุดิบ',
                    'ต้องลบก่อน "สินค้า" เสมอ — BOM ยังอ้างอิงสินค้าอยู่ ไม่เช่นนั้นจะลบสินค้าไม่ได้',
                  ],
                ),
                const SizedBox(height: 6),

                _masterDataCard(
                  title: 'ราคาขาย (Price List)',
                  subtitle: 'im_price_list (${_counts?['im_price_list'] ?? '-'} รายการ)',
                  value: _resetPriceList,
                  color: Colors.pink[600]!,
                  onChanged: (v) => setState(() => _resetPriceList = v ?? false),
                  detailLines: const [
                    'ลบราคาขายทั้งหมด รวมรายการราคาต่อสินค้า',
                    'ต้องลบก่อน "สินค้า" เสมอ — Price List ยังอ้างอิงสินค้าอยู่ ไม่เช่นนั้นจะลบสินค้าไม่ได้',
                  ],
                ),
                const SizedBox(height: 6),

                _masterDataCard(
                  title: 'สินค้า',
                  subtitle: 'im_item (${_counts?['im_item'] ?? '-'} รายการ)',
                  value: _resetItems,
                  color: Colors.red[700]!,
                  onChanged: (v) => setState(() => _resetItems = v ?? false),
                  detailLines: const [
                    'ลบสินค้าทั้งหมด รวมหน่วยนับทางเลือก/การตั้งค่าต่อคลังของสินค้า',
                    'หากยังมี BOM/Price List/IM Transactions/สต็อกคงเหลือของสินค้านี้ ต้องเลือกรายการนั้นด้วย ไม่เช่นนั้นจะลบไม่ได้',
                  ],
                ),
                const SizedBox(height: 6),

                _masterDataCard(
                  title: 'หมวดหมู่สินค้า',
                  subtitle: 'im_item_category (${_counts?['im_item_category'] ?? '-'} รายการ)',
                  value: _resetItemCategories,
                  color: Colors.blue[700]!,
                  onChanged: (v) => setState(() => _resetItemCategories = v ?? false),
                  detailLines: const [
                    'ลบหมวดหมู่สินค้าทั้งหมด (รวมหมวดหมู่ย่อย)',
                    'หากสินค้ายังอ้างอิงหมวดหมู่อยู่ ควรเลือก "สินค้า" ด้วย ไม่เช่นนั้นจะลบไม่ได้',
                  ],
                ),
                const SizedBox(height: 6),

                _masterDataCard(
                  title: 'หน่วยนับ',
                  subtitle: 'im_uom (${_counts?['im_uom'] ?? '-'} รายการ)',
                  value: _resetUom,
                  color: Colors.cyan[700]!,
                  onChanged: (v) => setState(() => _resetUom = v ?? false),
                  detailLines: const [
                    'ลบหน่วยนับทั้งหมด',
                    'หากสินค้ายังอ้างอิงหน่วยนับหลัก/หน่วยนับทางเลือกอยู่ ควรเลือก "สินค้า" ด้วย ไม่เช่นนั้นจะลบไม่ได้',
                  ],
                ),
                const SizedBox(height: 6),

                _masterDataCard(
                  title: 'คลังสินค้า / ตำแหน่งจัดเก็บ',
                  subtitle: 'im_warehouse (${_counts?['im_warehouse'] ?? '-'} รายการ) — '
                      'ตำแหน่งจัดเก็บ (${_counts?['im_location'] ?? '-'} รายการ)',
                  value: _resetWarehouses,
                  color: Colors.brown[600]!,
                  onChanged: (v) => setState(() => _resetWarehouses = v ?? false),
                  detailLines: const [
                    'ลบคลังสินค้าทั้งหมด รวมตำแหน่งจัดเก็บในคลังทุกตำแหน่ง',
                    'หากยังมีสินค้า/ธุรกรรม/สต็อกคงเหลือ/ชุดตรวจนับที่อ้างอิงคลังนี้ ต้องล้างรายการนั้นก่อน ไม่เช่นนั้นจะลบไม่ได้',
                  ],
                ),
                const SizedBox(height: 6),

                _masterDataCard(
                  title: 'ตั้งค่าเชื่อมต่อ GL',
                  subtitle: 'im_gl_account_setup (${_counts?['im_gl_account_setup'] ?? '-'} รายการ)',
                  value: _resetGlAccountSetup,
                  color: Colors.teal[700]!,
                  onChanged: (v) => setState(() => _resetGlAccountSetup = v ?? false),
                  detailLines: const [
                    'ลบการตั้งค่าบัญชีเชื่อมต่อ GL ตามประเภทเอกสารทั้งหมด',
                  ],
                ),
                const SizedBox(height: 6),

                _masterDataCard(
                  title: 'ตั้งค่าโหมดบัญชีสินค้าคงคลัง',
                  subtitle: (_counts?['im_accounting_setting_configured'] == true) ? 'ตั้งค่าแล้ว' : 'ยังไม่ตั้งค่า',
                  value: _resetAccountingSetting,
                  color: Colors.deepOrange[700]!,
                  onChanged: (v) => setState(() => _resetAccountingSetting = v ?? false),
                  detailLines: const [
                    'คืนค่าโหมดบัญชีสินค้าคงคลังเป็น Perpetual (ค่าเริ่มต้น)',
                    'ล้างบัญชีสต็อก/ต้นทุนขาย/ซื้อสินค้า/GL Document Type ปิดงวดที่ตั้งไว้เป็นค่าว่างทั้งหมด',
                  ],
                ),
                const SizedBox(height: 6),

                _masterDataCard(
                  title: 'ตั้งค่ารหัสอัตโนมัติ',
                  subtitle: 'สินค้า — เปิดใช้งาน: '
                      '${(_counts?['im_item_running']?['is_auto_numbering'] == true) ? 'ใช่' : 'ไม่ใช่'}, '
                      'เลขที่ถัดไป: ${_counts?['im_item_running']?['next_running_number'] ?? '-'}  |  '
                      'ชุดนับสต็อก — เลขที่ถัดไป: ${_counts?['im_stock_count_running']?['next_running_number'] ?? '-'}',
                  value: _resetItemRunning,
                  color: Colors.indigo[700]!,
                  onChanged: (v) => setState(() => _resetItemRunning = v ?? false),
                  detailLines: const [
                    'สินค้า: คืนค่าเป็นค่าเริ่มต้น ปิดใช้งาน, รูปแบบ ITEM-0001, เลขที่ถัดไป = 1',
                    'ชุดนับสต็อก: คืนค่าเป็นค่าเริ่มต้น เปิดใช้งาน, รูปแบบ CNT-000001, เลขที่ถัดไป = 1',
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
