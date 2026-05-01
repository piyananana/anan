import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ar_transaction.dart';
import '../services/ar_transaction_service.dart';
import '../../sa/models/module_document.dart';

class ArTransactionListWidget extends StatefulWidget {
  final VoidCallback onAddPressed;
  final Function(int) onEditPressed;
  final Function(int) onViewPressed;
  final bool shouldRefresh;
  final VoidCallback onRefreshComplete;

  const ArTransactionListWidget({
    super.key,
    required this.onAddPressed,
    required this.onEditPressed,
    required this.onViewPressed,
    required this.shouldRefresh,
    required this.onRefreshComplete,
  });

  @override
  State<ArTransactionListWidget> createState() => _ArTransactionListWidgetState();
}

class _ArTransactionListWidgetState extends State<ArTransactionListWidget> {
  final ArTransactionService _service = ArTransactionService();
  final _fmt = NumberFormat('#,##0.00');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  List<ArTransactionHeader> _rows = [];
  List<ModuleDocument> _docTypes = [];
  bool _isLoading = false;

  final _searchCtrl = TextEditingController();
  String? _selectedStatus;
  String? _selectedDocType; // sysDocType as String (e.g. '10', '30', '50', '70')

  DateTime? _dateFrom;
  DateTime? _dateTo;

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ArTransactionListWidget old) {
    super.didUpdateWidget(old);
    if (widget.shouldRefresh) {
      _fetchRows();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onRefreshComplete();
      });
    }
  }

  Future<void> _initialLoad() async {
    setState(() => _isLoading = true);
    try {
      final docTypes = await _service.fetchDocTypesByUser();
      setState(() => _docTypes = docTypes.where((d) => d.isDocType).toList());
      await _fetchRows();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchRows() async {
    setState(() => _isLoading = true);
    try {
      final rows = await _service.fetchRows(
        search: _searchCtrl.text.isEmpty ? null : _searchCtrl.text,
        status: _selectedStatus,
        docType: _selectedDocType,
        dateFrom: _dateFrom != null ? DateFormat('yyyy-MM-dd').format(_dateFrom!) : null,
        dateTo: _dateTo != null ? DateFormat('yyyy-MM-dd').format(_dateTo!) : null,
      );
      setState(() => _rows = rows);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_dateFrom ?? DateTime.now()) : (_dateTo ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) _dateFrom = picked;
        else _dateTo = picked;
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Draft': return Colors.orange;
      case 'Posted': return Colors.green;
      case 'Void': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _docTypeName(int? sysDocType) {
    return arDocTypeNames[sysDocType] ?? '';
  }

  String _docTypeNameFromHeader(ArTransactionHeader row) {
    final code = row.docCode ?? '';
    final name = row.docNameThai ?? '';
    return code.isNotEmpty ? '$code $name' : name;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterRow(),
        const Divider(height: 1),
        if (!_isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('พบ ${_rows.length} รายการ',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          ),
        Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildTable()),
      ],
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Doc type + Status + Date from + Date to
          Row(
            children: [
              // Doc type filter
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _selectedDocType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'ประเภทเอกสาร', isDense: true, border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
                    ..._docTypes.map((d) => DropdownMenuItem(
                        value: d.sysDocType,
                        child: Text('${d.docCode} ${d.docNameThai}',
                            overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) => setState(() => _selectedDocType = v),
                ),
              ),
              const SizedBox(width: 8),
              // Status filter
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _selectedStatus,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'สถานะ', isDense: true, border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
                    DropdownMenuItem(value: 'Draft', child: Text('Draft')),
                    DropdownMenuItem(value: 'Posted', child: Text('Posted')),
                    DropdownMenuItem(value: 'Void', child: Text('Void')),
                  ],
                  onChanged: (v) => setState(() => _selectedStatus = v),
                ),
              ),
              const SizedBox(width: 8),
              // Date from
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(true),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'จากวันที่', isDense: true, border: OutlineInputBorder()),
                    child: Text(
                        _dateFrom != null ? _dateFmt.format(_dateFrom!) : '-',
                        style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Date to
              Expanded(
                child: InkWell(
                  onTap: () => _pickDate(false),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'ถึงวันที่', isDense: true, border: OutlineInputBorder()),
                    child: Text(
                        _dateTo != null ? _dateFmt.format(_dateTo!) : '-',
                        style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Row 2: Search (flexible) + ค้นหา button + ล้าง button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ค้นหา (เลขที่เอกสาร / ลูกค้า / เลขที่อ้างอิง)',
                    isDense: true,
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.search, size: 16),
                  ),
                  onSubmitted: (_) => _fetchRows(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _fetchRows,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700], foregroundColor: Colors.white),
                child: const Text('ค้นหา'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: widget.onAddPressed,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('เพิ่มเอกสาร'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700], foregroundColor: Colors.white),
              ),
              if (_dateFrom != null || _dateTo != null ||
                  _selectedStatus != null || _selectedDocType != null ||
                  _searchCtrl.text.isNotEmpty) ...[
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _dateFrom = null;
                      _dateTo = null;
                      _selectedStatus = null;
                      _selectedDocType = null;
                      _searchCtrl.clear();
                    });
                    _fetchRows();
                  },
                  child: const Text('ล้าง'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    if (_rows.isEmpty) {
      return const Center(child: Text('ไม่พบรายการ'));
    }
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
        headingRowColor: WidgetStateProperty.all(Colors.teal[50]),
        columnSpacing: 12,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 42,
        columns: const [
          DataColumn(label: Text('เลขที่เอกสาร', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('ประเภท', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('วันที่', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('ครบกำหนด', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('ลูกค้า', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('ยอดรวม', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text('ชำระแล้ว', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text('คงเหลือ', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text('สถานะ', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('จัดการ', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: _rows.map((row) {
          final isDraft = row.status == 'Draft';
          return DataRow(
            cells: [
              DataCell(Text(row.docNo, style: const TextStyle(fontSize: 12))),
              DataCell(Text(_docTypeNameFromHeader(row), style: const TextStyle(fontSize: 12))),
              DataCell(Text(_dateFmt.format(row.docDate), style: const TextStyle(fontSize: 12))),
              DataCell(Text(row.dueDate != null ? _dateFmt.format(row.dueDate!) : '-', style: const TextStyle(fontSize: 12))),
              DataCell(Text('${row.customerCode ?? ''} ${row.customerNameTh ?? ''}', style: const TextStyle(fontSize: 12))),
              DataCell(Text(_fmt.format(row.totalAmountLc), style: const TextStyle(fontSize: 12))),
              DataCell(Text(_fmt.format(row.paidAmountLc), style: const TextStyle(fontSize: 12))),
              DataCell(Text(_fmt.format(row.balanceAmountLc), style: const TextStyle(fontSize: 12, color: Colors.blue))),
              DataCell(Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _statusColor(row.status).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(row.status, style: TextStyle(color: _statusColor(row.status), fontSize: 11, fontWeight: FontWeight.w600)),
              )),
              DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                if (isDraft)
                  IconButton(
                    icon: const Icon(Icons.edit, size: 16),
                    tooltip: 'แก้ไข',
                    onPressed: () => widget.onEditPressed(row.id),
                    visualDensity: VisualDensity.compact,
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.visibility, size: 16),
                    tooltip: 'ดู',
                    onPressed: () => widget.onViewPressed(row.id),
                    visualDensity: VisualDensity.compact,
                  ),
              ])),
            ],
          );
        }).toList(),
          ),
        ),
      ),
    );
  }
}
