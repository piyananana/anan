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

class ApVendorImportScreen extends StatefulWidget {
  final VoidCallback onFieldsChanged;

  const ApVendorImportScreen({super.key, required this.onFieldsChanged});

  @override
  State<ApVendorImportScreen> createState() => _ApVendorImportScreenState();
}

class _ApVendorImportScreenState extends State<ApVendorImportScreen> {
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

  static const _appColor = Color(0xFF37474F);

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
        Uri.parse('${AppConfig.apiAp}/ap_vendor/import/template'),
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

      final uri = Uri.parse('${AppConfig.apiAp}/ap_vendor/import/validate');
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
        content: Text('ต้องการนำเข้าข้อมูลเจ้าหนี้ $_validRows รายการใช่หรือไม่?'),
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
        Uri.parse('${AppConfig.apiAp}/ap_vendor/import/confirm'),
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
        backgroundColor: _appColor,
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
        Uri.parse('${AppConfig.apiAp}/ap_vendor/import/template/download'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        await downloadFile(response.bodyBytes, 'ap_vendor_template.xlsx');
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
        leading: const Icon(Icons.table_chart_outlined, color: _appColor),
        title: const Text('เทมเพลตนำเข้าข้อมูล',
            style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('คลิกเพื่อดูรายละเอียดคอลัมน์ในแต่ละ sheet'),
        trailing: OutlinedButton.icon(
          onPressed: _downloadTemplate,
          icon: const Icon(Icons.download, size: 18),
          label: const Text('ดาวน์โหลดเทมเพลต'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _appColor,
            side: const BorderSide(color: _appColor),
          ),
        ),
        initiallyExpanded: false,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'เทมเพลตประกอบด้วย 5 sheet ตามหัวข้อข้อมูลเจ้าหนี้ ทุก sheet (ยกเว้น "ข้อมูลพื้นฐาน") '
              'ใช้คอลัมน์ "old_vendor_code" (รหัสเก่าเจ้าหนี้) เป็นตัวเชื่อมข้อมูลกับแถวใน sheet "ข้อมูลพื้นฐาน"\n'
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
                backgroundColor: _appColor,
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
              DataColumn(label: Text('รหัสเจ้าหนี้')),
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
                      DataCell(Text(e['vendorCode'] ?? '')),
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
        const Text('คลิกแถวเพื่อดูรายละเอียดทุกหัวข้อของเจ้าหนี้',
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
                DataColumn(label: Text('รหัสเจ้าหนี้')),
                DataColumn(label: Text('กลุ่ม')),
                DataColumn(label: Text('ชื่อ (ไทย)')),
                DataColumn(label: Text('ชื่อ (อังกฤษ)')),
                DataColumn(label: Text('เลขภาษี')),
                DataColumn(label: Text('ประเภทธุรกิจ')),
                DataColumn(label: Text('สกุลเงิน')),
                DataColumn(label: Text('เครดิต (ด/ว)')),
                DataColumn(label: Text('ใช้งาน')),
              ],
              rows: _validatedData
                  .take(50)
                  .map((r) => DataRow(
                        onSelectChanged: (_) => _showVendorDetailDialog(r),
                        cells: [
                          DataCell(Text(r['vendor_code']?.toString() ?? '(อัตโนมัติ)')),
                          DataCell(Text(_fmt(r['vendor_group_code']))),
                          DataCell(ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Text(r['vendor_name_th']?.toString() ?? '',
                                overflow: TextOverflow.ellipsis),
                          )),
                          DataCell(ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Text(r['vendor_name_en']?.toString() ?? '',
                                overflow: TextOverflow.ellipsis),
                          )),
                          DataCell(Text(_fmt(r['tax_id']))),
                          DataCell(Text(_fmt(r['business_type_code']))),
                          DataCell(Text(_fmt(r['currency_code']))),
                          DataCell(Text('${_fmtNum(r['credit_term_months'])}/${_fmtNum(r['credit_term_days'])}')),
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

  // ─── Vendor detail dialog (tabbed, per ap_vendor_detail_widget sections) ──

  static const _addressColumns = [
    ['address_type', 'ประเภทที่อยู่'],
    ['address_no', 'บ้านเลขที่'],
    ['address_building_village', 'อาคาร/หมู่บ้าน'],
    ['address_alley', 'ซอย'],
    ['address_road', 'ถนน'],
    ['address_sub_district', 'ตำบล/แขวง'],
    ['address_district', 'อำเภอ/เขต'],
    ['address_province', 'จังหวัด'],
    ['address_zip_code', 'รหัสไปรษณีย์'],
    ['address_country', 'ประเทศ'],
    ['is_default', 'ที่อยู่หลัก'],
  ];

  static const _contactColumns = [
    ['contact_name', 'ชื่อผู้ติดต่อ'],
    ['position', 'ตำแหน่ง'],
    ['phone', 'โทรศัพท์'],
    ['mobile', 'มือถือ'],
    ['email', 'อีเมล'],
    ['is_default', 'ผู้ติดต่อหลัก'],
  ];

  static const _bankColumns = [
    ['bank_name', 'ธนาคาร'],
    ['branch_name', 'สาขา'],
    ['account_number', 'เลขที่บัญชี'],
    ['account_name', 'ชื่อบัญชี'],
    ['account_type', 'ประเภทบัญชี'],
    ['is_default', 'บัญชีหลัก'],
  ];

  void _showVendorDetailDialog(Map<String, dynamic> row) {
    const tabLabels = [
      'ข้อมูลพื้นฐาน',
      'ที่อยู่',
      'ผู้ติดต่อ',
      'บัญชีธนาคาร',
      'บัญชีเจ้าหนี้ (GL)',
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
                  backgroundColor: _appColor,
                  foregroundColor: Colors.white,
                  title: Text(
                    '${row['vendor_code']?.toString() ?? '(อัตโนมัติ)'} - ${row['vendor_name_th']?.toString() ?? ''}',
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
                    _buildListTable(row['addresses'] as List? ?? [], _addressColumns),
                    _buildListTable(row['contacts'] as List? ?? [], _contactColumns),
                    _buildListTable(row['bank_accounts'] as List? ?? [], _bankColumns),
                    _buildApAccountTab(row),
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
      ['รหัสเจ้าหนี้', row['vendor_code']?.toString() ?? '(อัตโนมัติ)'],
      ['กลุ่มเจ้าหนี้', _fmt(row['vendor_group_code'])],
      ['รหัสเก่า', _fmt(row['old_vendor_code'])],
      ['ชื่อ (ไทย)', _fmt(row['vendor_name_th'])],
      ['ชื่อ (อังกฤษ)', _fmt(row['vendor_name_en'])],
      ['เลขประจำตัวผู้เสียภาษี', _fmt(row['tax_id'])],
      ['ประเภทธุรกิจ', _fmt(row['business_type_code'])],
      ['เครดิต (เดือน)', _fmt(row['credit_term_months'])],
      ['เครดิต (วัน)', _fmt(row['credit_term_days'])],
      ['สกุลเงิน', _fmt(row['currency_code'])],
      ['ใช้งาน', _fmt(row['is_active'])],
      ['หมายเหตุ', _fmt(row['remark'])],
    ];
    return _buildKeyValueTable(items);
  }

  Widget _buildApAccountTab(Map<String, dynamic> row) {
    final items = <List<String>>[
      ['รหัสบัญชีเจ้าหนี้', _fmt(row['ap_account_code'])],
      ['ประเภทการชำระหลัก', _fmt(row['payment_method_code'])],
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
