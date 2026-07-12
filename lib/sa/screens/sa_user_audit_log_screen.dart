import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../utils/menu_scope.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/company.dart';
import '../services/auth_service.dart';
import '../services/company_service.dart';
import '../services/sa_user_audit_log_service.dart';
import '../services/language_provider.dart';

class SaUserAuditLogScreen extends StatefulWidget {
  const SaUserAuditLogScreen({super.key});

  @override
  State<SaUserAuditLogScreen> createState() => _SaUserAuditLogScreenState();
}

class _SaUserAuditLogScreenState extends State<SaUserAuditLogScreen> {
  final _service        = SaUserAuditLogService();
  final _auth           = AuthService();
  final _companyService = CompanyService();

  // Filter
  DateTime? _dateFrom;
  DateTime? _dateTo;
  int?      _selectedUserId;
  String    _logoutType = 'all';
  String    _sortBy     = 'login_desc';

  // Data
  List<AuditLogRow>             _rows     = [];
  List<Map<String, dynamic>>    _userList = [];
  int _total = 0;
  int _page  = 1;
  static const int _limit = 50;

  Company?              _company;
  Map<String, String>?  _headers;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _headers = await _auth.getAuthHeader();
    try {
      final results = await Future.wait([
        _companyService.fetchCompany(),
        _service.fetchUsers(),
      ]);
      if (mounted) {
        setState(() {
          _company  = results[0] as Company;
          _userList = results[1] as List<Map<String, dynamic>>;
        });
      }
    } catch (_) {}
    await _load(resetPage: true);
  }

  Future<void> _load({bool resetPage = false}) async {
    if (resetPage) _page = 1;
    if (mounted) setState(() => _loading = true);
    try {
      final result = await _service.fetchRows(
        userId:     _selectedUserId,
        dateFrom:   _dateFrom != null ? DateFormat('yyyy-MM-dd').format(_dateFrom!) : null,
        dateTo:     _dateTo   != null ? DateFormat('yyyy-MM-dd').format(_dateTo!)   : null,
        logoutType: _logoutType,
        sortBy:     _sortBy,
        page:       _page,
        limit:      _limit,
      );
      if (mounted) {
        setState(() {
          _rows  = result.rows;
          _total = result.total;
        });
      }
    } catch (e) {
      if (mounted) {
        final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  String _fmtDuration(int? seconds) {
    if (seconds == null) return '-';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color _statusColor(AuditLogRow row) {
    if (row.isActive) return Colors.green[700]!;
    switch (row.logoutType) {
      case 'normal':  return Colors.blue[700]!;
      case 'timeout': return Colors.orange[700]!;
      case 'forced':  return Colors.red[700]!;
      default:        return Colors.grey[600]!;
    }
  }

  String _statusLabel(AuditLogRow row, bool isEnglish) {
    if (row.isActive) return isEnglish ? 'Active' : 'ยังอยู่';
    switch (row.logoutType) {
      case 'normal':  return isEnglish ? 'Normal' : 'ปกติ';
      case 'timeout': return 'Timeout';
      case 'forced':  return 'Kicked';
      default:        return row.logoutType ?? '-';
    }
  }

  // ─── PDF ─────────────────────────────────────────────────────────────────

  Future<Uint8List> _generatePdf(PdfPageFormat format, bool isEnglish) async {
    final doc          = pw.Document();
    final fontData     = await rootBundle.load('assets/fonts/THSarabun.ttf');
    final fontBoldData = await rootBundle.load('assets/fonts/THSarabun Bold.ttf');
    final font         = pw.Font.ttf(fontData);
    final fontBold     = pw.Font.ttf(fontBoldData);

    final companyName  = _company?.thaiName ?? (isEnglish ? '(Company name not specified)' : '(ไม่ระบุชื่อบริษัท)');
    final userName     = _headers?['UserName'] ?? '';
    final printDateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    String dateRangeLine;
    if (_dateFrom != null && _dateTo != null) {
      dateRangeLine = isEnglish
          ? 'Date: ${DateFormat('dd/MM/yyyy').format(_dateFrom!)} to ${DateFormat('dd/MM/yyyy').format(_dateTo!)}'
          : 'วันที่ ${DateFormat('dd/MM/yyyy').format(_dateFrom!)} ถึง ${DateFormat('dd/MM/yyyy').format(_dateTo!)}';
    } else if (_dateFrom != null) {
      dateRangeLine = isEnglish
          ? 'From: ${DateFormat('dd/MM/yyyy').format(_dateFrom!)}'
          : 'ตั้งแต่วันที่ ${DateFormat('dd/MM/yyyy').format(_dateFrom!)}';
    } else if (_dateTo != null) {
      dateRangeLine = isEnglish
          ? 'To: ${DateFormat('dd/MM/yyyy').format(_dateTo!)}'
          : 'ถึงวันที่ ${DateFormat('dd/MM/yyyy').format(_dateTo!)}';
    } else {
      dateRangeLine = isEnglish ? 'All dates' : 'ทุกวัน';
    }

    final allUsersLabel = isEnglish ? 'All Users' : 'ทุกคน';
    final userLabel = _selectedUserId == null
        ? allUsersLabel
        : (_userList.firstWhere(
                (u) => u['id'] == _selectedUserId,
                orElse: () => {})['user_name'] as String? ?? allUsersLabel);

    final logoutLabels = isEnglish
        ? {'all': 'All', 'active': 'Active', 'normal': 'Normal', 'timeout': 'Timeout', 'forced': 'Kicked'}
        : {'all': 'ทั้งหมด', 'active': 'ยังอยู่', 'normal': 'ปกติ', 'timeout': 'Timeout', 'forced': 'Kicked'};
    final sortLabels = isEnglish
        ? {
            'login_desc':    'Login: Newest first',
            'login_asc':     'Login: Oldest first',
            'duration_desc': 'Duration: High > Low',
            'duration_asc':  'Duration: Low > High',
          }
        : {
            'login_desc':    'Login ล่าสุด > เก่าสุด',
            'login_asc':     'Login เก่าสุด > ล่าสุด',
            'duration_desc': 'Duration มาก > น้อย',
            'duration_asc':  'Duration น้อย > มาก',
          };
    final userLbl   = isEnglish ? 'User' : 'ผู้ใช้';
    final statusLbl = isEnglish ? 'Status' : 'สถานะ';
    final sortLbl   = isEnglish ? 'Sort' : 'เรียงโดย';
    final conditionLine =
        '$userLbl: $userLabel   $statusLbl: ${logoutLabels[_logoutType] ?? _logoutType}'
        '   $sortLbl: ${sortLabels[_sortBy] ?? _sortBy}';

    // Fetch all matching rows for PDF
    List<AuditLogRow> pdfRows = _rows;
    if (_total > _limit) {
      try {
        final result = await _service.fetchRows(
          userId:     _selectedUserId,
          dateFrom:   _dateFrom != null ? DateFormat('yyyy-MM-dd').format(_dateFrom!) : null,
          dateTo:     _dateTo   != null ? DateFormat('yyyy-MM-dd').format(_dateTo!)   : null,
          logoutType: _logoutType,
          sortBy:     _sortBy,
          page:       1,
          limit:      _total,
        );
        pdfRows = result.rows;
      } catch (_) {}
    }

    const fs10 = pw.TextStyle(fontSize: 10);
    const fs12 = pw.TextStyle(fontSize: 12);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      theme:      pw.ThemeData.withFont(base: font, bold: fontBold),
      margin:     const pw.EdgeInsets.all(20),
      header: (ctx) => pw.Column(children: [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Expanded(flex: 3, child: pw.Text(companyName, style: fs12)),
          pw.Expanded(
              flex: 7,
              child: pw.Text(
                  isEnglish ? 'Audit Log Report' : 'รายงานตรวจสอบการเข้าใช้งาน',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
          pw.Expanded(
              flex: 3,
              child: pw.Text(
                  isEnglish
                      ? 'Page ${ctx.pageNumber}/${ctx.pagesCount}'
                      : 'หน้า ${ctx.pageNumber}/${ctx.pagesCount}',
                  textAlign: pw.TextAlign.right, style: fs12)),
        ]),
        pw.SizedBox(height: 4),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Expanded(flex: 3, child: pw.Text('')),
          pw.Expanded(flex: 7,
              child: pw.Text(dateRangeLine,
                  textAlign: pw.TextAlign.center, style: fs12)),
          pw.Expanded(flex: 3,
              child: pw.Text(
                  isEnglish ? 'Printed by $userName' : 'พิมพ์โดย $userName',
                  textAlign: pw.TextAlign.right, style: fs12)),
        ]),
        pw.SizedBox(height: 4),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Expanded(flex: 10,
              child: pw.Text(conditionLine,
                  textAlign: pw.TextAlign.left, style: fs10)),
          pw.Expanded(flex: 3,
              child: pw.Text(
                  isEnglish ? 'Printed at $printDateStr' : 'พิมพ์เมื่อ $printDateStr',
                  textAlign: pw.TextAlign.right, style: fs12)),
        ]),
        pw.SizedBox(height: 4),
        pw.Divider(thickness: 0.5),
      ]),
      build: (ctx) {
        final hStyle = pw.TextStyle(font: fontBold, fontSize: 9);
        final cStyle = pw.TextStyle(font: font,     fontSize: 9);
        const edg    = pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2);

        pw.Widget hCell(String t, {pw.TextAlign a = pw.TextAlign.center}) =>
            pw.Container(
                padding: edg,
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
                child: pw.Text(t, style: hStyle, textAlign: a));

        pw.Widget dCell(String t, {pw.TextAlign a = pw.TextAlign.left}) =>
            pw.Container(padding: edg,
                child: pw.Text(t, style: cStyle, textAlign: a));

        final colW = <int, pw.TableColumnWidth>{
          0: const pw.FixedColumnWidth(22),  // #
          1: const pw.FlexColumnWidth(13),   // login at
          2: const pw.FlexColumnWidth(8),    // username
          3: const pw.FlexColumnWidth(13),   // full name
          4: const pw.FlexColumnWidth(10),   // hostname
          5: const pw.FlexColumnWidth(10),   // ip
          6: const pw.FlexColumnWidth(13),   // logout at
          7: const pw.FlexColumnWidth(7),    // status
          8: const pw.FlexColumnWidth(8),    // duration
        };

        return [
          pw.Table(
            columnWidths: colW,
            border: pw.TableBorder.all(width: 0.3, color: PdfColors.grey400),
            children: [
              pw.TableRow(children: [
                hCell('#'),
                hCell(isEnglish ? 'Login Date/Time'   : 'วันที่-เวลา Login',  a: pw.TextAlign.left),
                hCell(isEnglish ? 'Username'          : 'รหัสผู้ใช้',         a: pw.TextAlign.left),
                hCell(isEnglish ? 'Full Name'         : 'ชื่อผู้ใช้',         a: pw.TextAlign.left),
                hCell(isEnglish ? 'Hostname'          : 'ชื่อเครื่อง',        a: pw.TextAlign.left),
                hCell('IP Address',                                             a: pw.TextAlign.left),
                hCell(isEnglish ? 'Logout Date/Time'  : 'วันที่-เวลา Logout', a: pw.TextAlign.left),
                hCell(isEnglish ? 'Status'            : 'สถานะ'),
                hCell(isEnglish ? 'Duration'          : 'ระยะเวลา',           a: pw.TextAlign.right),
              ]),
              ...pdfRows.asMap().entries.map((entry) {
                final i = entry.key;
                final r = entry.value;
                final statusStr = r.isActive
                    ? (isEnglish ? 'Active'  : 'ยังอยู่')
                    : r.logoutType == 'normal'
                        ? (isEnglish ? 'Normal'  : 'ปกติ')
                        : r.logoutType == 'timeout'
                            ? 'Timeout'
                            : r.logoutType == 'forced'
                                ? 'Kicked'
                                : r.logoutType ?? '-';
                return pw.TableRow(
                  decoration: i.isOdd
                      ? const pw.BoxDecoration(color: PdfColors.grey100)
                      : null,
                  children: [
                    dCell('${i + 1}',                   a: pw.TextAlign.center),
                    dCell(r.loginAtStr),
                    dCell(r.username),
                    dCell(r.fullName),
                    dCell(r.hostname   ?? '-'),
                    dCell(r.ipAddress  ?? '-'),
                    dCell(r.logoutAtStr ?? '-'),
                    dCell(statusStr,                    a: pw.TextAlign.center),
                    dCell(_fmtDuration(r.durationSecondsDisplay), a: pw.TextAlign.right),
                  ],
                );
              }),
            ],
          ),
        ];
      },
    ));

    return doc.save();
  }

  void _showPdfPreview(bool isEnglish) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF37474F),
            foregroundColor: Colors.white,
            title: Text(isEnglish ? 'Audit Log Report' : 'รายงานตรวจสอบการเข้าใช้งาน'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          body: PdfPreview(
            build:                (format) => _generatePdf(format, isEnglish),
            initialPageFormat:    PdfPageFormat.a4.landscape,
            canChangeOrientation: false,
            canDebug:             false,
          ),
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    final totalPages = _total == 0 ? 1 : (_total / _limit).ceil();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF37474F),
        foregroundColor: Colors.white,
        title: const MenuTitle(),
        actions: [
          TextButton.icon(
            onPressed: () => _showPdfPreview(isEnglish),
            icon:  const Icon(Icons.print_rounded, color: Colors.white70, size: 18),
            label: Text(
                isEnglish ? 'Print PDF' : 'พิมพ์รายงาน PDF',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(isEnglish),
          Expanded(child: _buildTable(isEnglish)),
          _buildPaginationBar(totalPages, isEnglish),
        ],
      ),
    );
  }

  Widget _buildFilterBar(bool isEnglish) {
    return Card(
      margin:    const EdgeInsets.fromLTRB(8, 8, 8, 4),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _DatePickerBtn(
              label:   isEnglish ? 'Login From' : 'Login ตั้งแต่',
              date:    _dateFrom,
              onPick: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _dateFrom ?? DateTime.now(),
                  firstDate:   DateTime(2020),
                  lastDate:    DateTime(2099),
                );
                if (d != null) setState(() => _dateFrom = d);
              },
              onClear: () => setState(() => _dateFrom = null),
            ),
            _DatePickerBtn(
              label:   isEnglish ? 'To Date' : 'ถึงวันที่',
              date:    _dateTo,
              onPick: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _dateTo ?? DateTime.now(),
                  firstDate:   DateTime(2020),
                  lastDate:    DateTime(2099),
                );
                if (d != null) setState(() => _dateTo = d);
              },
              onClear: () => setState(() => _dateTo = null),
            ),
            SizedBox(
              width: 190,
              child: DropdownButtonFormField<int?>(
                value: _selectedUserId,
                decoration: InputDecoration(
                  labelText: isEnglish ? 'User' : 'ผู้ใช้',
                  isDense:   true,
                  border:    const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                isExpanded: true,
                items: [
                  DropdownMenuItem<int?>(
                      value: null,
                      child: Text(isEnglish ? 'All Users' : 'ทุกคน')),
                  ..._userList.map((u) => DropdownMenuItem<int?>(
                    value: u['id'] as int?,
                    child: Text(
                      '${u['user_name']}${(u['full_name'] as String?)?.isNotEmpty == true ? ' - ${u['full_name']}' : ''}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  )),
                ],
                onChanged: (v) => setState(() => _selectedUserId = v),
              ),
            ),
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                value: _logoutType,
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Status' : 'สถานะ',
                  isDense:   true,
                  border:    const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: [
                  DropdownMenuItem(value: 'all',     child: Text(isEnglish ? 'All' : 'ทั้งหมด')),
                  DropdownMenuItem(value: 'active',  child: Text(isEnglish ? 'Active' : 'ยังอยู่')),
                  DropdownMenuItem(value: 'normal',  child: Text(isEnglish ? 'Normal' : 'ปกติ')),
                  const DropdownMenuItem(value: 'timeout', child: Text('Timeout')),
                  const DropdownMenuItem(value: 'forced',  child: Text('Kicked')),
                ],
                onChanged: (v) => setState(() => _logoutType = v ?? 'all'),
              ),
            ),
            SizedBox(
              width: 230,
              child: DropdownButtonFormField<String>(
                value: _sortBy,
                decoration: InputDecoration(
                  labelText: isEnglish ? 'Sort By' : 'เรียงลำดับ',
                  isDense:   true,
                  border:    const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: [
                  DropdownMenuItem(
                      value: 'login_desc',
                      child: Text(isEnglish ? 'Login: Newest first' : 'Login ล่าสุด → เก่าสุด')),
                  DropdownMenuItem(
                      value: 'login_asc',
                      child: Text(isEnglish ? 'Login: Oldest first' : 'Login เก่าสุด → ล่าสุด')),
                  DropdownMenuItem(
                      value: 'duration_desc',
                      child: Text(isEnglish ? 'Duration: High → Low' : 'Duration มาก → น้อย')),
                  DropdownMenuItem(
                      value: 'duration_asc',
                      child: Text(isEnglish ? 'Duration: Low → High' : 'Duration น้อย → มาก')),
                ],
                onChanged: (v) => setState(() => _sortBy = v ?? 'login_desc'),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _load(resetPage: true),
              icon:  const Icon(Icons.search_rounded, size: 18),
              label: Text(isEnglish ? 'Search' : 'ค้นหา'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF37474F),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(bool isEnglish) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_rows.isEmpty) {
      return Center(
          child: Text(
              isEnglish ? 'No data found' : 'ไม่พบข้อมูล',
              style: const TextStyle(color: Colors.grey)));
    }

    const flex = [2, 12, 7, 11, 9, 9, 12, 7, 7];
    final hdrs = isEnglish
        ? ['#', 'Login Date/Time', 'Username', 'Full Name', 'Hostname', 'IP Address', 'Logout Date/Time', 'Status', 'Duration']
        : ['#', 'วันที่-เวลา Login', 'รหัสผู้ใช้', 'ชื่อผู้ใช้', 'ชื่อเครื่อง', 'IP Address', 'วันที่-เวลา Logout', 'สถานะ', 'ระยะเวลา'];
    const hStyle = TextStyle(
        fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white);
    const cStyle = TextStyle(fontSize: 12);

    Widget hCell(int i) => Expanded(
          flex: flex[i],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
            child: Text(hdrs[i], style: hStyle, overflow: TextOverflow.ellipsis),
          ),
        );

    Widget dCell(int i, Widget child) => Expanded(
          flex: flex[i],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: child,
          ),
        );

    return Column(
      children: [
        // ── Frozen header ──────────────────────────────────────────────
        Container(
          color: const Color(0xFF546E7A),
          child: Row(children: List.generate(hdrs.length, hCell)),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFF455A64)),
        // ── Vertically scrollable rows ──────────────────────────────────
        Expanded(
          child: ListView.builder(
            itemCount: _rows.length,
            itemBuilder: (ctx, i) {
              final r   = _rows[i];
              final num = (_page - 1) * _limit + i + 1;
              return Container(
                height: 40,
                decoration: BoxDecoration(
                  color: i.isEven ? Colors.white : Colors.blueGrey.shade50,
                  border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    dCell(0, Text('$num', style: cStyle)),
                    dCell(1, Text(r.loginAtStr, style: cStyle)),
                    dCell(2, Text(r.username,   style: cStyle, overflow: TextOverflow.ellipsis)),
                    dCell(3, Text(r.fullName,   style: cStyle, overflow: TextOverflow.ellipsis)),
                    dCell(4, Text(r.hostname   ?? '-', style: cStyle, overflow: TextOverflow.ellipsis)),
                    dCell(5, Text(r.ipAddress  ?? '-', style: cStyle)),
                    dCell(6, Text(r.logoutAtStr ?? '-', style: cStyle)),
                    dCell(7, _StatusChip(color: _statusColor(r), label: _statusLabel(r, isEnglish))),
                    dCell(8, Text(_fmtDuration(r.durationSecondsDisplay), style: cStyle)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPaginationBar(int totalPages, bool isEnglish) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color:  Colors.grey.shade100,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Text(isEnglish ? 'Total $_total records' : 'รวม $_total รายการ',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const Spacer(),
          TextButton(
            onPressed: _page > 1
                ? () { setState(() => _page--); _load(); }
                : null,
            child: Text(isEnglish ? '< Prev' : '< ก่อนหน้า'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(isEnglish ? 'Page $_page/$totalPages' : 'หน้า $_page/$totalPages',
                style: const TextStyle(fontSize: 12)),
          ),
          TextButton(
            onPressed: _page < totalPages
                ? () { setState(() => _page++); _load(); }
                : null,
            child: Text(isEnglish ? 'Next >' : 'ถัดไป >'),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _DatePickerBtn extends StatelessWidget {
  final String    label;
  final DateTime? date;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _DatePickerBtn({
    required this.label,
    required this.date,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasDate = date != null;
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border:       Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasDate
                  ? '$label: ${DateFormat('dd/MM/yyyy').format(date!)}'
                  : label,
              style: TextStyle(
                  fontSize: 13,
                  color: hasDate ? Colors.black87 : Colors.grey[600]),
            ),
            const SizedBox(width: 4),
            hasDate
                ? GestureDetector(
                    onTap: onClear,
                    child: Icon(Icons.close, size: 14, color: Colors.grey[600]),
                  )
                : Icon(Icons.calendar_today_rounded,
                    size: 14, color: Colors.grey[500]),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final Color  color;
  final String label;

  const _StatusChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color:        color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 11)),
    );
  }
}
