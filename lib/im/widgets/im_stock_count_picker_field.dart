// lib/im/widgets/im_stock_count_picker_field.dart
// Picker กลาง "เลือกเลขที่ใบตรวจนับ" ใช้ร่วมกันในหน้าจอ 3/4/5/6 — แสดงเฉพาะใบที่ยังไม่ปิด/ยกเลิก
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/im_stock_count.dart';
import '../services/im_stock_count_service.dart';
import '../../sa/services/sa_language_provider.dart';

class ImStockCountPickerField extends StatefulWidget {
  final void Function(ImStockCountHeader) onSelected;

  const ImStockCountPickerField({super.key, required this.onSelected});

  static Future<void> search(BuildContext context, {required void Function(ImStockCountHeader) onSelected}) {
    final isEnglish = Provider.of<LanguageProvider>(context, listen: false).isEnglish;
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        title: Text(isEnglish ? 'Select Count Sheet' : 'เลือกใบตรวจนับ', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 480,
          height: 560,
          child: ImStockCountPickerField(onSelected: (h) {
            onSelected(h);
            Navigator.of(ctx).pop();
          }),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(isEnglish ? 'Close' : 'ปิด', style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  @override
  State<ImStockCountPickerField> createState() => _ImStockCountPickerFieldState();
}

class _ImStockCountPickerFieldState extends State<ImStockCountPickerField> {
  final ImStockCountService _service = ImStockCountService();
  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _searchCtrl = TextEditingController();
  List<ImStockCountHeader> _rows = [];
  List<ImStockCountHeader> _filtered = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final rows = await _service.fetchRows(excludeClosedVoid: true);
      if (mounted) setState(() { _rows = rows; _filtered = rows; });
    } catch (_) {
      // เงียบไว้ — dialog picker ไม่จำเป็นต้องมี error banner
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? _rows
          : _rows.where((r) => r.countNo.toLowerCase().contains(query) || (r.warehouseCode ?? '').toLowerCase().contains(query)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: isEnglish ? 'Search count no. / warehouse' : 'ค้นหาเลขที่ใบตรวจนับ / คลัง',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: _applyFilter,
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(child: Text(isEnglish ? 'No count sheets found' : 'ไม่พบใบตรวจนับ'))
                  : ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final h = _filtered[i];
                        return ListTile(
                          dense: true,
                          title: Text(h.countNo, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '${_dateFmt.format(h.countDate)}   ${h.warehouseCode ?? ''} ${h.warehouseNameTh ?? ''}   [${h.status}]',
                          ),
                          onTap: () => widget.onSelected(h),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
