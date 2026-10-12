// lib/mo/screens/mo_status_report_screen.dart — รายงานสถานะใบสั่งผลิต (MO Status Report) หน้าจอสำหรับฝ่ายวางแผน
// (Planning): ตัวกรองสถานะ/คลัง/ช่วงวันที่/ค้นหา แสดงจำนวนวางแผน vs เบิกจริง (ฝั่งวัตถุดิบ) และวางแผน vs รับจริง
// (ฝั่งผลผลิต) พร้อม % สำเร็จ และยอดคงเหลือ WIP เปิดอยู่ ต่อ MO — read-only, ดึงจาก fetchStatusReport ใน
// moHeaderController.js (คำนวณ % complete ฝั่ง backend)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:provider/provider.dart';

import '../../sa/services/sa_language_provider.dart';
import '../../sa/utils/sa_menu_scope.dart';
import '../../sa/models/sa_company.dart';
import '../../sa/services/sa_company_service.dart';
import '../../im/models/im_warehouse.dart';
import '../../im/services/im_warehouse_service.dart';
import '../../utils/file_download.dart';
import '../models/mo_header.dart';
import '../services/mo_header_service.dart';

class MoStatusReportScreen extends StatefulWidget {
  const MoStatusReportScreen({super.key});

  @override
  State<MoStatusReportScreen> createState() => _MoStatusReportScreenState();
}

class _MoStatusReportScreenState extends State<MoStatusReportScreen> {
  final _moService = MoHeaderService();
  final _warehouseService = ImWarehouseService();
  final _companyService = CompanyService();
  final _fmtQty = NumberFormat('#,##0.####');
  final _fmtPct = NumberFormat('#,##0.0');
  final _fmtMoney = NumberFormat('#,##0.00');

  bool _isEnglish = false;
  bool _isLoading = false;
  bool _isExporting = false;

  List<ImWarehouse> _warehouses = [];
  Company? _company;
  List<MoStatusReportRow> _rows = [];

  String? _status;
  int? _warehouseId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  final _searchCtrl = TextEditingController();

  static const _statuses = ['Draft', 'Released', 'InProgress', 'Completed', 'Closed', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _isLoading = true);
    try {
      final res = await Future.wait([_warehouseService.fetchActiveRows(), _companyService.fetchCompany()]);
      _warehouses = res[0] as List<ImWarehouse>;
      _company = res[1] as Company?;
      await _search();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _search() async {
    final isEnglish = _isEnglish;
    setState(() => _isLoading = true);
    try {
      final rows = await _moService.fetchStatusReport(
        status: _status,
        warehouseId: _warehouseId,
        dateFrom: _dateFrom != null ? DateFormat('yyyy-MM-dd').format(_dateFrom!) : null,
        dateTo: _dateTo != null ? DateFormat('yyyy-MM-dd').format(_dateTo!) : null,
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      );
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEnglish ? 'Error: $e' : 'เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _dateFrom : _dateTo) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
    }
  }

  String _itemLabel(MoStatusReportRow r, bool isEnglish) {
    final name = isEnglish && (r.bomParentItemNameEn ?? '').isNotEmpty ? r.bomParentItemNameEn : r.bomParentItemNameTh;
    return '${r.bomParentItemCode ?? ''} ${name ?? ''}'.trim();
  }

  String _warehouseLabel(MoStatusReportRow r, bool isEnglish) {
    final name = isEnglish && (r.warehouseNameEn ?? '').isNotEmpty ? r.warehouseNameEn : r.warehouseNameTh;
    return '${r.warehouseCode ?? ''} ${name ?? ''}'.trim();
  }

  Future<void> _exportExcel() async {
    final isEnglish = _isEnglish;
    setState(() => _isExporting = true);
    try {
      final ex = Excel.createExcel();
      const sheetName = 'MoStatus';
      ex.rename('Sheet1', sheetName);
      final s = ex[sheetName];
      final hdrBg = ExcelColor.fromHexString('#92D050');
      final tsLabel = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      _xl(s, 0, 0, _company?.displayName(isEnglish) ?? '', bold: true);
      _xl(s, 1, 0, isEnglish ? 'Manufacturing Order Status Report' : 'รายงานสถานะใบสั่งผลิต', bold: true);
      _xl(s, 2, 0, '${isEnglish ? "Printed" : "พิมพ์"}: $tsLabel');

      final hdrs = isEnglish
          ? ['MO No.', 'Date', 'Item', 'Warehouse', 'Status', 'Order Qty', 'Component Planned', 'Component Issued', 'Output Planned', 'Output Received', '% Complete', 'WIP Balance']
          : ['เลขที่ MO', 'วันที่', 'สินค้า', 'คลัง', 'สถานะ', 'จำนวนสั่งผลิต', 'วัตถุดิบตามแผน', 'วัตถุดิบเบิกแล้ว', 'ผลผลิตตามแผน', 'ผลผลิตรับแล้ว', '% สำเร็จ', 'คงเหลือ WIP'];
      for (int i = 0; i < hdrs.length; i++) {
        _xl(s, 4, i, hdrs[i], bg: hdrBg, bold: true, align: HorizontalAlign.Center);
      }

      int row = 5;
      for (final r in _rows) {
        _xl(s, row, 0, r.docNo);
        _xl(s, row, 1, DateFormat('dd/MM/yyyy').format(r.docDate));
        _xl(s, row, 2, _itemLabel(r, isEnglish));
        _xl(s, row, 3, _warehouseLabel(r, isEnglish));
        _xl(s, row, 4, moHeaderStatusLabel(r.status, isEnglish));
        _xl(s, row, 5, r.orderQty, align: HorizontalAlign.Right);
        _xl(s, row, 6, r.componentPlannedQty, align: HorizontalAlign.Right);
        _xl(s, row, 7, r.componentIssuedQty, align: HorizontalAlign.Right);
        _xl(s, row, 8, r.outputPlannedQty, align: HorizontalAlign.Right);
        _xl(s, row, 9, r.outputReceivedQty, align: HorizontalAlign.Right);
        _xl(s, row, 10, r.percentComplete, align: HorizontalAlign.Right);
        _xl(s, row, 11, r.wipBalanceLc, align: HorizontalAlign.Right);
        row++;
      }

      final bytes = ex.encode();
      if (bytes == null) return;
      final title = isEnglish ? 'MO_Status_Report' : 'รายงานสถานะใบสั่งผลิต';
      final ts = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      await downloadFile(bytes, '${title}_$ts.xlsx');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _xl(Sheet s, int r, int c, dynamic v, {ExcelColor? bg, HorizontalAlign? align, bool bold = false}) {
    final cell = s.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
    cell.value = v is double ? DoubleCellValue(v) : TextCellValue(v?.toString() ?? '');
    cell.cellStyle = CellStyle(
      backgroundColorHex: bg ?? ExcelColor.none,
      horizontalAlign: align ?? HorizontalAlign.Left,
      bold: bold,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    _isEnglish = isEnglish;
    final fmtDate = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const MenuTitle(),
        backgroundColor: Colors.deepOrange[700],
        foregroundColor: Colors.white,
      ),
      body: Column(children: [
        Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String?>(
                  value: _status,
                  decoration: InputDecoration(labelText: isEnglish ? 'Status' : 'สถานะ', isDense: true, border: const OutlineInputBorder()),
                  items: [
                    DropdownMenuItem(value: null, child: Text(isEnglish ? 'All' : 'ทั้งหมด')),
                    ..._statuses.map((s) => DropdownMenuItem(value: s, child: Text(moHeaderStatusLabel(s, isEnglish)))),
                  ],
                  onChanged: (v) => setState(() => _status = v),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<int?>(
                  value: _warehouseId,
                  decoration: InputDecoration(labelText: isEnglish ? 'Warehouse' : 'คลัง', isDense: true, border: const OutlineInputBorder()),
                  items: [
                    DropdownMenuItem(value: null, child: Text(isEnglish ? 'All' : 'ทั้งหมด')),
                    ..._warehouses.map((w) => DropdownMenuItem(
                          value: w.id,
                          child: Text('${w.warehouseCode} ${isEnglish ? (w.warehouseNameEn ?? w.warehouseNameTh) : w.warehouseNameTh}'),
                        )),
                  ],
                  onChanged: (v) => setState(() => _warehouseId = v),
                ),
              ),
              SizedBox(
                width: 150,
                child: OutlinedButton(
                  onPressed: () => _pickDate(true),
                  child: Text(_dateFrom == null ? (isEnglish ? 'Date From' : 'วันที่เริ่ม') : fmtDate.format(_dateFrom!)),
                ),
              ),
              SizedBox(
                width: 150,
                child: OutlinedButton(
                  onPressed: () => _pickDate(false),
                  child: Text(_dateTo == null ? (isEnglish ? 'Date To' : 'วันที่สิ้นสุด') : fmtDate.format(_dateTo!)),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: isEnglish ? 'Search (MO No. / Item)' : 'ค้นหา (เลขที่ / สินค้า)',
                    prefixIcon: const Icon(Icons.search), isDense: true, border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _search,
                icon: const Icon(Icons.search, size: 18),
                label: Text(isEnglish ? 'Search' : 'ค้นหา'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange[700], foregroundColor: Colors.white),
              ),
              OutlinedButton.icon(
                onPressed: (_isExporting || _rows.isEmpty) ? null : _exportExcel,
                icon: _isExporting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.grid_on, size: 18),
                label: Text(isEnglish ? 'Export Excel' : 'ส่งออก Excel'),
              ),
            ]),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _rows.isEmpty
                  ? Center(child: Text(isEnglish ? 'No data' : 'ไม่พบข้อมูล', style: TextStyle(color: Colors.grey.shade600)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                          columns: [
                            DataColumn(label: Text(isEnglish ? 'MO No.' : 'เลขที่ MO')),
                            DataColumn(label: Text(isEnglish ? 'Date' : 'วันที่')),
                            DataColumn(label: Text(isEnglish ? 'Item' : 'สินค้า')),
                            DataColumn(label: Text(isEnglish ? 'Warehouse' : 'คลัง')),
                            DataColumn(label: Text(isEnglish ? 'Status' : 'สถานะ')),
                            DataColumn(label: Text(isEnglish ? 'Order Qty' : 'สั่งผลิต'), numeric: true),
                            DataColumn(label: Text(isEnglish ? 'Component\nIssued/Planned' : 'วัตถุดิบ\nเบิก/แผน'), numeric: true),
                            DataColumn(label: Text(isEnglish ? 'Output\nReceived/Planned' : 'ผลผลิต\nรับ/แผน'), numeric: true),
                            DataColumn(label: Text(isEnglish ? '% Complete' : '% สำเร็จ'), numeric: true),
                            DataColumn(label: Text(isEnglish ? 'WIP Balance' : 'คงเหลือ WIP'), numeric: true),
                          ],
                          rows: _rows.map((r) => DataRow(cells: [
                                DataCell(Text(r.docNo)),
                                DataCell(Text(fmtDate.format(r.docDate))),
                                DataCell(Text(_itemLabel(r, isEnglish))),
                                DataCell(Text(_warehouseLabel(r, isEnglish))),
                                DataCell(Text(moHeaderStatusLabel(r.status, isEnglish))),
                                DataCell(Text('${_fmtQty.format(r.orderQty)} ${r.uomCode ?? ''}')),
                                DataCell(Text('${_fmtQty.format(r.componentIssuedQty)} / ${_fmtQty.format(r.componentPlannedQty)}')),
                                DataCell(Text('${_fmtQty.format(r.outputReceivedQty)} / ${_fmtQty.format(r.outputPlannedQty)}')),
                                DataCell(Text('${_fmtPct.format(r.percentComplete)}%')),
                                DataCell(Text(_fmtMoney.format(r.wipBalanceLc),
                                    style: TextStyle(color: r.wipBalanceLc != 0 ? Colors.orange.shade800 : null))),
                              ])).toList(),
                        ),
                      ),
                    ),
        ),
      ]),
    );
  }
}
