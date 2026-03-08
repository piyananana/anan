import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/gl_entry.dart';
import '../models/period.dart';
import '../services/gl_entry_service.dart';
import '../services/period_service.dart';

class GlEntryListWidget extends StatefulWidget {
  final VoidCallback onAddPressed;
  final Function(int) onEditPressed;
  final Function(int) onViewPressed;
  final bool shouldRefresh;
  final VoidCallback onRefreshComplete;

  const GlEntryListWidget({
    super.key,
    required this.onAddPressed,
    required this.onEditPressed,
    required this.onViewPressed,
    required this.shouldRefresh,
    required this.onRefreshComplete,
  });

  @override
  State<GlEntryListWidget> createState() => _GlEntryListWidgetState();
}

class _GlEntryListWidgetState extends State<GlEntryListWidget> {
  final GlEntryService _entryService = GlEntryService();
  final PeriodService _periodService = PeriodService();

  List<GlEntryHeader> _entries = [];
  List<GlEntryHeader> _filteredEntries = [];
  bool _isLoading = false;

  List<FiscalYear> _fiscalYears = [];
  List<PostingPeriod> _periods = [];

  FiscalYear? _selectedFiscalYear;
  PostingPeriod? _selectedPeriod;
  final TextEditingController _searchCtrl = TextEditingController();

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
  void didUpdateWidget(covariant GlEntryListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldRefresh) {
      _fetchEntries();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onRefreshComplete();
      });
    }
  }

  Future<void> _initialLoad() async {
    setState(() => _isLoading = true);
    try {
      final fys = await _periodService.fetchActiveFiscalYears();
      setState(() => _fiscalYears = fys);

      if (fys.isNotEmpty) {
        final now = DateTime.now();
        try {
          _selectedFiscalYear = fys.firstWhere((fy) =>
              now.isAfter(fy.yearStartDate.subtract(const Duration(days: 1))) &&
              now.isBefore(fy.yearEndDate.add(const Duration(days: 1))));
        } catch (_) {
          _selectedFiscalYear = fys.first;
        }
        if (_selectedFiscalYear != null) {
          await _fetchPeriods(_selectedFiscalYear!.id);
        }
      }
      await _fetchEntries();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading master data: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchPeriods(int fyId) async {
    try {
      final periods =
          await _periodService.fetchPostingPeriodsByFiscalYearId(fyId);
      setState(() {
        _periods = periods;
        final now = DateTime.now();
        try {
          _selectedPeriod = periods.firstWhere((p) =>
              now.isAfter(
                  p.periodStartDate.subtract(const Duration(days: 1))) &&
              now.isBefore(p.periodEndDate.add(const Duration(days: 1))));
        } catch (_) {
          _selectedPeriod = periods.isNotEmpty ? periods.first : null;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error fetching periods: $e')));
      }
    }
  }

  Future<void> _fetchEntries() async {
    setState(() => _isLoading = true);
    try {
      final data = await _entryService.fetchEntries(
        periodId: _selectedPeriod?.id,
        fiscalYearId:
            _selectedPeriod == null ? _selectedFiscalYear?.id : null,
      );
      setState(() {
        _entries = data;
        _applyFilter();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error fetching entries: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) {
      _filteredEntries = List.from(_entries);
      return;
    }

    final keywords = query.toLowerCase().split(RegExp(r'\s+'));
    final dateFmt = DateFormat('dd/MM/yyyy');

    _filteredEntries = _entries.where((item) {
      final fields = [
        item.docCode,
        item.docName,
        item.docNo,
        dateFmt.format(item.docDate),
        item.refDocCode ?? '',
        item.refDocName ?? '',
        item.refDocNo ?? '',
        item.refDocDate != null ? dateFmt.format(item.refDocDate!) : '',
        item.description,
        item.status,
      ].map((f) => f.toLowerCase()).toList();

      // All keywords must match at least one field
      return keywords.every((kw) => fields.any((f) => f.contains(kw)));
    }).toList();
  }

  Future<void> _deleteEntry(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: const Text('ต้องการลบรายการนี้ใช่หรือไม่?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ลบ', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _entryService.deleteEntry(id);
        _fetchEntries();
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('ลบรายการสำเร็จ')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('ลบไม่สำเร็จ: $e')));
        }
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Draft':
        return Colors.red;
      case 'Deleted':
        return Colors.grey;
      case 'Posted':
        return Colors.black;
      default:
        return Colors.black;
    }
  }

  String _formatPeriodLabel(PostingPeriod p) {
    final fmt = DateFormat('dd/MM/yyyy');
    return '${p.periodName} (${fmt.format(p.periodStartDate)} - ${fmt.format(p.periodEndDate)})';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              // Fiscal Year
              SizedBox(
                width: 120,
                child: DropdownButtonFormField<FiscalYear>(
                  value: _selectedFiscalYear,
                  isExpanded: true,
                  items: _fiscalYears
                      .map((fy) => DropdownMenuItem(
                          value: fy,
                          child: Text(fy.fyCode,
                              overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedFiscalYear = val;
                        _selectedPeriod = null;
                        _periods = [];
                      });
                      _fetchPeriods(val.id).then((_) => _fetchEntries());
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'ปีบัญชี',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Period
              SizedBox(
                width: 280,
                child: DropdownButtonFormField<PostingPeriod>(
                  value: _selectedPeriod,
                  isExpanded: true,
                  items: _periods
                      .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(_formatPeriodLabel(p),
                              overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (val) {
                    setState(() => _selectedPeriod = val);
                    _fetchEntries();
                  },
                  decoration: const InputDecoration(
                    labelText: 'งวด',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Search
              Expanded(
                child: TextFormField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    labelText: 'ค้นหา (คั่นหลายคำด้วยวรรค)',
                    hintText: 'เช่น: JV draft 2024',
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchCtrl.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            tooltip: 'ล้างคำค้น',
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _applyFilter());
                            },
                          ),
                        const Icon(Icons.search),
                        const SizedBox(width: 4),
                      ],
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _applyFilter()),
                ),
              ),
              const SizedBox(width: 8),
              // Add Button
              IconButton(
                icon: const Icon(Icons.add_circle,
                    size: 32, color: Colors.green),
                tooltip: 'เพิ่มรายการใหม่',
                onPressed: widget.onAddPressed,
              ),
            ],
          ),
        ),
        // Result count
        if (!_isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _searchCtrl.text.trim().isEmpty
                    ? '${_filteredEntries.length} รายการ'
                    : 'พบ ${_filteredEntries.length} รายการ จาก ${_entries.length} รายการ',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredEntries.isEmpty
                  ? Center(
                      child: Text(_entries.isEmpty
                          ? 'ไม่พบรายการบัญชีตามเงื่อนไข'
                          : 'ไม่พบรายการที่ตรงกับคำค้น'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: _filteredEntries.length,
                      separatorBuilder: (ctx, i) =>
                          const SizedBox(height: 2),
                      itemBuilder: (ctx, index) {
                        final item = _filteredEntries[index];
                        final textColor = _getStatusColor(item.status);
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  _getStatusColor(item.status),
                              child: Text(item.status[0],
                                  style: const TextStyle(
                                      color: Colors.white)),
                            ),
                            title: Text('${item.docCode} ${item.docNo}',
                                style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              'วันที่: ${item.docDate.toString().split(' ')[0]} | ${item.description}',
                              style: TextStyle(
                                  color: textColor.withOpacity(0.8)),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                        NumberFormat("#,##0.00")
                                            .format(item.totalDebitLc),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text(item.status,
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: _getStatusColor(
                                                item.status))),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.visibility,
                                      color: Colors.blue),
                                  tooltip: 'ดูรายละเอียด',
                                  onPressed: () =>
                                      widget.onViewPressed(item.id),
                                ),
                                if (item.status == 'Draft')
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.orange),
                                    tooltip: 'แก้ไข',
                                    onPressed: () =>
                                        widget.onEditPressed(item.id),
                                  ),
                                if (item.status == 'Draft')
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    tooltip: 'ลบทั้งใบ',
                                    onPressed: () =>
                                        _deleteEntry(item.id),
                                  ),
                              ],
                            ),
                            onTap: () => widget.onViewPressed(item.id),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
