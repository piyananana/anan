import 'package:flutter/material.dart';
import '../models/po_pr_transaction.dart';
import '../services/po_pr_transaction_service.dart';
import '../../sa/widgets/sa_order_doc_list.dart';

// หน้ารายการ — แบบเดียวกับหน้ารายการ IM: ใช้ OrderDocListWidget (sa_order_doc_list.dart) ร่วมกับ SO/PO/ใบเสนอราคา/PR
class PrTransactionListWidget extends StatelessWidget {
  final Function(int) onEditPressed;
  final Function(int) onViewPressed;
  final bool shouldRefresh;
  final VoidCallback onRefreshComplete;
  final bool enableEditButton;

  const PrTransactionListWidget({
    super.key,
    required this.onEditPressed,
    required this.onViewPressed,
    required this.shouldRefresh,
    required this.onRefreshComplete,
    this.enableEditButton = true,
  });

  static final _service = PrTransactionService();

  static final _config = OrderDocListConfig(
    prefKey: 'pr_list_filter_collapsed',
    statuses: const ['Draft', 'Submitted', 'Approved', 'Rejected', 'PartiallyConverted', 'FullyConverted', 'Closed', 'Void', 'Deleted'],
    statusLabel: prTransactionStatusLabel,
    partyLabel: (en) => en ? 'Vendor' : 'ผู้ขาย',
    docNoLabel: (en) => en ? 'PR No. / Warehouse' : 'เลขที่ใบขอซื้อ / คลัง',
    personLabel: (en) => en ? 'Requester' : 'ผู้ขอ',
    valueLabel: (en) => en ? 'Est. Value' : 'มูลค่าประมาณ',
    searchTooltip: (en) => en ? 'Doc no. / requester / vendor / description' : 'เลขที่ / ผู้ขอ / ผู้ขาย / คำอธิบาย',
  );

  static OrderDocRow _row(PrTransactionHeader r) => OrderDocRow(
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
        person: r.requestedByName,
        totalQty: r.totalQty,
        valueLc: r.totalValueLc,
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
