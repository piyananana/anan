import 'package:flutter/material.dart';
import '../models/mo_header.dart';
import '../services/mo_header_service.dart';
import '../../sa/widgets/sa_order_doc_list.dart';

// หน้ารายการใบสั่งผลิต — แบบเดียวกับหน้ารายการ IM: ใช้ OrderDocListWidget (sa_order_doc_list.dart)
// คู่ค้า = สินค้าที่ผลิต (สินค้าหลักของ BOM), จำนวน = จำนวนสั่งผลิต + หน่วย, ไม่มีคอลัมน์มูลค่า
class MoHeaderListWidget extends StatelessWidget {
  final Function(int) onEditPressed;
  final Function(int) onViewPressed;
  final bool shouldRefresh;
  final VoidCallback onRefreshComplete;
  final bool enableEditButton;

  const MoHeaderListWidget({
    super.key,
    required this.onEditPressed,
    required this.onViewPressed,
    required this.shouldRefresh,
    required this.onRefreshComplete,
    this.enableEditButton = true,
  });

  static final _service = MoHeaderService();

  static final _config = OrderDocListConfig(
    prefKey: 'mo_list_filter_collapsed',
    statuses: const ['Draft', 'Submitted', 'Rejected', 'Released', 'InProgress', 'Completed', 'Closed', 'Cancelled', 'Deleted'],
    statusLabel: moHeaderStatusLabel,
    partyLabel: (en) => en ? 'Item' : 'สินค้าที่ผลิต',
    docNoLabel: (en) => en ? 'MO No. / Warehouse' : 'เลขที่ใบสั่งผลิต / คลัง',
    dueLabel: (en) => en ? 'Due Date' : 'ครบกำหนด',
    qtyLabel: (en) => en ? 'Order Qty' : 'จำนวนสั่งผลิต',
    searchTooltip: (en) => en ? 'Doc no. / item / description' : 'เลขที่ / สินค้า / คำอธิบาย',
  );

  static OrderDocRow _row(MoHeader r) => OrderDocRow(
        id: r.id,
        docNo: r.docNo,
        docDate: r.docDate,
        status: r.status,
        partyCode: r.bomParentItemCode,
        partyNameTh: r.bomParentItemNameTh,
        partyNameEn: r.bomParentItemNameEn,
        warehouseCode: r.warehouseCode,
        warehouseNameTh: r.warehouseNameTh,
        warehouseNameEn: r.warehouseNameEn,
        dueDate: r.dueDate,
        totalQty: r.orderQty,
        qtyUnit: r.uomCode,
        description: r.description,
      );

  @override
  Widget build(BuildContext context) => OrderDocListWidget(
        config: _config,
        fetch: ({required dateFrom, required dateTo, required includeDeleted}) async =>
            (await _service.fetchRows(dateFrom: dateFrom, dateTo: dateTo, includeDeleted: includeDeleted)).map(_row).toList(),
        onEditPressed: onEditPressed,
        onViewPressed: onViewPressed,
        shouldRefresh: shouldRefresh,
        onRefreshComplete: onRefreshComplete,
        enableEditButton: enableEditButton,
      );
}
