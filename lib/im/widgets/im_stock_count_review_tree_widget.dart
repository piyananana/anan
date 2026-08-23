// lib/im/widgets/im_stock_count_review_tree_widget.dart
// ผัง location แบบอ่านอย่างเดียว (ไม่ใช่ picker) — ใช้ในหน้าจอสร้างข้อมูลตรวจนับ (ข้อ 2) เพื่อให้ผู้ใช้
// ตรวจสอบว่าสินค้าที่ดึงมาจากยอดคงเหลืออยู่ใน bin ที่ถูกต้องหรือไม่ ก่อนบันทึกลงใบตรวจนับ
// default ย่อไว้ทั้งหมด (เหมือน ImLocationTreeWidget ที่ _expandedState เริ่มว่าง = ย่อ)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sa/services/sa_language_provider.dart';
import '../models/im_location.dart';
import '../models/im_stock_count.dart';
import '../services/im_location_service.dart';

class ImStockCountReviewTreeWidget extends StatefulWidget {
  final int warehouseId;
  final List<ImStockCountDetail> details;

  const ImStockCountReviewTreeWidget({super.key, required this.warehouseId, required this.details});

  @override
  State<ImStockCountReviewTreeWidget> createState() => _ImStockCountReviewTreeWidgetState();
}

class _ImStockCountReviewTreeWidgetState extends State<ImStockCountReviewTreeWidget> {
  final ImLocationService _svc = ImLocationService();
  List<ImLocation> _locations = [];
  bool _isLoading = false;
  final Map<int, bool> _expandedState = {};

  @override
  void initState() {
    super.initState();
    _fetchLocations();
  }

  @override
  void didUpdateWidget(covariant ImStockCountReviewTreeWidget old) {
    super.didUpdateWidget(old);
    if (widget.warehouseId != old.warehouseId) _fetchLocations();
  }

  Future<void> _fetchLocations() async {
    setState(() => _isLoading = true);
    try {
      final fetched = await _svc.fetchRows(warehouseId: widget.warehouseId);
      if (mounted) setState(() { _locations = fetched; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ImLocation> _children(int? parentId) =>
      _locations.where((l) => l.parentId == parentId).toList()..sort((a, b) => a.locationCode.compareTo(b.locationCode));

  List<ImStockCountDetail> _linesForLocation(int locationId) =>
      widget.details.where((d) => d.locationId == locationId).toList()..sort((a, b) => (a.itemCode ?? '').compareTo(b.itemCode ?? ''));

  Widget _buildNode(ImLocation item, int level, bool isEnglish) {
    final isGroup = item.locationType == 'GROUP';
    final children = _children(item.id);
    final lines = isGroup ? const <ImStockCountDetail>[] : _linesForLocation(item.id);
    final hasExpandableContent = children.isNotEmpty || lines.isNotEmpty;
    final isExpanded = _expandedState[item.id] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: hasExpandableContent ? () => setState(() => _expandedState[item.id] = !isExpanded) : null,
          child: Padding(
            padding: EdgeInsets.only(left: level * 16.0, top: 4, bottom: 4),
            child: Row(children: [
              if (hasExpandableContent)
                Icon(isExpanded ? Icons.arrow_drop_down : Icons.arrow_right, color: Colors.black87)
              else
                const SizedBox(width: 24),
              Icon(isGroup ? Icons.folder_outlined : Icons.inventory_2_outlined, color: Colors.black54, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('${item.locationCode}  ${item.locationName ?? ''}', style: const TextStyle(fontSize: 15))),
              if (!isGroup)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    isEnglish ? '${lines.length} items' : '${lines.length} รายการ',
                    style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade700),
                  ),
                ),
            ]),
          ),
        ),
        if (isExpanded) ...[
          ...children.map((c) => _buildNode(c, level + 1, isEnglish)),
          ...lines.map((d) => Padding(
                padding: EdgeInsets.only(left: (level + 1) * 16.0 + 24, top: 2, bottom: 2),
                child: Row(children: [
                  const Icon(Icons.circle, size: 6, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${d.itemCode ?? ''} — ${d.itemName ?? ''}',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(d.uomCode ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ]),
              )),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = context.watch<LanguageProvider>().isEnglish;
    if (_isLoading) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    final topLevel = _children(null);
    if (topLevel.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(isEnglish ? 'No location plan found for this warehouse' : 'ไม่พบผังตำแหน่งจัดเก็บของคลังนี้', style: TextStyle(color: Colors.grey.shade600)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: topLevel.map((l) => _buildNode(l, 0, isEnglish)).toList(),
    );
  }
}
