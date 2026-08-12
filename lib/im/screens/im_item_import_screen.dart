import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../sa/services/sa_auth_service.dart';
import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_app_l10n.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../utils/file_download.dart';

class ImItemImportScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;

  const ImItemImportScreen({super.key, required this.onFieldsChanged});

  @override
  State<ImItemImportScreen> createState() => _ImItemImportScreenState();
}

class _ImItemImportScreenState extends State<ImItemImportScreen> {
  // File state
  String? _fileName;
  Uint8List? _fileBytes;
  String? _fileExtension;

  // Template (loaded dynamically so it always matches the backend)
  List<Map<String, dynamic>> _templateSheets = [];

  // Validation result
  bool _isValidated = false;
  int _totalRows = 0;
  int _validRows = 0;
  int _errorRows = 0;
  List<Map<String, dynamic>> _errors = [];
  List<Map<String, dynamic>> _validatedData = [];

  bool _isLoading = false;
  bool _isImporting = false;

  final _previewScrollCtrl = ScrollController();

  static const _appColor = Colors.teal;

  @override
  void initState() {
    super.initState();
    _loadTemplateSheets();
  }

  @override
  void dispose() {
    _previewScrollCtrl.dispose();
    super.dispose();
  }

  // ─── Template definition ─────────────────────────────────────────────────

  Future<void> _loadTemplateSheets() async {
    try {
      final authService = context.read<AuthService>();
      final headers = await authService.getAuthHeader();
      final response = await http.get(
        Uri.parse('${AppConfig.apiIm}/im_item/import/template'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _templateSheets = List<Map<String, dynamic>>.from(data['sheets'] ?? []);
        });
      }
    } catch (_) {}
  }

  // ─── File picker ──────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    setState(() {
      _fileName = file.name;
      _fileBytes = file.bytes;
      _fileExtension = file.extension?.toLowerCase();
      _isValidated = false;
      _errors = [];
      _validatedData = [];
    });
  }

  // ─── Validate ─────────────────────────────────────────────────────────────

  Future<void> _validate() async {
    if (_fileBytes == null) return;
    setState(() => _isLoading = true);
    try {
      final authService = context.read<AuthService>();
      final headers = await authService.getAuthHeader();

      final uri = Uri.parse('${AppConfig.apiIm}/im_item/import/validate');
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(headers);

      final mimeType = _fileExtension == 'csv'
          ? 'text/csv'
          : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

      request.files.add(http.MultipartFile.fromBytes(
        'file',
        _fileBytes!,
        filename: _fileName!,
        contentType: MediaType.parse(mimeType),
      ));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _isValidated = true;
          _totalRows = (data['totalRows'] as num).toInt();
          _validRows = (data['validRows'] as num).toInt();
          _errorRows = (data['errorRows'] as num).toInt();
          _errors = List<Map<String, dynamic>>.from(data['errors'] ?? []);
          _validatedData = List<Map<String, dynamic>>.from(data['data'] ?? []);
        });
      } else {
        final body = jsonDecode(response.body);
        _showSnack(body['message'] ?? 'เกิดข้อผิดพลาด', isError: true);
      }
    } catch (e) {
      _showSnack('เกิดข้อผิดพลาด: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ─── Confirm import ───────────────────────────────────────────────────────

  Future<void> _confirmImport() async {
    final l = AppL10n(Provider.of<LanguageProvider>(context, listen: false).isEnglish);
    if (_validatedData.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการนำเข้า'),
        content: Text('ต้องการนำเข้าข้อมูลสินค้า $_validRows รายการใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(l.confirm, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isImporting = true);
    try {
      final authService = context.read<AuthService>();
      final headers = await authService.getAuthHeader();
      headers['Content-Type'] = 'application/json';

      final response = await http.post(
        Uri.parse('${AppConfig.apiIm}/im_item/import/confirm'),
        headers: headers,
        body: jsonEncode({'rows': _validatedData}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final imported = data['imported'] ?? 0;
        final skipped = data['skipped'] ?? 0;
        final errs = (data['errors'] as List?)?.length ?? 0;
        if (mounted) {
          _showSnack(
            'นำเข้าสำเร็จ $imported รายการ'
            '${skipped > 0 ? '  |  ข้ามรหัสซ้ำ $skipped รายการ' : ''}'
            '${errs > 0 ? '  |  ผิดพลาด $errs รายการ' : ''}',
          );
          setState(() {
            _fileName = null;
            _fileBytes = null;
            _isValidated = false;
            _errors = [];
            _validatedData = [];
          });
          widget.onFieldsChanged();
        }
      } else {
        String errMsg = 'เกิดข้อผิดพลาด (${response.statusCode})';
        try {
          final body = jsonDecode(response.body);
          errMsg = body['message'] ?? errMsg;
        } catch (_) {
          if (response.body.isNotEmpty) errMsg = response.body;
        }
        _showSnack(errMsg, isError: true);
      }
    } catch (e) {
      _showSnack('เกิดข้อผิดพลาด: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppL10n(context.watch<LanguageProvider>().isEnglish);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _appColor.shade700,
        foregroundColor: Colors.white,
        title: const MenuTitle(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'เริ่มใหม่',
            onPressed: () => setState(() {
              _fileName = null;
              _fileBytes = null;
              _fileExtension = null;
              _isValidated = false;
              _totalRows = 0;
              _validRows = 0;
              _errorRows = 0;
              _errors = [];
              _validatedData = [];
              _isLoading = false;
              _isImporting = false;
            }),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildTemplateSection(),
          const SizedBox(height: 16),
          _buildFilePickerSection(),
          if (_isValidated) ...[
            const SizedBox(height: 16),
            _buildResultSection(),
          ],
          const SizedBox(height: 80),
        ]),
      ),
      bottomNavigationBar: _isValidated && _errorRows == 0 && _validRows > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton.icon(
                  onPressed: (_isImporting || !(MenuScope.of(context)?.canCreate ?? true))
                      ? null
                      : _confirmImport,
                  icon: _isImporting
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_isImporting
                      ? 'กำลังนำเข้า...'
                      : 'ยืนยันนำเข้าข้อมูล $_validRows รายการ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  // ─── Template section ─────────────────────────────────────────────────────

  Future<void> _downloadTemplate() async {
    try {
      final authService = context.read<AuthService>();
      final headers = await authService.getAuthHeader();
      final response = await http.get(
        Uri.parse('${AppConfig.apiIm}/im_item/import/template/download'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        await downloadFile(response.bodyBytes, 'im_item_template.xlsx');
      } else {
        _showSnack('ดาวน์โหลดเทมเพลตไม่สำเร็จ (${response.statusCode})', isError: true);
      }
    } catch (e) {
      _showSnack('เกิดข้อผิดพลาด: $e', isError: true);
    }
  }

  Widget _buildTemplateSection() {
    return Card(
      child: ExpansionTile(
        leading: Icon(Icons.table_chart_outlined, color: _appColor.shade700),
        title: const Text('เทมเพลตนำเข้าข้อมูล',
            style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('คลิกเพื่อดูรายละเอียดคอลัมน์ในแต่ละ sheet'),
        trailing: OutlinedButton.icon(
          onPressed: _downloadTemplate,
          icon: const Icon(Icons.download, size: 18),
          label: const Text('ดาวน์โหลดเทมเพลต'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _appColor.shade700,
            side: BorderSide(color: _appColor.shade700),
          ),
        ),
        initiallyExpanded: false,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'เทมเพลตประกอบด้วย 4 sheet ตามหัวข้อข้อมูลสินค้า ทุก sheet (ยกเว้น "ข้อมูลพื้นฐาน") '
              'ใช้คอลัมน์ "old_item_code" (รหัสสินค้าเก่า) เป็นตัวเชื่อมข้อมูลกับแถวใน sheet "ข้อมูลพื้นฐาน"\n'
              '★ = จำเป็นต้องระบุ',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
          for (final sheet in _templateSheets) _buildTemplateSheetTile(sheet),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTemplateSheetTile(Map<String, dynamic> sheet) {
    final columns = List<Map<String, dynamic>>.from(sheet['columns'] ?? []);
    return ExpansionTile(
      title: Text(sheet['name']?.toString() ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: DataTable(
            columnSpacing: 16,
            headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
            columns: const [
              DataColumn(label: Text('ชื่อ Header', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('ความหมาย',   style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('จำเป็น',      style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('ตัวอย่าง',   style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: columns
                .map((col) => DataRow(cells: [
                      DataCell(Text(col['key']?.toString() ?? '',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                      DataCell(Text(col['label']?.toString() ?? '')),
                      DataCell((col['required'] as bool? ?? false)
                          ? const Icon(Icons.star, color: Colors.red, size: 14)
                          : const Text('-', style: TextStyle(color: Colors.grey))),
                      DataCell(Text(col['example']?.toString() ?? '',
                          style: const TextStyle(color: Colors.grey, fontSize: 12))),
                    ]))
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ─── File picker section ──────────────────────────────────────────────────

  Widget _buildFilePickerSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('เลือกไฟล์นำเข้า',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          const Text('รองรับไฟล์ .xlsx, .xls, .csv',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.grey.shade50,
                ),
                child: Text(
                  _fileName ?? 'ยังไม่ได้เลือกไฟล์',
                  style: TextStyle(
                      color: _fileName != null ? Colors.black87 : Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('เลือกไฟล์'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _fileBytes == null || _isLoading ? null : _validate,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.fact_check_outlined),
              label: const Text('ตรวจสอบ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _appColor.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  // ─── Validation result section ────────────────────────────────────────────

  Widget _buildResultSection() {
    final allOk = _errorRows == 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Card(
        color: allOk ? Colors.green.shade50 : Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Icon(
              allOk ? Icons.check_circle : Icons.warning_amber_rounded,
              color: allOk ? Colors.green.shade700 : Colors.orange.shade700,
              size: 36,
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                allOk
                    ? 'ข้อมูลถูกต้องทั้งหมด พร้อมนำเข้า'
                    : 'พบข้อมูลไม่ถูกต้อง กรุณาแก้ไขไฟล์แล้วตรวจสอบใหม่',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: allOk ? Colors.green.shade800 : Colors.orange.shade800),
              ),
              const SizedBox(height: 4),
              Text(
                'ทั้งหมด: $_totalRows รายการ'
                '   ถูกต้อง: $_validRows รายการ'
                '   ไม่ถูกต้อง: $_errorRows รายการ',
                style: const TextStyle(fontSize: 13),
              ),
            ]),
          ]),
        ),
      ),

      if (_errors.isNotEmpty) ...[
        const SizedBox(height: 16),
        const Text('รายการที่ไม่ถูกต้อง',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 14)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            headingRowColor: WidgetStateProperty.all(Colors.red.shade50),
            columns: const [
              DataColumn(label: Text('แถวที่')),
              DataColumn(label: Text('รหัสสินค้า')),
              DataColumn(label: Text('คอลัมน์')),
              DataColumn(label: Text('ข้อผิดพลาด')),
            ],
            rows: [
              for (final e in _errors)
                for (final err in (e['errors'] as List))
                  DataRow(
                    color: WidgetStateProperty.all(Colors.red.shade50),
                    cells: [
                      DataCell(Text('${e['row']}')),
                      DataCell(Text(e['itemCode'] ?? '')),
                      DataCell(Text(err['column'] ?? '',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                      DataCell(Text(err['message'] ?? '')),
                    ],
                  ),
            ],
          ),
        ),
      ],

      if (_validRows > 0) ...[
        const SizedBox(height: 16),
        Text(
          'ตัวอย่างข้อมูลที่จะนำเข้า${_validRows > 50 ? ' (แสดง 50 จาก $_validRows รายการ)' : ' ($_validRows รายการ)'}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        const Text('คลิกแถวเพื่อดูรายละเอียดทุกหัวข้อของสินค้า',
            style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        Scrollbar(
          controller: _previewScrollCtrl,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _previewScrollCtrl,
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 12,
              headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
              columns: const [
                DataColumn(label: Text('รหัสสินค้า')),
                DataColumn(label: Text('หมวดหมู่')),
                DataColumn(label: Text('ชื่อ (ไทย)')),
                DataColumn(label: Text('ชื่อ (อังกฤษ)')),
                DataColumn(label: Text('ประเภทสินค้า')),
                DataColumn(label: Text('หน่วยนับหลัก')),
                DataColumn(label: Text('คลังตั้งต้น')),
                DataColumn(label: Text('ใช้งาน')),
              ],
              rows: _validatedData
                  .take(50)
                  .map((r) => DataRow(
                        onSelectChanged: (_) => _showItemDetailDialog(r),
                        cells: [
                          DataCell(Text(r['item_code']?.toString() ?? '(อัตโนมัติ)')),
                          DataCell(Text(_fmt(r['category_code']))),
                          DataCell(ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Text(r['item_name_th']?.toString() ?? '',
                                overflow: TextOverflow.ellipsis),
                          )),
                          DataCell(ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Text(r['item_name_en']?.toString() ?? '',
                                overflow: TextOverflow.ellipsis),
                          )),
                          DataCell(Text(_fmt(r['item_type']))),
                          DataCell(Text(_fmt(r['base_uom_code']))),
                          DataCell(Text(_fmt(r['default_warehouse_code']))),
                          DataCell(Text(_fmt(r['is_active']))),
                        ],
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    ]);
  }

  // ─── Item detail dialog (tabbed, per im_item_detail_widget sections) ─────

  static const _uomConversionColumns = [
    ['uom_code', 'หน่วยนับ'],
    ['conversion_factor', 'อัตราแปลง'],
    ['barcode', 'บาร์โค้ด'],
    ['is_purchase_default', 'หน่วยซื้อตั้งต้น'],
    ['is_sales_default', 'หน่วยขายตั้งต้น'],
  ];

  static const _itemWarehouseColumns = [
    ['warehouse_id', 'คลังสินค้า (id)'],
    ['min_stock_qty', 'สต็อกขั้นต่ำ'],
    ['max_stock_qty', 'สต็อกสูงสุด'],
    ['reorder_point', 'จุดสั่งซื้อ'],
    ['default_location_id', 'ตำแหน่งจัดเก็บ (id)'],
  ];

  void _showItemDetailDialog(Map<String, dynamic> row) {
    const tabLabels = [
      'ข้อมูลพื้นฐาน',
      'หน่วยนับทางเลือก',
      'คลังสินค้า',
      'บัญชี GL',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        final size = MediaQuery.of(ctx).size;
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: SizedBox(
            width: size.width * 0.9,
            height: size.height * 0.9,
            child: DefaultTabController(
              length: tabLabels.length,
              child: Column(children: [
                AppBar(
                  automaticallyImplyLeading: false,
                  backgroundColor: _appColor.shade700,
                  foregroundColor: Colors.white,
                  title: Text(
                    '${row['item_code']?.toString() ?? '(อัตโนมัติ)'} - ${row['item_name_th']?.toString() ?? ''}',
                    style: const TextStyle(fontSize: 15, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                  bottom: TabBar(
                    isScrollable: true,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: tabLabels.map((l) => Tab(text: l)).toList(),
                  ),
                ),
                Expanded(
                  child: TabBarView(children: [
                    _buildGeneralTab(row),
                    _buildListTable(row['uom_conversions'] as List? ?? [], _uomConversionColumns),
                    _buildListTable(row['item_warehouses'] as List? ?? [], _itemWarehouseColumns),
                    _buildGlAccountTab(row),
                  ]),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGeneralTab(Map<String, dynamic> row) {
    final items = <List<String>>[
      ['รหัสสินค้า', row['item_code']?.toString() ?? '(อัตโนมัติ)'],
      ['หมวดหมู่', _fmt(row['category_code'])],
      ['รหัสเก่า', _fmt(row['old_item_code'])],
      ['ชื่อ (ไทย)', _fmt(row['item_name_th'])],
      ['ชื่อ (อังกฤษ)', _fmt(row['item_name_en'])],
      ['บาร์โค้ด', _fmt(row['barcode'])],
      ['คำอธิบาย', _fmt(row['description'])],
      ['ประเภทสินค้า', _fmt(row['item_type'])],
      ['หน่วยนับหลัก', _fmt(row['base_uom_code'])],
      ['วิธีคำนวณต้นทุน', _fmt(row['costing_method'])],
      ['ต้นทุนมาตรฐาน', _fmt(row['standard_cost'])],
      ['ซื้อได้', _fmt(row['is_purchase_item'])],
      ['ขายได้', _fmt(row['is_sales_item'])],
      ['ผลิตได้', _fmt(row['is_manufactured'])],
      ['ติดตาม Lot', _fmt(row['is_lot_tracked'])],
      ['ติดตาม Serial', _fmt(row['is_serial_tracked'])],
      ['อายุสินค้า (วัน)', _fmt(row['shelf_life_days'])],
      ['คลังสินค้าตั้งต้น', _fmt(row['default_warehouse_code'])],
      ['สต็อกขั้นต่ำ', _fmt(row['min_stock_qty'])],
      ['สต็อกสูงสุด', _fmt(row['max_stock_qty'])],
      ['จุดสั่งซื้อ', _fmt(row['reorder_point'])],
      ['ประเภทภาษี VAT ตั้งต้น', _fmt(row['default_vat_type'])],
      ['ใช้งาน', _fmt(row['is_active'])],
    ];
    return _buildKeyValueTable(items);
  }

  Widget _buildGlAccountTab(Map<String, dynamic> row) {
    final items = <List<String>>[
      ['รหัสบัญชีสินค้าคงเหลือ', _fmt(row['inventory_account_code'])],
      ['รหัสบัญชีต้นทุนขาย', _fmt(row['cogs_account_code'])],
      ['รหัสบัญชีรายได้', _fmt(row['revenue_account_code'])],
      ['รหัสบัญชีค่าใช้จ่าย', _fmt(row['expense_account_code'])],
    ];
    return _buildKeyValueTable(items);
  }

  Widget _buildKeyValueTable(List<List<String>> items) {
    return _DualScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: items
              .map((kv) => TableRow(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      child: Text(kv[0],
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 240),
                        child: Text(kv[1].isEmpty ? '-' : kv[1]),
                      ),
                    ),
                  ]))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildListTable(List<dynamic> rows, List<List<String>> columns) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('ไม่มีข้อมูล', style: TextStyle(color: Colors.grey)),
      );
    }
    return _DualScrollView(
      child: DataTable(
        columnSpacing: 16,
        headingRowColor: WidgetStateProperty.all(Colors.blueGrey.shade50),
        columns: columns
            .map((c) => DataColumn(
                label: Text(c[1],
                    style: const TextStyle(fontWeight: FontWeight.bold))))
            .toList(),
        rows: rows.map((r) {
          final map = r as Map<String, dynamic>;
          return DataRow(
            cells: columns
                .map((c) => DataCell(Text(_fmt(map[c[0]]))))
                .toList(),
          );
        }).toList(),
      ),
    );
  }

  String _fmtNum(dynamic v) {
    if (v == null) return '0';
    final n = v is num ? v : num.tryParse(v.toString()) ?? 0;
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n.toString();
  }

  String _fmt(dynamic val) {
    if (val == null) return '';
    if (val is bool) return val ? 'ใช่' : 'ไม่ใช่';
    if (val is List) return val.map((e) => _fmtNum(e)).join(', ');
    if (val is num) return _fmtNum(val);
    return val.toString();
  }
}

// ─── Dual scrollbar (vertical + horizontal) wrapper ─────────────────────────
class _DualScrollView extends StatefulWidget {
  final Widget child;
  const _DualScrollView({required this.child});

  @override
  State<_DualScrollView> createState() => _DualScrollViewState();
}

class _DualScrollViewState extends State<_DualScrollView> {
  final _vertCtrl = ScrollController();
  final _horzCtrl = ScrollController();

  @override
  void dispose() {
    _vertCtrl.dispose();
    _horzCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _vertCtrl,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _vertCtrl,
        child: Scrollbar(
          controller: _horzCtrl,
          thumbVisibility: true,
          notificationPredicate: (notif) => notif.depth == 0,
          child: SingleChildScrollView(
            controller: _horzCtrl,
            scrollDirection: Axis.horizontal,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
