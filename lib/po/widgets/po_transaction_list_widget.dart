import 'package:flutter/material.dart';
import '../models/po_transaction.dart';
import '../services/po_transaction_service.dart';
import '../../sa/widgets/sa_order_doc_list.dart';

// หน้ารายการ — แบบเดียวกับหน้ารายการ IM: ใช้ OrderDocListWidget (sa_order_doc_list.dart) ร่วมกับ SO/PO/ใบเสนอราคา/PR
class PoTransactionListWidget extends StatelessWidget {
  final Function(int) onEditPressed;
  final Function(int) onViewPressed;
  final bool shouldRefresh;
  final VoidCallback onRefreshComplete;
  final bool enableEditButton;

  const PoTransactionListWidget({
    super.key,
    required this.onEditPressed,
    required this.onViewPressed,
    required this.shouldRefresh,
    required this.onRefreshComplete,
    this.enableEditButton = true,
  });

  static final _service = PoTransactionService();

  static final _config = OrderDocListConfig(
    prefKey: 'po_list_filter_collapsed',
    statuses: const ['Draft', 'Submitted', 'Rejected', 'Approved', 'PartiallyReceived', 'FullyReceived', 'Closed', 'Void', 'Deleted'],
    statusLabel: poTransactionStatusLabel,
    partyLabel: (en) => en ? 'Vendor' : 'ผู้ขาย',
    docNoLabel: (en) => en ? 'PO No. / Warehouse' : 'เลขที่ใบสั่งซื้อ / คลัง',
    dueLabel: (en) => en ? 'Due Date' : 'ครบกำหนด',
    valueLabel: (en) => en ? 'Before VAT' : 'ก่อน VAT',
    searchTooltip: (en) => en ? 'Doc no. / vendor / description' : 'เลขที่ / ผู้ขาย / คำอธิบาย',
  );

  static OrderDocRow _row(PoTransactionHeader r) => OrderDocRow(
        id: r.id,
        docNo: r.docNo,
        docDate: r.docDate,
        status: r.status,
        partyCode: r.vendorCode,
        partyNameTh: r.vendorNameTh,
        partyNameEn: r.vendorNameEn,
        warehouseCode: r.warehouseCode,
        warehouseNameTh: r.warehouseNameTh,
        warehouseNameEn: r.warehouseNameEn,
        dueDate: r.dueDate,
        totalQty: r.totalQty,
        valueLc: r.totalValueLc,
        totalLc: r.totalAmountLc,
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
