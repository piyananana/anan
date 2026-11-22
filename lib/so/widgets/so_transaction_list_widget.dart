import 'package:flutter/material.dart';
import '../models/so_transaction.dart';
import '../services/so_transaction_service.dart';
import '../../sa/widgets/sa_order_doc_list.dart';

// หน้ารายการ — แบบเดียวกับหน้ารายการ IM: ใช้ OrderDocListWidget (sa_order_doc_list.dart) ร่วมกับ SO/PO/ใบเสนอราคา/PR
class SoTransactionListWidget extends StatelessWidget {
  final Function(int) onEditPressed;
  final Function(int) onViewPressed;
  final bool shouldRefresh;
  final VoidCallback onRefreshComplete;
  final bool enableEditButton;

  const SoTransactionListWidget({
    super.key,
    required this.onEditPressed,
    required this.onViewPressed,
    required this.shouldRefresh,
    required this.onRefreshComplete,
    this.enableEditButton = true,
  });

  static final _service = SoTransactionService();

  static final _config = OrderDocListConfig(
    prefKey: 'so_list_filter_collapsed',
    statuses: const ['Draft', 'Submitted', 'Rejected', 'Approved', 'PartiallyDelivered', 'FullyDelivered', 'Closed', 'Void', 'Deleted'],
    statusLabel: soTransactionStatusLabel,
    partyLabel: (en) => en ? 'Customer' : 'ลูกค้า',
    docNoLabel: (en) => en ? 'SO No. / Warehouse' : 'เลขที่ใบสั่งขาย / คลัง',
    dueLabel: (en) => en ? 'Due Date' : 'ครบกำหนด',
    refLabel: (en) => en ? 'Customer PO' : 'ใบสั่งซื้อลูกค้า',
    valueLabel: (en) => en ? 'Before VAT' : 'ก่อน VAT',
    searchTooltip: (en) => en ? 'Doc no. / customer PO / description' : 'เลขที่ / ใบสั่งซื้อลูกค้า / คำอธิบาย',
  );

  static OrderDocRow _row(SoTransactionHeader r) => OrderDocRow(
        id: r.id,
        docNo: r.docNo,
        docDate: r.docDate,
        status: r.status,
        partyCode: r.customerCode,
        partyNameTh: r.customerNameTh,
        partyNameEn: r.customerNameEn,
        warehouseCode: r.warehouseCode,
        warehouseNameTh: r.warehouseNameTh,
        warehouseNameEn: r.warehouseNameEn,
        dueDate: r.dueDate,
        ref: r.customerPoNo,
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
